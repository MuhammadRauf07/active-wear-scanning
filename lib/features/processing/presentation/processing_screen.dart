import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/batch/model/batch_header_model.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/processing/repo/processing_repo.dart';
import 'package:flutter/material.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final _processingRepo = ProcessingRepo();
  final _batchRepo = BatchRepo();

  List<Operation> _operations = [];
  Operation? _selectedOperation;
  bool _isLoadingOperations = false;

  // Stats
  final Map<int, int> _opBatchCounts = {};
  final Map<int, List<_BatchSummaryItem>> _opBatchDetails = {};
  final Map<int, bool> _loadingDetails = {};

  @override
  void initState() {
    super.initState();
    _fetchOperations();
  }

  Future<void> _fetchOperations() async {
    setState(() => _isLoadingOperations = true);
    final result = await _processingRepo.fetchProcessingOperations();

    if (result.success && result.data != null) {
      final List<Operation> fetched = result.data as List<Operation>;

      final filteredOps = fetched.where((op) {
        if (op.identifierRef == null) return false;
        if (op.processNature != 1) return false;
        final int? idRef = int.tryParse(op.identifierRef!);
        return idRef != null;
      }).toList();

      filteredOps.sort((a, b) {
        final int valA = int.parse(a.identifierRef!);
        final int valB = int.parse(b.identifierRef!);
        return valA.compareTo(valB);
      });

      if (mounted) {
        setState(() {
          _operations = filteredOps;
          _isLoadingOperations = false;
        });
        _fetchAllBatchCounts();
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingOperations = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading operations: ${result.message}'),
          ),
        );
      }
    }
  }

  Future<void> _fetchAllBatchCounts() async {
    final futures = _operations.map((op) async {
      final res = await _processingRepo.fetchProductionProgress({
        'OperationId': op.id.toString(),
        'TransactionType': '2',
      });
      if (res.success && res.data != null) {
        final records = res.data as List<ProductionProgressResponseModel>;
        final uniqueBatchIds = records
            .map((r) => r.productionProgress.batchHeaderId)
            .whereType<int>()
            .toSet();
        if (mounted) {
          setState(() {
            _opBatchCounts[op.id] = uniqueBatchIds.length;
          });
        }
      }
    });

    await Future.wait(futures);
  }

  Future<void> _fetchOpDetails(int operationId) async {
    if (_opBatchDetails.containsKey(operationId)) return;

    setState(() => _loadingDetails[operationId] = true);

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

        // Fetch Batch Header info
        final bhRes = await _batchRepo.fetchBatchHeaderById(bhId);
        if (bhRes.success && bhRes.data != null) {
          final bhFull = BatchHeaderResponseModel.fromJson(bhRes.data);

          // Use machine from the batch header (prioritize brand like in Batch History)
          // Fallback to production progress machine info if header info is missing
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
          _loadingDetails[operationId] = false;
        });
      }
    } else {
      if (mounted) setState(() => _loadingDetails[operationId] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CustomInspectionHeader(
              heading: 'Processing',
              subtitle: 'WIP transaction',
              isShowBackIcon: true,
              topPadding: 10,
              horizontalPadding: 12,
            ),
            Expanded(
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
                      child: _isLoadingOperations
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _operations.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  'No operations available.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _operations.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, thickness: 1),
                              itemBuilder: (context, index) {
                                final op = _operations[index];
                                final count = _opBatchCounts[op.id] ?? 0;
                                final isSelected =
                                    _selectedOperation?.id == op.id;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedOperation = op;
                                      _fetchOpDetails(op.id);
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    color: isSelected
                                        ? Colors.blue.shade50
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            op.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: isSelected
                                                  ? Colors.blue.shade800
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: count > 0
                                                ? Colors.blue
                                                : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            count.toString(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: count > 0
                                                  ? Colors.white
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 20,
                                          color: isSelected
                                              ? Colors.blue
                                              : Colors.grey.shade300,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (_selectedOperation != null) ...[
                      const SizedBox(height: 20),
                      ContentCard(
                        child: _buildDetailsTable(_selectedOperation!.id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTable(int opId) {
    if (_loadingDetails[opId] == true) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final summaries = _opBatchDetails[opId];
    if (summaries == null || summaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade400, size: 32),
              const SizedBox(height: 8),
              const Text(
                'No batches found for this operation.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'Batch Details: ${_selectedOperation!.name}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'BATCH CODE',
                  style: TextStyle(
                    fontSize: 12,
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
                    fontSize: 12,
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
                    fontSize: 12,
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
                    fontSize: 12,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
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
                        fontSize: 12,
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
                        fontSize: 11,
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
  final String batchCode;
  final String machine;
  final String color;
  final int trayCount;
  final double totalWeight;

  _BatchSummaryItem({
    required this.batchCode,
    required this.machine,
    required this.color,
    required this.trayCount,
    required this.totalWeight,
  });
}
