import 'package:flutter/services.dart';
import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/lapping/model/lapping_model.dart';
import 'package:active_wear_scanning/features/lapping/repo/lapping_repo.dart';
import 'package:active_wear_scanning/features/processing/repo/processing_repo.dart';
import 'package:flutter/material.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';

class LappingDetailScreen extends StatefulWidget {
  final int batchHeaderId;
  final String batchCode;
  final int? machineId;
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
    required this.machineId,
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
  final _lappingRepo = LappingRepo();
  bool _isLoading = false;
  List<LappingModel> _trays = [];
  final Map<String, _WorkOrderSummary> _workOrders = {};
  String? _selectedWorkOrderId;
  final Map<String, List<LappingModel>> _scannedTraysByWO = {};

  final _trayBarcodeController = TextEditingController();
  final _trayQtyController = TextEditingController();
  final _trayFocusNode = FocusNode();

  final Map<String, double> _trayOverrideQuantities = {};

  final FocusNode _focusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  @override
  void dispose() {
    _focusNode.dispose();
    _trayBarcodeController.dispose();
    _trayQtyController.dispose();
    _trayFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBatchData();
    });
  }

  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final now = DateTime.now();
      if (_lastKeyPress != null && now.difference(_lastKeyPress!).inMilliseconds > 200) {
        _barcodeBuffer = '';
      }
      _lastKeyPress = now;

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.isNotEmpty) {
          final code = _barcodeBuffer;
          _barcodeBuffer = '';
          _processBluetoothScan(code);
        }
      } else if (event.character != null) {
        _barcodeBuffer += event.character!;
      }
    }
  }

  Future<void> _processBluetoothScan(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return;

    if (_selectedWorkOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Work Order first')));
      return;
    }
    
    AppLoader.show(context, message: 'Validating Tray...');
    final error = await _onTrayScanned(code);
    AppLoader.hide(context);
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red));
    }
  }

  Future<void> _fetchBatchData() async {
    setState(() => _isLoading = true);

    final res = await _lappingRepo.fetchProductionProgress({
      'BatchHeaderId': widget.batchHeaderId.toString(),
      'TransactionType': '2',
    });

    if (res.success && res.data != null) {
      final List<LappingModel> fetchedTrays =
      res.data as List<LappingModel>;

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

    LappingModel? matchedTray;
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

        matchedTray = LappingModel(
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
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: _onKey,
        child: SafeArea(
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
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        FocusScope.of(context).unfocus();
                      },
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
        
        // --- 1. SET UP AND CREATE HANDOVER PRODUCTION PROGRESS (THE ANCHOR RECORD) ---
        Map<String, dynamic> nextJson = scannedTray.productionProgress.toJson();
        nextJson.remove('id');
        nextJson.remove('progressCode');
        nextJson.remove('concurrencyStamp');
        nextJson.remove('batchLinesId');

        nextJson.addAll({
          "subOperation": "Handover",
          "transactionType": 2, // Handover
          "primaryTrayId": scannedTray.primaryTrayModel.id,
          "secondaryTrayId": scannedTray.primaryTrayModel.id, // Fill secondary fallback
          "primaryQuantity": trayQty,
          "secondaryQuantity": scannedTray.productionProgress.secondaryQuantity ?? 0,
          "primaryUOM": scannedTray.productionProgress.primaryUOM ?? 4,
          "secondaryUOM": scannedTray.productionProgress.secondaryUOM ?? 1,
          "productGrade": scannedTray.productionProgress.productGrade ?? 0,
          "productNature": scannedTray.productionProgress.productNature ?? 0,
          "shiftId": scannedTray.productionProgress.shiftId ?? 1,
          "machineId": scannedTray.productionProgress.machineId ?? (_trays.isNotEmpty ? _trays.first.productionProgress.machineId : null),
          "isLastProcess": false,
          "reworkFlag": false,
          "lotMakingFlag": false, // Strict pass
          "locatorId": nextLocatorId,
          "operationId": handoverOpId ?? scannedTray.productionProgress.operationId,
          "wipStatus": widget.nextOperationId != null ? 0 : 1,
          "gbsFlag": false,
          "pbsFlag": false,
          "date": DateTime.now().toIso8601String(),
          "operatorDescription": "system",
          "processedItemId": scannedTray.processedItem?.id ?? scannedTray.productionProgress.processedItemId ?? scannedTray.item.id,
          "itemId": scannedTray.item.id,
          "workOrderHeaderId": scannedTray.workOrderHeader.id,
          "workOrderLineId": scannedTray.workOrderLine.id,
        });

        // Include batchHeaderId in the initial creation so the Handover PP is always
        // grouped correctly in ProcessingScreen._fetchOpDetails (which groups by batchHeaderId).
        nextJson['batchHeaderId'] = widget.batchHeaderId;
        nextJson.remove("planHeaderId"); // Only planHeaderId needs purging

        final ppRes = await _processingRepo.createProductionProgress(nextJson);
        if (!ppRes.success) {
          throw Exception("Failed to generate Handover Progress track sequence for tray. Server Message: ${ppRes.message}");
        }
        // Parse targetProgressId safely — ABP POST returns id=0 in the body (backend quirk)
        // The record IS persisted — we must re-fetch by operationId+trayId to get the real ID.
        final dynamic ppData = ppRes.data;
        debugPrint('🆕 PP Create Response: $ppData');
        int? targetProgressId;
        if (ppData is Map) {
          final rawId = int.tryParse(ppData['id']?.toString() ?? '');
          if (rawId != null && rawId > 0) targetProgressId = rawId;
        } else if (ppData is int && ppData > 0) {
          targetProgressId = ppData;
        }

        // ABP returns id=0 → re-fetch to resolve the real DB id
        ProductionProgressResponseModel? latestHandoverPP;
        if (targetProgressId == null || targetProgressId == 0) {
          debugPrint('⚠️ id=0 returned — re-fetching PP by operationId+trayId...');
          final refetchRes = await _processingRepo.fetchProductionProgress({
            'OperationId': (handoverOpId ?? scannedTray.productionProgress.operationId).toString(),
            'TransactionType': '2',
          });
          if (refetchRes.success && refetchRes.data != null) {
            final list = refetchRes.data as List<ProductionProgressResponseModel>;
            final matches = list.where((r) =>
              r.primaryTrayModel.id == scannedTray.primaryTrayModel.id &&
              (r.productionProgress.subOperation ?? '').toLowerCase() == 'handover'
            ).toList();
            if (matches.isNotEmpty) {
              matches.sort((a, b) => (a.productionProgress.id ?? 0).compareTo(b.productionProgress.id ?? 0));
              latestHandoverPP = matches.last;
              targetProgressId = latestHandoverPP.productionProgress.id;
            }
          }
        }

        if (targetProgressId == null || targetProgressId == 0) {
          throw Exception("Could not resolve Handover Progress ID after creation. Raw: $ppData");
        }
        debugPrint('✅ Resolved targetProgressId: $targetProgressId');

        // --- 1b. MARK CURRENT LAPPING PROGRESS AS COMPLETED (transactionType=3) ---
        // Query server with BOTH OperationId AND BatchHeaderId to target only this batch's lapping PP.
        // Also exclude subOperation='Handover' to avoid closing the newly created handover record.
        {
          final lappingPpRes = await _lappingRepo.fetchProductionProgress({
            'OperationId': widget.currentOperationId.toString(),
            'BatchHeaderId': widget.batchHeaderId.toString(),
            'TransactionType': '2',
          });
          LappingModel? realLappingPP;
          if (lappingPpRes.success && lappingPpRes.data != null) {
            final list = lappingPpRes.data as List<LappingModel>;
            // Exclude handover PPs — we only want the source lapping PP
            realLappingPP = list.where((r) =>
              r.primaryTrayModel.id == scannedTray.primaryTrayModel.id &&
              (r.productionProgress.subOperation ?? '').toLowerCase() != 'handover'
            ).firstOrNull;
          }
          // Fallback: check _trays (loaded in initState from same batch)
          realLappingPP ??= _trays.where((t) =>
            t.primaryTrayModel.id == scannedTray.primaryTrayModel.id &&
            (t.productionProgress.subOperation ?? '').toLowerCase() != 'handover'
          ).firstOrNull;

          if (realLappingPP != null &&
              realLappingPP.productionProgress.id != null &&
              realLappingPP.productionProgress.id! > 0) {
            final closeJson = realLappingPP.productionProgress.toJson();
            closeJson['transactionType'] = 3;
            // Keep concurrencyStamp — ABP requires it on PUT
            final closeRes = await _processingRepo.updateProductionProgress(
              realLappingPP.productionProgress.id!, closeJson,
            );
            if (!closeRes.success) {
              debugPrint('⚠️ Step 1b close-lapping failed: ${closeRes.message}');
            } else {
              debugPrint('✅ Closed Lapping PP id=${realLappingPP.productionProgress.id}');
            }
          } else {
            debugPrint('⚠️ No real Lapping PP found to close for tray ${scannedTray.primaryTrayModel.trayCode}');
          }
        }

        // --- 2. FETCH PREVIOUS WIP TRANSACTION (From the tray's state prior to Handover) ---
        int? wipId;
        if (scannedTray.productionProgress.id != null) {
          final nativeWipRes = await _batchRepo.fetchWipTransactionsByProgressId(scannedTray.productionProgress.id!);
          if (nativeWipRes.success && nativeWipRes.data != null) {
            final items = nativeWipRes.data as List<Map<String, dynamic>>;
            if (items.isNotEmpty) {
              wipId = items.first['wipTransaction']?['id'] as int?;
            }
          }
        }

        // --- 3. CREATE BATCH LINE (Cross-linked to established WIP logically) ---
        int? blId;
        if (wipId != null) {
            final blRes = await _batchRepo.createBatchLine({
            "planDate": DateTime.now().toIso8601String(),
            "transactionDate": DateTime.now().toIso8601String(),
            "primaryQuantity": trayQty,
            "primaryUOM": scannedTray.productionProgress.primaryUOM ?? 4,
            "secondaryQuantity": 0, 
            "secondaryUOM": scannedTray.productionProgress.secondaryUOM ?? 1,
            "batchLineCode": "BL-${widget.batchHeaderId}-${scannedTray.primaryTrayModel.id}",
            "batchHeaderId": widget.batchHeaderId,
            "progressId": targetProgressId,
            "wipTransactionId": wipId, 
            "workOrderHeaderId": scannedTray.workOrderHeader.id,
            "workOrderLineId": scannedTray.workOrderLine.id,
            "itemId": scannedTray.item.id,
            "trayId": scannedTray.primaryTrayModel.id,
            "locatorId": nextLocatorId,
            "processItemId": scannedTray.processedItem?.id ?? scannedTray.productionProgress.processedItemId ?? scannedTray.item.id ?? 0,
            "active": true,
        });

        if (!blRes.success || blRes.data == null) {
            throw Exception("Batch Line Error: ${blRes.message}");
        }

        blId = blRes.data['id'] ?? blRes.data['batchLine']?['id'] ?? blRes.data;
        }

        // --- 4. UPDATE TRAY DETAILS LOGIC (Visual State Link) ---
        final tRes = await _batchRepo.fetchTrayDetailById(scannedTray.primaryTrayModel.id!);
        if (tRes.success) {
          final tData = tRes.data['trayDetail'] ?? tRes.data;
          Map<String, dynamic> trayUpd = Map<String, dynamic>.from(tData);
          trayUpd["trayQuantity"] = trayQty.toInt();
          trayUpd["batchHeaderId"] = widget.batchHeaderId;
          trayUpd["isReAssigned"] = true;
          if (widget.machineId != null) {
            trayUpd["resourceId"] = widget.machineId;
          }
          trayUpd["workOrderHeaderId"] = scannedTray.workOrderHeader.id;
          trayUpd["workOrderLineId"] = scannedTray.workOrderLine.id;
          trayUpd["knitItemId"] = scannedTray.processedItem?.id ?? scannedTray.productionProgress.processedItemId ?? scannedTray.item.id;
          trayUpd["locatorId"] = nextLocatorId;
          
          if (blId != null) {
             trayUpd["batchLinesId"] = blId; 
          }
          await _batchRepo.updateTrayDetails(scannedTray.primaryTrayModel.id!, trayUpd);
        }

        // --- 5. FINALIZE PRODUCTION PROGRESS ---
        // Use the re-fetched PP's own data as base (has valid concurrencyStamp for ABP PUT).
        if (latestHandoverPP != null) {
          final finalJson = latestHandoverPP!.productionProgress.toJson();
          finalJson['batchHeaderId'] = widget.batchHeaderId;
          // Keep concurrencyStamp — ABP REQUIRES it on PUT (do NOT remove)
          if (blId != null) finalJson['batchLinesId'] = blId;
          final finalRes = await _processingRepo.updateProductionProgress(targetProgressId!, finalJson);
          if (!finalRes.success) {
            debugPrint('⚠️ Step 5 PP finalize failed (non-critical): ${finalRes.message}');
          } else {
            debugPrint('✅ Step 5 PP finalized with batchHeaderId=${widget.batchHeaderId}');
          }
        }
      }

      AppLoader.hide(context);
      setState(() {
        _isLoading = false;
        _scannedTraysByWO.clear();
        _trayOverrideQuantities.clear();
      });

      _showDialog('Success', 'Trays successfully assigned to new machine.', isSuccess: true, onDismiss: () {
        Navigator.pop(context, true); 
      });
    } catch (e) {
      AppLoader.hide(context);
      setState(() => _isLoading = false);
      _showDialog('Save Changes Error', e.toString());
    }
  }

  void _showDialog(String title, String message, {bool isSuccess = false, VoidCallback? onDismiss}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: isSuccess ? Colors.green : Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (onDismiss != null) onDismiss();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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