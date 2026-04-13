import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/processing/repo/processing_repo.dart';
import 'package:flutter/material.dart';

class LappingDetailScreen extends StatefulWidget {
  final int batchHeaderId;
  final String batchCode;

  const LappingDetailScreen({
    super.key,
    required this.batchHeaderId,
    required this.batchCode,
  });

  @override
  State<LappingDetailScreen> createState() => _LappingDetailScreenState();
}

class _LappingDetailScreenState extends State<LappingDetailScreen> {
  final _processingRepo = ProcessingRepo();
  bool _isLoading = false;
  List<ProductionProgressResponseModel> _trays = [];
  final Map<int, _WorkOrderSummary> _workOrders = {};
  int? _selectedWorkOrderId;

  @override
  void initState() {
    super.initState();
    _fetchBatchData();
  }

  Future<void> _fetchBatchData() async {
    setState(() => _isLoading = true);

    final res = await _processingRepo.fetchProductionProgress({
      'BatchHeaderId': widget.batchHeaderId.toString(),
      'TransactionType': '2', // Show active trays
    });

    if (res.success && res.data != null) {
      final List<ProductionProgressResponseModel> fetchedTrays =
          res.data as List<ProductionProgressResponseModel>;

      // Group by Work Order safely
      final Map<int, _WorkOrderSummary> summaries = {};
      for (final tray in fetchedTrays) {
        // Ensure the record has the necessary nested data before processing
        final woId = tray.productionProgress.workOrderHeaderId;

        if (woId != null) {
          if (summaries.containsKey(woId)) {
            final existing = summaries[woId]!;
            summaries[woId] = _WorkOrderSummary(
              id: woId,
              description: existing.description,
              componentDescription: existing.componentDescription,
              trayCount: existing.trayCount + 1,
            );
          } else {
            // Access nested fields safely with fallback values to ensure they are non-nullable
            final woDesc = tray.workOrderHeader.description;
            final itemDesc = tray.item.componentDescription ?? '';

            summaries[woId] = _WorkOrderSummary(
              id: woId,
              description: woDesc,
              componentDescription: itemDesc,
              trayCount: 1,
            );
          }
        }
      }

      setState(() {
        _trays = fetchedTrays;
        _workOrders.clear();
        _workOrders.addAll(summaries);
        _isLoading = false;
        // Safe check for first element
        if (_workOrders.isNotEmpty) {
          _selectedWorkOrderId = _workOrders.keys.first;
        }
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching batch data: ${res.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CustomInspectionHeader(
              heading: 'Lapping Details',
              subtitle: widget.batchCode,
              isShowBackIcon: true,
              topPadding: 10,
              horizontalPadding: 12,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_workOrders.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                'Select Work Order',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            ContentCard(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedWorkOrderId,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.blue,
                                  ),
                                  items: _workOrders.values.map((summary) {
                                    return DropdownMenuItem<int>(
                                      value: summary.id,
                                      child: Text(
                                        summary.dropdownLabel,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(
                                      () => _selectedWorkOrderId = value,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ] else if (!_isLoading && _trays.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No trays found in this batch.'),
                              ),
                            ),
                          const SizedBox(height: 20),
                          // const Center(
                          //   child: Text(
                          //     'Lapping Process Details\nComing Soon',
                          //     textAlign: TextAlign.center,
                          //     style: TextStyle(
                          //       fontSize: 16,
                          //       color: Colors.grey,
                          //       fontWeight: FontWeight.w500,
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkOrderSummary {
  final int id;
  final String description;
  final String componentDescription;
  final int trayCount;

  _WorkOrderSummary({
    required this.id,
    required this.description,
    required this.componentDescription,
    required this.trayCount,
  });

  String get dropdownLabel =>
      '$description - $componentDescription - $trayCount trays';
}
