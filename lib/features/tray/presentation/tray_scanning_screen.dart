import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/barcode_scanner_dialog.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/tray/model/plan_header_model.dart';
import 'package:active_wear_scanning/features/tray/model/scanned_tray.dart';
import 'package:active_wear_scanning/features/tray/model/tray_details_model.dart';
import 'package:active_wear_scanning/features/tray/repo/tray_scanning_repo.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:flutter/material.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';

import '../../../core/widgets/custom_expanded_async_dropdown.dart';
import '../../../core/widgets/scanner_always_open.dart';

class TrayScanningScreen extends StatefulWidget {
  const TrayScanningScreen({super.key});

  @override
  State<TrayScanningScreen> createState() => _TrayScanningScreenState();
}

class _TrayScanningScreenState extends State<TrayScanningScreen> {
  final _trayScanningRepo = fromPlex<TrayScanningRepo>();
  String _machineBarcode = '';
  final List<ScannedTray> _scannedTrays = [];
  final List<TextEditingController> _quantityControllers = [];
  final _overrideQuantityController = TextEditingController();

  List<PlanLineResponseModel>? _planLines;
  List<TrayDetailsModel> availableTraysDetail = [];
  List<ProductionProgressResponseModel> existingProductionProgresses = [];
  PlanLineResponseModel? _selectedPlanLine;

  static const _inputAndButtonHeight = 42.0;
  static const _borderColor = Colors.blue;

  static final _labelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  static final _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );

  // Bluetooth Scanner Support
  final FocusNode _focusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _overrideQuantityController.dispose();
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
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

  void _processBluetoothScan(String scannedCode) {
    final code = scannedCode.trim();
    if (code.isEmpty) return;

    if (_machineBarcode.isEmpty) {
      // Treat as machine scan
      _fetchMachineData(code);
    } else {
      // Treat as tray scan
      final error = _validateTrayForScan(code);
      if (error != null) {
        _showError(error as String);
      }
    }
  }

  String _getPlanQuantityPerTray() {
    if (_selectedPlanLine == null) return '';
    final quantity = _selectedPlanLine!.planLine.quantityPerTray;
    return quantity == quantity.roundToDouble()
        ? quantity.round().toString()
        : quantity.toString();
  }

  String _getDefaultQuantityForNewTray() {
    final override = _overrideQuantityController.text.trim();
    if (override.isNotEmpty) return override;
    return _getPlanQuantityPerTray();
  }

  Future<String?> _validateTrayForScan(String scannedCode) async {
    if (_selectedPlanLine == null) return 'Please select a work order first';
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid tray code';

    final alreadyScanned = _scannedTrays.any((t) => t.trayCode.trim() == code);
    if (alreadyScanned) return 'Already assigned';

    final available = availableTraysDetail.where((t) {
      final trayCodeFromApi = (t.trayDetails?.trayCode ?? '').trim().toLowerCase();
      final scannedCodeClean = code.toLowerCase();
      return trayCodeFromApi == scannedCodeClean;
    }).toList();

    if (available.isEmpty) return 'Tray not available';

    final trayDetail = available.first.trayDetails;
    if (trayDetail?.active != true) return 'Tray is not active';
    if ((trayDetail?.trayType ?? 0) != 1) return 'Invalid tray type.';
    if (trayDetail?.isReAssigned == true) {
      return 'Tray is already reassigned in Lapping and cannot be bound again.';
    }

    final bool isEmptied =
        trayDetail?.locatorId == null ||
        trayDetail?.trayQuantity == "0" ||
        trayDetail?.trayQuantity == 0;

    final alreadyInProduction = existingProductionProgresses.any(
      (t) => (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase() == code.toLowerCase(),
    );

    if (alreadyInProduction && !isEmptied) {
      return 'Tray already scanned (Exists in Production Progress)';
    }

    int targetItemId = _selectedPlanLine?.item.id ?? 0;
    String colorDesc = _selectedPlanLine?.item.colorDescription ?? '';
    String sizeDesc = _selectedPlanLine?.item.sizeDescription ?? '';
    double perGarmentTube = _selectedPlanLine?.item.perGarmentTube ?? 0;

    if (targetItemId > 0) {
      AppLoader.show(context, message: "Fetching item details...");
      final itemRes = await _trayScanningRepo.fetchItemDef(targetItemId);
      AppLoader.hide(context);
      
      if (itemRes.success && itemRes.data != null) {
        final itemData = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
        if (itemData['colorDescription'] != null) colorDesc = itemData['colorDescription'];
        if (itemData['sizeDescription'] != null) sizeDesc = itemData['sizeDescription'];
        if (itemData['perGarmentTube'] != null) perGarmentTube = (itemData['perGarmentTube'] as num).toDouble();
      }
    }

    setState(() {
      _scannedTrays.add(
        ScannedTray(
          trayCode: code,
          trayUpdateId: trayDetail!.id,
          trayConcurrencyStamp: trayDetail.concurrencyStamp,
          colorDescription: colorDesc,
          sizeDescription: sizeDesc,
          perGarmentTube: perGarmentTube,
        ),
      );
      final controller = TextEditingController(text: _getDefaultQuantityForNewTray());
      controller.addListener(() => setState(() {}));
      _quantityControllers.add(controller);
    });

    return null;
  }

  Map<String, dynamic> _buildPlanLineDetailsMap(PlanLineResponseModel planLine) {
    final result = <String, dynamic>{};
    void addField(String key, IconData icon, String label, String? value) {
      if (value != null && value.trim().isNotEmpty && value.trim() != 'null') {
        result[key] = {'icon': icon, 'label': label, 'value': value};
      }
    }

    final plan = planLine.planLine;
    final shift = planLine.shift;
    final workOrder = planLine.workOrderHeader;
    final item = planLine.item;

    addField('Plan Date', Icons.calendar_today, 'Plan Date', plan.planDate.toString());
    addField('Knitting Tube', Icons.precision_manufacturing, 'Knitting Tube', plan.primaryPlanQuantity.toString());
    addField('Tubes Per Tray', Icons.grid_view, 'Tubes Per Tray', plan.quantityPerTray.toString());
    addField('Garment Pcs', Icons.checkroom, 'Garment Pcs', plan.secondaryPlanQuantity.toString());
    addField('Shift Code', Icons.schedule, 'Shift Code', shift.code.toString());
    addField('Work Order Code', Icons.assignment, 'Work Order Code', workOrder.workOrderCode);
    addField('Work Order Date', Icons.event, 'Work Order Date', workOrder.workOrderDate);
    addField('Item Description', Icons.description, 'Item Description', item.description);

    return result;
  }

  Future<void> _onScanTray() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trays',
      onResult: (scannedCode) {
        return _validateTrayForScan(scannedCode);
      },
    );
  }

  Future<void> _onScanMachineBarcode() async {
    final scannedCode = await BarcodeScannerDialog.show(
      context,
      title: 'Scan Barcode',
    );

    if (scannedCode == null || !mounted) return;
    _fetchMachineData(scannedCode);
  }

  Future<void> _fetchMachineData(String scannedCode) async {
    setState(() {
      _machineBarcode = scannedCode;
      _planLines = null;
      _selectedPlanLine = null;
    });

    AppLoader.show(context, message: 'Loading Machine Data...');
    try {
      final apiResult = await _trayScanningRepo.loadWorkOrderBySerialNumber(scannedCode);
      final trayDetailsModel = await _trayScanningRepo.fetchAvailableTrayDetails();
      final progressResult = await _trayScanningRepo.fetchProductionProgress();

      if (!mounted) return;

      if (apiResult.success && apiResult.data != null) {
        setState(() {
          _planLines = List<PlanLineResponseModel>.from(apiResult.data);
          if (progressResult.success && progressResult.data != null) {
            existingProductionProgresses = progressResult.data as List<ProductionProgressResponseModel>;
          }
          if (trayDetailsModel.data != null) {
            availableTraysDetail = (trayDetailsModel.data as List).map((item) => item as TrayDetailsModel).toList();
          }
          // if (_planLines!.length == 1) {
          //   _selectedPlanLine = _planLines!.first;
          //   _overrideQuantityController.text = _getPlanQuantityPerTray();
          // }
        });
      } else {
        _showError(apiResult.message ?? "No data found");
        setState(() {
          _machineBarcode = ''; // Reset if failed so BT scanner can try again
        });
      }
    } catch (e) {
      debugPrint('Error loading machine data: $e');
      _showError(e.toString());
      setState(() {
        _machineBarcode = '';
      });
    } finally {
      if (mounted) AppLoader.hide(context);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $message'), backgroundColor: Colors.red));
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Success: $message'), backgroundColor: Colors.green));
  }

  void saveTrayAndProductionProgress() async {
    if (_scannedTrays.isEmpty) return;
    AppLoader.show(context, message: 'Saving Changes...');
    try {
      for (int i = 0; i < _scannedTrays.length; i++) {
        final trayResFetch = await _trayScanningRepo.fetchTrayById(_scannedTrays[i].trayUpdateId!);
        if (!trayResFetch.success || trayResFetch.data == null) {
          throw Exception('Could not refresh tray details for ${_scannedTrays[i].trayCode}: ${trayResFetch.message}');
        }

        final latestTray = trayResFetch.data as TrayDetailsModel;
        final latestTrayDetail = latestTray.trayDetails;

        Map<String, dynamic> planData = {
          'trayCode': latestTrayDetail?.trayCode,
          'trayType': 1,
          'shiftId': _selectedPlanLine!.planLine.shiftId,
          'planLineId': _selectedPlanLine!.planLine.id,
          'workOrderHeaderId': _selectedPlanLine!.workOrderHeader.id,
          'workOrderLineId': _selectedPlanLine!.workOrderLine.id,
          'knitItemId': _selectedPlanLine!.planLine.itemId,
          "locatorId": 2,
          "active": true,
          "trayQuantity": (double.tryParse(_quantityControllers[i].text) ?? 5.0).toInt(),
          'concurrencyStamp': latestTrayDetail?.concurrencyStamp,
          "resourceId": _selectedPlanLine!.resource.id,
        };

        Map<String, dynamic> productionProgressData = {
          "subOperation": "Knitting",
          "date": DateTime.now().toIso8601String(),
          "transactionType": 2,
          "operatorDescription": "system",
          "primaryQuantity": (double.tryParse(_quantityControllers[i].text) ?? 5.0),
          "primaryUOM": _selectedPlanLine!.planLine.primaryUOM ?? 0,
          "secondaryQuantity": (_selectedPlanLine!.item.perGarmentTube) * (double.tryParse(_quantityControllers[i].text) ?? 5.0),
          "secondaryUOM": _selectedPlanLine!.planLine.secondaryUOM ?? 0,
          "wipStatus": 0,
          "gbsFlag": false,
          "pbsFlag": false,
          "productGrade": 0,
          "productNature": 0,
          "isLastProcess": false,
          "lotMakingFlag": false,
          "reworkFlag": false,
          "operationId": _selectedPlanLine!.operation.id,
          "workOrderHeaderId": _selectedPlanLine!.workOrderHeader.id,
          "workOrderLineId": _selectedPlanLine!.workOrderLine.id,
          "itemId": _selectedPlanLine!.planLine.itemId,
          "shiftId": _selectedPlanLine!.planLine.shiftId,
          "primaryTrayId": latestTrayDetail?.id,
          "secondaryTrayId": latestTrayDetail?.id,
          "machineId": _selectedPlanLine!.planLine.resourceId,
          "locatorId": 2,
        };

        if (_selectedPlanLine!.planLine.planHeaderId != 0 && _selectedPlanLine!.planLine.planHeaderId != null) {
          productionProgressData["planHeaderId"] = _selectedPlanLine!.planLine.planHeaderId;
        }

        final trayRes = await _trayScanningRepo.updateTrayDetails(planData, latestTrayDetail!.id!);
        final progRes = await _trayScanningRepo.saveProductionProgress(productionProgressData);

        if (!trayRes.success || !progRes.success) {
          throw Exception(trayRes.message ?? progRes.message ?? 'Unknown error saving tray');
        }
      }

      if (mounted) {
        _showSuccessMessage('Saved successfully!');
        setState(() {
          _scannedTrays.clear();
          _quantityControllers.clear();
          _machineBarcode = '';
          _planLines = null;
          _selectedPlanLine = null;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Save Error: $e');
      _showError(e.toString());
    } finally {
      if (mounted) AppLoader.hide(context);
    }
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
          excluding: false, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomInspectionHeader(
                heading: 'Tray Scanning',
                subtitle: 'Scan tray barcode to record production',
                isShowBackIcon: true,
                topPadding: 0,
                horizontalPadding: 12,
                widget: CustomOutlinedButton(
                  label: 'Save Changes',
                  borderColor: Colors.blue,
                  textColor: Colors.blue,
                  buttonHeight: _inputAndButtonHeight,
                  onPressed: saveTrayAndProductionProgress,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMachineScannerSection(),
                      const SizedBox(height: 10),
                      if (_planLines != null) _buildScannedTraysSection(),
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

  Widget _buildMachineScannerSection() {
    final locked = _scannedTrays.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Machine Scanner',
          subtitle: 'Scan the machine barcode to load work order details',
        ),
        const SizedBox(height: 12),
        ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scan Machine Barcode', style: _labelStyle),
              const SizedBox(height: 8),
              IgnorePointer(
                ignoring: locked,
                child: Opacity(
                  opacity: locked ? 0.45 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildMachineBarcodeField()),
                          const SizedBox(width: 10),
                          CustomOutlinedButton(
                            label: 'Scan Machine',
                            borderColor: Colors.blue,
                            fillColor: Colors.blue,
                            textColor: Colors.white,
                            buttonHeight: _inputAndButtonHeight,
                            onPressed: _onScanMachineBarcode,
                          ),
                        ],
                      ),
                      _buildWorkOrderDropdown(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_selectedPlanLine != null) ...[
                DynamicInfoDisplay(
                  items: _buildPlanLineDetailsMap(_selectedPlanLine!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMachineBarcodeField() {
    return SizedBox(
      height: _inputAndButtonHeight,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(Icons.qr_code_scanner, size: 20, color: Colors.grey.shade400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _machineBarcode.isEmpty
                    ? 'Place cursor here and scan barcode...'
                    : _machineBarcode,
                style: TextStyle(
                  fontSize: 14,
                  color: _machineBarcode.isEmpty ? Colors.grey.shade400 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedTraysSection() {
    final hasTrays = _scannedTrays.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Scanned Trays',
          subtitle: 'Scan a machine to start binding trays',
        ),
        const SizedBox(height: 12),
        ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scanned Trays (${_scannedTrays.length})',
                    style: _labelStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        height: _inputAndButtonHeight,
                        child: TextField(
                          controller: _overrideQuantityController,
                          decoration: _inputDecoration(
                            hintText: 'Tubes per tray',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
                            borderRadius: 4,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CustomOutlinedButton(
                        label: 'Scan Tray',
                        borderColor: Colors.blue,
                        fillColor: Colors.blue,
                        textColor: Colors.white,
                        buttonHeight: _inputAndButtonHeight,
                        onPressed: _onScanTray,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTrayTableHeader(),
              if (!hasTrays)
                _buildEmptyState()
              else
                ...List.generate(
                  _scannedTrays.length,
                  (index) => _buildTrayRow(index, _scannedTrays[index]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrayTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('TRAY CODE', style: _tableHeaderStyle.copyWith(letterSpacing: 1.1))),
          Expanded(flex: 2, child: Text('WORK ORDER', style: _tableHeaderStyle.copyWith(letterSpacing: 1.1))),
          Expanded(flex: 3, child: Text('ITEM DESCRIPTION', style: _tableHeaderStyle.copyWith(letterSpacing: 1.1))),
          Expanded(flex: 2, child: Text('COLOR', style: _tableHeaderStyle.copyWith(letterSpacing: 1.1))),
          Expanded(flex: 2, child: Text('SIZE', style: _tableHeaderStyle.copyWith(letterSpacing: 1.1))),
          Expanded(flex: 2, child: Text('PCS/TUBE', style: _tableHeaderStyle.copyWith(letterSpacing: 1.1))),
          Expanded(flex: 2, child: Text('TUBES', style: _tableHeaderStyle.copyWith(letterSpacing: 1.1))),
          Expanded(flex: 2, child: Text('PCS', style: _tableHeaderStyle.copyWith(letterSpacing: 1.1))),
          Expanded(flex: 2, child: Text('WEIGHT', style: _tableHeaderStyle.copyWith(letterSpacing: 1.1))),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'No scanned trays yet. Start by scanning a tray barcode.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Widget _buildTrayRow(int index, ScannedTray tray) {
    final isEmpty = tray.trayCode.isEmpty;
    final displayCode = isEmpty ? '-' : tray.trayCode;

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
          Expanded(
            flex: 2,
            child: Text(
              displayCode,
              style: TextStyle(fontSize: 13, color: isEmpty ? Colors.grey : Colors.black87),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _selectedPlanLine?.workOrderHeader.workOrderCode ?? "-",
              style: TextStyle(fontSize: 12, color: isEmpty ? Colors.grey : Colors.black87),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _selectedPlanLine?.item.description ?? "-",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: isEmpty ? Colors.grey : Colors.black87),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.colorDescription.isNotEmpty ? tray.colorDescription : "-",
              style: TextStyle(fontSize: 11, color: isEmpty ? Colors.grey : Colors.black87, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.sizeDescription.isNotEmpty ? tray.sizeDescription : "-",
              style: TextStyle(fontSize: 11, color: isEmpty ? Colors.grey : Colors.black87),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.perGarmentTube > 0 ? tray.perGarmentTube.toStringAsFixed(0) : '-',
              style: TextStyle(fontSize: 12, color: isEmpty ? Colors.grey : Colors.indigo.shade700, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 55,
                height: 35,
                child: TextField(
                  controller: _quantityControllers[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 1.5)),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Builder(
              builder: (_) {
                final qty = double.tryParse(_quantityControllers[index].text) ?? 0;
                final garmentPcs = (tray.perGarmentTube > 0) ? (qty * tray.perGarmentTube) : 0;
                return Text(
                  garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isEmpty ? Colors.grey : Colors.teal.shade700,
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Builder(
              builder: (_) {
                final qty = double.tryParse(_quantityControllers[index].text) ?? 0;
                final pw = _selectedPlanLine?.item.pieceWeight;
                if (pw == null || pw == 0) return const Text('-', style: TextStyle(fontSize: 13));
                return Text('${(qty * pw).toStringAsFixed(2)} g', style: const TextStyle(fontSize: 13));
              },
            ),
          ),
          const SizedBox(width: 8),
          _buildDeleteTrayButton(index),
        ],
      ),
    );
  }

  Widget _buildDeleteTrayButton(int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _quantityControllers[index].dispose();
          _quantityControllers.removeAt(index);
          _scannedTrays.removeAt(index);
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
    );
  }

  Widget _buildWorkOrderDropdown() {
    if (_planLines == null || _planLines!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Work Order & Item Description', style: _labelStyle),
          const SizedBox(height: 8),
          CustomExpandedAsyncDropdown<PlanLineResponseModel>(
            hint: "Select from list",
            width: double.infinity,
            height: 48,
            borderColor: Colors.blue,
            items: _planLines,
            selectedValue: _selectedPlanLine,
            itemAsString: (plan) => "${plan.workOrderHeader.workOrderCode} - ${plan.item.description}",
            onChanged: (newValue) {
              setState(() {
                _selectedPlanLine = newValue;
                if (_selectedPlanLine != null) {
                  _overrideQuantityController.text = _getPlanQuantityPerTray();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    bool isDense = false,
    EdgeInsetsGeometry? contentPadding,
    double borderRadius = 6,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: _borderColor),
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: isDense ? null : Icon(Icons.qr_code_scanner, size: 20, color: Colors.grey.shade400),
      border: border,
      focusedBorder: border,
      enabledBorder: border,
      isDense: isDense,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
