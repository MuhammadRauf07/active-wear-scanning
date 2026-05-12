import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/barcode_scanner_dialog.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
import 'package:active_wear_scanning/core/widgets/empty_scan_state.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/core/widgets/tray_table_header.dart';
import 'package:active_wear_scanning/features/tray/model/scanned_tray.dart';
import 'package:active_wear_scanning/features/tray/presentation/widgets/scanned_tray_row.dart';
import 'package:active_wear_scanning/features/tray/presentation/widgets/work_order_dropdown.dart';
import 'package:active_wear_scanning/features/tray/model/plan_header_model.dart';
import 'package:active_wear_scanning/features/tray/model/tray_details_model.dart';
import 'package:active_wear_scanning/features/tray/repo/tray_scanning_repo.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:flutter/material.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';

import '../../../core/widgets/custom_expanded_async_dropdown.dart';

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

  // Bluetooth Scanner Support
  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _overrideQuantityController.dispose();
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final now = DateTime.now();
    if (_lastKeyPress != null && now.difference(_lastKeyPress!).inMilliseconds > 200) {
      _barcodeBuffer = '';
    }
    _lastKeyPress = now;

    final ch = event.character;
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        ch == '\n' || ch == '\r';

    if (isEnter) {
      if (_barcodeBuffer.isNotEmpty) {
        final code = _barcodeBuffer;
        _barcodeBuffer = '';
        debugPrint('📡 BT Scanner → code: $code');
        _processBluetoothScan(code);
        return true; // consume the Enter so it doesn't submit a focused TextField
      }
    } else if (ch != null && ch.isNotEmpty) {
      _barcodeBuffer += ch;
    }
    return false;
  }

  Future<void> _processBluetoothScan(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return;

    if (_machineBarcode.isEmpty) {
      // Treat as machine scan
      _fetchMachineData(code);
    } else {
      // Treat as tray scan
      final error = await _validateTrayForScan(code);
      if (error != null && mounted) {
        _showError(error);
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
          "isStarted": false,
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
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: ExcludeSemantics(
          excluding: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── App bar ────────────────────────────────────────────────────
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

              // ── Pinned: Machine scanner card (barcode input + WO dropdown) ─
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: _buildMachineScannerSection(),
              ),

              // ── Pinned: Info display — only after WO selected ──────────────
              if (_selectedPlanLine != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: DynamicInfoDisplay(
                    items: _buildPlanLineDetailsMap(_selectedPlanLine!),
                  ),
                ),
              ],

              // ── Scrollable Table: Header Pinned, Rows Scrollable ───────────
              if (_selectedPlanLine != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _buildScannedTraysSection(),
                  ),
                ),
            ],
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
                      WorkOrderDropdown(
                        planLines: _planLines,
                        selectedPlanLine: _selectedPlanLine,
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
                ),
              ),
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
    return ContentCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Toolbar: Scanned count, Tubes per tray, Scan Tray button ──────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scanned Trays (${_scannedTrays.length})',
                  style: _labelStyle.copyWith(fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    const Text(
                      'Tubes per tray:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      height: _inputAndButtonHeight,
                      child: TextField(
                        controller: _overrideQuantityController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: _inputDecoration(
                          hintText: '',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          borderRadius: 4,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
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
          ),
          
          // ── Fixed Table Header ─────────────────────────────────────────────
          const TrayTableHeader(),

          // ── Scrollable List of Values ──────────────────────────────────────
          Expanded(
            child: _scannedTrays.isEmpty
                ? const EmptyScanState(hasBorder: false)
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _scannedTrays.length,
                    itemBuilder: (context, index) {
                      return ScannedTrayRow(
                        index: index,
                        tray: _scannedTrays[index],
                        quantityController: _quantityControllers[index],
                        selectedPlanLine: _selectedPlanLine,
                        onDelete: () {
                          setState(() {
                            _quantityControllers[index].dispose();
                            _quantityControllers.removeAt(index);
                            _scannedTrays.removeAt(index);
                          });
                        },
                      );
                    },
                  ),
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
