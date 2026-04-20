import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/features/batch/model/batch_header_model.dart';
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

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final _processingRepo = ProcessingRepo();
  final _batchRepo = BatchRepo();
  final _batchBarcodeController = TextEditingController();

  List<Operation> _operations = [];
  Map<int, int> _opBatchCounts = {};
  Map<int, List<_BatchSummaryItem>> _opBatchDetails = {};
  Map<int, bool> _loadingDetails = {};

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

      final res = await _processingRepo.fetchProcessingOperations();
      if (res.success && res.data != null) {
        final List<Operation> allOps = List<Operation>.from(res.data);
        if (mounted) {
          setState(() {
            _operations = allOps.where((op) {
              final isProcessing = op.processNature == 1;
              final isNumeric = RegExp(r'^\d+$').hasMatch(op.code);
              return isProcessing && isNumeric;
            }).toList()
              ..sort((a, b) => int.parse(a.code).compareTo(int.parse(b.code)));
          });
        }
        await _fetchAllBatchCounts();
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

  Future<void> _fetchBatchCount(int operationId) async {
    final res = await _processingRepo.fetchProductionProgress({
      'OperationId': operationId.toString(),
      'TransactionType': '2',
    });
    if (res.success && res.data != null) {
      final list = res.data as List<ProductionProgressResponseModel>;
      final uniqueBatches = <int>{};
      for (var r in list) {
        if (r.productionProgress.batchHeaderId != null) {
          uniqueBatches.add(r.productionProgress.batchHeaderId!);
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
      AppLoader.show(context, message: 'Fetching Batch Details...');
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
          final bhId = r.productionProgress.batchHeaderId;
          if (bhId != null) {
            grouped.putIfAbsent(bhId, () => []).add(r);
          }
        }

        final List<_BatchSummaryItem> summaries = [];
        for (final entry in grouped.entries) {
          final bhId = entry.key;
          final groupRecords = entry.value;

          final bhRes = await _batchRepo.fetchBatchHeaderById(bhId);
          if (bhRes.success && bhRes.data != null) {
            final bhFull = BatchHeaderResponseModel.fromJson(bhRes.data);

            final machineCode =
                bhFull.machine?.brand ??
                bhFull.machine?.resourceCode ??
                groupRecords.first.machineModel.brand ??
                groupRecords.first.machineModel.resourceCode ??
                '-';

            double totalWeight = 0;
            for (final gr in groupRecords) {
              final qty = gr.productionProgress.primaryQuantity ?? 0;
              final pw = gr.item.pieceWeight ?? 0;
              totalWeight += qty * pw;
            }

            summaries.add(
              _BatchSummaryItem(
                batchHeaderId: bhId,
                batchCode: bhFull.batchHeader.batchHeaderCode ?? '-',
                machine: machineCode,
                color: bhFull.batchHeader.colorDescription ?? '-',
                trayCount: groupRecords.length,
                totalWeight: totalWeight,
              ),
            );
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
        AppLoader.hide(context);
      }
    }
  }

  void _onScanBatch() async {
    final barcode = _batchBarcodeController.text.trim();
    if (barcode.isEmpty) return;
  }

  @override
  Widget build(BuildContext context) {
    bool isAnyLoading = _isLoadingOperations || _loadingDetails.values.any((e) => e);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // Wrap EVERYTHING in ExcludeSemantics when loading is active 
        // to prevent semantics tree infinite recursion crashes.
        child: ExcludeSemantics(
          excluding: isAnyLoading,
          child: Column(
            children: [
              CustomInspectionHeader(
                heading: 'Processing',
                subtitle: 'WIP transaction',
                isShowBackIcon: true,
                topPadding: 10,
                horizontalPadding: 12,
                onBackPress: () {
                  if (_selectedOperation != null) {
                    setState(() => _selectedOperation = null);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: isAnyLoading,
              // Expanded(
              //   child: AbsorbPointer(
              //     absorbing: isAnyLoading,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Operation Overview',
                          subtitle: 'Select an operation to view batch details',
                        ),
                        const SizedBox(height: 12),
                        ContentCard(
                          padding: EdgeInsets.zero,
                          child: _isLoadingOperations
                              ? const SizedBox(
                                  height: 140,
                                  child: Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : _operations.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(40),
                                      child: Center(
                                        child: Text(
                                          'No operations found.',
                                          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _operations.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1),
                                      itemBuilder: (context, index) {
                                        final op = _operations[index];
                                        final count = _opBatchCounts[op.id] ?? 0;
                                        final isSelected = _selectedOperation?.id == op.id;

                                        return Column(
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
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 180),
                                                color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        op.name,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                          color: isSelected ? Colors.blue.shade800 : Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: count > 0 ? Colors.blue : Colors.grey.shade200,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        count.toString(),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: count > 0 ? Colors.white : Colors.grey.shade600,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(
                                                      isSelected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                                      size: 20,
                                                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (isSelected)
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: _buildDetailsTable(op.id),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsTable(int opId) {
    if (_loadingDetails[opId] == true) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final summaries = _opBatchDetails[opId];
    if (summaries == null || summaries.isEmpty) {
      return const ContentCard(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 32),
                SizedBox(height: 8),
                Text(
                  'No batches found for this operation.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'BATCH ID',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'MACHINE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'COLOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'TRAYS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'WEIGHT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const Expanded(flex: 3, child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 8),
          ...summaries.map((s) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      s.batchCode,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      s.machine,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      s.color,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${s.trayCount} trays',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${s.totalWeight.toStringAsFixed(2)} kg',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
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
                                  machine: s.machine,
                                  color: s.color,
                                  trayCount: s.trayCount,
                                  totalWeight: s.totalWeight,
                                  operationName: _selectedOperation?.name ?? '-',
                                  nextOperationName: nextOpName,
                                  nextOperationId: nextOpId,
                                ),
                              ),
                            );
                            if (result == true) {
                              SchedulerBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() { _selectedOperation = null; });
                                  _fetchOperations();
                                }
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 34),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          child: const Text('Batch Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BatchSummaryItem {
  final int batchHeaderId;
  final String batchCode;
  final String machine;
  final String color;
  final int trayCount;
  final double totalWeight;

  _BatchSummaryItem({
    required this.batchHeaderId,
    required this.batchCode,
    required this.machine,
    required this.color,
    required this.trayCount,
    required this.totalWeight,
  });
}
