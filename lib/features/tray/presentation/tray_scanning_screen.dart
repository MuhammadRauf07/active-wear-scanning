import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/utils/barcode_buffer_parser.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/barcode_scanner_dialog.dart';
import 'package:active_wear_scanning/core/widgets/empty_scan_state.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
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
  String _productionType = 'good';
  final _quantityInputFieldController = TextEditingController();
  final _remarksInputFieldController = TextEditingController();

  List<PlanLineResponseModel>? _planLines;
  List<TrayDetailsModel> availableTraysDetail = [];
  List<ProductionProgressResponseModel> existingProductionProgresses = [];
  PlanLineResponseModel? _selectedPlanLine;

  // Centralized Bluetooth Scanner Support
  final _barcodeParser = BarcodeBufferParser();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _overrideQuantityController.dispose();
    _quantityInputFieldController.dispose();
    _remarksInputFieldController.dispose();
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    return _barcodeParser.handleKey(event, _processBluetoothScan);
  }

  Future<void> _processBluetoothScan(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return;

    if (_machineBarcode.isEmpty) {
      // Treat as machine scan
      _fetchMachineData(code);
    } else {
      // Treat as tray scan
      if (_productionType != 'good') {
        _showError('Tray scanning is not for Sample and C Grade production.');
        return;
      }
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
    if (code.isEmpty) return 'Invalid Tray';

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
    if ((trayDetail?.trayType ?? 0) != 1) return 'Invalid Tray type.';
    if (trayDetail?.isReAssigned == true) {
      return 'Tray is already reassigned in Lapping and cannot be bound again.';
    }

    final bool isEmptied =
        trayDetail?.locatorId == null ||
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
      if (mounted) AppLoader.show(context, message: "Fetching item details...");
      final itemRes = await _trayScanningRepo.fetchItemDef(targetItemId);
      if (mounted) AppLoader.hide(context);
      
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

    HapticFeedbackHelper.scanSuccess();
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
    if (!mounted) return;
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trays',
      onResult: (scannedCode) {
        return _validateTrayForScan(scannedCode);
      },
      scannedItemsBuilder: (context) {
        return StatefulBuilder(
          builder: (context, setSubState) {
            if (_scannedTrays.isEmpty) {
              return const Center(
                child: Text(
                  'No trays scanned yet',
                  style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFB0BEC5),
                  width: 1.5,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  const TrayTableHeader(),
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
                            setSubState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onScanMachineBarcode() async {
    final scannedCode = await BarcodeScannerDialog.show(
      context,
      title: 'Scan Barcode',
    );

    if (scannedCode == null || !mounted) return;
    HapticFeedbackHelper.scanSuccess();
    _fetchMachineData(scannedCode);
  }

  Future<void> _fetchMachineData(String scannedCode) async {
    setState(() {
      _machineBarcode = scannedCode;
      _planLines = null;
      _selectedPlanLine = null;
      _productionType = 'good';
      _quantityInputFieldController.clear();
      _remarksInputFieldController.clear();
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
          } else if (!progressResult.success) {
            _showError(progressResult.message);
          }
          if (trayDetailsModel.data != null) {
            availableTraysDetail = (trayDetailsModel.data as List).map((item) => item as TrayDetailsModel).toList();
          }
        });
      } else {
        _showError(apiResult.message);
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
    HapticFeedbackHelper.scanError();
    AppSnackBar.showError(context, message: message);
  }


  bool get _isSaveEnabled {
    if (_productionType == 'good') {
      return _scannedTrays.isNotEmpty;
    } else {
      final text = _quantityInputFieldController.text.trim();
      if (text.isEmpty) return false;
      final val = int.tryParse(text);
      if (val == null || val <= 0) return false;
      return _remarksInputFieldController.text.trim().isNotEmpty;
    }
  }

  void saveTrayAndProductionProgress() async {
    if (!_isSaveEnabled) return;

    if (_productionType == 'good') {
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
            "primaryUOM": _selectedPlanLine!.planLine.primaryUOM,
            "secondaryQuantity": (_selectedPlanLine!.item.perGarmentTube) * (double.tryParse(_quantityControllers[i].text) ?? 5.0),
            "secondaryUOM": _selectedPlanLine!.planLine.secondaryUOM,
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

          if (_selectedPlanLine!.planLine.planHeaderId != 0) {
            productionProgressData["planHeaderId"] = _selectedPlanLine!.planLine.planHeaderId;
          }

          final trayRes = await _trayScanningRepo.updateTrayDetails(planData, latestTrayDetail!.id!);
          if (!trayRes.success) {
            throw Exception(trayRes.message);
          }

          final progRes = await _trayScanningRepo.saveProductionProgress(productionProgressData);
          if (!progRes.success) {
            throw Exception(progRes.message);
          }
        }

        if (mounted) {
          HapticFeedbackHelper.scanSuccess();
          AppSnackBar.showSuccess(context, message: 'Saved successfully!');
          setState(() {
            _scannedTrays.clear();
            _quantityControllers.clear();
            _machineBarcode = '';
            _planLines = null;
            _selectedPlanLine = null;
            _productionType = 'good';
            _quantityInputFieldController.clear();
          });
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Save Error: $e');
        _showError(e.toString());
      } finally {
        if (mounted) AppLoader.hide(context);
      }
    } else {
      final qtyText = _quantityInputFieldController.text.trim();
      final int? x = int.tryParse(qtyText);
      if (x == null || x <= 0) return;

      AppLoader.show(context, message: 'Saving $x entries...');
      try {
        final List<Future<PlexApiResult>> postFutures = [];
        final int nature = _productionType == 'sample' ? 1 : 0;
        final int grade = _productionType == 'c_grade' ? 2 : 0;

        for (int i = 0; i < x; i++) {
          Map<String, dynamic> productionProgressData = {
            "subOperation": "Knitting",
            "date": DateTime.now().toIso8601String(),
            "transactionType": 2,
            "operatorDescription": "system",
            "primaryQuantity": 1.0,
            "primaryUOM": _selectedPlanLine!.planLine.primaryUOM,
            "secondaryQuantity": _selectedPlanLine!.item.perGarmentTube,
            "secondaryUOM": _selectedPlanLine!.planLine.secondaryUOM,
            "wipStatus": 0,
            "gbsFlag": false,
            "pbsFlag": false,
            "productGrade": grade,
            "productNature": nature,
            "isLastProcess": false,
            "isStarted": false,
            "lotMakingFlag": false,
            "reworkFlag": false,
            "operationId": _selectedPlanLine!.operation.id,
            "workOrderHeaderId": _selectedPlanLine!.workOrderHeader.id,
            "workOrderLineId": _selectedPlanLine!.workOrderLine.id,
            "itemId": _selectedPlanLine!.planLine.itemId,
            "shiftId": _selectedPlanLine!.planLine.shiftId,
            "machineId": _selectedPlanLine!.planLine.resourceId,
            "locatorId": 2,
            "remarks": _remarksInputFieldController.text.trim().isNotEmpty
                ? _remarksInputFieldController.text.trim()
                : null,
          };

          if (_selectedPlanLine!.planLine.planHeaderId != 0) {
            productionProgressData["planHeaderId"] = _selectedPlanLine!.planLine.planHeaderId;
          }

          postFutures.add(_trayScanningRepo.saveProductionProgress(productionProgressData));
        }

        final results = await Future.wait(postFutures);

        int successCount = 0;
        final List<String> errors = [];
        for (final res in results) {
          if (res.success) {
            successCount++;
          } else {
            errors.add(res.message);
          }
        }

        if (successCount == results.length) {
          if (mounted) {
            HapticFeedbackHelper.scanSuccess();
            AppSnackBar.showSuccess(context, message: 'Successfully saved $successCount entries.');
            setState(() {
              _quantityInputFieldController.clear();
              _remarksInputFieldController.clear();
              _machineBarcode = '';
              _planLines = null;
              _selectedPlanLine = null;
              _productionType = 'good';
            });
            Navigator.pop(context);
          }
        } else {
          throw Exception('Saved $successCount/${results.length} entries successfully. Errors: ${errors.join(", ")}');
        }
      } catch (e) {
        debugPrint('Save Error: $e');
        _showError(e.toString());
      } finally {
        if (mounted) AppLoader.hide(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Lightest Industrial Grey
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
                      const SizedBox(height: 12),
                      _TrayFadeSlideTransition(delay: 180, child: _buildProductionTypeRadioButtons()),
                    ],
  
                    // Action Area
                    if (_selectedPlanLine != null && _productionType == 'good') ...[
                      const SizedBox(height: 16),
                      _TrayFadeSlideTransition(delay: 200, child: _buildActionArea()),
                    ],
                  ],
                ),
              ),
  
              // ── Scrollable Section (Table or Input Field) ───────────────────
              if (_selectedPlanLine != null) ...[
                if (_productionType == 'good') ...[
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
                      child: _buildScannedTraysTable(),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildQuantityInputFieldSection(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ] else 
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const CustomBackButton(),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tray Scanning',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'Scan Trays in a Work Order',
                    style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isSaveEnabled
                  ? () {
                      HapticFeedbackHelper.buttonClick();
                      saveTrayAndProductionProgress();
                    }
                  : null,
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE CHANGES'),
              style: AppTheme.saveButtonStyle(isEnabled: _isSaveEnabled),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedTraysTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB0BEC5),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const TrayTableHeader(),
          Expanded(
            child: _scannedTrays.isEmpty
                ? const EmptyScanState()
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

  Widget _buildMachineScannerSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left: Scan/Active Machine Button ──────────────────────────
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _machineBarcode.isEmpty
                                  ? 'Scan Machine'
                                  : 'Active Machine: ${_machineBarcode.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF546E7A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _scannedTrays.isEmpty
                              ? () {
                                  HapticFeedbackHelper.buttonClick();
                                  _onScanMachineBarcode();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _machineBarcode.isEmpty
                                ? const Color(0xFF0D47A1)
                                : const Color(0xFF455A64),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade200,
                            disabledForegroundColor: Colors.grey.shade400,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'SCAN MACHINE',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // ── Right: Work Order Selection (or placeholder) ──────────────
                Expanded(
                  flex: 5,
                  child: _machineBarcode.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Work Order ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF546E7A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            WorkOrderDropdown(
                              enabled: _scannedTrays.isEmpty,
                              planLines: _planLines,
                              selectedPlanLine: _selectedPlanLine,
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedPlanLine = newValue;
                                  if (_selectedPlanLine != null) {
                                    _overrideQuantityController.text =
                                        _getPlanQuantityPerTray();
                                  }
                                  _quantityInputFieldController.clear();
                                });
                              },
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

  Widget _buildProductionInfoGrid() {
    final info = _buildPlanLineDetailsMap(_selectedPlanLine!);
    
    double totalUnits = 0;
    for (int i = 0; i < _scannedTrays.length; i++) {
      totalUnits += double.tryParse(_quantityControllers[i].text) ?? 0;
    }

    final List<Map<String, dynamic>> allItems = [
      // Row 1: Primary WO & Date Info
      {'label': 'WORK ORDER', 'icon': Icons.qr_code_rounded, 'value': info['Work Order Code']?['value']},
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
        color: isEditable ? const Color(0xFFFFFDE7) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditable ? const Color(0xFFFFD54F) : const Color(0xFFB0BEC5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                item['icon'],
                size: 12,
                color: isEditable ? const Color(0xFFF57F17) : const Color(0xFF1976D2),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item['label'],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isEditable ? const Color(0xFFE65100) : const Color(0xFF546E7A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isEditable)
            Center(
              child: Container(
                width: 60,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFFE082), width: 1),
                ),
                child: TextField(
                  controller: _overrideQuantityController,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE65100),
                  ),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.only(top: 4),
                    isCollapsed: true,
                    border: InputBorder.none,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (val) {
                    if (val.startsWith('0')) {
                      _overrideQuantityController.text = val.replaceFirst(RegExp(r'^0+'), '');
                      _overrideQuantityController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _overrideQuantityController.text.length),
                      );
                    }
                  },
                  onEditingComplete: () {
                    final val = _overrideQuantityController.text.trim();
                    if (val.isEmpty || (int.tryParse(val) ?? 0) <= 0) {
                      _overrideQuantityController.text = _getPlanQuantityPerTray();
                    }
                    FocusScope.of(context).unfocus();
                  },
                ),
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
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedbackHelper.buttonClick();
          _onScanTray();
        },
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
        label: const Text(
          'TRAY SCAN',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildProductionTypeRadioButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRODUCTION NATURE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF546E7A),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildRadioOption('Good Production', 'good'),
              ),
              Expanded(
                child: _buildRadioOption('Sample', 'sample'),
              ),
              Expanded(
                child: _buildRadioOption('C Grade Production', 'c_grade'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String label, String value) {
    final isSelected = _productionType == value;
    Color optionColor;
    if (value == 'sample') {
      optionColor = const Color(0xFFF59E0B); // Amber/Yellow
    } else if (value == 'c_grade') {
      optionColor = const Color(0xFFEF4444); // Red
    } else {
      optionColor = const Color(0xFF0D47A1); // Primary Blue
    }

    return InkWell(
      onTap: () {
        HapticFeedbackHelper.buttonClick();
        setState(() {
          _productionType = value;
          _quantityInputFieldController.clear();
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: _productionType,
            activeColor: optionColor,
            fillColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return optionColor;
              }
              return Colors.grey.shade400;
            }),
            onChanged: (val) {
              if (val != null) {
                HapticFeedbackHelper.buttonClick();
                setState(() {
                  _productionType = val;
                  _quantityInputFieldController.clear();
                });
              }
            },
          ),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? optionColor : const Color(0xFF37474F),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityInputFieldSection() {
    final title = _productionType == 'sample' ? 'Sample Quantity' : 'C Grade Quantity';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB0BEC5),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF546E7A),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
            ),
            child: TextField(
              controller: _quantityInputFieldController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (val) {
                if (val.startsWith('0')) {
                  _quantityInputFieldController.text = val.replaceFirst(RegExp(r'^0+'), '');
                  _quantityInputFieldController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _quantityInputFieldController.text.length),
                  );
                }
                setState(() {});
              },
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D47A1),
              ),
              decoration: const InputDecoration(
                hintText: 'Enter Quantity',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.add_box_rounded, color: Color(0xFF0D47A1)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'REMARKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF546E7A),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
            ),
            child: TextField(
              controller: _remarksInputFieldController,
              keyboardType: TextInputType.text,
              onChanged: (val) => setState(() {}),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF263238),
              ),
              decoration: const InputDecoration(
                hintText: 'Enter Remarks',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.comment_rounded, color: Color(0xFF546E7A)),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _TrayFadeSlideTransition extends StatefulWidget {
  final Widget child;
  final int delay;

  const _TrayFadeSlideTransition({required this.child, required this.delay});

  @override
  State<_TrayFadeSlideTransition> createState() => _TrayFadeSlideTransitionState();
}

class _TrayFadeSlideTransitionState extends State<_TrayFadeSlideTransition> {
  late Future<void> _delayFuture;

  @override
  void initState() {
    super.initState();
    _delayFuture = Future.delayed(Duration(milliseconds: widget.delay));
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return FutureBuilder(
          future: _delayFuture,
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
      child: widget.child,
    );
  }
}
