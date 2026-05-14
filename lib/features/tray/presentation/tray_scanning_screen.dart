import 'dart:ui';

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

    String? formatDate(String? dateStr) {
      if (dateStr == null) return null;
      return dateStr.split('T')[0].split(' ')[0];
    }

    addField('Plan Date', Icons.calendar_today, 'Plan Date', formatDate(plan.planDate.toString()));
    addField('Knitting Tube', Icons.precision_manufacturing, 'Knitting Tube', plan.primaryPlanQuantity.toString());
    addField('Tubes Per Tray', Icons.grid_view, 'Tubes Per Tray', plan.quantityPerTray.toString());
    addField('Garment Pcs', Icons.checkroom, 'Garment Pcs', plan.secondaryPlanQuantity.toString());
    addField('Shift Code', Icons.schedule, 'Shift Code', shift.code.toString());
    addField('Work Order Code', Icons.assignment, 'Work Order Code', workOrder.workOrderCode);
    addField('Work Order Date', Icons.event, 'Work Order Date', formatDate(workOrder.workOrderDate));
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
      backgroundColor: const Color(0xFFE3F2FD), // Consistent Sky Blue
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Premium Header (Fixed) ────────────────────────────────────────
            _buildPremiumHeader(context),

            // ── Fixed Top Sections ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Machine Scanner Section
                  _TrayFadeSlideTransition(delay: 0, child: _buildMachineScannerSection()),

                  // Production Information Section
                  if (_selectedPlanLine != null) ...[
                    const SizedBox(height: 16),
                    const _TrayFadeSlideTransition(
                      delay: 100,
                      child: Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Production Intelligence',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                        ),
                      ),
                    ),
                    _TrayFadeSlideTransition(delay: 150, child: _buildProductionInfoGrid()),
                  ],

                  // Action Area
                  if (_selectedPlanLine != null) ...[
                    const SizedBox(height: 16),
                    _TrayFadeSlideTransition(delay: 200, child: _buildActionArea()),
                  ],
                ],
              ),
            ),

            // ── Scrollable Table Section ─────────────────────────────────────
            if (_selectedPlanLine != null) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 16, 8),
                child: _TrayFadeSlideTransition(
                  delay: 250,
                  child: Text(
                    'Active Scanned Trays',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TrayFadeSlideTransition(delay: 300, child: _buildScannedTraysTable()),
                ),
              ),
              const SizedBox(height: 16),
            ] else 
              const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0D47A1), size: 20),
                visualDensity: VisualDensity.compact,
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tray Scanning',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                    ),
                    Text(
                      'Production Execution HUD',
                      style: TextStyle(fontSize: 11, color: Color(0xFF546E7A), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _scannedTrays.isEmpty ? null : saveTrayAndProductionProgress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade200,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('SAVE BATCH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMachineScannerSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left: Barcode Scanner Visual ──────────────────────────────
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Container(
                        height: 90, // Reduced height to prevent overflow
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D47A1).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.2), width: 1.5),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.precision_manufacturing_rounded, size: 40, color: const Color(0xFF0D47A1).withValues(alpha: 0.5)),
                            if (_machineBarcode.isNotEmpty)
                              Positioned(
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF455A64),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _machineBarcode,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ),
                              ),
                            // Industrial Corners
                            Positioned(top: 8, left: 8, child: _cornerBracket(top: true, left: true, color: const Color(0xFF0D47A1))),
                            Positioned(top: 8, right: 8, child: _cornerBracket(top: true, left: false, color: const Color(0xFF0D47A1))),
                            Positioned(bottom: 8, left: 8, child: _cornerBracket(top: false, left: true, color: const Color(0xFF0D47A1))),
                            Positioned(bottom: 8, right: 8, child: _cornerBracket(top: false, left: false, color: const Color(0xFF0D47A1))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 38, // Slightly more compact button
                        child: ElevatedButton.icon(
                          onPressed: _onScanMachineBarcode,
                          icon: const Icon(Icons.precision_manufacturing_rounded, size: 18),
                          label: const Text('SCAN MACHINE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // ── Right: Work Order Selection ──────────────────────────────
                Expanded(
                  flex: 5,
                  child: _machineBarcode.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            Icon(Icons.touch_app_rounded, color: Colors.grey.withValues(alpha: 0.3), size: 30),
                            const SizedBox(height: 8),
                            Text(
                              'AWAITING SCAN',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Work Order Select',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF546E7A)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                              ),
                              child: WorkOrderDropdown(
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
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cornerBracket({required bool top, required bool left, required Color color}) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: color.withValues(alpha: 0.5), width: 2) : BorderSide.none,
          bottom: !top ? BorderSide(color: color.withValues(alpha: 0.5), width: 2) : BorderSide.none,
          left: left ? BorderSide(color: color.withValues(alpha: 0.5), width: 2) : BorderSide.none,
          right: !left ? BorderSide(color: color.withValues(alpha: 0.5), width: 2) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildProductionInfoGrid() {
    final info = _buildPlanLineDetailsMap(_selectedPlanLine!);
    
    double totalUnits = 0;
    for (int i = 0; i < _scannedTrays.length; i++) {
      totalUnits += double.tryParse(_quantityControllers[i].text) ?? 0;
    }

    final List<Map<String, dynamic>> allItems = [
      // Row 1: Primary WO & Date Info
      {'label': 'WORK ORDER CODE', 'icon': Icons.qr_code_rounded, 'value': info['Work Order Code']?['value']},
      {'label': 'PLAN DATE', 'icon': Icons.calendar_today_rounded, 'value': info['Plan Date']?['value']},
      {'label': 'WORK ORDER DATE', 'icon': Icons.event_note_rounded, 'value': info['Work Order Date']?['value']},
      {'label': 'GARMENT PCS', 'icon': Icons.checkroom_rounded, 'value': info['Garment Pcs']?['value']},
      {'label': 'KNITTING TUBE', 'icon': Icons.settings_suggest_rounded, 'value': info['Knitting Tube']?['value']},
      
      // Row 2: Targets & Performance
      {'label': 'TUBES PER TRAY', 'icon': Icons.flag_rounded, 'value': info['Knitting Tube']?['value']},
      {'label': 'SHIFT', 'icon': Icons.timer_rounded, 'value': info['Shift Code']?['value']},
      {'label': 'SCANNED TRAYS', 'icon': Icons.layers_rounded, 'value': '${_scannedTrays.length}'},
      {'label': 'SCANNED TUBES', 'icon': Icons.analytics_rounded, 'value': totalUnits.toStringAsFixed(0)},
      {'label': 'TRAY CAPACITY', 'icon': Icons.grid_view_rounded, 'isEditable': true},

      // Row 3: Full Width Details
      {'label': 'ITEM DESCRIPTION', 'icon': Icons.description_rounded, 'value': info['Item Description']?['value'], 'isFullWidth': true},
    ];

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.8, // More compact aspect ratio
          ),
          itemCount: 10,
          itemBuilder: (context, index) => _buildMetricCard(allItems[index]),
        ),
        const SizedBox(height: 8),
        _buildMetricCard(allItems[10]),
      ],
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> item) {
    final bool isFullWidth = item['isFullWidth'] ?? false;
    final bool isEditable = item['isEditable'] ?? false;
    final Color? valueColor = item['color'];

    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(item['icon'], size: 12, color: const Color(0xFF1976D2)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item['label'],
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF546E7A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isEditable)
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(6),
              ),
              child: TextField(
                controller: _overrideQuantityController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1)),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  border: InputBorder.none,
                ),
                keyboardType: TextInputType.number,
              ),
            )
          else
            Text(
              item['value'] ?? '---',
              style: TextStyle(
                fontSize: isFullWidth ? 14 : 12,
                fontWeight: FontWeight.w700,
                color: valueColor ?? const Color(0xFF263238),
              ),
              maxLines: isFullWidth ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildActionArea() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onScanTray,
          borderRadius: BorderRadius.circular(16),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'INITIALIZE TRAY SCAN',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannedTraysTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Column(
          children: [
            const TrayTableHeader(),
            if (_scannedTrays.isEmpty)
              const Expanded(child: EmptyScanState(hasBorder: false))
            else
              Expanded(
                child: ListView.builder(
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
      ),
    );
  }
}

class _TrayFadeSlideTransition extends StatelessWidget {
  final Widget child;
  final int delay;

  const _TrayFadeSlideTransition({required this.child, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return FutureBuilder(
          future: Future.delayed(Duration(milliseconds: delay)),
          builder: (context, snapshot) {
            final isVisible = snapshot.connectionState == ConnectionState.done;
            return AnimatedOpacity(
              opacity: isVisible ? value : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Transform.translate(
                offset: Offset(0.0, (1.0 - (isVisible ? value : 0.0)) * 20),
                child: child,
              ),
            );
          },
        );
      },
      child: child,
    );
  }
}
