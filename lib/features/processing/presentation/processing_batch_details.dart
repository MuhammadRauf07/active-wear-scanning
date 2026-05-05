import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
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

  @override
  void initState() {
    super.initState();
    _checkReworkCapability();
    _fetchMachineCapacity();
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
                                  //'weight': {'icon': Icons.scale, 'label': 'Total Weight', 'value': '${widget.totalWeight.toStringAsFixed(2)} kg'},
                                  //'trays': {'icon': Icons.layers, 'label': 'Tray Count', 'value': '${widget.trayCount} trays'},
                                  'operation': {'icon': Icons.settings_applications, 'label': 'Current Process', 'value': widget.operationName},
                                  if (widget.nextOperationName.isNotEmpty && widget.nextOperationName != 'Completed')
                                    'next_process': {'icon': Icons.arrow_forward_outlined, 'label': 'Next Process', 'value': widget.nextOperationName},
                                  if (!isLapping) 'is_rework': {'icon': Icons.sync_problem, 'label': 'Is Rework', 'value': isReworkBatch ? 'Yes' : 'No'},
                                  'is_reassigned': {'icon': Icons.assignment_turned_in, 'label': 'Re-assigned', 'value': isReassignedBatch ? 'Yes' : 'No'},
                                  if (_reworkTargetOpName != null)
                                    'rework_to': {'icon': Icons.subdirectory_arrow_left, 'label': 'Rework To', 'value': _reworkTargetOpName!},
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildScanSummary(),
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
                                    Expanded(
                                      flex: 3,
                                      child: CustomOutlinedButton(
                                        label: 'Submit',
                                        borderColor: (isLapping && !isReassignedBatch && !_isReworkMode) ? Colors.grey.shade400 : Colors.green,
                                        textColor: (isLapping && !isReassignedBatch && !_isReworkMode) ? Colors.grey.shade400 : Colors.green,
                                        onPressed: (isLapping && !isReassignedBatch && !_isReworkMode) ? null : _confirmSubmit,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showTrays) ...[
                          const SizedBox(height: 20),
                          const SectionHeader(
                            title: 'Internal Trays',
                            subtitle: 'View and manage trays in this operation',
                          ),
                          const SizedBox(height: 12),
                          _buildTrayTable(),
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

  Widget _buildTrayTable() {
    if (_trays.isEmpty) return const Center(child: Text('No trays found'));

    return ContentCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('TRAY CODE', style: _tableHeaderStyle)),
                Expanded(flex: 2, child: Text('ITEM DESCRIPTION', style: _tableHeaderStyle)),
                Expanded(flex: 1, child: Text('COLOR', style: _tableHeaderStyle)),
                Expanded(flex: 1, child: Text('SIZE', style: _tableHeaderStyle)),
                Expanded(flex: 1, child: Text('PCS/TUBE', style: _tableHeaderStyle)),
                Expanded(flex: 1, child: Text('TUBES', style: _tableHeaderStyle)),
                Expanded(flex: 1, child: Text('PCS', style: _tableHeaderStyle)),
                Expanded(flex: 1, child: Text('WEIGHT', style: _tableHeaderStyle)),
                if (_isReworkMode) const SizedBox(width: 44) else const SizedBox(width: 8),
              ],
            ),
          ),
          ..._trays.map((t) {
            final isSel = _selectedReworkTrayIds.contains(t.productionProgress.id);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(t.primaryTrayModel.trayCode ?? '-', style: const TextStyle(fontSize: 13))),
                  Expanded(flex: 2, child: Text(t.item.description ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  Expanded(flex: 1, child: Text(t.item.colorDescription?.isNotEmpty == true ? t.item.colorDescription! : '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  Expanded(flex: 1, child: Text(t.item.sizeDescription?.isNotEmpty == true ? t.item.sizeDescription! : '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  Expanded(flex: 1, child: Text((t.item.perGarmentTube ?? 0) > 0 ? t.item.perGarmentTube!.toStringAsFixed(0) : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo.shade700))),
                  Expanded(flex: 1, child: Text(t.productionProgress.primaryQuantity?.toStringAsFixed(0) ?? '0', style: const TextStyle(fontSize: 13))),
                  Expanded(flex: 1, child: Builder(builder: (_) {
                    final tubes = t.productionProgress.primaryQuantity ?? 0;
                    final pgt = t.item.perGarmentTube ?? 0;
                    final garmentPcs = pgt > 0 ? tubes * pgt : 0;
                    return Text(garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade700));
                  })),
                  Expanded(flex: 1, child: Text('${((t.productionProgress.primaryQuantity ?? 0) * (t.item.pieceWeight ?? 0)).toStringAsFixed(2)} g', style: const TextStyle(fontSize: 13))),
                  if (_isReworkMode)

                    SizedBox(
                      width: 44,
                      child: Checkbox(
                        visualDensity: VisualDensity.compact,
                        value: isSel,
                        activeColor: Colors.orange,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedReworkTrayIds.add(t.productionProgress.id!);
                            } else {
                              _selectedReworkTrayIds.remove(t.productionProgress.id);
                            }
                          });
                        },
                      ),
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Scan Summary ────────────────────────────────────────────────────────────
  Widget _buildScanSummary() {
    // ── Compute aggregates ──────────────────────────────────────────────────
    double totalPcs = 0;
    double totalWeight = 0;
    final Map<String, List<ProductionProgressResponseModel>> byWO = {};

    for (final t in _trays) {
      final qty = t.productionProgress.primaryQuantity ?? 0;
      final pw = t.item.pieceWeight ?? 0;
      totalPcs += qty;
      totalWeight += qty * pw;
      final woCode = t.workOrderHeader?.workOrderCode ?? 'Unknown WO';
      byWO.putIfAbsent(woCode, () => []).add(t);
    }

    final capacity = _machineCapacity;
    final remaining = capacity != null ? (capacity - totalWeight) : null;
    final isOverCapacity = remaining != null && remaining < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 6),
            Text(
              'Scan Summary',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade800,
              ),
            ),
            // const Spacer(),
            // Container(
            //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            //   decoration: BoxDecoration(
            //     color: isOverCapacity ? Colors.red.shade50 : Colors.blue.shade50,
            //     borderRadius: BorderRadius.circular(20),
            //   ),
            //   // child: Text(
            //   //   isOverCapacity ? 'Over Capacity' : 'Live',
            //   //   style: TextStyle(
            //   //     fontSize: 10,
            //   //     fontWeight: FontWeight.bold,
            //   //     color: isOverCapacity ? Colors.red.shade700 : Colors.blue.shade700,
            //   //   ),
            //   // ),
            // ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // ── Stat row: Trays / Pcs / Weight / Capacity / Remaining ──────────
        IntrinsicHeight(
          child: Row(
            children: [
              _statTile('No. of Trays', '${_trays.length}', Icons.layers_outlined),
              _verticalDivider(),
              _statTile('Total Tubes', totalPcs.toStringAsFixed(0), Icons.format_list_numbered),
              if (capacity != null && capacity > 0) ...[
                _verticalDivider(),
                _statTile('Capacity', capacity.toStringAsFixed(1), Icons.settings_input_component),
                // _verticalDivider(),
                // _statTile(
                //   isOverCapacity ? 'Over By' : 'Remaining',
                //   remaining!.abs().toStringAsFixed(1),
                //   isOverCapacity ? Icons.warning_amber_rounded : Icons.hourglass_empty,
                //   valueColor: isOverCapacity ? Colors.red.shade700 : Colors.blue.shade700,
                // ),
              ],
              _verticalDivider(),
              _statTile('Allocated Weight', totalWeight.toStringAsFixed(1), Icons.scale_outlined),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 4),

        // ── WO-grouped expandable list ─────────────────────────────────────
        ...byWO.entries.map((entry) {
          final woCode = entry.key;
          final woTrays = entry.value;
          
          // Group by Item within the WO
          final Map<String, List<ProductionProgressResponseModel>> byItem = {};
          double woPcs = 0;
          double woWeight = 0;
          for (final t in woTrays) {
            final qty = t.productionProgress.primaryQuantity ?? 0;
            final pw = t.item.pieceWeight ?? 0;
            woPcs += qty;
            woWeight += qty * pw;
            final itemDesc = t.item.description;
            byItem.putIfAbsent(itemDesc, () => []).add(t);
          }

          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              childrenPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.assignment_outlined, size: 16, color: Colors.blue.shade700),
              ),
              title: Text(
                woCode,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${woTrays.length} trays · ${woPcs.toStringAsFixed(0)} tubes · ${woWeight.toStringAsFixed(2)} g',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              children: [
                // Sub-header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      Expanded(flex: 5, child: Text('ITEM DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                      Expanded(flex: 2, child: Text('TRAYS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                      Expanded(flex: 2, child: Text('TUBES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                      Expanded(flex: 3, child: Text('WEIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                    ],
                  ),
                ),
                ...byItem.entries.toList().asMap().entries.map((e) {
                  final i = e.key;
                  final itemEntry = e.value;
                  final itemDesc = itemEntry.key;
                  final itemTrays = itemEntry.value;
                  
                  double itemPcs = 0;
                  double itemWeight = 0;
                  for (final t in itemTrays) {
                    final qty = t.productionProgress.primaryQuantity ?? 0;
                    final pw = t.item.pieceWeight ?? 0;
                    itemPcs += qty;
                    itemWeight += qty * pw;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: i.isEven ? Colors.white : Colors.grey.shade50,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            itemDesc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${itemTrays.length}',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            itemPcs.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            '${itemWeight.toStringAsFixed(2)} g',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon, {Color? valueColor}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade600),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 2),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}
