import 'package:flutter/material.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/features/processing/model/batch_summary_item.dart';
import 'package:active_wear_scanning/features/processing/presentation/processing_batch_details.dart';
import 'package:active_wear_scanning/features/processing/presentation/widgets/batch_details_table.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';
import 'package:active_wear_scanning/features/knitting_production/repo/knitting_production_repo.dart';
import 'package:active_wear_scanning/features/knitting_production/model/tray_details_model.dart';
import '../../../core/widgets/app_loader.dart';
import '../../lot_making/repo/lot_repo.dart';
import '../repo/processing_repo.dart';
import '../../gbs/model/production_progress.dart';
import '../../common-models/common_models.dart';


class OptimisticTransfer {
  final int batchHeaderId;
  final BatchSummaryItem item;
  final DateTime timestamp;

  OptimisticTransfer({
    required this.batchHeaderId,
    required this.item,
    required this.timestamp,
  });
}

class DisposedBatch {
  final int batchHeaderId;
  final DateTime timestamp;

  DisposedBatch({
    required this.batchHeaderId,
    required this.timestamp,
  });
}

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final _processingRepo = ProcessingRepo();
  final _lotRepo = LotRepo();
  final _trayRepo = KnittingProductionRepo();
  final _batchBarcodeController = TextEditingController();

  List<Operation> _operations = [];
  List<Operation> _allOperations = [];
  Map<int, int> _opBatchCounts = {};
  Map<int, List<BatchSummaryItem>> _opBatchDetails = {};
  Map<int, bool> _loadingDetails = {};
  Map<int, String> _trayIdToCode = {}; // trayDetailId → trayCode lookup
  static final Map<int, List<DisposedBatch>> _disposedBatches = {};
  static final Map<int, List<OptimisticTransfer>> _optimisticCache = {};

  Operation? _selectedOperation;
  bool _isLoadingOperations = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchOperations();
    });
  }

  @override
  void dispose() {
    _disposedBatches.clear();
    _optimisticCache.clear();
    super.dispose();
  }

  Future<void> _fetchOperations() async {
    try {
      if (mounted) setState(() => _isLoadingOperations = true);
      AppLoader.show(context, message: 'Loading Operations...');

      // Removed blocking global fetchAvailableTrayDetails setup to load screen instantly.
      // Trolley details will be resolved dynamically on-demand.

      final res = await _processingRepo.fetchProcessingOperations();
      if (res.success && res.data != null) {
        final List<Operation> allOps = List<Operation>.from(res.data);
        if (mounted) {
          setState(() {
            _allOperations = allOps;
            _operations =
            allOps.where((op) {
              final isProcessing = op.processNature == 1;
              final isNumeric = RegExp(r'^\d+$').hasMatch(op.code);
              return isProcessing && isNumeric;
            }).toList()
              ..sort(
                    (a, b) => int.parse(a.code).compareTo(int.parse(b.code)),
              );
          });
        }
        await _fetchAllBatchCounts();

        // Auto-refresh the expanded lane if one is selected
        if (_selectedOperation != null) {
          await _fetchOpDetails(_selectedOperation!.id, force: true);
        }
      }
    } catch (e) {
      debugPrint('Error fetching operations: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingOperations = false);
        AppLoader.hide(context);
      }
    }
  }

  Future<void> _fetchAllBatchCounts() async {
    final res = await _processingRepo.fetchProductionProgress({
      'TransactionType': '2',
      'MaxResultCount': '1000',
    });

    if (res.success && res.data != null) {
      final allRecords = res.data as List<ProductionProgressResponseModel>;

      // Group records by operationId in memory
      final Map<int, List<ProductionProgressResponseModel>> recordsByOp = {};
      for (var r in allRecords) {
        if (r.productionProgress.transactionType != 2) continue;
        if (r.productionProgress.wipStatus != 0) continue;
        final opId = r.productionProgress.operationId;
        if (opId != null) {
          recordsByOp.putIfAbsent(opId, () => []).add(r);
        }
      }

      final newCounts = <int, int>{};
      for (var op in _operations) {
        final list = recordsByOp[op.id] ?? [];
        final uniqueBatches = <int>{};
        for (var r in list) {
          final bhId = r.productionProgress.batchHeaderId;
          if (bhId != null) {
            if (_isBatchDisposed(op.id, bhId)) continue;
            uniqueBatches.add(bhId);
          }
        }

        // Inject non-expired optimistic cache counts
        final pending = _optimisticCache[op.id] ?? [];
        final now = DateTime.now();
        pending.removeWhere((x) => now.difference(x.timestamp).inSeconds > 25);
        for (final opt in pending) {
          if (!_isBatchDisposed(op.id, opt.batchHeaderId)) {
            uniqueBatches.add(opt.batchHeaderId);
          }
        }

        newCounts[op.id] = uniqueBatches.length;
      }

      if (mounted) {
        setState(() {
          _opBatchCounts = newCounts;
        });
      }
    }
  }

  bool _isBatchDisposed(int operationId, int bhId) {
    final list = _disposedBatches[operationId] ?? [];
    final now = DateTime.now();
    list.removeWhere((x) => now.difference(x.timestamp).inSeconds > 25);
    return list.any((x) => x.batchHeaderId == bhId);
  }

  Future<void> _fetchBatchCount(int operationId) async {
    final res = await _processingRepo.fetchProductionProgress({
      'OperationId': operationId.toString(),
      'TransactionType': '2',
      'MaxResultCount': '1000',
    });
    if (res.success && res.data != null) {
      final list = res.data as List<ProductionProgressResponseModel>;
      final uniqueBatches = <int>{};
      for (var r in list) {
        if (r.productionProgress.transactionType != 2) continue;
        if (r.productionProgress.wipStatus != 0) continue;
        if (r.productionProgress.operationId != operationId) continue;

        final bhId = r.productionProgress.batchHeaderId;
        if (bhId != null) {
          if (_isBatchDisposed(operationId, bhId)) continue;
          uniqueBatches.add(bhId);
        }
      }

      // Inject non-expired optimistic cache counts
      final pending = _optimisticCache[operationId] ?? [];
      final now = DateTime.now();
      pending.removeWhere((x) => now.difference(x.timestamp).inSeconds > 120);
      for (final opt in pending) {
        if (!_isBatchDisposed(operationId, opt.batchHeaderId)) {
          uniqueBatches.add(opt.batchHeaderId);
        }
      }

      if (mounted) {
        setState(() {
          _opBatchCounts[operationId] = uniqueBatches.length;
        });
      }
    }
  }

  Future<void> _fetchOpDetails(int operationId, {bool force = false}) async {
    final hasCache = _opBatchDetails.containsKey(operationId);
    if (!force && hasCache) return;

    try {
      setState(() {
        if (!hasCache) {
          _loadingDetails[operationId] = true;
        }
      });

      final res = await _processingRepo.fetchProductionProgress({
        'OperationId': operationId.toString(),
        'TransactionType': '2',
        'MaxResultCount': '1000',
      });

      if (res.success && res.data != null) {
        final records = res.data as List<ProductionProgressResponseModel>;
        final Map<int, List<ProductionProgressResponseModel>> grouped = {};

        for (final r in records) {
          if (r.productionProgress.transactionType != 2) continue;
          if (r.productionProgress.wipStatus != 0) continue;
          if (r.productionProgress.operationId != operationId) continue;

          final bhId = r.productionProgress.batchHeaderId;
          if (bhId != null) {
            if (_isBatchDisposed(operationId, bhId))
              continue; // Mask eventual consistency lag

            final groupList = grouped.putIfAbsent(bhId, () => []);
            final trayCode = r.primaryTrayModel.trayCode ?? 'UNKNOWN';
            final existingIdx = groupList.indexWhere((e) =>
            (e.primaryTrayModel.trayCode ?? 'UNKNOWN') == trayCode);
            if (existingIdx != -1) {
              if ((r.productionProgress.id ?? 0) >
                  (groupList[existingIdx].productionProgress.id ?? 0)) {
                groupList[existingIdx] = r;
              }
            } else {
              groupList.add(r);
            }
          }
        }

        final List<BatchSummaryItem> summaries = [];
        for (final entry in grouped.entries) {
          try {
            final bhId = entry.key;
            final groupRecords = entry.value;

            final bhRes = await _lotRepo.fetchLotHeaderById(bhId);
            if (bhRes.success && bhRes.data != null) {
              final bhFull = LotHeaderResponseModel.fromJson(bhRes.data);

              String? machineCode =
                  bhFull.machine?.brand ?? bhFull.machine?.resourceCode;
              if (machineCode == null && bhFull.batchHeader.machineId != null) {
                final mRes = await _lotRepo.fetchMachineById(
                  bhFull.batchHeader.machineId!,
                );
                if (mRes.success && mRes.data != null) {
                  final mData = mRes.data as Map<String, dynamic>;
                  machineCode = mData['resourceCode']?.toString() ?? mData['brand']?.toString();
                }
              }
              machineCode ??=
                  groupRecords.first.machineModel.brand ??
                      groupRecords.first.machineModel.resourceCode ??
                      '-';

              double totalTubes = 0.0;
              double totalWeight = 0.0;
              for (final gr in groupRecords) {
                final qty = gr.productionProgress.primaryQuantity ?? 0;
                final pw = gr.item.pieceWeight ?? 0;
                totalTubes += qty;
                totalWeight += qty * pw;
              }

              final bool isStarted = groupRecords.any((r) =>
              r.productionProgress.isStarted ?? false);
              final bool isRework = groupRecords.any((r) =>
              r.productionProgress.reworkFlag ?? false);
              
              final blRes = await _lotRepo.fetchLotLines(batchHeaderId: bhId);
              bool isReassigned = false;
              if (blRes.success && blRes.data != null) {
                final linesList = blRes.data as List;
                isReassigned = linesList.any((l) {
                  final dBl = l['batchLines'] as Map<String, dynamic>? ?? l;
                  return dBl['isReAssigned'] == true;
                });
              }

              int? nextOpId;
              String? nextOpName;

              if (blRes.success && blRes.data != null) {
                final linesList = blRes.data as List;
                if (linesList.isNotEmpty) {
                  final firstLine = linesList.first;
                  final bl = firstLine['batchLines'] as Map<String, dynamic>? ?? firstLine;
                  final itemId = bl['itemId'] as int?;
                  final workOrderLineId = bl['workOrderLineId'] as int?;
                  final colorDescription = bhFull.batchHeader.colorDescription;

                  int? firstProcessedItemId;
                  if (workOrderLineId != null && colorDescription != null) {
                    try {
                      final woRes = await _lotRepo.fetchWorkOrderLineDetails(
                        workOrderLineId,
                        colorDescription,
                      );
                      if (woRes.success && woRes.data != null) {
                        final dynamic dData = woRes.data;
                        if (dData is List && dData.isNotEmpty) {
                          final firstItem = dData.first;
                          if (firstItem is Map) {
                            final raw = firstItem['processedItemId'] ?? firstItem['itemId'] ?? firstItem['processIItemd'];
                            if (raw is int) {
                              firstProcessedItemId = raw;
                            } else if (raw is Map) {
                              firstProcessedItemId = raw['id'] as int?;
                            }
                          }
                        } else if (dData is Map) {
                          final raw = dData['processedItemId'] ?? dData['itemId'];
                          if (raw is int) {
                            firstProcessedItemId = raw;
                          } else if (raw is Map) {
                            firstProcessedItemId = raw['id'] as int?;
                          }
                        }
                      }
                    } catch (_) {}
                  }
                  final effectiveItemId = firstProcessedItemId ?? itemId;

                  if (effectiveItemId != null) {
                    final routingRes = await _lotRepo.fetchItemRoutings(effectiveItemId);
                    if (routingRes.success && routingRes.data != null) {
                      final routingItems = routingRes.data as List;
                      final List<Map<String, dynamic>> parsedRoutings = [];
                      for (final r in routingItems) {
                        final map = r is Map<String, dynamic> ? r : {};
                        final ir = map['itemRouting'] as Map<String, dynamic>? ?? map;
                        final opId = ir['operationId'] as int?;
                        final seq = ir['sequence'] as int? ?? ir['seq'] as int?;
                        if (opId != null && seq != null) {
                          parsedRoutings.add({
                            'operationId': opId,
                            'seq': seq,
                          });
                        }
                      }
                      parsedRoutings.sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));

                      final currentIdx = parsedRoutings.indexWhere((r) => r['operationId'] == operationId);
                      if (currentIdx != -1 && currentIdx < parsedRoutings.length - 1) {
                        nextOpId = parsedRoutings[currentIdx + 1]['operationId'] as int?;
                        if (nextOpId != null) {
                          final targetOpIdx = _allOperations.indexWhere((o) => o.id == nextOpId);
                          nextOpName = targetOpIdx != -1 ? _allOperations[targetOpIdx].name : 'N/A';
                        }
                      }
                    }
                  }
                }
              }

              String? trolleyCode;
              final trayDetailId = bhFull.batchHeader.trayDetailId;
              if (trayDetailId != null) {
                if (_trayIdToCode.containsKey(trayDetailId)) {
                  trolleyCode = _trayIdToCode[trayDetailId];
                } else {
                  final tRes = await _lotRepo.fetchTrayDetailById(trayDetailId);
                  if (tRes.success && tRes.data != null) {
                    final tJson = tRes.data as Map;
                    final tdJson = tJson['trayDetails'] ?? tJson['trayDetail'] ?? tJson;
                    final tCode = tdJson['trayCode']?.toString();
                    if (tCode != null) {
                      _trayIdToCode[trayDetailId] = tCode;
                      trolleyCode = tCode;
                    }
                  }
                }
              }

              final bool isDraft = groupRecords.any((r) => r.productionProgress.pbsFlag == true || r.productionProgress.draftFlag == true);

              summaries.add(
                BatchSummaryItem(
                  batchHeaderId: bhId,
                  machineId: bhFull.batchHeader.machineId,
                  batchCode: bhFull.batchHeader.batchHeaderCode ?? '-',
                  machine: machineCode,
                  color: bhFull.batchHeader.colorDescription ?? '-',
                  trayCount: groupRecords.length,
                  totalTubes: totalTubes,
                  totalWeight: totalWeight,
                  trolleyCode: trolleyCode,
                  isStarted: isStarted,
                  reworkFlag: isRework,
                  isReassigned: isReassigned,
                  isDraft: isDraft,
                  nextOperationId: nextOpId,
                  nextOperationName: nextOpName,
                ),
              );
            }
          } catch (itemErr) {
            debugPrint('Error processing batch $entry: $itemErr');
          }
        }

        // Inject non-expired optimistic cache items
        final pending = _optimisticCache[operationId] ?? [];
        final now = DateTime.now();
        pending.removeWhere((x) =>
        now
            .difference(x.timestamp)
            .inSeconds > 120);
        for (final opt in pending) {
          if (!summaries.any((b) => b.batchHeaderId == opt.batchHeaderId) &&
              !_isBatchDisposed(operationId, opt.batchHeaderId)) {
            summaries.add(opt.item);
          }
        }

        if (mounted) {
          setState(() {
            _opBatchDetails[operationId] = summaries;
            _opBatchCounts[operationId] = summaries.length;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching op details: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingDetails[operationId] = false);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    bool isAnyLoading =
        _isLoadingOperations || _loadingDetails.values.any((e) => e);

    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Slate 100 Background
        body: SafeArea(
          child: Column(
            children: [
              // 1. Technical Header
              CustomInspectionHeader(
                heading: 'WIP PROCESSING',
                subtitle: 'Manufacturing Status & Tracking',
                isShowBackIcon: true,
                topPadding: 0,
                horizontalPadding: 16,
                onBackPress: () {
                  if (_selectedOperation != null) {
                    setState(() => _selectedOperation = null);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),

              const SizedBox(height: 16),

              // 3. Operation Grid
              Expanded(
                child: AbsorbPointer(
                  absorbing: isAnyLoading,
                  child: _isLoadingOperations && _operations.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _operations.length,
                    itemBuilder: (context, index) {
                      final op = _operations[index];
                      final count = _opBatchCounts[op.id] ?? 0;
                      final isSelected = _selectedOperation?.id == op.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1B64A3)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: const Color(0xFF1B64A3).withValues(
                                  alpha: 0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ] : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                   if (isSelected) {
                                     _selectedOperation = null;
                                   } else {
                                     _selectedOperation = op;
                                     _fetchOpDetails(op.id, force: true);
                                   }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                color: isSelected ? const Color(0xFF1B64A3)
                                    .withValues(alpha: 0.03) : Colors.white,
                                child: Row(
                                  children: [
                                    // Op Name
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text(
                                            op.name.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: isSelected ? const Color(
                                                  0xFF1B64A3) : const Color(
                                                  0xFF334155),
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          Text(
                                            'Work-in-Progress Tracking',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Active Count Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: count > 0 ? const Color(
                                            0xFF1B64A3) : const Color(
                                            0xFF94A3B8).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (count > 0)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                  right: 4),
                                              child: Icon(Icons.layers_rounded,
                                                  size: 10,
                                                  color: Colors.white),
                                            ),
                                          Text(
                                            '$count BATCHES',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: count > 0
                                                  ? Colors.white
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      isSelected ? Icons
                                          .keyboard_arrow_up_rounded : Icons
                                          .keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: isSelected ? const Color(
                                          0xFF1B64A3) : const Color(0xFFCBD5E1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 1.5, right: 1.5, bottom: 1.5),
                                child: BatchDetailsTable(
                                  isLoading: _loadingDetails[op.id] == true,
                                  summaries: _opBatchDetails[op.id],
                                  onDetailsPressed: (s) async {
                                     final currentIndex = _operations
                                         .indexWhere((o) =>
                                     o.id == _selectedOperation?.id);
                                     final nextOpName = s.nextOperationName ?? 'N/A';
                                     final nextOpId = s.nextOperationId;
                                     final activeOpId = _selectedOperation?.id;
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ProcessingBatchDetailsScreen(
                                              batchHeaderId: s.batchHeaderId,
                                              currentOperationId: _selectedOperation!
                                                  .id,
                                              batchCode: s.batchCode,
                                              machineId: s.machineId,
                                              machine: s.machine,
                                              color: s.color,
                                              trayCount: s.trayCount,
                                              totalWeight: s.totalWeight,
                                              operationName: _selectedOperation
                                                  ?.name ?? '-',
                                              nextOperationName: nextOpName,
                                              nextOperationId: nextOpId,
                                              hasPreviousProcess: currentIndex >
                                                  0,
                                            ),
                                      ),
                                    );

                                     if (result != null && result is Map &&
                                         result['submitted'] == true) {
                                       final List<int> targetOps = [];
                                       if (result['targetOps'] is List) {
                                         for (final item in result['targetOps']) {
                                           if (item is num) {
                                             targetOps.add(item.toInt());
                                           }
                                         }
                                       }

                                       if (mounted && activeOpId != null) {
                                         _fetchOpDetails(activeOpId, force: true);
                                         _fetchBatchCount(activeOpId);
                                         for (final tOpId in targetOps) {
                                           _fetchBatchCount(tOpId);
                                           if (_selectedOperation?.id == tOpId) {
                                             _fetchOpDetails(tOpId, force: true);
                                           } else {
                                             _opBatchDetails.remove(tOpId);
                                           }
                                         }
                                       }

                                       final isRework = result['isRework'] == true;
                                       final isReassigned = result['isReassigned'] == true;
                                       final hasRemainingHeldTrays = result['hasRemainingHeldTrays'] == true;

                                       setState(() {
                                         if (!hasRemainingHeldTrays && activeOpId != null) {
                                           final dList = _disposedBatches.putIfAbsent(activeOpId, () => []);
                                           dList.removeWhere((x) => x.batchHeaderId == s.batchHeaderId);
                                           dList.add(DisposedBatch(
                                             batchHeaderId: s.batchHeaderId,
                                             timestamp: DateTime.now(),
                                           ));
                                           final currentList = _opBatchDetails[activeOpId];
                                           if (currentList != null) {
                                             _opBatchDetails[activeOpId] = currentList.where((b) => b.batchHeaderId != s.batchHeaderId).toList();
                                           }
                                           if ((_opBatchCounts[activeOpId] ?? 0) > 0) {
                                             _opBatchCounts[activeOpId] = (_opBatchCounts[activeOpId] ?? 1) - 1;
                                           }
                                         }

                                         for (final tOpId in targetOps) {
                                           _opBatchCounts[tOpId] = (_opBatchCounts[tOpId] ?? 0) + 1;

                                           final targetList = _opBatchDetails[tOpId] ?? [];
                                           final updatedBatch = BatchSummaryItem(
                                             batchHeaderId: s.batchHeaderId,
                                             machineId: s.machineId,
                                             batchCode: s.batchCode,
                                             machine: s.machine,
                                             color: s.color,
                                             trayCount: s.trayCount,
                                             totalTubes: s.totalTubes,
                                             totalWeight: s.totalWeight,
                                             trolleyCode: s.trolleyCode,
                                             isStarted: false,
                                             reworkFlag: isRework || s.reworkFlag,
                                             isReassigned: isReassigned || s.isReassigned,
                                             isDraft: false,
                                           );
                                           if (!targetList.any((b) => b.batchHeaderId == s.batchHeaderId)) {
                                             _opBatchDetails[tOpId] = List.from(targetList)..add(updatedBatch);
                                           }

                                           final list = _optimisticCache.putIfAbsent(tOpId, () => []);
                                           list.removeWhere((x) => x.batchHeaderId == s.batchHeaderId);
                                           list.add(OptimisticTransfer(
                                             batchHeaderId: s.batchHeaderId,
                                             item: updatedBatch,
                                             timestamp: DateTime.now(),
                                           ));
                                         }

                                         _selectedOperation = null;
                                       });
                                     } else {
                                       if (mounted && activeOpId != null) {
                                         _fetchOpDetails(activeOpId, force: true);
                                         _fetchBatchCount(activeOpId);
                                       }
                                     }
                                   },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
