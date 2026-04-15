import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/processing/repo/processing_repo.dart';
import 'package:flutter/material.dart';

import '../../lapping/presentation/lapping_detail_screen.dart';

class ProcessingBatchDetailsScreen extends StatefulWidget {
  final int batchHeaderId;
  final int currentOperationId;
  final String batchCode;
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
  bool _showTrays = false;
  bool _isLoadingTrays = false;
  List<ProductionProgressResponseModel> _trays = [];

  Future<void> _toggleTrayDetails() async {
    if (_showTrays) {
      setState(() => _showTrays = false);
      return;
    }

    if (_trays.isNotEmpty) {
      setState(() => _showTrays = true);
      return;
    }

    setState(() {
      _isLoadingTrays = true;
      _showTrays = true;
    });

    final res = await _processingRepo.fetchProductionProgress({
      'BatchHeaderId': widget.batchHeaderId.toString(),
      'OperationId': widget.currentOperationId.toString(),
      'TransactionType': '2',
    });

    if (res.success && res.data != null) {
      setState(() {
        _trays = res.data as List<ProductionProgressResponseModel>;
        _isLoadingTrays = false;
      });
    } else {
      setState(() => _isLoadingTrays = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading trays: ${res.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AppLoaderContextAttach(
        child: SafeArea(
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
                                'batch': {
                                  'icon': Icons.qr_code,
                                  'label': 'Batch ID',
                                  'value': widget.batchCode,
                                },
                                'machine': {
                                  'icon': Icons.precision_manufacturing,
                                  'label': 'Machine',
                                  'value': widget.machine,
                                },
                                'color': {
                                  'icon': Icons.palette,
                                  'label': 'Color',
                                  'value': widget.color,
                                },
                                'weight': {
                                  'icon': Icons.scale,
                                  'label': 'Total Weight',
                                  'value': '${widget.totalWeight.toStringAsFixed(2)} kg',
                                },
                                'trays': {
                                  'icon': Icons.layers,
                                  'label': 'Tray Count',
                                  'value': '${widget.trayCount} trays',
                                },
                                'operation': {
                                  'icon': Icons.settings_applications,
                                  'label': 'Current Process',
                                  'value': widget.operationName,
                                },
                                'next_operation': {
                                  'icon': Icons.next_plan,
                                  'label': 'Next Process',
                                  'value': widget.nextOperationId == null
                                      ? 'N/A (It\'s a last process)'
                                      : widget.nextOperationName,
                                },
                              },
                            ),
                            const Divider(height: 32),
                            // Row(
                            //   children: [
                            //     Expanded(
                            //       child: CustomOutlinedButton(
                            //         label: _showTrays ? 'Hide Trays' : 'Show Trays',
                            //         borderColor: Colors.blue,
                            //         textColor: _showTrays ? Colors.white : Colors.blue,
                            //         fillColor: _showTrays ? Colors.blue : Colors.transparent,
                            //         onPressed: _toggleTrayDetails,
                            //       ),
                            //     ),
                            //     if (!widget.operationName.toLowerCase().contains('lapping')) ...[
                            //       const SizedBox(width: 8),
                            //       Expanded(
                            //         child: CustomOutlinedButton(
                            //           label: 'Rework',
                            //           borderColor: Colors.orange,
                            //           textColor: Colors.orange,
                            //           onPressed: () {
                            //             ScaffoldMessenger.of(context).showSnackBar(
                            //               const SnackBar(content: Text('Rework action initiated')),
                            //             );
                            //           },
                            //         ),
                            //       ),
                            //       const SizedBox(width: 8),
                            //       Expanded(
                            //         child: CustomOutlinedButton(
                            //           label: 'Submit',
                            //           borderColor: Colors.green,
                            //           textColor: Colors.green,
                            //           onPressed: _confirmSubmit,
                            //         ),
                            //       ),
                            //     ],
                            //   ],
                            // ),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomOutlinedButton(
                                    label: _showTrays ? 'Hide Trays' : 'Show Trays',
                                    borderColor: Colors.blue,
                                    textColor: _showTrays ? Colors.white : Colors.blue,
                                    fillColor: _showTrays ? Colors.blue : Colors.transparent,
                                    onPressed: _toggleTrayDetails,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (widget.operationName.toLowerCase().contains('lapping'))
                                // --- Lapping Specific Action ---
                                  Expanded(
                                    child: CustomOutlinedButton(
                                      label: 'Re-assign Trays',
                                      borderColor: Colors.green,
                                      textColor: Colors.green,
                                      onPressed: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => LappingDetailScreen(
                                              batchHeaderId: widget.batchHeaderId,
                                              batchCode: widget.batchCode,
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
                                        // Agar lapping screen se submit ho gaya toh piche bhi refresh bhejain
                                        if (result == true) {
                                          Navigator.pop(context, true);
                                        }
                                      },
                                    ),
                                  )
                                else ...[
                                  // --- Standard Submit/Rework Actions ---
                                  Expanded(
                                    child: CustomOutlinedButton(
                                      label: 'Rework',
                                      borderColor: Colors.orange,
                                      textColor: Colors.orange,
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Rework action initiated')),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: CustomOutlinedButton(
                                      label: 'Submit',
                                      borderColor: Colors.green,
                                      textColor: Colors.green,
                                      onPressed: _confirmSubmit,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_showTrays) ...[
                        const SizedBox(height: 20),
                        const SectionHeader(
                          title: 'Tray Information',
                          subtitle: 'Individual tray details in this batch',
                        ),
                        const SizedBox(height: 12),
                        _buildTrayTable(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSubmit() {
    final String nextProcessText = widget.nextOperationId == null
        ? 'final process completion'
        : 'next process "${widget.nextOperationName}"';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: Text(
            'Are you sure you want to submit batch to $nextProcessText? This will move all trays to the designated workflow stage.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
    AppLoader.show();

    // Ensure trays are loaded
    if (_trays.isEmpty) {
      final res = await _processingRepo.fetchProductionProgress({
        'BatchHeaderId': widget.batchHeaderId.toString(),
        'OperationId': widget.currentOperationId.toString(),
        'TransactionType': '2',
      });
      if (res.success && res.data != null) {
        setState(() {
          _trays = res.data as List<ProductionProgressResponseModel>;
        });
      } else {
        AppLoader.hide();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Failed to fetch trays for submission: ${res.message}')));
        }
        return;
      }
    }

    try {
      for (final t in _trays) {
        // 1. PUT current record (transactionType = 3)
        final currentPp = t.productionProgress;
        final updatedJson = currentPp.toJson();
        updatedJson['transactionType'] = 3;

        final putRes = await _processingRepo.updateProductionProgress(
            currentPp.id!, updatedJson);

        if (!putRes.success) {
          throw Exception(
              'Failed to update tray ${t.primaryTrayModel.trayCode}: ${putRes.message}');
        }

        debugPrint('📤 Submission for Tray: ${t.primaryTrayModel.trayCode}');
        final nextModelJson = currentPp.toJson();
        // Reset key identifiers for the next process/final record
        nextModelJson['transactionType'] = 2;
        nextModelJson.remove('id');
        nextModelJson.remove('progressCode');
        nextModelJson.remove('concurrencyStamp');
        nextModelJson['batchHeaderId'] = widget.batchHeaderId;

        if (widget.nextOperationId != null) {
          // Standard Handover to next operation
          nextModelJson['operationId'] = widget.nextOperationId;
        } else {
          // Final Process: Stay in current operation but set wipStatus to 1
          nextModelJson['wipStatus'] = 1;
        }

        final postRes =
            await _processingRepo.createProductionProgress(nextModelJson);
        if (!postRes.success) {
          throw Exception(
              'Failed to create handover record for tray ${t.primaryTrayModel.trayCode}: ${postRes.message}');
        }
      }

      AppLoader.hide();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Batch submitted successfully!')));
        Navigator.pop(context, true); // Return true to indicate change
      }
    } catch (e) {
      AppLoader.hide();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildTrayTable() {
    if (_isLoadingTrays) {
      return const ContentCard(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_trays.isEmpty) {
      return const ContentCard(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No trays found', style: TextStyle(color: Colors.grey))),
        ),
      );
    }

    return ContentCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('TRAY CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('ITEM DESC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('WEIGHT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          ..._trays.map((t) {
            final qty = t.productionProgress.primaryQuantity ?? 0;
            final pw = t.item.pieceWeight ?? 0;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(t.primaryTrayModel.trayCode ?? '-', style: const TextStyle(fontSize: 12))),
                  Expanded(flex: 3, child: Text(t.item.description ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                  Expanded(flex: 2, child: Text(qty.toString(), style: const TextStyle(fontSize: 12))),
                  Expanded(flex: 2, child: Text('${(qty * pw).toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
