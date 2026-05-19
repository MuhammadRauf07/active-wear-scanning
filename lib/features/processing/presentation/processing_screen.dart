import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/features/processing/model/batch_summary_item.dart';
//import 'package:active_wear_scanning/features/processing/model/processing_model.dart';
import 'package:active_wear_scanning/features/processing/presentation/processing_batch_details.dart';
import 'package:active_wear_scanning/features/processing/presentation/widgets/batch_details_table.dart';
import 'package:active_wear_scanning/features/batch/model/batch_header_model.dart';
import 'package:active_wear_scanning/features/tray/repo/tray_scanning_repo.dart';
import 'package:active_wear_scanning/features/tray/model/tray_details_model.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/content_card.dart';
import '../../../core/widgets/custom_outlined_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../batch/repo/batch_repo.dart';
import '../../lapping/presentation/lapping_detail_screen.dart';
import '../repo/processing_repo.dart';
import '../../gbs/model/production_progress.dart';
import '../../common-models/common_models.dart';
import 'processing_batch_details.dart';

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
  final _batchRepo = BatchRepo();
  final _trayRepo = TrayScanningRepo();
  final _batchBarcodeController = TextEditingController();

  List<Operation> _operations = [];
  Map<int, int> _opBatchCounts = {};
  Map<int, List<BatchSummaryItem>> _opBatchDetails = {};
  Map<int, bool> _loadingDetails = {};
  Map<int, String> _trayIdToCode = {}; // trayDetailId → trayCode lookup
  static final Map<int, List<DisposedBatch>> _disposedBatches = {};
  static final Map<int, List<OptimisticTransfer>> _optimisticCache = {};

  Operation? _selectedOperation;
  bool _isLoadingOperations = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchOperations();
    });
  }

  Future<void> _fetchOperations() async {
    try {
      if (mounted) setState(() => _isLoadingOperations = true);
      AppLoader.show(context, message: 'Loading Operations...');

      // Build tray lookup map once
      final trayRes = await _trayRepo.fetchAvailableTrayDetails();
      if (trayRes.success && trayRes.data != null) {
        for (final t in trayRes.data as List<TrayDetailsModel>) {
          final id = t.trayDetails?.id;
          final code = t.trayDetails?.trayCode;
          if (id != null && code != null) _trayIdToCode[id] = code;
        }
      }

      final res = await _processingRepo.fetchProcessingOperations();
      if (res.success && res.data != null) {
        final List<Operation> allOps = List<Operation>.from(res.data);
        if (mounted) {
          setState(() {
            _operations =
                allOps.where((op) {
                  final isProcessing = op.processNature == 1;
                  final isNumeric = RegExp(r'^\d+$').hasMatch(op.code);
                  return isProcessing && isNumeric;
                }).toList()..sort(
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
    final List<Future> futures = [];
    for (var op in _operations) {
      futures.add(_fetchBatchCount(op.id));
    }
    await Future.wait(futures);
    if (mounted) setState(() => _isInitialLoading = false);
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
    });
    if (res.success && res.data != null) {
      final list = res.data as List<ProductionProgressResponseModel>;
      final uniqueBatches = <int>{};
      for (var r in list) {
        if (r.productionProgress.transactionType != 2) continue; // Local filter fallback
        if (r.productionProgress.operationId != operationId) continue; // Critical: Ensure it belongs to this lane
        
        final bhId = r.productionProgress.batchHeaderId;
        if (bhId != null) {
          if (_isBatchDisposed(operationId, bhId)) continue; // Mask eventual consistency lag
          uniqueBatches.add(bhId);
        }
      }

      // Inject non-expired optimistic cache counts
      final pending = _optimisticCache[operationId] ?? [];
      final now = DateTime.now();
      pending.removeWhere((x) => now.difference(x.timestamp).inSeconds > 25);
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
    if (!force && _opBatchDetails.containsKey(operationId)) return;

    try {
      setState(() {
        _loadingDetails[operationId] = true;
        if (force) _opBatchDetails.remove(operationId);
      });

      final res = await _processingRepo.fetchProductionProgress({
        'OperationId': operationId.toString(),
        'TransactionType': '2',
      });

      if (res.success && res.data != null) {
        final records = res.data as List<ProductionProgressResponseModel>;
        final Map<int, List<ProductionProgressResponseModel>> grouped = {};

        for (final r in records) {
          if (r.productionProgress.transactionType != 2) continue; // Local filter fallback
          if (r.productionProgress.operationId != operationId) continue; // Critical: Ensure it belongs to this lane
          
          final bhId = r.productionProgress.batchHeaderId;
          if (bhId != null) {
            if (_isBatchDisposed(operationId, bhId)) continue; // Mask eventual consistency lag

            final groupList = grouped.putIfAbsent(bhId, () => []);
            final trayCode = r.primaryTrayModel.trayCode ?? 'UNKNOWN';
            final existingIdx = groupList.indexWhere((e) => (e.primaryTrayModel.trayCode ?? 'UNKNOWN') == trayCode);
            if (existingIdx != -1) {
              if ((r.productionProgress.id ?? 0) > (groupList[existingIdx].productionProgress.id ?? 0)) {
                groupList[existingIdx] = r;
              }
            } else {
              groupList.add(r);
            }
          }
        }

        final List<BatchSummaryItem> summaries = [];
        for (final entry in grouped.entries) {
          final bhId = entry.key;
          final groupRecords = entry.value;

          final bhRes = await _batchRepo.fetchBatchHeaderById(bhId);
          if (bhRes.success && bhRes.data != null) {
            final bhFull = BatchHeaderResponseModel.fromJson(bhRes.data);

            // Prefer batch header machine (the user-selected machine when creating the batch).
            // When bhFull.machine is null (API returns machineId as scalar only), fetch by ID.
            String? machineCode =
                bhFull.machine?.brand ?? bhFull.machine?.resourceCode;
            if (machineCode == null && bhFull.batchHeader.machineId != null) {
              final mRes = await _batchRepo.fetchMachineById(
                bhFull.batchHeader.machineId!,
              );
              if (mRes.success && mRes.data != null) {
                final mData = mRes.data as Map<String, dynamic>;
                final mJson = mData['resource'] ?? mData;
                machineCode =
                    mJson['brand']?.toString() ??
                    mJson['resourceCode']?.toString();
              }
            }
            machineCode ??=
                groupRecords.first.machineModel.brand ??
                groupRecords.first.machineModel.resourceCode ??
                '-';

            double totalWeight = 0;
            double totalTubes = 0;
            for (final gr in groupRecords) {
              final qty = gr.productionProgress.primaryQuantity ?? 0;
              final pw = gr.item.pieceWeight ?? 0;
              totalTubes += qty;
              totalWeight += qty * pw;
            }

            final bool isStarted = groupRecords.any((r) => r.productionProgress.isStarted ?? false);
            final bool isRework = groupRecords.any((r) => r.productionProgress.reworkFlag ?? false);
            final bool isReassigned = groupRecords.any((r) => r.primaryTrayModel.isReAssigned ?? false);

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
                trolleyCode: bhFull.batchHeader.trayDetailId != null
                    ? _trayIdToCode[bhFull.batchHeader.trayDetailId]
                    : null,
                isStarted: isStarted,
                reworkFlag: isRework,
                isReassigned: isReassigned,
              ),
            );
          }
        }

        // Inject non-expired optimistic cache items
        final pending = _optimisticCache[operationId] ?? [];
        final now = DateTime.now();
        pending.removeWhere((x) => now.difference(x.timestamp).inSeconds > 25);
        for (final opt in pending) {
          if (!summaries.any((b) => b.batchHeaderId == opt.batchHeaderId) &&
              !_isBatchDisposed(operationId, opt.batchHeaderId)) {
            summaries.add(opt.item);
          }
        }

        if (mounted) {
          setState(() {
            _opBatchDetails[operationId] = summaries;
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

  void _onScanBatch() async {
    final barcode = _batchBarcodeController.text.trim();
    if (barcode.isEmpty) return;
  }  @override
  Widget build(BuildContext context) {
    bool isAnyLoading =
        _isLoadingOperations || _loadingDetails.values.any((e) => e);

    return Scaffold(
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

            // 2. Search & Filter Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: TextField(
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Search Batch # or Operation...',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF1B64A3)),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Operation Grid
            Expanded(
              child: AbsorbPointer(
                absorbing: isAnyLoading,
                child: _isLoadingOperations
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
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
                                color: isSelected ? const Color(0xFF1B64A3) : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: const Color(0xFF1B64A3).withValues(alpha: 0.08),
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
                                        _fetchOpDetails(op.id);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    color: isSelected ? const Color(0xFF1B64A3).withValues(alpha: 0.03) : Colors.white,
                                    child: Row(
                                      children: [
                                        // Op Name
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                op.name.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  color: isSelected ? const Color(0xFF1B64A3) : const Color(0xFF334155),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: count > 0 ? const Color(0xFF1B64A3) : const Color(0xFF94A3B8).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (count > 0)
                                                const Padding(
                                                  padding: EdgeInsets.only(right: 4),
                                                  child: Icon(Icons.layers_rounded, size: 10, color: Colors.white),
                                                ),
                                              Text(
                                                '$count BATCHES',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  color: count > 0 ? Colors.white : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          isSelected ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                          size: 20,
                                          color: isSelected ? const Color(0xFF1B64A3) : const Color(0xFFCBD5E1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 1.5, right: 1.5, bottom: 1.5),
                                    child: BatchDetailsTable(
                                      isLoading: _loadingDetails[op.id] == true,
                                      summaries: _opBatchDetails[op.id],
                                      onDetailsPressed: (s) async {
                                        final currentIndex = _operations.indexWhere((o) => o.id == _selectedOperation?.id);
                                        String nextOpName = 'N/A';
                                        int? nextOpId;
                                        if (currentIndex != -1 && currentIndex < _operations.length - 1) {
                                          nextOpName = _operations[currentIndex + 1].name;
                                          nextOpId = _operations[currentIndex + 1].id;
                                        }
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ProcessingBatchDetailsScreen(
                                              batchHeaderId: s.batchHeaderId,
                                              currentOperationId: _selectedOperation!.id,
                                              batchCode: s.batchCode,
                                              machineId: s.machineId,
                                              machine: s.machine,
                                              color: s.color,
                                              trayCount: s.trayCount,
                                              totalWeight: s.totalWeight,
                                              operationName: _selectedOperation?.name ?? '-',
                                              nextOperationName: nextOpName,
                                              nextOperationId: nextOpId,
                                              hasPreviousProcess: currentIndex > 0,
                                            ),
                                          ),
                                        );
                                           if (result != null && result is Map && result['submitted'] == true) {
                                             final List<int> targetOps = [];
                                             if (result['targetOps'] is List) {
                                               for (final item in result['targetOps']) {
                                                 if (item is num) {
                                                   targetOps.add(item.toInt());
                                                 }
                                               }
                                             }
                                             final isRework = result['isRework'] == true;
                                             final isReassigned = result['isReassigned'] == true;
                                             
                                             setState(() {
                                               final dispList = _disposedBatches.putIfAbsent(op.id, () => []);
                                               dispList.removeWhere((x) => x.batchHeaderId == s.batchHeaderId);
                                               dispList.add(DisposedBatch(
                                                 batchHeaderId: s.batchHeaderId!,
                                                 timestamp: DateTime.now(),
                                               ));

                                              final currentList = _opBatchDetails[op.id];
                                              if (currentList != null) {
                                                _opBatchDetails[op.id] = List.from(currentList)
                                                  ..removeWhere((b) => b.batchHeaderId == s.batchHeaderId);
                                              }
                                              
                                              // Optimistic UI updates for counts and lists
                                              final currentCount = _opBatchCounts[op.id] ?? 0;
                                              if (currentCount > 0) {
                                                _opBatchCounts[op.id] = currentCount - 1;
                                              }
                                              
                                              for (final tOpId in targetOps) {
                                                _opBatchCounts[tOpId] = (_opBatchCounts[tOpId] ?? 0) + 1;
                                                
                                                // Optimistically inject the batch into the target lane's list
                                                final targetList = _opBatchDetails[tOpId] ?? [];
                                                // Ensure we don't duplicate if it somehow exists
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
                                                );
                                                if (!targetList.any((b) => b.batchHeaderId == s.batchHeaderId)) {
                                                  _opBatchDetails[tOpId] = List.from(targetList)..add(updatedBatch);
                                                }

                                                // Populate optimistic cache to protect against eventual consistency API delays
                                                final list = _optimisticCache.putIfAbsent(tOpId, () => []);
                                                list.removeWhere((x) => x.batchHeaderId == s.batchHeaderId);
                                                list.add(OptimisticTransfer(
                                                  batchHeaderId: s.batchHeaderId,
                                                  item: updatedBatch,
                                                  timestamp: DateTime.now(),
                                                ));
                                              }

                                              // Collapse the currently expanded process card
                                              _selectedOperation = null;
                                            });
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
    );
  }
}

  // Removed _buildDetailsTable and _BatchSummaryItem as they were extracted.

  // ── Small status / flag badge ────────────────────────────────────────────────
  Widget _statusBadge({
    required String label,
    required Color color,
    required Color bg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

