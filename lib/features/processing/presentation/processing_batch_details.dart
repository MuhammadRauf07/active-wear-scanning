import 'dart:developer' as dev;

import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';
import 'package:active_wear_scanning/features/lot_making/repo/lot_repo.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/lapping/presentation/lapping_detail_screen.dart';
import 'package:active_wear_scanning/features/processing/presentation/widgets/batch_scan_summary.dart';
import 'package:active_wear_scanning/features/processing/presentation/widgets/processing_tray_table.dart';
import 'package:active_wear_scanning/features/processing/repo/processing_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ProcessingBatchDetailsScreen extends StatefulWidget {
  final int batchHeaderId;
  final int currentOperationId;
  final String batchCode;
  final int? machineId;
  final String machine;
  final String color;
  final int trayCount;
  final double totalWeight;
  final String operationName;
  final String nextOperationName;
  final int? nextOperationId;
  final bool hasPreviousProcess;

  const ProcessingBatchDetailsScreen({
    super.key,
    required this.batchHeaderId,
    required this.currentOperationId,
    required this.batchCode,
    this.machineId,
    required this.machine,
    required this.color,
    required this.trayCount,
    required this.totalWeight,
    required this.operationName,
    required this.nextOperationName,
    this.nextOperationId,
    required this.hasPreviousProcess,
  });

  @override
  State<ProcessingBatchDetailsScreen> createState() => _ProcessingBatchDetailsScreenState();
}

class _ProcessingBatchDetailsScreenState extends State<ProcessingBatchDetailsScreen> {
  final _processingRepo = ProcessingRepo();
  final _lotRepo = LotRepo();
  bool _showTrays = false;
  bool _isLoadingTrays = false;
  List<ProductionProgressResponseModel> _trays = [];
  double? _machineCapacity;
  late bool _hasPreviousProcess;

  static final _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );

  bool _isReworkMode = false;
  final Set<int> _selectedReworkTrayIds = {};
  final Set<int> _failedTrayIds = {};
  int? _reworkTargetOpId;
  String? _reworkTargetOpName;

  // ── Batch Start Tracking ───────────────────────────────────────────────
  bool _isBatchStarted = false;
  DateTime? _issueTime;   // creationTime of the production progress records
  DateTime? _startTime;   // startDate from productionProgress (set on Start)

  // ── Trolley Management ───────────────────────────────────────────────
  String? _trolleyCode;
  int? _trolleyDetailId;
  bool _isUpdatingTrolley = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _hasPreviousProcess = widget.hasPreviousProcess;
    _fetchMachineCapacity();
    _fetchBatchHeader();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchTraysIfNeeded();
    });
  }

  Future<void> _fetchMachineCapacity() async {
    if (widget.machineId == null) return;
    final res = await _lotRepo.fetchMachineById(widget.machineId!);
    if (res.success && res.data != null) {
      final mData = res.data as Map<String, dynamic>;
      final mJson = mData['resource'] ?? mData;
      final cap = mJson['capacity'];
      if (cap != null) {
        if (mounted) {
          setState(() {
            _machineCapacity = double.tryParse(cap.toString());
          });
        }
      }
    }
  }

  // ── Fetch batch header to resolve current trolley ────────────────────────
  Future<void> _fetchBatchHeader() async {
    try {
      final res = await _lotRepo.fetchLotHeaderById(widget.batchHeaderId);
      if (!res.success || res.data == null) return;
      final bh = LotHeaderResponseModel.fromJson(
          res.data as Map<String, dynamic>);
      final trayDetailId = bh.batchHeader.trayDetailId;
      if (trayDetailId != null) {
        final trayRes = await _lotRepo.fetchTrayDetailById(trayDetailId);
        if (trayRes.success && trayRes.data != null) {
          final trayRaw = trayRes.data as Map<String, dynamic>;
          // API may return nested {trayDetail:{...}} or flat object
          final tdMap = (trayRaw['trayDetail'] is Map)
              ? Map<String, dynamic>.from(trayRaw['trayDetail'] as Map)
              : trayRaw;
          final code = tdMap['trayCode']?.toString();
          if (mounted) {
            setState(() {
              _trolleyCode = code;
              _trolleyDetailId = trayDetailId;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Fetch batch header error: $e');
    }
  }

  Future<void> _fetchTraysIfNeeded() async {
    if (_trays.isNotEmpty) return;

    AppLoader.show(context, message: 'Loading Trays...');
    setState(() => _isLoadingTrays = true);

    try {
      final res = await _processingRepo.fetchProductionProgress({
        'BatchHeaderId': widget.batchHeaderId.toString(),
        'OperationId': widget.currentOperationId.toString(),
        'TransactionType': '2',
      });
      if (res.success && res.data != null) {
        if (mounted) {
          final list = res.data as List<ProductionProgressResponseModel>;
          
          // ── De-duplicate by Tray Code ──────────────────────────────────────
          // If multiple records exist for the same tray in this op/batch,
          // keep only the one with the highest ID (most recent).
          final Map<String, ProductionProgressResponseModel> uniqueTrays = {};
          for (final tray in list) {
            if (tray.productionProgress.transactionType != 2) continue; // Local filter
            if (tray.productionProgress.operationId != widget.currentOperationId) continue; // Local filter
            final code = tray.primaryTrayModel.trayCode ?? 'UNKNOWN';
            if (!uniqueTrays.containsKey(code) || (tray.productionProgress.id ?? 0) > (uniqueTrays[code]!.productionProgress.id ?? 0)) {
              uniqueTrays[code] = tray;
            }
          }
          final deDuplicatedList = uniqueTrays.values.toList();

          // Sort by trayCode consistently
          deDuplicatedList.sort((a, b) => (a.primaryTrayModel.trayCode ?? '').compareTo(b.primaryTrayModel.trayCode ?? ''));

          // Enrich each tray with color/size/perGarmentTube from item-defs API
          final enrichedList = <ProductionProgressResponseModel>[];
          for (final tray in deDuplicatedList) {
            final mainItemId = tray.item.id; // Always use main item for display metadata
            final processedItemId = tray.productionProgress.processedItemId;

            String colorDesc = tray.item.colorDescription ?? '';
            String sizeDesc = tray.item.sizeDescription ?? '';
            double perGarmentTube = tray.item.perGarmentTube ?? 0;

            if (mainItemId > 0) {
              final itemRes = await _lotRepo.fetchItemDef(mainItemId);
              if (itemRes.success && itemRes.data != null) {
                final itemData = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
                // perGarmentTube always from main item
                if (itemData['perGarmentTube'] != null) {
                  perGarmentTube = (itemData['perGarmentTube'] as num).toDouble();
                }
                // color/size from main item if not null
                if (itemData['colorDescription'] != null) colorDesc = itemData['colorDescription'];
                if (itemData['sizeDescription'] != null) sizeDesc = itemData['sizeDescription'];
              }
            }

            // If color is still empty, try processedItemId as fallback
            if (colorDesc.isEmpty && processedItemId != null && processedItemId > 0) {
              final processedRes = await _lotRepo.fetchItemDef(processedItemId);
              if (processedRes.success && processedRes.data != null) {
                final pd = processedRes.data is Map ? processedRes.data as Map<String, dynamic> : {};
                if (pd['colorDescription'] != null) colorDesc = pd['colorDescription'];
                if (sizeDesc.isEmpty && pd['sizeDescription'] != null) sizeDesc = pd['sizeDescription'];
              }
            }

            final updatedItem = tray.item.copyWith(
              colorDescription: colorDesc,
              sizeDescription: sizeDesc,
              perGarmentTube: perGarmentTube,
            );
            enrichedList.add(tray.copyWith(item: updatedItem));
          }

          setState(() {
            _trays = enrichedList;
            _isLoadingTrays = false;
            // Derive start-tracking state from first tray
            if (enrichedList.isNotEmpty) {
              final pp = enrichedList.first.productionProgress;
              _isBatchStarted = pp.isStarted == true;
              _issueTime = pp.creationTime;
              _startTime = pp.startDate;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading trays: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingTrays = false);
        AppLoader.hide(context);
      }
    }
  }

  Future<void> _toggleTrayDetails() async {
    if (_showTrays) {
      setState(() => _showTrays = false);
      return;
    }
    setState(() => _showTrays = true);
    await _fetchTraysIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final isLapping = widget.operationName.toLowerCase().contains('lapping');
    final isReworkBatch = _trays.isNotEmpty && _trays.any((t) => t.productionProgress.reworkFlag == true);
    final isReassignedBatch = _trays.isNotEmpty && _trays.any((t) => t.primaryTrayModel.isReAssigned == true);

    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          child: Column(
            children: [
              _buildPremiumHeader(context),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _isLoadingTrays,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBatchIntelligenceGrid(),
                        const SizedBox(height: 12),
                        _buildActionConsole(),
                        if (_showTrays) ...[
                          const SizedBox(height: 16),
                          Expanded(
                            child: _buildTrayTableContainer(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context) {
    final isLapping = widget.operationName.toLowerCase().contains('lapping');
    final isReworkBatch = _trays.isNotEmpty && _trays.any((t) => t.productionProgress.reworkFlag == true);
    final isReassignedBatch = _trays.isNotEmpty && _trays.any((t) => t.primaryTrayModel.isReAssigned == true);
    final submitBlocked = !_isBatchStarted || (isLapping && !isReassignedBatch && !_isReworkMode);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFB0BEC5),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const CustomBackButton(),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Batch Processing',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'BATCH: ${widget.batchCode}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: submitBlocked ? null : _confirmSubmit,
              icon: Icon(
                _failedTrayIds.isNotEmpty ? Icons.replay_rounded : Icons.check_circle_rounded,
                size: 16,
              ),
              label: Text(
                _failedTrayIds.isNotEmpty
                    ? 'RETRY SUBMISSION (${_failedTrayIds.length})'
                    : 'SUBMIT BATCH',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _failedTrayIds.isNotEmpty
                    ? const Color(0xFFE65100) // Deep Orange for retry action
                    : const Color(0xFF2E7D32), // Standard Green
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchIntelligenceGrid() {
    final isReworkBatch = _trays.isNotEmpty && _trays.any((t) => t.productionProgress.reworkFlag == true);
    final isReassignedBatch = _trays.isNotEmpty && _trays.any((t) => t.primaryTrayModel.isReAssigned == true);

    return Column(
      children: [
        // ── 1. PREMIUM PROCESS FLOW RIBBON ────────────────────────────────
        _buildProcessFlowRibbon(),
        const SizedBox(height: 16),

        // ── 2. PHYSICAL & OPERATIONAL METRICS HUD ────────────────────────
        _buildAeroIntelligenceGrid(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProcessFlowRibbon() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B64A3), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B64A3).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildProcessNode('CURRENT', widget.operationName, Icons.settings_suggest_rounded, true),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Divider(color: Colors.white38, thickness: 1.5),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
          _buildProcessNode('NEXT', widget.nextOperationName, Icons.arrow_forward_rounded, false),
        ],
      ),
    );
  }

  Widget _buildProcessNode(String label, String value, IconData icon, bool isActive) {
    return Column(
      crossAxisAlignment: isActive ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9, 
            fontWeight: FontWeight.w900, 
            color: Colors.white.withValues(alpha: 0.7), 
            letterSpacing: 1.2
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) Icon(icon, color: Colors.white, size: 16),
            if (isActive) const SizedBox(width: 8),
            Text(
              value.toUpperCase(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            if (!isActive) const SizedBox(width: 8),
            if (!isActive) Icon(icon, color: Colors.white60, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildAeroIntelligenceGrid() {
    final isReworkBatch = _trays.isNotEmpty && _trays.any((t) => t.productionProgress.reworkFlag == true);
    final isReassignedBatch = _trays.isNotEmpty && _trays.any((t) => t.primaryTrayModel.isReAssigned == true);

    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3.2, // Leaner, lower profile
          children: [
            _buildHUDCard('BATCH #', widget.batchCode, Icons.tag_rounded),
            _buildHUDCard('MACHINE', widget.machine, Icons.precision_manufacturing_rounded),
            _buildHUDCard('COLOR', widget.color, Icons.palette_rounded),
            _buildHUDCard('TROLLEY', _trolleyCode ?? 'N/A', Icons.local_shipping_rounded, valueColor: _trolleyCode != null ? const Color(0xFF1B64A3) : const Color(0xFF94A3B8)),
            _buildHUDCard('TRAYS', '${widget.trayCount} UNITS', Icons.inventory_2_rounded),
            _buildHUDCard('WEIGHT', '${widget.totalWeight.toStringAsFixed(1)} g', Icons.scale_rounded),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildModernTime('ISSUED', _issueTime),
              _buildModernTime('STARTED', _startTime),
              _buildModernStatus('RE-ASSIGN', isReassignedBatch ? 'YES' : 'NO', isReassignedBatch ? const Color(0xFF60A5FA) : Colors.white24),
              _buildModernStatus('REWORK', isReworkBatch ? 'YES' : 'NO', isReworkBatch ? const Color(0xFFFB923C) : Colors.white24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHUDCard(String label, String value, IconData icon, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(10), // Reduced from 12
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12, // Slightly smaller for slim fit
                    fontWeight: FontWeight.w900, 
                    color: valueColor ?? const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTime(String label, DateTime? time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(
          time != null ? _formatTimeOnly(time) : '--:--',
          style: TextStyle(
            fontSize: 13, 
            fontWeight: FontWeight.w900, 
            color: time != null ? Colors.white : Colors.white24,
            fontFamily: 'monospace'
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatus(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13, 
            fontWeight: FontWeight.w900, 
            color: valueColor,
            letterSpacing: 0.5
          ),
        ),
      ],
    );
  }

  String _formatTimeOnly(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMetricCard(String label, String value, IconData icon, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.2, strokeAlign: BorderSide.strokeAlignOutside),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF1B64A3), size: 14),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.3)),
          const SizedBox(height: 1),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: valueColor ?? const Color(0xFF1E293B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }



  Widget _buildTimeIndicator(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF78909C)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF90A4AE))),
            Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF455A64))),
          ],
        ),
      ],
    );
  }

  Widget _buildTrayTableContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5, strokeAlign: BorderSide.strokeAlignOutside),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BATCHED TRAYS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5)),
                    Text('Units within current production batch', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF78909C))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFECEFF1), borderRadius: BorderRadius.circular(6)),
                  child: Text('${_trays.length} Units', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF455A64))),
                ),
              ],
            ),
          ),
          Expanded(
            child: ProcessingTrayTable(
              trays: _trays,
              isReworkMode: _isReworkMode,
              selectedReworkTrayIds: _selectedReworkTrayIds,
              onReworkToggle: (progressId, selected) {
                setState(() {
                  if (selected) {
                    _selectedReworkTrayIds.add(progressId);
                  } else {
                    _selectedReworkTrayIds.remove(progressId);
                  }
                });
              },
              onSelectAllToggle: (selected) {
                setState(() {
                  if (selected) {
                    _selectedReworkTrayIds.addAll(
                      _trays.map((t) => t.productionProgress.id).whereType<int>(),
                    );
                  } else {
                    _selectedReworkTrayIds.clear();
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Time formatting helpers ────────────────────────────────────────────────
  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = '${dt.day}/${dt.month}/${dt.year}';
    return '$d $h:$m';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  // ── Trolley: Confirm Free ───────────────────────────────────────────────
  void _confirmFreeTrolley() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Free Trolley'),
        content: Text(
          'Remove trolley "$_trolleyCode" from batch ${widget.batchCode}?\n\n'
          'You will need to re-attach a trolley before submitting.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () { Navigator.pop(ctx); _freeTrolley(); },
            child: const Text('Free Trolley'),
          ),
        ],
      ),
    );
  }

  // ── Trolley: Free (detach from batch header) ───────────────────────────
  Future<void> _freeTrolley() async {
    setState(() => _isUpdatingTrolley = true);
    AppLoader.show(context, message: 'Freeing trolley...');
    try {
      final bhRes = await _lotRepo.fetchLotHeaderById(widget.batchHeaderId);
      if (!bhRes.success || bhRes.data == null) {
        AppLoader.hide(context);
        setState(() => _isUpdatingTrolley = false);
        _showError('Failed to fetch batch header');
        return;
      }
      final bh = LotHeaderResponseModel.fromJson(
          bhRes.data as Map<String, dynamic>).batchHeader;
      final updateRes = await _lotRepo.updateLotHeader(widget.batchHeaderId, {
        'planDate': bh.planDate,
        'colorDescription': bh.colorDescription,
        'lockFlag': bh.lockFlag ?? false,
        'batchHeaderCode': bh.batchHeaderCode,
        'machineId': bh.machineId,
        'colorCode': bh.colorCodeId,
        'shiftId': bh.shiftId,
        'trayDetailId': null,
        'concurrencyStamp': bh.concurrencyStamp,
      });
      AppLoader.hide(context);
      if (updateRes.success) {
        setState(() {
          _trolleyCode = null;
          _trolleyDetailId = null;
          _isUpdatingTrolley = false;
        });
        AppSnackBar.showWarning(context, message: 'Trolley free. Scan a new trolley before submitting.');
      } else {
        setState(() => _isUpdatingTrolley = false);
        _showError('Free failed: ${updateRes.message}');
      }
    } catch (e) {
      AppLoader.hide(context);
      setState(() => _isUpdatingTrolley = false);
      debugPrint('Free trolley error: $e');
    }
  }

  // ── Trolley: Scan dialog ───────────────────────────────────────────────
  // ── Trolley: Open scanner (same as batch list) ──────────────────────────
  Future<void> _showScanTrolleyDialog() async {
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trolley',
      onResult: (scannedCode) async {
        final code = scannedCode.trim();
        if (code.isEmpty) return 'Invalid trolley code';
        return await _attachTrolley(code);
      },
    );
  }

  // ── Trolley: Attach (validate + update batch header) ─────────────────────
  /// Returns null on success, error message string on failure.
  /// The ScannerAlwaysOpen widget shows returned errors inside the scanner UI.
  Future<String?> _attachTrolley(String code) async {
    setState(() => _isUpdatingTrolley = true);
    AppLoader.show(context, message: 'Validating trolley...');
    try {
      // 1. Look up tray detail by code
      final result = await _lotRepo.fetchTrayDetailByCode(code);
      AppLoader.hide(context);

      if (!result.success || result.data == null) {
        setState(() => _isUpdatingTrolley = false);
        return 'Trolley not found: $code';
      }

      // Parse: API may return {trayDetail:{...}} or flat
      final rawMap = result.data as Map<String, dynamic>;
      final tdMap = (rawMap['trayDetail'] is Map)
          ? Map<String, dynamic>.from(rawMap['trayDetail'] as Map)
          : rawMap;

      // 2. Validate active
      if (tdMap['active'] != true) {
        setState(() => _isUpdatingTrolley = false);
        return 'Trolley "$code" is not active';
      }

      // 3. Validate type == 4 (Trolley)
      if ((tdMap['trayType'] as int? ?? 0) != 4) {
        setState(() => _isUpdatingTrolley = false);
        return 'Invalid type. Only Type 4 (Trolley) is allowed.';
      }

      final trolleyId = tdMap['id'] as int?;
      if (trolleyId == null) {
        setState(() => _isUpdatingTrolley = false);
        return 'Could not resolve trolley ID';
      }

      // 4. Uniqueness: batchHeaderId must be null OR equal this batch
      final assignedBatchId = tdMap['batchHeaderId'] as int?;
      if (assignedBatchId != null && assignedBatchId != widget.batchHeaderId) {
        setState(() => _isUpdatingTrolley = false);
        return 'Trolley already assigned to another batch (ID: $assignedBatchId)';
      }

      // 5. Attach: fetch fresh batch header and PUT with new trayDetailId
      AppLoader.show(context, message: 'Attaching trolley...');
      final bhRes = await _lotRepo.fetchLotHeaderById(widget.batchHeaderId);
      if (!bhRes.success || bhRes.data == null) {
        AppLoader.hide(context);
        setState(() => _isUpdatingTrolley = false);
        return 'Failed to fetch batch header';
      }
      final bh = LotHeaderResponseModel.fromJson(
          bhRes.data as Map<String, dynamic>).batchHeader;
      final updateRes = await _lotRepo.updateLotHeader(widget.batchHeaderId, {
        'planDate': bh.planDate,
        'colorDescription': bh.colorDescription,
        'lockFlag': bh.lockFlag ?? false,
        'batchHeaderCode': bh.batchHeaderCode,
        'machineId': bh.machineId,
        'colorCode': bh.colorCodeId,
        'shiftId': bh.shiftId,
        'trayDetailId': trolleyId,
        'concurrencyStamp': bh.concurrencyStamp,
      });
      AppLoader.hide(context);
      if (updateRes.success) {
        final resolvedCode = tdMap['trayCode']?.toString() ?? code;
        setState(() {
          _trolleyCode = resolvedCode;
          _trolleyDetailId = trolleyId;
          _isUpdatingTrolley = false;
        });
        // Close the scanner
        if (mounted) Navigator.of(context).pop();
        AppSnackBar.showSuccess(context, message: 'Trolley "$resolvedCode" attached successfully.');
        return null; // success
      } else {
        setState(() => _isUpdatingTrolley = false);
        return 'Attach failed: ${updateRes.message}';
      }
    } catch (e) {
      AppLoader.hide(context);
      setState(() => _isUpdatingTrolley = false);
      debugPrint('Attach trolley error: $e');
      return 'Unexpected error. Please try again.';
    }
  }

  void _showError(String msg) {
    AppSnackBar.showError(context, message: msg);
  }

  // ── Confirm Start ─────────────────────────────────────────────────────────
  void _confirmStart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Batch'),
        content: Text(
          'Are you sure you want to start batch ${widget.batchCode}?\n'
          '${_trays.length} tray${_trays.length != 1 ? 's' : ''} will be marked as started.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _startBatch();
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  // ── Start Batch ───────────────────────────────────────────────────────────
  Future<void> _startBatch() async {
    AppLoader.show(context, message: 'Starting batch...');
    final now = DateTime.now();
    bool anyFailed = false;

    for (final t in _trays) {
      final pp = t.productionProgress;
      final payload = pp.toJson()
        ..['isStarted'] = true
        ..['startDate'] = now.toIso8601String();
      // Remove read-only fields that the PUT endpoint rejects
      payload.remove('id');
      payload.remove('progressCode');
      payload.remove('creationTime');
      payload.remove('creatorId');
      payload.remove('lastModificationTime');
      payload.remove('lastModifierId');

      final res = await _processingRepo.updateProductionProgress(pp.id!, payload);
      if (!res.success) anyFailed = true;
    }

    AppLoader.hide(context);
    if (!mounted) return;

    if (anyFailed) {
      AppSnackBar.showError(context, message: 'Some trays failed to start. Please retry.');
    } else {
      setState(() {
        _isBatchStarted = true;
        _startTime = now;
        _trays.clear(); // Force refresh to get new concurrency stamps
      });
      await _fetchTraysIfNeeded();
    }
  }

  void _showReworkDialog() async {
    AppLoader.show(context, message: 'Fetching previous operations...');
    final res = await _processingRepo.fetchProcessingOperations();
    AppLoader.hide(context);

    if (!res.success || res.data == null) return;

    final fetchedOps = res.data as List<Operation>;
    final allOps = fetchedOps.where((op) {
      if (op.identifierRef == null) return false;
      if (op.processNature != 1) return false;
      return int.tryParse(op.identifierRef!) != null;
    }).toList();

    final currentOp = allOps.firstWhere((o) => o.id == widget.currentOperationId, orElse: () => allOps.first);
    final currentSeq = int.tryParse(currentOp.identifierRef ?? '0') ?? 0;

    final prevOps = allOps.where((op) {
      final seq = int.tryParse(op.identifierRef ?? '999') ?? 999;
      return seq < currentSeq;
    }).toList();

    if (prevOps.isEmpty || !mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rework Target'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: prevOps.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final op = prevOps[i];
              return ListTile(
                title: Text(op.name),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isReworkMode = true;
                    _reworkTargetOpId = op.id;
                    _reworkTargetOpName = op.name;
                    _showTrays = true;
                  });
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmSubmit() {
    // ── Guard: trolley must be attached ───────────────────────────────────
    if (_trolleyDetailId == null) {
      AppSnackBar.showError(context, message: 'Please scan a trolley before submitting.');
      return;
    }
    String msg = 'Proceed with batch submission?';
    if (_isReworkMode) {
      msg = '${_selectedReworkTrayIds.length} trays will return to $_reworkTargetOpName.\nOthers will proceed to standard flow.';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitBatch();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBatch() async {
    AppLoader.show(context, message: 'Submitting...');
    try {
      final baseProgress = _trays.isNotEmpty ? _trays.first.productionProgress : null;
      final targetOpId = widget.nextOperationId ?? widget.currentOperationId;
      int nextLocatorId = baseProgress?.locatorId ?? 10;
      final locRes = await _processingRepo.fetchLocators(operationId: targetOpId);
      if (locRes.success && locRes.data != null) {
        final List locList = locRes.data is Map ? (locRes.data['items'] ?? []) : locRes.data;
        final match = locList.cast<Map>().firstWhere(
          (e) => (e['operation']?['id'] ?? e['locator']?['operationId'])?.toString() == targetOpId.toString(),
          orElse: () => {},
        );
        if (match.isNotEmpty) nextLocatorId = match['locator']?['id'] as int? ?? (baseProgress?.locatorId ?? 10);
      }

      final List<int> newFailedTrayIds = [];
      final traysToProcess = _trays;

      for (final t in traysToProcess) {
        final pp = t.productionProgress;
        final json = pp.toJson();
        final isRework = _isReworkMode && _selectedReworkTrayIds.contains(pp.id);

        try {
          if (isRework) {
            json['transactionType'] = 3;
            json['wipStatus'] = 1;
            json.remove('id');
            json.remove('progressCode');
            json.remove('creationTime');
            json.remove('creatorId');
            json.remove('lastModificationTime');
            json.remove('lastModifierId');
            final updRes = await _processingRepo.updateProductionProgress(pp.id!, json);
            if (!updRes.success) throw Exception('Update failed: ${updRes.message}');

            int rewLoc = pp.locatorId ?? 10;
            final rewRes = await _processingRepo.fetchLocators(operationId: _reworkTargetOpId!);
            if (rewRes.success && rewRes.data != null) {
              final List rl = rewRes.data is Map ? (rewRes.data['items'] ?? []) : rewRes.data;
              final rm = rl.cast<Map>().firstWhere(
                    (e) => (e['operation']?['id'] ?? e['locator']?['operationId'])?.toString() == _reworkTargetOpId.toString(),
                orElse: () => {},
              );
              if (rm.isNotEmpty) rewLoc = rm['locator']?['id'] as int? ?? (pp.locatorId ?? 10);
            }

            final newJ = pp.toJson();
            newJ.remove('id');
            newJ.remove('progressCode');
            newJ.remove('concurrencyStamp');
            newJ.addAll({
              'transactionType': 2,
              'reworkFlag': true,
              'isStarted': false,
              'startDate': null,
              'machineId': null,
              'batchLinesId': pp.batchLinesId,
              'isLastProcess': false,
              'operationId': _reworkTargetOpId,
              'locatorId': rewLoc,
              'date': DateTime.now().toIso8601String(),
            });
            final crRes = await _processingRepo.createProductionProgress(newJ);
            if (!crRes.success) throw Exception('Create failed: ${crRes.message}');
          } else if (widget.nextOperationId != null) {
            json['transactionType'] = 3;
            json['wipStatus'] = 1;
            json.remove('id');
            json.remove('progressCode');
            json.remove('creationTime');
            json.remove('creatorId');
            json.remove('lastModificationTime');
            json.remove('lastModifierId');
            
            dev.log('🚀 [HEATSET/NEXT] Updating old PP ID ${pp.id} to TxType 3: $json');
            final updRes = await _processingRepo.updateProductionProgress(pp.id!, json);
            dev.log('✅ [HEATSET/NEXT] Update Response: ${updRes.success} | ${updRes.message} | ${updRes.data}');
            if (!updRes.success) throw Exception('Update failed: ${updRes.message}');

            final newJ = pp.toJson();
            newJ.remove('id');
            newJ.remove('progressCode');
            newJ.remove('concurrencyStamp');
            newJ.addAll({
              'transactionType': 2,
              'reworkFlag': pp.reworkFlag ?? false,
              'isStarted': false,
              'startDate': null,
              'machineId': null,
              'batchLinesId': pp.batchLinesId,
              'isLastProcess': false,
              'operationId': widget.nextOperationId,
              'locatorId': nextLocatorId,
              'date': DateTime.now().toIso8601String(),
            });
            final crRes = await _processingRepo.createProductionProgress(newJ);
            if (!crRes.success) throw Exception('Create failed: ${crRes.message}');
          } else {
            json['transactionType'] = 3;
            json['wipStatus'] = 1;
            json['isLastProcess'] = true; // ✅ Flags tray as ready for Induction
            json.remove('id');
            json.remove('progressCode');
            json.remove('creationTime');
            json.remove('creatorId');
            json.remove('lastModificationTime');
            json.remove('lastModifierId');
            final updRes = await _processingRepo.updateProductionProgress(pp.id!, json);
            if (!updRes.success) throw Exception('Update final progress failed: ${updRes.message}');
          }
        } catch (e) {
          dev.log('❌ Tray submission error for PP ${pp.id}: $e');
          newFailedTrayIds.add(pp.id!);
        }
      }

      setState(() {
        if (_failedTrayIds.isEmpty) {
          _failedTrayIds.addAll(newFailedTrayIds);
        } else {
          for (final t in traysToProcess) {
            final id = t.productionProgress.id!;
            if (newFailedTrayIds.contains(id)) {
              _failedTrayIds.add(id);
            } else {
              _failedTrayIds.remove(id);
            }
          }
        }
      });

      if (_failedTrayIds.isNotEmpty) {
        throw Exception('${_failedTrayIds.length} tray(s) failed to submit. Please check connection and retry.');
      }

      if (mounted) {
        AppLoader.hide(context);
        
        final List<int> targetOps = [];
        if (_isReworkMode && _reworkTargetOpId != null) {
          targetOps.add(_reworkTargetOpId!);
        }
        
        bool hasStandard = false;
        if (_isReworkMode) {
          hasStandard = _trays.any((t) => !_selectedReworkTrayIds.contains(t.productionProgress.id));
        } else {
          hasStandard = true;
        }
        
        if (hasStandard && widget.nextOperationId != null) {
          if (!targetOps.contains(widget.nextOperationId!)) {
            targetOps.add(widget.nextOperationId!);
          }
        }

        Navigator.pop(context, {
          'submitted': true,
          'targetOps': targetOps,
          'isRework': _isReworkMode,
          'isReassigned': false,
        });
      }
    } catch (e) {
      AppLoader.hide(context);
      if (mounted) {
        AppSnackBar.showError(context, message: e.toString());
      }
    }
  }

  Widget _buildActionConsole() {
    final isLapping = widget.operationName.toLowerCase().contains('lapping');
    final isReworkBatch = _trays.isNotEmpty && _trays.any((t) => t.productionProgress.reworkFlag == true);
    final isReassignedBatch = _trays.isNotEmpty && _trays.any((t) => t.primaryTrayModel.isReAssigned == true);

    return Container(
      width: double.infinity, // Expand to full width
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONTROL CONSOLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildConsoleButton(
                  label: _showTrays ? 'HIDE' : 'SHOW',
                  icon: _showTrays ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: const Color(0xFF1B64A3),
                  onPressed: _toggleTrayDetails,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildConsoleButton(
                  label: _isBatchStarted ? 'STARTED' : 'START',
                  icon: _isBatchStarted ? Icons.check_circle_outline_rounded : Icons.play_arrow_rounded,
                  color: _isBatchStarted ? const Color(0xFF94A3B8) : const Color(0xFF2E7D32),
                  onPressed: (_isBatchStarted || _trays.isEmpty) ? null : _confirmStart,
                ),
              ),
              const SizedBox(width: 6),
              if (_hasPreviousProcess && !isLapping) ...[
                Expanded(
                  child: _buildConsoleButton(
                    label: _isReworkMode ? 'CANCEL' : 'REWORK',
                    icon: Icons.sync_problem_rounded,
                    color: _isReworkMode ? Colors.red : Colors.orange.shade800,
                    onPressed: !_isBatchStarted
                        ? null
                        : () {
                            if (_isReworkMode) {
                              setState(() {
                                _isReworkMode = false;
                                _selectedReworkTrayIds.clear();
                                _reworkTargetOpId = null;
                                _reworkTargetOpName = null;
                              });
                            } else {
                              _showReworkDialog();
                            }
                          },
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (isLapping && !isReassignedBatch) ...[
                Expanded(
                  child: _buildConsoleButton(
                    label: 'RE-ASSIGN',
                    icon: Icons.assignment_turned_in_rounded,
                    color: Colors.teal,
                    onPressed: !_isBatchStarted ? null : () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LappingDetailScreen(
                            batchHeaderId: widget.batchHeaderId,
                            batchCode: widget.batchCode,
                            machineId: widget.machineId,
                            machine: widget.machine,
                            color: widget.color,
                            trayCount: widget.trayCount,
                            totalWeight: widget.totalWeight,
                            currentOperationId: widget.currentOperationId,
                            nextOperationId: widget.nextOperationId,
                            nextOperationName: widget.nextOperationName,
                          ),
                        ),
                      );
                      if (mounted && result == true) {
                        Navigator.pop(context, {
                          'submitted': true,
                          'targetOps': [if (widget.nextOperationId != null) widget.nextOperationId!],
                          'isReassigned': true,
                          'isRework': false,
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: _buildConsoleButton(
                  label: _trolleyCode != null ? 'FREE TROLLEY' : 'SCAN TROLLEY',
                  icon: _trolleyCode != null ? Icons.link_off_rounded : Icons.qr_code_scanner_rounded,
                  color: _trolleyCode != null ? Colors.red.shade700 : Colors.teal.shade700,
                  onPressed: !_isBatchStarted
                      ? null
                      : (_isUpdatingTrolley ? null : (_trolleyCode != null ? _confirmFreeTrolley : _showScanTrolleyDialog)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleButton({required String label, required IconData icon, required Color color, required VoidCallback? onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        disabledBackgroundColor: const Color(0xFFF1F5F9),
        disabledForegroundColor: const Color(0xFF94A3B8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 8)),
        ],
      ),
    );
  }
}
