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
import 'package:active_wear_scanning/features/knitting_production/model/scanned_tray.dart';
import 'package:active_wear_scanning/features/knitting_production/presentation/widgets/scanned_tray_row.dart';
import 'package:active_wear_scanning/features/knitting_production/presentation/widgets/work_order_dropdown.dart';
import 'package:active_wear_scanning/features/knitting_production/model/plan_header_model.dart';
import 'package:active_wear_scanning/features/knitting_production/model/tray_details_model.dart';
import 'package:active_wear_scanning/features/knitting_production/repo/knitting_production_repo.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:flutter/material.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';

class KnittingProductionScreen extends StatefulWidget {
  const KnittingProductionScreen({super.key});

  @override
  State<KnittingProductionScreen> createState() => _KnittingProductionScreenState();
}

class _KnittingProductionScreenState extends State<KnittingProductionScreen> {
  final _trayScanningRepo = fromPlex<KnittingProductionRepo>();
  String _machineBarcode = '';
  final List<ScannedTray> _scannedTrays = [];
  final List<TextEditingController> _quantityControllers = [];
  final _overrideQuantityController = TextEditingController();
  String _productionType = 'good';
  final _quantityInputFieldController = TextEditingController();
  final _remarksInputFieldController = TextEditingController();
  bool _usePreviousShift = false;

  List<PlanLineResponseModel>? _planLines;
  List<PlanLineResponseModel> _allRawPlanLines = [];
  List<TrayDetailsModel> availableTraysDetail = [];
  List<ProductionProgressResponseModel> existingProductionProgresses = [];
  List<Map<String, dynamic>> _allLotHeaders = [];
  List<Map<String, dynamic>> _allLotLines = [];
  PlanLineResponseModel? _selectedPlanLine;
  List<Shift> _shifts = [];
  final Map<int, List<PlanLineResponseModel>> _allPlanLinesForWorkOrderLines = {};

  // Centralized Bluetooth Scanner Support
  final _barcodeParser = BarcodeBufferParser();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _loadShifts();
    _quantityInputFieldController.addListener(_onQuantityChanged);
  }

  void _onQuantityChanged() {
    setState(() {});
  }

  Future<void> _loadShifts() async {
    try {
      final res = await _trayScanningRepo.fetchShifts();
      if (res.success && res.data != null) {
        setState(() {
          _shifts = List<Shift>.from(res.data);
          _shifts.sort((a, b) => a.startTime.compareTo(b.startTime));
        });
      }
    } catch (e) {
      debugPrint('Error loading shifts: $e');
    }
  }

  int _getCurrentShiftId() {
    if (_shifts.isEmpty) {
      return _selectedPlanLine?.planLine.shiftId ?? 1;
    }

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    int parseTimeToMinutes(String timeStr) {
      try {
        final parts = timeStr.split(':');
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        return hours * 60 + minutes;
      } catch (e) {
        return 0;
      }
    }

    for (final shift in _shifts) {
      final startMin = parseTimeToMinutes(shift.startTime);
      final endMin = parseTimeToMinutes(shift.endTime);

      if (startMin <= endMin) {
        if (currentMinutes >= startMin && currentMinutes < endMin) {
          return shift.id;
        }
      } else {
        if (currentMinutes >= startMin || currentMinutes < endMin) {
          return shift.id;
        }
      }
    }

    return _selectedPlanLine?.planLine.shiftId ?? 1;
  }

  Map<String, dynamic> _getTargetShiftAndDate() {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (_shifts.isEmpty) {
      return {
        'shiftId': _selectedPlanLine?.planLine.shiftId ?? 1,
        'dateStr': todayStr,
      };
    }

    final currentShiftId = _getCurrentShiftId();
    final currentShiftIndex = _shifts.indexWhere((s) => s.id == currentShiftId);
    if (currentShiftIndex == -1) {
      return {
        'shiftId': currentShiftId,
        'dateStr': todayStr,
      };
    }

    // Determine if the current shift is C shift and it is past midnight (hour < 6)
    final currentShift = _shifts[currentShiftIndex];
    final isCShift = currentShift.code.toUpperCase() == 'C' || currentShiftIndex == 2;
    final isPastMidnight = isCShift && now.hour < 6;

    int targetShiftId = currentShiftId;
    String targetDateStr = todayStr;

    if (_usePreviousShift) {
      if (currentShiftIndex == 0) { // A Shift
        // Previous shift is C Shift (last shift)
        final prevShift = _shifts.last;
        targetShiftId = prevShift.id;
        final yesterday = now.subtract(const Duration(days: 1));
        targetDateStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
      } else if (isCShift) { // C Shift
        // Previous shift is B Shift (second shift)
        final prevShift = _shifts[1];
        targetShiftId = prevShift.id;
        if (isPastMidnight) {
          // B Shift occurred yesterday
          final yesterday = now.subtract(const Duration(days: 1));
          targetDateStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
        } else {
          // B Shift occurred today
          targetDateStr = todayStr;
        }
      } else { // B Shift
        // Previous shift is A Shift (first shift)
        final prevShift = _shifts[0];
        targetShiftId = prevShift.id;
        targetDateStr = todayStr;
      }
    } else {
      // Normal shift logic
      if (isPastMidnight) {
        final yesterday = now.subtract(const Duration(days: 1));
        targetDateStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
      } else {
        targetDateStr = todayStr;
      }
    }

    return {
      'shiftId': targetShiftId,
      'dateStr': targetDateStr,
    };
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _overrideQuantityController.dispose();
    _quantityInputFieldController.removeListener(_onQuantityChanged);
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
        _showError('Knitting Production is not for Sample and C Grade production.');
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
    // Check if the tray is currently reassigned in any active draft lot line
    bool isReassignedInDraft = false;
    for (final line in _allLotLines) {
      final bl = line['batchLines'] as Map<String, dynamic>? ?? line;
      if (bl == null) continue;

      final blTrayId = bl['trayId'] as int?;
      final blIsReassigned = bl['isReAssigned'] as bool? ?? false;

      if (blTrayId == trayDetail?.id && blIsReassigned) {
        final lineHeaderId = bl['batchHeaderId'];
        // Check if this headerId belongs to a draft lot header (lockFlag == false)
        final isDraft = _allLotHeaders.any(
          (h) {
            final bh = h['batchHeader'] as Map<String, dynamic>? ?? h;
            final isLocked = bh['lockFlag'] as bool? ?? false;
            return bh['id']?.toString() == lineHeaderId?.toString() && !isLocked;
          },
        );
        if (isDraft) {
          isReassignedInDraft = true;
          break;
        }
      }
    }

    if (isReassignedInDraft) {
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

  double _getSumPrimaryQuantityForWorkOrder(int workOrderLineId) {
    final globalLines = _allPlanLinesForWorkOrderLines[workOrderLineId];
    if (globalLines != null && globalLines.isNotEmpty) {
      return globalLines.fold<double>(0.0, (sum, line) => sum + line.planLine.primaryQuantity);
    }
    return _allRawPlanLines
        .where((line) => line.planLine.workOrderLineId == workOrderLineId)
        .fold<double>(0.0, (sum, line) => sum + line.planLine.primaryQuantity);
  }

  Map<String, dynamic> _buildPlanLineDetailsMap(PlanLineResponseModel planLine) {
    final result = <String, dynamic>{};
    void addField(String key, IconData icon, String label, String? value) {
      if (value != null && value.trim().isNotEmpty && value.trim() != 'null') {
        result[key] = {'icon': icon, 'label': label, 'value': value};
      }
    }

    final plan = planLine.planLine;
    final workOrder = planLine.workOrderHeader;
    final item = planLine.item;

    String? formatDate(String? dateStr) {
      if (dateStr == null) return null;
      return dateStr.split('T')[0].split(' ')[0];
    }

    final totalWoPlanQty = planLine.workOrderLine.tubesAfterAdjustment;
    final sumPrimaryQty = _getSumPrimaryQuantityForWorkOrder(plan.workOrderLineId);
    final remainingWoPlanQty = totalWoPlanQty - sumPrimaryQty;

    addField('Plan Date', Icons.calendar_today, 'Plan Date', formatDate(plan.planDate.toString()));
    addField('Knitting Tube', Icons.precision_manufacturing, 'Knitting Tube', plan.primaryPlanQuantity.toString());
    addField('Tubes Per Tray', Icons.grid_view, 'Tubes Per Tray', plan.quantityPerTray.toString());
    addField('Garment Pcs', Icons.checkroom, 'Garment Pcs', plan.secondaryPlanQuantity.toString());
    addField('Shift Code', Icons.schedule, 'Shift Code', planLine.shift.code.toString());
    addField('Work Order Code', Icons.assignment, 'Work Order Code', workOrder.workOrderCode);
    addField('Work Order Date', Icons.event, 'Work Order Date', formatDate(workOrder.workOrderDate));
    addField('Item Description', Icons.description, 'Item Description', item.description);
    addField('Total WO Plan QTY', Icons.analytics_rounded, 'Total WO Plan QTY', totalWoPlanQty.toStringAsFixed(0));
    addField('Remaining WO Plan QTY', Icons.hourglass_empty_rounded, 'Remaining WO Plan QTY', remainingWoPlanQty.toStringAsFixed(0));

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
      _allRawPlanLines = [];
      _selectedPlanLine = null;
      _productionType = 'good';
      _quantityInputFieldController.clear();
      _remarksInputFieldController.clear();
      _allPlanLinesForWorkOrderLines.clear();
    });

    AppLoader.show(context, message: 'Loading Machine Data...');
    try {
      final apiResult = await _trayScanningRepo.loadWorkOrderBySerialNumber(scannedCode);
      final trayDetailsModel = await _trayScanningRepo.fetchAvailableTrayDetails();
      final progressResult = await _trayScanningRepo.fetchProductionProgress();
      final headersResult = await _trayScanningRepo.fetchLotHeaders();
      final linesResult = await _trayScanningRepo.fetchLotLines();

      if (!mounted) return;

      if (apiResult.success && apiResult.data != null) {
        final rawLines = List<PlanLineResponseModel>.from(apiResult.data);
        final targetInfo = _getTargetShiftAndDate();
        final String targetDateStr = targetInfo['dateStr'];
        final int targetShiftId = targetInfo['shiftId'];
        
        final filteredLines = rawLines.where((element) {
          final planDate = element.planLine.planDate;
          final dateMatches = planDate.startsWith(targetDateStr);
          if (_shifts.isEmpty) {
            return dateMatches;
          }
          final shiftMatches = element.planLine.shiftId == targetShiftId;
          return dateMatches && shiftMatches;
        }).toList();

        // Fetch global plan lines for all unique workOrderLineIds
        final uniqueWOLineIds = rawLines.map((e) => e.planLine.workOrderLineId).toSet().toList();
        for (final wId in uniqueWOLineIds) {
          try {
            final globalRes = await _trayScanningRepo.fetchPlanLinesByWorkOrderLineId(wId);
            if (globalRes.success && globalRes.data != null) {
              _allPlanLinesForWorkOrderLines[wId] = List<PlanLineResponseModel>.from(globalRes.data);
            }
          } catch (e) {
            debugPrint('Error fetching global plan lines for workOrderLineId $wId: $e');
          }
        }

        setState(() {
          _planLines = filteredLines;
          _allRawPlanLines = rawLines;
          if (progressResult.success && progressResult.data != null) {
            existingProductionProgresses = progressResult.data as List<ProductionProgressResponseModel>;
          } else if (!progressResult.success) {
            _showError(progressResult.message);
          }
          if (headersResult.success && headersResult.data != null) {
            _allLotHeaders = List<Map<String, dynamic>>.from(headersResult.data as List);
          }
          if (linesResult.success && linesResult.data != null) {
            _allLotLines = List<Map<String, dynamic>>.from(linesResult.data as List);
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

  /// Fetch the plan-line, add [goodQty]/[goodPcs]/[sampleQty]/[cGradeQty] cumulatively, then PUT back.
  Future<void> _updatePlanLineQuantity({
    double goodQty = 0,
    double goodPcs = 0,
    double sampleQty = 0,
    double cGradeQty = 0,
  }) async {
    if (_selectedPlanLine == null) return;
    final planLineId = _selectedPlanLine!.planLine.id;

    try {
      // 1. Fetch the latest state (concurrencyStamp + current quantities)
      final fetchResult = await _trayScanningRepo.fetchPlanLineById(planLineId);
      if (!fetchResult.success || fetchResult.data == null) {
        debugPrint('Plan-line refresh failed: ${fetchResult.message}');
        if (mounted) _showError('Plan-line refresh failed: ${fetchResult.message}');
        return;
      }

      final latestPlanLine = fetchResult.data as PlanLine;

      // No restriction here. Warning confirmation dialog will handle the check before save.

      // 2. Build cumulative flat update payload.
      // - No 'id' in the body per Swagger schema (id is passed in the URL).
      // - Body must NOT be wrapped in 'input'.
      // - quantityPerTray must be serialized as Int32 (not double).
      // - Only flat ID fields (e.g., operationId) are used; nested objects are not part of PUT schema.
      // - concurrencyStamp must be inside the flat body.
      final Map<String, dynamic> updateData = {
        'planDate': latestPlanLine.planDate,
        'quantityPerTray': latestPlanLine.quantityPerTray.toInt(),
        'cancelled': latestPlanLine.cancelled,
        'primaryUOM': latestPlanLine.primaryUOM,
        'primaryPlanQuantity': latestPlanLine.primaryPlanQuantity.toInt(),
        'secondaryPlanQuantity': latestPlanLine.secondaryPlanQuantity.toInt(),
        'secondaryUOM': latestPlanLine.secondaryUOM,
        'primaryQuantity': (latestPlanLine.primaryQuantity + goodQty).toInt(),
        'secondaryQuantity': (latestPlanLine.secondaryQuantity + goodPcs).toInt(),
        'cycleTime': latestPlanLine.cycleTime,
        'sampleQty': (latestPlanLine.sampleQty + sampleQty).toInt(),
        'cGradeQty': (latestPlanLine.cGradeQty + cGradeQty).toInt(),
        'operationId': latestPlanLine.operationId,
        'shiftId': latestPlanLine.shiftId,
        'resourceId': latestPlanLine.resourceId,
        'workOrderHeaderId': latestPlanLine.workOrderHeaderId,
        'workOrderLineId': latestPlanLine.workOrderLineId,
        'itemId': latestPlanLine.itemId,
        'costCenterLineId': latestPlanLine.costCenterLineId,
        'concurrencyStamp': latestPlanLine.concurrencyStamp,
        // Optional nullable fields — only include when non-null
        if (latestPlanLine.orderNo != null) 'orderNo': latestPlanLine.orderNo,
        if (latestPlanLine.actualStartTime != null) 'actualStartTime': latestPlanLine.actualStartTime,
        if (latestPlanLine.actualEndTime != null) 'actualEndTime': latestPlanLine.actualEndTime,
        if (latestPlanLine.cutsomerPO != null) 'cutsomerPO': latestPlanLine.cutsomerPO,
        if (latestPlanLine.planLineCode != null) 'planLineCode': latestPlanLine.planLineCode,
        if (latestPlanLine.saleOrderMstId != null) 'saleOrderMstId': latestPlanLine.saleOrderMstId,
        if (latestPlanLine.saleOrderLineId != null) 'saleOrderLineId': latestPlanLine.saleOrderLineId,
        if (latestPlanLine.planHeaderId != null) 'planHeaderId': latestPlanLine.planHeaderId,
      };

      // 3. PUT — Flat body directly.
      final updateResult = await _trayScanningRepo.updatePlanLine(
        updateData,
        planLineId,
      );
      if (!updateResult.success) {
        debugPrint('Plan-line update failed: ${updateResult.message}');
        if (mounted) {
          _showError('Plan-line update failed: ${updateResult.message}');
        }
      }
    } catch (e) {
      debugPrint('_updatePlanLineQuantity error: $e');
      if (mounted) {
        _showError('Plan-line update error: $e');
      }
    }
  }

  void saveTrayAndProductionProgress() async {
    if (!_isSaveEnabled) return;

    if (_productionType == 'good') {
      AppLoader.show(context, message: 'Saving Changes...');
      try {
        final totalScannedTubes = _scannedTrays.fold<double>(
          0,
          (sum, tray) {
            final idx = _scannedTrays.indexOf(tray);
            return sum + (double.tryParse(_quantityControllers[idx].text) ?? 0);
          },
        );

        final targetWorkOrderLineId = _selectedPlanLine!.planLine.workOrderLineId;

        // Refresh and check that primary quantity does not exceed tubes after adjustment.
        // If it does, warn user with overproduction warning confirmation dialog.
        if (mounted) AppLoader.show(context, message: 'Refreshing plan data...');
        final apiResult = await _trayScanningRepo.loadWorkOrderBySerialNumber(_machineBarcode);
        if (!apiResult.success || apiResult.data == null) {
          if (mounted) AppLoader.hide(context);
          throw Exception('Failed to refresh work order data: ${apiResult.message}');
        }
        
        final freshRawLines = List<PlanLineResponseModel>.from(apiResult.data);

        // Fetch global plan lines for the targetWorkOrderLineId
        final globalRes = await _trayScanningRepo.fetchPlanLinesByWorkOrderLineId(targetWorkOrderLineId);
        if (!globalRes.success || globalRes.data == null) {
          if (mounted) AppLoader.hide(context);
          throw Exception('Failed to refresh global plan lines: ${globalRes.message}');
        }
        final freshGlobalLines = List<PlanLineResponseModel>.from(globalRes.data);

        if (mounted) {
          setState(() {
            _allRawPlanLines = freshRawLines;
            _allPlanLinesForWorkOrderLines[targetWorkOrderLineId] = freshGlobalLines;
            
            final matchedIndex = freshRawLines.indexWhere((element) => element.planLine.id == _selectedPlanLine!.planLine.id);
            if (matchedIndex != -1) {
              _selectedPlanLine = freshRawLines[matchedIndex];
            } else {
              final globalMatchedIndex = freshGlobalLines.indexWhere((element) => element.planLine.id == _selectedPlanLine!.planLine.id);
              if (globalMatchedIndex != -1) {
                _selectedPlanLine = freshGlobalLines[globalMatchedIndex];
              }
            }
          });
        }
        if (mounted) AppLoader.hide(context);

        double sumPrimaryQty = 0;
        for (final line in freshGlobalLines) {
          if (line.planLine.workOrderLineId == targetWorkOrderLineId) {
            sumPrimaryQty += line.planLine.primaryQuantity;
          }
        }
        final double limit = _selectedPlanLine!.workOrderLine.tubesAfterAdjustment;

        bool proceed = true;
        if (sumPrimaryQty + totalScannedTubes > limit) {
          if (mounted) {
            proceed = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return AlertDialog(
                  backgroundColor: const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                      SizedBox(width: 8),
                      Text(
                        'Overproduction Alert',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  content: const Text(
                    'Plan production has been scanned. More production will be taken as shortfall. Do you want to proceed?',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ) ?? false;
          } else {
            proceed = false;
          }
        }

        if (!proceed) return;

        if (mounted) AppLoader.show(context, message: 'Saving Changes...');

        for (int i = 0; i < _scannedTrays.length; i++) {
          final trayResFetch = await _trayScanningRepo.fetchTrayById(_scannedTrays[i].trayUpdateId!);
          if (!trayResFetch.success || trayResFetch.data == null) {
            throw Exception('Could not refresh tray details for ${_scannedTrays[i].trayCode}: ${trayResFetch.message}');
          }

          final latestTray = trayResFetch.data as TrayDetailsModel;
          final latestTrayDetail = latestTray.trayDetails;

          final targetShiftId = _selectedPlanLine!.planLine.shiftId;

          Map<String, dynamic> planData = {
            'trayCode': latestTrayDetail?.trayCode,
            'trayType': 1,
            'shiftId': targetShiftId,
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
            "transactionType": 6,
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
            "shiftId": targetShiftId,
            "primaryTrayId": latestTrayDetail?.id,
            "secondaryTrayId": latestTrayDetail?.id,
            "machineId": _selectedPlanLine!.planLine.resourceId,
            "locatorId": 2,
          };

          if (_selectedPlanLine!.planLine.planHeaderId != null) {
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

        // ── Cumulative good-quantity update on plan line ─────────────────
         _scannedTrays.fold<double>(
          0,
          (sum, tray) {
            final idx = _scannedTrays.indexOf(tray);
            return sum + (double.tryParse(_quantityControllers[idx].text) ?? 0);
          },
        );
        final totalScannedPcs = _scannedTrays.fold<double>(
          0,
          (sum, tray) {
            final idx = _scannedTrays.indexOf(tray);
            final qty = double.tryParse(_quantityControllers[idx].text) ?? 0;
            return sum + (qty * tray.perGarmentTube);
          },
        );
        await _updatePlanLineQuantity(goodQty: totalScannedTubes, goodPcs: totalScannedPcs);

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
        final List<Map<String, dynamic>> payloads = [];
        final int nature = _productionType == 'sample' ? 1 : 0;
        final int grade = _productionType == 'c_grade' ? 2 : 0;

        for (int i = 0; i < x; i++) {
          Map<String, dynamic> productionProgressData = {
            "subOperation": "Knitting",
            "date": DateTime.now().toIso8601String(),
            "transactionType": 6,
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

          if (_selectedPlanLine!.planLine.planHeaderId != null) {
            productionProgressData["planHeaderId"] = _selectedPlanLine!.planLine.planHeaderId;
          }

          payloads.add(productionProgressData);
        }

        // Execute API calls in batches of 15 to prevent connection/socket exhaustion
        final List<PlexApiResult> results = [];
        const int batchSize = 15;
        for (int i = 0; i < payloads.length; i += batchSize) {
          final end = (i + batchSize < payloads.length) ? i + batchSize : payloads.length;
          final chunk = payloads.sublist(i, end);

          final chunkFutures = chunk
              .map((p) => _trayScanningRepo.saveProductionProgress(p))
              .toList();
          final chunkResults = await Future.wait(chunkFutures);
          results.addAll(chunkResults);
        }

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
          // ── Cumulative sample/c-grade quantity update on plan line ────────
          final int enteredQty = int.tryParse(qtyText) ?? 0;
          if (_productionType == 'sample') {
            await _updatePlanLineQuantity(sampleQty: enteredQty.toDouble());
          } else {
            await _updatePlanLineQuantity(cGradeQty: enteredQty.toDouble());
          }

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
  
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Machine Scanner Section
                      _KnittingProductionFadeSlideTransition(delay: 0, child: _buildMachineScannerSection()),
  
                      // Production Information Section
                      if (_selectedPlanLine != null) ...[
                        const SizedBox(height: 16),
                        const _KnittingProductionFadeSlideTransition(
                          delay: 100,
                          child: Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'PRODUCTION INTELLIGENCE',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                            ),
                          ),
                        ),
                        _KnittingProductionFadeSlideTransition(delay: 150, child: _buildProductionInfoGrid()),
                        const SizedBox(height: 12),
                        _KnittingProductionFadeSlideTransition(delay: 180, child: _buildProductionTypeRadioButtons()),
                      ],
  
                      // Action Area
                      if (_selectedPlanLine != null && _productionType == 'good') ...[
                        const SizedBox(height: 16),
                        _KnittingProductionFadeSlideTransition(delay: 200, child: _buildActionArea()),
                      ],
  
                      // Scrollable Section (Table or Input Field)
                      if (_selectedPlanLine != null) ...[
                        if (_productionType == 'good') ...[
                          const SizedBox(height: 16),
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: _KnittingProductionFadeSlideTransition(
                              delay: 250,
                              child: Text(
                                'ACTIVE SCANNED TRAYS',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                              ),
                            ),
                          ),
                          _KnittingProductionFadeSlideTransition(
                            delay: 280,
                            child: SizedBox(
                              height: 320,
                              child: _buildScannedTraysTable(),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          _buildQuantityInputFieldSection(),
                        ],
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
                    'Knitting Production',
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
                                  : 'ACTIVE MACHINE: ${_machineBarcode.toUpperCase()}',
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
                          onPressed: (_scannedTrays.isEmpty && _quantityInputFieldController.text.trim().isEmpty)
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
                            InkWell(
                              onTap: (_scannedTrays.isEmpty && _quantityInputFieldController.text.trim().isEmpty)
                                  ? () {
                                      HapticFeedbackHelper.buttonClick();
                                      setState(() {
                                        _usePreviousShift = !_usePreviousShift;
                                      });
                                      if (_machineBarcode.isNotEmpty) {
                                        _fetchMachineData(_machineBarcode);
                                      }
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _usePreviousShift,
                                      activeColor: const Color(0xFF0D47A1),
                                      onChanged: (_scannedTrays.isEmpty && _quantityInputFieldController.text.trim().isEmpty)
                                          ? (value) {
                                              if (value != null) {
                                                HapticFeedbackHelper.buttonClick();
                                                setState(() {
                                                  _usePreviousShift = value;
                                                });
                                                if (_machineBarcode.isNotEmpty) {
                                                  _fetchMachineData(_machineBarcode);
                                                }
                                              }
                                            }
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Add to Previous Shift',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF37474F),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'SELECT WORK ORDER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF546E7A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_planLines == null || _planLines!.isEmpty)
                              Container(
                                height: 48,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFCFD8DC),
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  'No data found',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              )
                            else
                              WorkOrderDropdown(
                                enabled: _scannedTrays.isEmpty && _quantityInputFieldController.text.trim().isEmpty,
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
      {'label': 'TUBES PER TRAY', 'icon': Icons.flag_rounded, 'value': info['Tubes Per Tray']?['value']},
      
      // Row 2: Targets & Performance
      {'label': 'SHIFT', 'icon': Icons.timer_rounded, 'value': info['Shift Code']?['value']},
      {'label': 'SCANNED TRAYS', 'icon': Icons.layers_rounded, 'value': '${_scannedTrays.length}'},
      {'label': 'SCANNED TUBES', 'icon': Icons.analytics_rounded, 'value': totalUnits.toStringAsFixed(0)},
      {'label': 'TRAY CAPACITY', 'icon': Icons.grid_view_rounded, 'isEditable': true},
      {'label': 'TOTAL WO PLAN QTY', 'icon': Icons.analytics_rounded, 'value': info['Total WO Plan QTY']?['value']},
      {'label': 'REMAINING WO PLAN QTY', 'icon': Icons.hourglass_empty_rounded, 'value': info['Remaining WO Plan QTY']?['value']},

      // Row 3: Full Width Details
      {'label': 'ITEM DESCRIPTION', 'icon': Icons.description_rounded, 'value': info['Item Description']?['value'], 'isFullWidth': true},
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final double cellWidth = (screenWidth - 32 - (3 * 6)) / 4;
    final double cellHeight = screenWidth >= 600 ? 74.0 : 68.0;
    final double childAspectRatio = cellWidth / cellHeight;

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: 12,
          itemBuilder: (context, index) => _buildMetricCard(allItems[index]),
        ),
        const SizedBox(height: 8),
        _buildMetricCard(allItems[12]),
      ],
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> item) {
    final bool isFullWidth = item['isFullWidth'] ?? false;
    final bool isEditable = item['isEditable'] ?? false;
    final Color? valueColor = item['color'];
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth >= 600;

    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: isFullWidth
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : (isTablet
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
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
                size: isTablet ? 12 : 11,
                color: isEditable ? const Color(0xFFF57F17) : const Color(0xFF1976D2),
              ),
              SizedBox(width: isTablet ? 6 : 4),
              Expanded(
                child: Text(
                  item['label'],
                  style: TextStyle(
                    fontSize: isTablet ? 10 : 8.5,
                    fontWeight: FontWeight.w700,
                    color: isEditable ? const Color(0xFFE65100) : const Color(0xFF546E7A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isEditable)
            Center(
              child: Container(
                width: isTablet ? 60 : 54,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFFE082), width: 1),
                ),
                child: TextField(
                  controller: _overrideQuantityController,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE65100),
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
                fontSize: isFullWidth ? 14 : (isTablet ? 12 : 10.5),
                fontWeight: FontWeight.w800,
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
          'SCAN TRAY',
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

  void _handleProductionTypeChange(String newType) {
    if (_productionType == newType) return;

    if (_productionType == 'good' && _scannedTrays.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Text(
                  'Confirm Switch',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Switching production nature will dismiss all scanned trays. Do you want to proceed?',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _productionType = newType;
                    _scannedTrays.clear();
                    _quantityControllers.clear();
                    _quantityInputFieldController.clear();
                    _remarksInputFieldController.clear();
                  });
                },
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      setState(() {
        _productionType = newType;
        _quantityInputFieldController.clear();
        _remarksInputFieldController.clear();
      });
    }
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
                child: _buildRadioOption('GOOD PRODUCTION', 'good'),
              ),
              Expanded(
                child: _buildRadioOption('SAMPLE', 'sample'),
              ),
              Expanded(
                child: _buildRadioOption('C-GRADE PRODUCTION', 'c_grade'),
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
        _handleProductionTypeChange(value);
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
                _handleProductionTypeChange(val);
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
    final isRemarksEnabled = _quantityInputFieldController.text.trim().isNotEmpty;
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
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
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
              color: isRemarksEnabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isRemarksEnabled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _remarksInputFieldController,
              enabled: isRemarksEnabled,
              keyboardType: TextInputType.text,
              onChanged: (val) => setState(() {}),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isRemarksEnabled ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
              ),
              decoration: InputDecoration(
                hintText: 'Enter Remarks',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.comment_rounded,
                  color: isRemarksEnabled ? const Color(0xFF0D47A1) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _KnittingProductionFadeSlideTransition extends StatefulWidget {
  final Widget child;
  final int delay;

  const _KnittingProductionFadeSlideTransition({required this.child, required this.delay});

  @override
  State<_KnittingProductionFadeSlideTransition> createState() => _KnittingProductionFadeSlideTransitionState();
}

class _KnittingProductionFadeSlideTransitionState extends State<_KnittingProductionFadeSlideTransition> {
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
