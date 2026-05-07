import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/batch/model/batch_header_model.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/lapping/presentation/lapping_detail_screen.dart';
import 'package:active_wear_scanning/features/processing/presentation/widgets/batch_scan_summary.dart';
import 'package:active_wear_scanning/features/processing/presentation/widgets/processing_tray_table.dart';
import 'package:active_wear_scanning/features/processing/repo/processing_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../lapping/presentation/lapping_detail_screen.dart';

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
  });

  @override
  State<ProcessingBatchDetailsScreen> createState() => _ProcessingBatchDetailsScreenState();
}

class _ProcessingBatchDetailsScreenState extends State<ProcessingBatchDetailsScreen> {
  final _processingRepo = ProcessingRepo();
  final _batchRepo = BatchRepo();
  bool _showTrays = false;
  bool _isLoadingTrays = false;
  List<ProductionProgressResponseModel> _trays = [];
  double? _machineCapacity;
  bool _hasPreviousProcess = false;

  static final _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );

  bool _isReworkMode = false;
  final Set<int> _selectedReworkTrayIds = {};
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
    _checkReworkCapability();
    _fetchMachineCapacity();
    _fetchBatchHeader();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchTraysIfNeeded();
    });
  }

  Future<void> _fetchMachineCapacity() async {
    if (widget.machineId == null) return;
    final res = await _batchRepo.fetchMachineById(widget.machineId!);
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
      final res = await _batchRepo.fetchBatchHeaderById(widget.batchHeaderId);
      if (!res.success || res.data == null) return;
      final bh = BatchHeaderResponseModel.fromJson(
          res.data as Map<String, dynamic>);
      final trayDetailId = bh.batchHeader.trayDetailId;
      if (trayDetailId != null) {
        final trayRes = await _batchRepo.fetchTrayDetailById(trayDetailId);
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

  Future<void> _checkReworkCapability() async {
    final res = await _processingRepo.fetchProcessingOperations();
    if (res.success && res.data != null) {
      final allOps = res.data as List<Operation>;
      final currentOp = allOps.firstWhere((o) => o.id == widget.currentOperationId, orElse: () => allOps.first);
      final currentSeq = int.tryParse(currentOp.identifierRef ?? '0') ?? 0;
      
      final hasPrev = allOps.any((op) {
        final seq = int.tryParse(op.identifierRef ?? '999') ?? 999;
        return seq < currentSeq && op.processNature == 1;
      });

      if (mounted) setState(() => _hasPreviousProcess = hasPrev);
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
          // Sort by trayCode consistently so order never changes between fetches
          list.sort((a, b) => (a.primaryTrayModel.trayCode ?? '').compareTo(b.primaryTrayModel.trayCode ?? ''));

          // Enrich each tray with color/size/perGarmentTube from item-defs API
          final enrichedList = <ProductionProgressResponseModel>[];
          for (final tray in list) {
            final mainItemId = tray.item.id; // Always use main item for display metadata
            final processedItemId = tray.productionProgress.processedItemId;

            String colorDesc = tray.item.colorDescription ?? '';
            String sizeDesc = tray.item.sizeDescription ?? '';
            double perGarmentTube = tray.item.perGarmentTube ?? 0;

            if (mainItemId > 0) {
              final itemRes = await _batchRepo.fetchItemDef(mainItemId);
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
              final processedRes = await _batchRepo.fetchItemDef(processedItemId);
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
    final isReassignedBatch = _trays.isNotEmpty && _trays.every((t) => t.primaryTrayModel.isReAssigned == true);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ExcludeSemantics(
          excluding: _isLoadingTrays,
          child: Column(
            children: [
              CustomInspectionHeader(
                heading: 'Batch Details',
                subtitle: widget.batchCode,
                isShowBackIcon: true,
                topPadding: 10,
                horizontalPadding: 12,
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _isLoadingTrays,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Batch Overview',
                          subtitle: 'Detailed information and actions for this batch',
                        ),
                        const SizedBox(height: 12),
                        ContentCard(
                          child: Column(
                            children: [
                              DynamicInfoDisplay(
                                items: {
                                  'batch': {'icon': Icons.qr_code, 'label': 'Batch ID', 'value': widget.batchCode},
                                  'machine': {'icon': Icons.precision_manufacturing, 'label': 'Machine', 'value': widget.machine},
                                  'color': {'icon': Icons.palette, 'label': 'Color', 'value': widget.color},
                                  'operation': {'icon': Icons.settings_applications, 'label': 'Current Process', 'value': widget.operationName},
                                  if (widget.nextOperationName.isNotEmpty && widget.nextOperationName != 'Completed')
                                    'next_process': {'icon': Icons.arrow_forward_outlined, 'label': 'Next Process', 'value': widget.nextOperationName},
                                  if (!isLapping) 'is_rework': {'icon': Icons.sync_problem, 'label': 'Is Rework', 'value': isReworkBatch ? 'Yes' : 'No'},
                                  'is_reassigned': {'icon': Icons.assignment_turned_in, 'label': 'Re-assigned', 'value': isReassignedBatch ? 'Yes' : 'No'},
                                  if (_reworkTargetOpName != null)
                                    'rework_to': {'icon': Icons.subdirectory_arrow_left, 'label': 'Rework To', 'value': _reworkTargetOpName!},
                                  if (_issueTime != null)
                                    'issue_time': {'icon': Icons.schedule, 'label': 'Issue Time', 'value': _formatTime(_issueTime!)},
                                  if (_startTime != null)
                                    'start_time': {'icon': Icons.play_circle_outline, 'label': 'Start Time', 'value': _formatTime(_startTime!)},
                                  if (_isBatchStarted && _issueTime != null && _startTime != null)
                                    'idle_time': {'icon': Icons.hourglass_empty, 'label': 'Idle Time', 'value': _formatDuration(_startTime!.difference(_issueTime!))},
                                  'trolley': {
                                    'icon': Icons.local_shipping_outlined,
                                    'label': 'Trolley',
                                    'value': _trolleyCode ?? 'Not Assigned',
                                  },
                                },
                              ),
                              const SizedBox(height: 16),
                              BatchScanSummary(
                                trays: _trays,
                                machineCapacity: _machineCapacity,
                              ),
                              const Divider(height: 32),
                              SizedBox(
                                height: 48,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: CustomOutlinedButton(
                                        label: _showTrays ? 'Hide Trays' : 'Show Trays',
                                        borderColor: Colors.blue,
                                        textColor: _showTrays ? Colors.white : Colors.blue,
                                        fillColor: _showTrays ? Colors.blue : Colors.white,
                                        onPressed: _toggleTrayDetails,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // ── Start button: visible only when not yet started ──
                                    if (!_isBatchStarted) ...[
                                      Expanded(
                                        flex: 3,
                                        child: CustomOutlinedButton(
                                          label: 'Start',
                                          icon: Icons.play_arrow_rounded,
                                          borderColor: Colors.green,
                                          fillColor: Colors.green,
                                          textColor: Colors.white,
                                          onPressed: _trays.isEmpty ? null : _confirmStart,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    if (_hasPreviousProcess && !isLapping) ...[
                                      Expanded(
                                        flex: 3,
                                        child: CustomOutlinedButton(
                                          label: _isReworkMode ? 'Cancel' : 'Rework',
                                          borderColor: _isReworkMode ? Colors.red : Colors.orange,
                                          textColor: _isReworkMode ? Colors.red : Colors.orange,
                                          onPressed: () {
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
                                      const SizedBox(width: 4),
                                    ],
                                    if (isLapping && !isReassignedBatch) ...[
                                      Expanded(
                                        flex: 3,
                                        child: CustomOutlinedButton(
                                          label: 'Re-assign',
                                          borderColor: Colors.teal,
                                          textColor: Colors.teal,
                                          onPressed: () async {
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
                                              Navigator.pop(context, true);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    // ── Trolley: Free if attached, Scan if not ─────
                                    Expanded(
                                      flex: 3,
                                      child: _trolleyCode != null
                                          ? CustomOutlinedButton(
                                              label: 'Free Trolley',
                                              icon: Icons.link_off,
                                              borderColor: Colors.red.shade400,
                                              textColor: Colors.red.shade400,
                                              onPressed: _isUpdatingTrolley ? null : _confirmFreeTrolley,
                                            )
                                          : CustomOutlinedButton(
                                              label: 'Scan Trolley',
                                              icon: Icons.qr_code_scanner,
                                              borderColor: Colors.teal,
                                              textColor: Colors.teal,
                                              onPressed: _isUpdatingTrolley ? null : _showScanTrolleyDialog,
                                            ),
                                    ),
                                    const SizedBox(width: 4),
                                    // ── Submit: disabled until batch is started ─────
                                    Expanded(
                                      flex: 3,
                                      child: Builder(builder: (_) {
                                        final submitBlocked = !_isBatchStarted || (isLapping && !isReassignedBatch && !_isReworkMode);
                                        return CustomOutlinedButton(
                                          label: 'Submit',
                                          borderColor: submitBlocked ? Colors.grey.shade400 : Colors.green,
                                          textColor: submitBlocked ? Colors.grey.shade400 : Colors.green,
                                          onPressed: submitBlocked ? null : _confirmSubmit,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showTrays) ...[
                          const SizedBox(height: 16),
                          ProcessingTrayTable(
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
      final bhRes = await _batchRepo.fetchBatchHeaderById(widget.batchHeaderId);
      if (!bhRes.success || bhRes.data == null) {
        AppLoader.hide(context);
        setState(() => _isUpdatingTrolley = false);
        _showError('Failed to fetch batch header');
        return;
      }
      final bh = BatchHeaderResponseModel.fromJson(
          bhRes.data as Map<String, dynamic>).batchHeader;
      final updateRes = await _batchRepo.updateBatchHeader(widget.batchHeaderId, {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trolley freed. Scan a new trolley before submitting.'), backgroundColor: Colors.orange),
        );
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
      final result = await _batchRepo.fetchTrayDetailByCode(code);
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
      final bhRes = await _batchRepo.fetchBatchHeaderById(widget.batchHeaderId);
      if (!bhRes.success || bhRes.data == null) {
        AppLoader.hide(context);
        setState(() => _isUpdatingTrolley = false);
        return 'Failed to fetch batch header';
      }
      final bh = BatchHeaderResponseModel.fromJson(
          bhRes.data as Map<String, dynamic>).batchHeader;
      final updateRes = await _batchRepo.updateBatchHeader(widget.batchHeaderId, {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trolley "$resolvedCode" attached successfully.'),
            backgroundColor: Colors.green,
          ),
        );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Some trays failed to start. Please retry.'), backgroundColor: Colors.red),
      );
    } else {
      setState(() {
        _isBatchStarted = true;
        _startTime = now;
      });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please scan a trolley before submitting.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
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
      final targetOpId = widget.nextOperationId ?? widget.currentOperationId;
      int nextLocatorId = 10;
      final locRes = await _processingRepo.fetchLocators(operationId: targetOpId);
      if (locRes.success && locRes.data != null) {
        final locList = locRes.data as List;
        final match = locList.cast<Map>().firstWhere(
          (e) => (e['operation']?['id'] ?? e['locator']?['operationId'])?.toString() == targetOpId.toString(),
          orElse: () => {},
        );
        if (match.isNotEmpty) nextLocatorId = match['locator']?['id'] as int? ?? 10;
      }

      for (final t in _trays) {
        final pp = t.productionProgress;
        final json = pp.toJson();
        final isRework = _isReworkMode && _selectedReworkTrayIds.contains(pp.id);

        if (isRework) {
          json['transactionType'] = 3;
          json['reworkFlag'] = true;
          await _processingRepo.updateProductionProgress(pp.id!, json);

          int rewLoc = 10;
          final rewRes = await _processingRepo.fetchLocators(operationId: _reworkTargetOpId!);
          if (rewRes.success && rewRes.data != null) {
            final rl = rewRes.data as List;
            final rm = rl.cast<Map>().firstWhere(
                  (e) => (e['operation']?['id'] ?? e['locator']?['operationId'])?.toString() == _reworkTargetOpId.toString(),
              orElse: () => {},
            );
            if (rm.isNotEmpty) rewLoc = rm['locator']?['id'] as int? ?? 10;
          }

          final newJ = pp.toJson();
          newJ.remove('id');
          newJ.remove('progressCode');
          newJ.addAll({
            'transactionType': 2,
            'reworkFlag': true,
            'operationId': _reworkTargetOpId,
            'locatorId': rewLoc,
            'date': DateTime.now().toIso8601String(),
          });
          await _processingRepo.createProductionProgress(newJ);
        } else if (widget.nextOperationId != null) {
          json['transactionType'] = 3;
          await _processingRepo.updateProductionProgress(pp.id!, json);

          final newJ = pp.toJson();
              newJ.remove('id');
              newJ.remove('progressCode');
              newJ.addAll({
                'transactionType': 2,
                'operationId': widget.nextOperationId,
                'locatorId': nextLocatorId,
                'date': DateTime.now().toIso8601String(),
                'isStarted': false,
                'startDate': null,
              });
              await _processingRepo.createProductionProgress(newJ);
        } else {
          json['transactionType'] = 3;
          json['wipStatus'] = 1;
          json['isLastProcess'] = true; // ✅ Flags tray as ready for Induction
          await _processingRepo.updateProductionProgress(pp.id!, json);
        }
      }

      if (mounted) {
        AppLoader.hide(context);
        Navigator.pop(context, true);
      }
    } catch (e) {
      AppLoader.hide(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Removed _buildTrayTable, _buildScanSummary, _statTile, and _verticalDivider as they are extracted
}
