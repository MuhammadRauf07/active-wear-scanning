import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
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
  bool _hasPreviousProcess = false; // ✅ Added to track rework capability

  // Rework State
  bool _isReworkMode = false;
  final Set<int> _selectedReworkTrayIds = {};
  int? _reworkTargetOpId;
  String? _reworkTargetOpName;

  Future<void> _fetchTraysIfNeeded() async {
    if (_trays.isNotEmpty) return;

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
      if (mounted) {
        setState(() {
          _trays = res.data as List<ProductionProgressResponseModel>;
          _isLoadingTrays = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingTrays = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trays: ${res.message}')),
        );
      }
    }
  }

  Future<void> _toggleTrayDetails() async {
    if (_showTrays) {
      setState(() => _showTrays = false);
      return;
    }

    await _fetchTraysIfNeeded();
  }

  @override
  void initState() {
    super.initState();
    _checkReworkCapability(); // ✅ Initial check
  }

  Future<void> _checkReworkCapability() async {
    // We already fetch operations in _showReworkDialog, 
    // but to know if to HIDE the button initially, we can do a quick check here.
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
                                'is_rework': {
                                  'icon': Icons.sync_problem,
                                  'label': 'Is Rework',
                                  'value': (_trays.isNotEmpty && (_trays.first.productionProgress.reworkFlag ?? false)) ? 'Yes' : 'No',
                                },
                                'rework_to': {
                                  'icon': Icons.subdirectory_arrow_left,
                                  'label': 'Rework To',
                                  'value': _reworkTargetOpName ?? 'N/A',
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
                                  if (_hasPreviousProcess) ...[
                                    Expanded(
                                      child: CustomOutlinedButton(
                                        label: _isReworkMode ? 'Cancel Rework' : 'Rework',
                                        borderColor: _isReworkMode ? Colors.red : Colors.orange,
                                        textColor: _isReworkMode ? Colors.red : Colors.orange,
                                        onPressed: () {
                                          if (_isReworkMode) {
                                            setState(() {
                                              _isReworkMode = false;
                                              _selectedReworkTrayIds.clear();
                                              _reworkTargetOpName = null;
                                              _reworkTargetOpId = null;
                                            });
                                          } else {
                                            _showReworkDialog();
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SectionHeader(
                              title: 'Internal Trays',
                              subtitle: 'View and manage trays in this operation',
                            ),
                            if (!_isReworkMode && _trays.isNotEmpty)
                              TextButton.icon(
                                onPressed: _showReworkDialog,
                                icon: const Icon(Icons.history, size: 18, color: Colors.orange),
                                label: const Text('Rework', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                              )
                            else if (_isReworkMode)
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _isReworkMode = false;
                                  _selectedReworkTrayIds.clear();
                                }),
                                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                label: const Text('Cancel Rework', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTrayTable(),
                        if (_isReworkMode && _selectedReworkTrayIds.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: CustomOutlinedButton(
                              label: 'Return to $_reworkTargetOpName',
                              borderColor: Colors.orange,
                              fillColor: Colors.orange,
                              textColor: Colors.white,
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Rework processing starting...'))
                                );
                              },
                            ),
                          ),
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

  void _showReworkDialog() async {
    AppLoader.show(message: 'Fetching previous operations...');
    final res = await _processingRepo.fetchProcessingOperations();
    AppLoader.hide();

    if (!res.success || res.data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load operations')));
      }
      return;
    }

    final fetchedOps = res.data as List<Operation>;
    
    // Apply standard filtering like ProcessingScreen
    final allOps = fetchedOps.where((op) {
      if (op.identifierRef == null) return false;
      if (op.processNature != 1) return false;
      return int.tryParse(op.identifierRef!) != null;
    }).toList();

    // Find current op info to filter previous ones
    final currentOp = allOps.firstWhere(
      (o) => o.id == widget.currentOperationId, 
      orElse: () => Operation(code: '', name: '', description: '', identifierRef: '0', concurrencyStamp: '', creationTime: '', lastModificationTime: '', creatorId: '', lastModifierId: '', id: 0)
    );
    final currentSeq = int.tryParse(currentOp.identifierRef ?? '0') ?? 0;

    final prevOps = allOps.where((op) {
      final seq = int.tryParse(op.identifierRef ?? '999') ?? 999;
      return seq < currentSeq;
    }).toList();

    if (prevOps.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No previous operations found for rework.')));
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 300, // Fixed width for cleaner look
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Rework Target',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: prevOps.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final op = prevOps[index];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _isReworkMode = true;
                          _reworkTargetOpId = op.id;
                          _reworkTargetOpName = op.name;
                          _selectedReworkTrayIds.clear();
                          _showTrays = true; // Ensure UI section is open
                        });
                        _fetchTraysIfNeeded(); // Use non-toggling fetch
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        child: Text(
                          op.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSubmit() {
    String message = 'Are you sure you want to submit batch? This will move all trays to the designated workflow stage.';
    
    if (_isReworkMode) {
      final reworkCount = _selectedReworkTrayIds.length;
      final normalCount = _trays.length - reworkCount;
      message = 'Rework Assignment:\n• $reworkCount trays returning to $_reworkTargetOpName\n• $normalCount trays proceeding to standard flow.';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: Text(message),
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
      // Fetch dynamic locatorId for handover
      int handoverLocatorId = 10; // Default fallback
      final targetOpId = widget.nextOperationId ?? widget.currentOperationId;
      final locRes = await _processingRepo.fetchLocators(operationId: targetOpId);
      if (locRes.success && locRes.data != null) {
        final locList = locRes.data as List;
        final matchingEntry = locList.cast<Map>().firstWhere(
          (entry) => (entry['operation']?['id'] ?? entry['locator']?['operationId'])?.toString() == targetOpId.toString(),
          orElse: () => {},
        );
        if (matchingEntry.isNotEmpty) {
          handoverLocatorId = matchingEntry['locator']?['id'] as int? ?? 10;
          debugPrint('✅ Processing Handover: Op=$targetOpId -> Loc=$handoverLocatorId');
        }
      }

      for (final t in _trays) {
        final currentPp = t.productionProgress;
        final updatedJson = currentPp.toJson();
        final isSelectedForRework = _isReworkMode && _selectedReworkTrayIds.contains(currentPp.id);

        if (isSelectedForRework) {
          // --- REWORK SUBMISSION (Return to Previous Op) ---
          debugPrint('🔄 Reworking Tray: ${t.primaryTrayModel.trayCode} back to $_reworkTargetOpName');
          
          // 1. Mark current record as handed over (Type 3)
          updatedJson['transactionType'] = 3;
          updatedJson['reworkFlag'] = true; // Mark as rework
          final putRes = await _processingRepo.updateProductionProgress(currentPp.id!, updatedJson);
          if (!putRes.success) throw Exception('Rework failed for tray ${t.primaryTrayModel.trayCode}');

          // 2. Resolve Locator for Rework Target
          int reworkLocatorId = 10;
          final locRes = await _processingRepo.fetchLocators(operationId: _reworkTargetOpId!);
          if (locRes.success && locRes.data != null) {
            final locList = locRes.data as List;
            final match = locList.cast<Map>().firstWhere(
              (e) => (e['operation']?['id'] ?? e['locator']?['operationId'])?.toString() == _reworkTargetOpId.toString(),
              orElse: () => {},
            );
            if (match.isNotEmpty) reworkLocatorId = match['locator']?['id'] as int? ?? 10;
          }

          // 3. Create new record at Rework Operation
          final nextModelJson = currentPp.toJson();
          nextModelJson['transactionType'] = 2;
          nextModelJson.remove('id');
          nextModelJson.remove('progressCode');
          nextModelJson['batchHeaderId'] = widget.batchHeaderId;
          nextModelJson['locatorId'] = reworkLocatorId;
          nextModelJson['operationId'] = _reworkTargetOpId;
          nextModelJson['reworkFlag'] = true; // Carry over flag
          nextModelJson['gbsFlag'] = false;
          nextModelJson['pbsFlag'] = false;

          final postRes = await _processingRepo.createProductionProgress(nextModelJson);
          if (!postRes.success) throw Exception('Failed to return tray to previous op');

        } else if (widget.nextOperationId != null) {
          // --- STANDARD HANDOVER (Op A -> Op B) ---
          updatedJson['transactionType'] = 3;
          final putRes = await _processingRepo.updateProductionProgress(currentPp.id!, updatedJson);
          if (!putRes.success) throw Exception('Update failed for tray ${t.primaryTrayModel.trayCode}');

          // Resolve Locator for Next Op
          int nextLocatorId = 10;
          final locRes = await _processingRepo.fetchLocators(operationId: widget.nextOperationId!);
          if (locRes.success && locRes.data != null) {
            final locList = locRes.data as List;
            final match = locList.cast<Map>().firstWhere(
              (e) => (e['operation']?['id'] ?? e['locator']?['operationId'])?.toString() == widget.nextOperationId.toString(),
              orElse: () => {},
            );
            if (match.isNotEmpty) nextLocatorId = match['locator']?['id'] as int? ?? 10;
          }

          final nextModelJson = currentPp.toJson();
          nextModelJson['transactionType'] = 2;
          nextModelJson.remove('id');
          nextModelJson.remove('progressCode');
          nextModelJson['batchHeaderId'] = widget.batchHeaderId;
          nextModelJson['locatorId'] = nextLocatorId;
          nextModelJson['operationId'] = widget.nextOperationId;
          nextModelJson['gbsFlag'] = false;
          nextModelJson['pbsFlag'] = false;

          final postRes = await _processingRepo.createProductionProgress(nextModelJson);
          if (!postRes.success) throw Exception('Handover failed for tray ${t.primaryTrayModel.trayCode}');

        } else {
          // --- FINAL PROCESS SUBMISSION ---
          updatedJson['transactionType'] = 3;
          updatedJson['wipStatus'] = 1;
          updatedJson['isLastProcess'] = true;
          updatedJson['gbsFlag'] = false;
          updatedJson['pbsFlag'] = false;

          final putRes = await _processingRepo.updateProductionProgress(currentPp.id!, updatedJson);
          if (!putRes.success) throw Exception('Finalize failed for tray ${t.primaryTrayModel.trayCode}');
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
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('TRAY CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('ITEM DESC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('WEIGHT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                if (_isReworkMode)
                  Expanded(
                    flex: 1, 
                    child: Checkbox(
                      value: _selectedReworkTrayIds.length == _trays.length && _trays.isNotEmpty,
                      activeColor: Colors.orange,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedReworkTrayIds.addAll(_trays.map((t) => t.productionProgress.id!).whereType<int>());
                          } else {
                            _selectedReworkTrayIds.clear();
                          }
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          ..._trays.map((t) {
            final qty = t.productionProgress.primaryQuantity ?? 0;
            final pw = t.item.pieceWeight ?? 0;
            final trayId = t.productionProgress.id ?? 0;
            final isSelected = _selectedReworkTrayIds.contains(trayId);

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                color: isSelected ? Colors.orange.withOpacity(0.05) : null,
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(t.primaryTrayModel.trayCode ?? '-', style: const TextStyle(fontSize: 12))),
                  Expanded(flex: 3, child: Text(t.item.description ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                  Expanded(flex: 2, child: Text(qty.toString(), style: const TextStyle(fontSize: 12))),
                  Expanded(flex: 2, child: Text('${(qty * pw).toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue))),
                  if (_isReworkMode)
                    Expanded(
                      flex: 1,
                      child: Checkbox(
                        value: isSelected,
                        activeColor: Colors.orange,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedReworkTrayIds.add(trayId);
                            } else {
                              _selectedReworkTrayIds.remove(trayId);
                            }
                          });
                        },
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
