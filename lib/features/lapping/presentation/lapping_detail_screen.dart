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
  static const _inputAndButtonHeight = 44.0;
  static final _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );
  
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBatchData();
    });
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
      AppLoader.show(context, message: "Searching system trays...");
      final trayRes = await _batchRepo.fetchTrayDetailByCode(trayCode);
      AppLoader.hide(context);

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
            processedItemId: refTray.productionProgress.processedItemId, // ✅ FIXED: Preserve inner ID
          ),
          operation: refTray.operation,
          shift: refTray.shift,
          machineModel: refTray.machineModel,
          workOrderHeader: refTray.workOrderHeader,
          workOrderLine: refTray.workOrderLine,
          item: refTray.item,
          processedItem: refTray.processedItem, // ✅ FIXED: Preserve processedItem
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
        child: ExcludeSemantics(
          excluding: _isLoading,
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
                              // const SizedBox(height: 24),
                              // const SectionHeader(title: 'Scan Trays', subtitle: 'Verify and assign trays to the selected work order'),
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
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildTableHeader(),
              ...List.generate(_workOrders.values.length, (index) {
                final wo = _workOrders.values.elementAt(index);
                final isSelected = _selectedWorkOrderId == wo.id;
                final reassigned = (_scannedTraysByWO[wo.id] ?? []).fold<double>(0, (sum, t) =>
                sum + (_trayOverrideQuantities[t.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0));

                return InkWell(
                  onTap: () => setState(() => _selectedWorkOrderId = wo.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.05) : (index.isEven ? Colors.white : Colors.grey.shade50),
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade300),
                        right: BorderSide(color: Colors.grey.shade300),
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(wo.description, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                        Expanded(flex: 6, child: Text(wo.componentDescription, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                        Expanded(flex: 2, child: Text('${wo.trayCount}', style: const TextStyle(fontSize: 12, color: Colors.black87))),
                        Expanded(flex: 2, child: Text('${wo.cumulativePieces.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
                        Expanded(flex: 2, child: Text(reassigned > 0 ? '${reassigned.toInt()}' : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: reassigned > 0 ? Colors.green : Colors.grey))),
                        Radio<String>(
                          value: wo.id, 
                          groupValue: _selectedWorkOrderId, 
                          activeColor: Colors.blue, 
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) => setState(() => _selectedWorkOrderId = val)
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('WORK ORDER', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 6, child: Text('ITEM DESC', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('TRAYS', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('TOTAL', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('RE-ASGN', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green))),
          const SizedBox(width: 32),
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
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _buildScannedHeader(),
            ...List.generate(traysToShow.length, (index) {
              final t = traysToShow[index];
              final trayKey = t.primaryTrayModel.trayCode?.toLowerCase() ?? '';
              final qty = _trayOverrideQuantities[trayKey] ?? 0;
              final pw = t.item.pieceWeight ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade300),
                    right: BorderSide(color: Colors.grey.shade300),
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                  color: index.isEven ? Colors.white : Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(t.primaryTrayModel.trayCode ?? '-', style: const TextStyle(fontSize: 13, color: Colors.black87))),
                    Expanded(flex: 4, child: Text(t.processedItem?.description ?? t.item.description ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                    Expanded(
                      flex: 2, 
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            qty.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    Expanded(flex: 2, child: Text('${(qty * pw).toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 13, color: Colors.black87))),
                    const SizedBox(width: 8),
                    GestureDetector(
                        onTap: () {
                          setState(() {
                            _scannedTraysByWO[_selectedWorkOrderId]?.remove(t);
                            _trayOverrideQuantities.remove(trayKey);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.cancel, size: 18, color: Colors.red.shade400),
                        ),
                    ),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('TRAY CODE', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 4, child: Text('ITEM DESC', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('QUANTITY', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('WEIGHT', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          const SizedBox(width: 44),
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
      // Only process newly reassigned trays
      final assignedTrays = _scannedTraysByWO.values.expand((list) => list).toList();
      final allScannedTrays = assignedTrays;

      if (allScannedTrays.isEmpty) {
        AppLoader.hide(context);
        setState(() => _isLoading = false);
        _showDialog('No Changes', 'No new trays were reassigned.');
        return;
      }

      // --- Step 2 & 3: Sequential Processing (Audit -> BatchLine -> Progress) ---
      // Determine Handover Location
      int nextLocatorId = 3; 
      final baseProgress = allScannedTrays.first.productionProgress;
      final handoverOpId = widget.nextOperationId ?? baseProgress?.operationId;

      if (handoverOpId != null) {
        final locRes = await _batchRepo.fetchLocators(operationId: handoverOpId);
        if (locRes.success && locRes.data != null) {
          final locList = locRes.data as List;
          final matchingEntry = locList.cast<Map>().firstWhere(
                (entry) => (entry['operation']?['id'] ?? entry['locator']?['operationId'])?.toString() == handoverOpId.toString(),
            orElse: () => {},
          );
          if (matchingEntry.isNotEmpty) {
            nextLocatorId = matchingEntry['locator']?['id'] as int? ?? 3;
          }
        }
      }

      for (final scannedTray in allScannedTrays) {
        final double trayQty = _trayOverrideQuantities[scannedTray.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0;
        
        // 1. Post WIP Transaction (Seeding the audit trail)
        Map<String, dynamic> wipPayload = {
          "transactionDate": DateTime.now().toIso8601String(),
          "transactionType": 2, // Handover
          "operatorDescription": "system",
          "primaryQuantity": trayQty,
          "primaryUOM": scannedTray.productionProgress.primaryUOM ?? 4,
          "progressId": scannedTray.productionProgress.id, 
          "operationId": handoverOpId,
          "locatorId": nextLocatorId,
          "batchHeaderId": widget.batchHeaderId,
          "itemId": scannedTray.item.id,
          "primaryTrayId": scannedTray.primaryTrayModel.id,
          "workOrderHeaderId": scannedTray.workOrderHeader.id,
          "workOrderLineId": scannedTray.workOrderLine.id,
        };
        
        final wipRes = await _batchRepo.postWipTransaction(wipPayload);
        int? wipId;
        if (wipRes.success && wipRes.data != null) {
          wipId = wipRes.data['id'] ?? wipRes.data['wipTransaction']?['id'] ?? wipRes.data;
        }

        // 2. Create Batch Line (Linked to WIP Transaction)
        final blRes = await _batchRepo.createBatchLine({
          "batchHeaderId": widget.batchHeaderId,
          "progressId": scannedTray.productionProgress.id,
          "wipTransactionId": wipId, // ✅ CRITICAL LINK
          "workOrderHeaderId": scannedTray.workOrderHeader.id,
          "workOrderLineId": scannedTray.workOrderLine.id,
          "itemId": scannedTray.item.id,
          "primaryUomId": scannedTray.productionProgress.primaryUOM ?? 4,
          "primaryQuantity": trayQty,
          "active": true,
        });

        int? blId;
        if (blRes.success && blRes.data != null) {
          blId = blRes.data['id'] ?? blRes.data['batchLine']?['id'] ?? blRes.data;
          
          // 3. Update Tray Detail with new Batch Line
          final tRes = await _batchRepo.fetchTrayDetailById(scannedTray.primaryTrayModel.id!);
          if (tRes.success) {
            final tData = tRes.data['trayDetail'] ?? tRes.data;
            await _batchRepo.updateTrayDetails(scannedTray.primaryTrayModel.id!, {
              ...tData,
              'trayQuantity': trayQty.toInt(),
              'batchHeaderId': widget.batchHeaderId,
              'batchLinesId': blId,
              'isReAssigned': true,
            });
          }
        }

        // 4. Close old Production Progress
        if (scannedTray.productionProgress.id != null) {
          await _processingRepo.updateProductionProgress(
            scannedTray.productionProgress.id!,
            {...scannedTray.productionProgress.toJson(), 'transactionType': 3}
          );
        }

        // 5. Create New Production Progress (The Handover)
        Map<String, dynamic> nextJson = scannedTray.productionProgress.toJson();
        nextJson.remove('id');
        nextJson.remove('progressCode');
        nextJson.remove('concurrencyStamp');
        
        nextJson.addAll({
          "transactionType": 2,
          "batchHeaderId": widget.batchHeaderId,
          "batchLinesId": blId,
          "primaryTrayId": scannedTray.primaryTrayModel.id,
          "primaryQuantity": trayQty,
          "operationId": handoverOpId,
          "locatorId": nextLocatorId,
          "wipStatus": widget.nextOperationId != null ? 0 : 1,
          "gbsFlag": false,
          "pbsFlag": false,
          "date": DateTime.now().toIso8601String(),
          "operatorDescription": "system",
        });

        if (nextJson['processedItemId'] == null || nextJson['processedItemId'] == 0) {
          nextJson['processedItemId'] = scannedTray.item.id;
        }

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