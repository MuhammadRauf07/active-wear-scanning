import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/processing/repo/processing_repo.dart';
import 'package:flutter/material.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';

class LappingDetailScreen extends StatefulWidget {
  final int batchHeaderId;
  final String batchCode;
  final String machine;
  final String color;
  final int trayCount;
  final double totalWeight;
  final int currentOperationId;
  final int? nextOperationId;
  final String nextOperationName;

  const LappingDetailScreen({
    super.key,
    required this.batchHeaderId,
    required this.batchCode,
    required this.machine,
    required this.color,
    required this.trayCount,
    required this.totalWeight,
    required this.currentOperationId,
    this.nextOperationId,
    required this.nextOperationName,
  });

  @override
  State<LappingDetailScreen> createState() => _LappingDetailScreenState();
}

class _LappingDetailScreenState extends State<LappingDetailScreen> {
  final _processingRepo = ProcessingRepo();
  final _batchRepo = BatchRepo();
  bool _isLoading = false;
  List<ProductionProgressResponseModel> _trays = [];
  final Map<String, _WorkOrderSummary> _workOrders = {};
  String? _selectedWorkOrderId;
  final Map<String, List<ProductionProgressResponseModel>> _scannedTraysByWO = {};

  final _trayBarcodeController = TextEditingController();
  final _trayQtyController = TextEditingController();
  final _trayFocusNode = FocusNode();

  final Map<String, double> _trayOverrideQuantities = {};

  @override
  void dispose() {
    _trayBarcodeController.dispose();
    _trayQtyController.dispose();
    _trayFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchBatchData();
  }

  Future<void> _fetchBatchData() async {
    setState(() => _isLoading = true);

    final res = await _processingRepo.fetchProductionProgress({
      'BatchHeaderId': widget.batchHeaderId.toString(),
      'TransactionType': '2',
    });

    if (res.success && res.data != null) {
      final List<ProductionProgressResponseModel> fetchedTrays =
      res.data as List<ProductionProgressResponseModel>;

      final Map<String, _WorkOrderSummary> summaries = {};

      for (final tray in fetchedTrays) {
        final woId = tray.workOrderHeader?.id;
        final itemDesc = tray.processedItem?.description ?? tray.item?.description ?? '';

        if (woId != null && itemDesc.isNotEmpty) {
          final compositeId = '${woId}_$itemDesc';

          if (summaries.containsKey(compositeId)) {
            final existing = summaries[compositeId]!;
            summaries[compositeId] = _WorkOrderSummary(
              id: compositeId,
              description: existing.description,
              componentDescription: existing.componentDescription,
              trayCount: existing.trayCount + 1,
              cumulativePieces: existing.cumulativePieces + (tray.productionProgress.primaryQuantity ?? 0),
            );
          } else {
            final woDesc = tray.workOrderHeader?.description ?? '';
            summaries[compositeId] = _WorkOrderSummary(
              id: compositeId,
              description: woDesc,
              componentDescription: itemDesc,
              trayCount: 1,
              cumulativePieces: tray.productionProgress.primaryQuantity ?? 0,
            );
          }
        }
      }

      setState(() {
        _trays = fetchedTrays;
        _workOrders.clear();
        _workOrders.addAll(summaries);
        _isLoading = false;
        _selectedWorkOrderId = null;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${res.message}')),
        );
      }
    }
  }

  // --- Core Validation Logic (Updated for Tray-Detail Support) ---
  Future<String?> _onTrayScanned(String code) async {
    if (_trayQtyController.text.trim().isEmpty) return 'Please add No. of Pcs before scanning!';
    final double inputPcs = double.tryParse(_trayQtyController.text) ?? 0;
    if (inputPcs <= 0) return 'Pcs amount must be greater than 0!';

    final trayCode = code.trim().toLowerCase();
    if (trayCode.isEmpty) return 'Invalid tray code';

    final activeSummary = _workOrders[_selectedWorkOrderId];
    if (activeSummary == null) return 'No Active Work Order selected!';

    final currentWOTrays = _scannedTraysByWO[_selectedWorkOrderId] ?? [];
    if (currentWOTrays.any((t) => t.primaryTrayModel.trayCode?.toLowerCase() == trayCode)) {
      return 'Tray already scanned in this session!';
    }

    double totalScanned = currentWOTrays.fold(0, (sum, t) =>
    sum + (_trayOverrideQuantities[t.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0));

    if ((totalScanned + inputPcs) > activeSummary.cumulativePieces) {
      return 'Limit exceeded! Max: ${activeSummary.cumulativePieces}';
    }

    ProductionProgressResponseModel? matchedTray;
    matchedTray = _trays.where((t) => t.primaryTrayModel.trayCode?.toLowerCase() == trayCode).firstOrNull;

    if (matchedTray == null) {
      AppLoader.show(message: "Searching system trays...");
      final trayRes = await _batchRepo.fetchTrayDetailByCode(trayCode);
      AppLoader.hide();

      if (trayRes.success && trayRes.data != null) {
        final trayMap = trayRes.data.containsKey('trayDetail') ? trayRes.data['trayDetail'] : trayRes.data;
        final int? existingBatch = trayMap['batchHeaderId'];
        if (existingBatch != null && existingBatch != 0 && existingBatch != widget.batchHeaderId) {
          return 'Tray belongs to another batch ($existingBatch)';
        }

        final refTray = _trays.firstWhere((t) => '${t.workOrderHeader.id}_${t.processedItem?.description ?? t.item.description}' == _selectedWorkOrderId);

        matchedTray = ProductionProgressResponseModel(
          productionProgress: ProductionProgress(
            id: null,
            primaryTrayId: trayMap['id'],
            locatorId: trayMap['locatorId'] ?? 2,
            primaryQuantity: inputPcs,
            transactionType: 2,
          ),
          operation: refTray.operation,
          shift: refTray.shift,
          machineModel: refTray.machineModel,
          workOrderHeader: refTray.workOrderHeader,
          workOrderLine: refTray.workOrderLine,
          item: refTray.item,
          primaryTrayModel: PrimaryTrayModel(
            id: trayMap['id'],
            trayCode: trayMap['trayCode'],
            concurrencyStamp: trayMap['concurrencyStamp'],
          ),
        );
      } else {
        return 'Tray not available in system!';
      }
    }

    setState(() {
      _trayOverrideQuantities[trayCode] = inputPcs;
      _scannedTraysByWO.putIfAbsent(_selectedWorkOrderId!, () => []);
      _scannedTraysByWO[_selectedWorkOrderId!]!.add(matchedTray!);
      _trayBarcodeController.clear();
      _trayFocusNode.requestFocus();
    });
    return null;
  }

  void _openScanner() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Tray',
      onResult: (scannedCode) async {
        return await _onTrayScanned(scannedCode);
      },
    );
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
              buttonLabel: 'Submit',
              callBack: _saveChanges,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DynamicInfoDisplay(
                      items: {
                        'batch': {'icon': Icons.qr_code, 'label': 'Batch ID', 'value': widget.batchCode},
                        'machine': {'icon': Icons.precision_manufacturing, 'label': 'Machine', 'value': widget.machine},
                        'color': {'icon': Icons.palette, 'label': 'Color', 'value': widget.color},
                        'weight': {'icon': Icons.scale, 'label': 'Req Weight', 'value': '${widget.totalWeight.toStringAsFixed(2)} kg'},
                        'trays': {'icon': Icons.layers, 'label': 'Active Trays', 'value': '${widget.trayCount} trays'},
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildWorkOrderSelection(),
                    if (_selectedWorkOrderId != null) ...[
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Scan Trays', subtitle: 'Verify and assign trays to the selected work order'),
                      const SizedBox(height: 12),
                      _buildScannerUI(), // Unified Scanner & Table Layout
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

  Widget _buildWorkOrderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Select Work Order Line', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        ContentCard(
          child: Column(
            children: [
              _buildTableHeader(),
              ..._workOrders.values.map((wo) {
                final isSelected = _selectedWorkOrderId == wo.id;
                final reassigned = (_scannedTraysByWO[wo.id] ?? []).fold<double>(0, (sum, t) =>
                sum + (_trayOverrideQuantities[t.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0));

                return InkWell(
                  onTap: () => setState(() => _selectedWorkOrderId = wo.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.transparent,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(wo.description, style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 6, child: Text(wo.componentDescription, style: const TextStyle(fontSize: 11))),
                        Expanded(flex: 2, child: Text('${wo.trayCount}', style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 2, child: Text('${wo.cumulativePieces.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
                        Expanded(flex: 2, child: Text(reassigned > 0 ? '${reassigned.toInt()}' : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: reassigned > 0 ? Colors.green : Colors.grey))),
                        Radio<String>(value: wo.id, groupValue: _selectedWorkOrderId, activeColor: Colors.blue, onChanged: (val) => setState(() => _selectedWorkOrderId = val)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      color: Colors.grey.shade100,
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('WORK ORDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 6, child: Text('ITEM DESC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('TRAYS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('RE-ASGN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green))),
          SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildScannerUI() {
    final traysToShow = _scannedTraysByWO[_selectedWorkOrderId] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Tray Scanner', subtitle: 'Scan tray barcodes to assign them to this work order'),
        const SizedBox(height: 12),
        ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Scan Tray Barcode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Pcs Field

                  // Ready for scan bar (GBS style)
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ready for scan...',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 70,
                    height: 44,
                    child: TextField(
                      controller: _trayQtyController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Pcs',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),
                  CustomOutlinedButton(
                    label: 'Scan Tray',
                    borderColor: Colors.blue,
                    fillColor: Colors.blue,
                    textColor: Colors.white,
                    buttonHeight: 44,
                    onPressed: _openScanner,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Scanned Trays (${traysToShow.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ],
        ),
        if (traysToShow.isNotEmpty)
          _buildScannedTraysTable()
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Text(
              'No scanned trays yet. Start by scanning a tray barcode.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _buildScannedTraysTable() {
    final traysToShow = _scannedTraysByWO[_selectedWorkOrderId] ?? [];
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: ContentCard(
        child: Column(
          children: [
            _buildScannedHeader(),
            ...traysToShow.map((t) {
              final trayKey = t.primaryTrayModel.trayCode?.toLowerCase() ?? '';
              final qty = _trayOverrideQuantities[trayKey] ?? 0;
              final pw = t.item.pieceWeight ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(t.primaryTrayModel.trayCode ?? '-', style: const TextStyle(fontSize: 12))),
                    Expanded(flex: 3, child: Text(t.processedItem?.description ?? t.item.description ?? '-', style: const TextStyle(fontSize: 11))),
                    Expanded(flex: 2, child: Text(qty.toString(), style: const TextStyle(fontSize: 12))),
                    Expanded(flex: 2, child: Text('${(qty * pw).toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
                    IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                        onPressed: () {
                          setState(() {
                            _scannedTraysByWO[_selectedWorkOrderId]?.remove(t);
                            _trayOverrideQuantities.remove(trayKey);
                          });
                        }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      color: Colors.grey.shade100,
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('TRAY CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text('ITEM DESC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('WEIGHT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          SizedBox(width: 36),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // --- Submission Logic ---
  Future<void> _saveChanges() async {
    final allScannedTrays = _scannedTraysByWO.values.expand((list) => list).toList();

    if (allScannedTrays.isEmpty) {
      _showDialog('No Trays Scanned', 'Please scan at least one tray.');
      return;
    }

    // Completion validation
    for (final wo in _workOrders.values) {
      if ((_scannedTraysByWO[wo.id] ?? []).isEmpty) {
        _showDialog('Incomplete', 'Missing trays for "${wo.componentDescription}"');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // --- Step 1: Deactivate Old Batch Lines ---
      final batchLinesRes = await _batchRepo.fetchBatchLines(batchHeaderId: widget.batchHeaderId);
      if (batchLinesRes.success && batchLinesRes.data != null) {
        for (var line in (batchLinesRes.data as List)) {
          final bl = line['batchLines'] ?? line;
          if (bl['id'] != null && (bl['active'] == true || bl['isActive'] == true)) {
            await _batchRepo.updateBatchLine(bl['id'], {...bl, 'active': false, 'isActive': false});
          }
        }
      }

      // --- Step 2: Create New Batch Lines & Update Tray Details ---
      for (final tray in allScannedTrays) {
        final double qty = _trayOverrideQuantities[tray.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0;

        // Correcting the reference: Composite key use karein jo validation mein set hui thi
        final String compositeKey = '${tray.workOrderHeader.id}_${tray.processedItem?.description ?? tray.item.description}';
        final activeSummary = _workOrders[compositeKey];

        await _batchRepo.createBatchLine({
          "primaryQuantity": qty,
          "batchHeaderId": widget.batchHeaderId,
          "progressId": tray.productionProgress.id,
          "workOrderHeaderId": tray.workOrderHeader.id,
          "workOrderLineId": tray.workOrderLine.id,
          "itemId": tray.item.id,
          "trayId": tray.primaryTrayModel.id,
          "isReAssigned": true,
          // Batch Lines uses 'processItemId'
          "processItemId": tray.processedItem?.id ?? tray.item.id,
          "active": true,
        });

        if (tray.primaryTrayModel.id != null) {
          final tRes = await _batchRepo.fetchTrayDetailById(tray.primaryTrayModel.id!);
          if (tRes.success) {
            final tData = tRes.data['trayDetail'] ?? tRes.data;
            await _batchRepo.updateTrayDetails(tray.primaryTrayModel.id!, {
              ...tData,
              'trayQuantity': qty.toInt(),
              'batchHeaderId': widget.batchHeaderId,
              'isReAssigned': true,
            });
          }
        }
      }

      // --- Step 3: Handover (Production Progress) ---
      for (final originalTray in _trays) {
        if (originalTray.productionProgress.id != null) {
          await _processingRepo.updateProductionProgress(
              originalTray.productionProgress.id!,
              {...originalTray.productionProgress.toJson(), 'transactionType': 3}
          );
        }
      }

      for (final scannedTray in allScannedTrays) {
        final double newQty = _trayOverrideQuantities[scannedTray.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0;
        final base = _trays.first.productionProgress;

        Map<String, dynamic> nextJson = {
          "transactionType": 2,
          "batchHeaderId": widget.batchHeaderId,
          "primaryTrayId": scannedTray.primaryTrayModel.id,
          "primaryQuantity": newQty,

          // 🔥 FIX 1: Spelling changed to 'processedItemId' for QA visibility
          // 🔥 FIX 2: itemId ko processItem logic se update kiya
          "processedItemId": scannedTray.processedItem?.id ?? scannedTray.item.id,

          "operationId": widget.nextOperationId ?? base.operationId,
          "previousOperationId": base.operationId,
          "wipStatus": widget.nextOperationId != null ? 0 : 1,

          "shiftId": scannedTray.productionProgress.shiftId ?? base.shiftId,
          "machineId": scannedTray.productionProgress.machineId ?? base.machineId,
          "workOrderHeaderId": scannedTray.workOrderHeader.id,
          "workOrderLineId": scannedTray.workOrderLine.id,
          "itemId": scannedTray.item.id,
          "locatorId": base.locatorId ?? 3,
          "primaryUOM": base.primaryUOM,
          "secondaryUOM": base.secondaryUOM,
          "transactionDate": DateTime.now().toIso8601String(),
          "operatorDescription": "system",
        };

        final cres = await _processingRepo.createProductionProgress(nextJson);
        if (!cres.success) {
          throw Exception('Handover failed for Tray: ${scannedTray.primaryTrayModel.trayCode}');
        }
      }

      setState(() => _isLoading = false);
      if (mounted) _showSuccess();

    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("❌ Save Changes Error: $e");
      _showDialog('Error', e.toString());
    }
  }

  void _showDialog(String title, String msg) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
  }

  void _showSuccess() {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Success'), content: const Text('Batch updated and submitted!'), actions: [TextButton(onPressed: () {
      Navigator.pop(ctx);
      Navigator.pop(context, true);
    }, child: const Text('OK'))]));
  }
}

class _WorkOrderSummary {
  final String id;
  final String description;
  final String componentDescription;
  final int trayCount;
  final double cumulativePieces;
  _WorkOrderSummary({required this.id, required this.description, required this.componentDescription, required this.trayCount, required this.cumulativePieces});
}