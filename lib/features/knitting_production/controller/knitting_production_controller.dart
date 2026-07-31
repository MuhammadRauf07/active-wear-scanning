import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/knitting_production/model/plan_header_model.dart';
import 'package:active_wear_scanning/features/knitting_production/model/scanned_tray.dart';
import 'package:active_wear_scanning/features/knitting_production/model/tray_details_model.dart';
import 'package:active_wear_scanning/features/knitting_production/repo/knitting_production_repo.dart';
import 'package:active_wear_scanning/features/knitting_production/model/knitting_production_state.dart';

class KnittingProductionController extends ChangeNotifier {
  final _repo = fromPlex<KnittingProductionRepo>();

  KnittingProductionState _state = const KnittingProductionState();
  KnittingProductionState get state => _state;

  KnittingProductionController() {
    loadShifts();
  }

  Future<void> loadShifts() async {
    try {
      final res = await _repo.fetchShifts();
      if (res.success && res.data != null) {
        final shiftsList = List<Shift>.from(res.data);
        shiftsList.sort((a, b) => a.startTime.compareTo(b.startTime));
        _state = _state.copyWith(shifts: shiftsList);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading shifts: $e');
    }
  }

  int _getCurrentShiftId() {
    if (_state.shifts.isEmpty) {
      return _state.selectedPlanLine?.planLine.shiftId ?? 1;
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

    for (final shift in _state.shifts) {
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

    return _state.selectedPlanLine?.planLine.shiftId ?? 1;
  }

  Map<String, dynamic> _getTargetShiftAndDate() {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (_state.shifts.isEmpty) {
      return {
        'shiftId': _state.selectedPlanLine?.planLine.shiftId ?? 1,
        'dateStr': todayStr,
      };
    }

    final currentShiftId = _getCurrentShiftId();
    final currentShiftIndex = _state.shifts.indexWhere((s) => s.id == currentShiftId);
    if (currentShiftIndex == -1) {
      return {
        'shiftId': currentShiftId,
        'dateStr': todayStr,
      };
    }

    final currentShift = _state.shifts[currentShiftIndex];
    final isCShift = currentShift.code.toUpperCase() == 'C' || currentShiftIndex == 2;
    final isPastMidnight = isCShift && now.hour < 6;

    int targetShiftId = currentShiftId;
    String targetDateStr = todayStr;

    if (_state.usePreviousShift) {
      if (currentShiftIndex == 0) { // A Shift
        final prevShift = _state.shifts.last;
        targetShiftId = prevShift.id;
        final yesterday = now.subtract(const Duration(days: 1));
        targetDateStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
      } else if (isCShift) { // C Shift
        final prevShift = _state.shifts[1];
        targetShiftId = prevShift.id;
        if (isPastMidnight) {
          final yesterday = now.subtract(const Duration(days: 1));
          targetDateStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
        } else {
          targetDateStr = todayStr;
        }
      } else { // B Shift
        final prevShift = _state.shifts[0];
        targetShiftId = prevShift.id;
        targetDateStr = todayStr;
      }
    } else {
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

  void resetMachine() {
    _state = _state.copyWith(
      machineBarcode: '',
      clearPlanLines: true,
      clearSelectedPlanLine: true,
      scannedTrays: [],
      productionType: 'good',
      allRawPlanLines: [],
      availableTraysDetail: [],
      existingProductionProgresses: [],
      allLotHeaders: [],
      allLotLines: [],
      allPlanLinesForWorkOrderLines: {},
      clearError: true,
    );
    notifyListeners();
  }

  bool _isLoadingMoreAvailableTrays = false;
  bool get isLoadingMoreAvailableTrays => _isLoadingMoreAvailableTrays;
  bool _hasMoreAvailableTrays = true;
  bool get hasMoreAvailableTrays => _hasMoreAvailableTrays;

  Future<void> fetchAvailableTrays({bool isRefresh = true}) async {
    if (isRefresh) {
      _hasMoreAvailableTrays = true;
      _state = _state.copyWith(availableTraysDetail: []);
      notifyListeners();
    }

    try {
      final skipCount = isRefresh ? 0 : _state.availableTraysDetail.length;
      final trayDetailsModel = await _repo.fetchAvailableTrayDetails(
        maxResultCount: 100,
        skipCount: skipCount,
      );
      if (trayDetailsModel.success && trayDetailsModel.data != null) {
        final newItems = (trayDetailsModel.data as List).map((item) => item as TrayDetailsModel).toList();
        if (newItems.length < 100) {
          _hasMoreAvailableTrays = false;
        }
        final updatedList = isRefresh ? newItems : [..._state.availableTraysDetail, ...newItems];
        _state = _state.copyWith(availableTraysDetail: updatedList);
        notifyListeners();
      } else {
        if (isRefresh) {
          _hasMoreAvailableTrays = false;
        }
      }
    } catch (e) {
      debugPrint('Error fetching available trays: $e');
    }
  }

  Future<void> fetchMoreAvailableTrays() async {
    if (_isLoadingMoreAvailableTrays || !_hasMoreAvailableTrays) return;
    _isLoadingMoreAvailableTrays = true;
    notifyListeners();

    await fetchAvailableTrays(isRefresh: false);

    _isLoadingMoreAvailableTrays = false;
    notifyListeners();
  }

  Future<void> fetchMachineData(String scannedCode) async {
    _state = _state.copyWith(
      isLoading: true,
      machineBarcode: scannedCode,
      clearPlanLines: true,
      clearSelectedPlanLine: true,
      scannedTrays: [],
      productionType: 'good',
      allRawPlanLines: [],
      availableTraysDetail: [],
      existingProductionProgresses: [],
      allLotHeaders: [],
      allLotLines: [],
      allPlanLinesForWorkOrderLines: {},
      clearError: true,
    );
    notifyListeners();

    try {
      final apiResult = await _repo.loadWorkOrderBySerialNumber(scannedCode);
      final progressResult = await _repo.fetchProductionProgress();
      final headersResult = await _repo.fetchLotHeaders();
      final linesResult = await _repo.fetchLotLines();

      if (apiResult.success && apiResult.data != null) {
        final rawLines = List<PlanLineResponseModel>.from(apiResult.data);
        final targetInfo = _getTargetShiftAndDate();
        final String targetDateStr = targetInfo['dateStr'];
        final int targetShiftId = targetInfo['shiftId'];

        final filteredLines = rawLines.where((element) {
          final planDate = element.planLine.planDate;
          final dateMatches = planDate.startsWith(targetDateStr);
          if (_state.shifts.isEmpty) return dateMatches;
          final shiftMatches = element.planLine.shiftId == targetShiftId;
          return dateMatches && shiftMatches;
        }).toList();

        // Fetch global plan lines for unique workOrderLineIds
        final uniqueWOLineIds = rawLines.map((e) => e.planLine.workOrderLineId).toSet().toList();
        final Map<int, List<PlanLineResponseModel>> allPlanLinesForWorkOrderLines = {};

        for (final wId in uniqueWOLineIds) {
          try {
            final globalRes = await _repo.fetchPlanLinesByWorkOrderLineId(wId);
            if (globalRes.success && globalRes.data != null) {
              allPlanLinesForWorkOrderLines[wId] = List<PlanLineResponseModel>.from(globalRes.data);
            }
          } catch (e) {
            debugPrint('Error fetching global plan lines for workOrderLineId $wId: $e');
          }
        }

        List<ProductionProgressResponseModel> existingProductionProgresses = [];
        if (progressResult.success && progressResult.data != null) {
          existingProductionProgresses = progressResult.data as List<ProductionProgressResponseModel>;
        }

        List<Map<String, dynamic>> allLotHeaders = [];
        if (headersResult.success && headersResult.data != null) {
          allLotHeaders = List<Map<String, dynamic>>.from(headersResult.data as List);
        }

        List<Map<String, dynamic>> allLotLines = [];
        if (linesResult.success && linesResult.data != null) {
          allLotLines = List<Map<String, dynamic>>.from(linesResult.data as List);
        }

        _state = _state.copyWith(
          planLines: filteredLines,
          allRawPlanLines: rawLines,
          allPlanLinesForWorkOrderLines: allPlanLinesForWorkOrderLines,
          existingProductionProgresses: existingProductionProgresses,
          allLotHeaders: allLotHeaders,
          allLotLines: allLotLines,
          availableTraysDetail: [],
          isLoading: false,
        );
      } else {
        throw Exception(apiResult.message);
      }
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        machineBarcode: '',
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  void changeSelectedPlanLine(PlanLineResponseModel? line) {
    _state = _state.copyWith(selectedPlanLine: line, clearSelectedPlanLine: line == null);
    notifyListeners();
  }

  void setProductionType(String type) {
    _state = _state.copyWith(productionType: type);
    notifyListeners();
  }

  void togglePreviousShift(bool usePrev) {
    _state = _state.copyWith(usePreviousShift: usePrev);
    
    // Recalculate filtered plan lines based on new shift selection
    if (_state.allRawPlanLines.isNotEmpty) {
      final targetInfo = _getTargetShiftAndDate();
      final String targetDateStr = targetInfo['dateStr'];
      final int targetShiftId = targetInfo['shiftId'];

      final filteredLines = _state.allRawPlanLines.where((element) {
        final planDate = element.planLine.planDate;
        final dateMatches = planDate.startsWith(targetDateStr);
        if (_state.shifts.isEmpty) return dateMatches;
        final shiftMatches = element.planLine.shiftId == targetShiftId;
        return dateMatches && shiftMatches;
      }).toList();

      _state = _state.copyWith(planLines: filteredLines);
    }
    notifyListeners();
  }

  void removeScannedTray(int index) {
    final list = List<ScannedTray>.from(_state.scannedTrays);
    list.removeAt(index);
    _state = _state.copyWith(scannedTrays: list);
    notifyListeners();
  }

  void updateTrayQuantity(int index, String qty) {
    final list = List<ScannedTray>.from(_state.scannedTrays);
    final tray = list[index];
    list[index] = tray.copyWith(quantity: qty);
    _state = _state.copyWith(scannedTrays: list);
    notifyListeners();
  }

  void toggleTrayHold(int index, bool isHold) {
    if (index >= 0 && index < _state.scannedTrays.length) {
      final list = List<ScannedTray>.from(_state.scannedTrays);
      list[index] = list[index].copyWith(isHold: isHold);
      _state = _state.copyWith(scannedTrays: list);
      notifyListeners();
    }
  }

  String getPlanQuantityPerTray() {
    if (_state.selectedPlanLine == null) return '';
    final quantity = _state.selectedPlanLine!.planLine.quantityPerTray;
    return quantity == quantity.roundToDouble()
        ? quantity.round().toString()
        : quantity.toString();
  }

  String getDefaultQuantityForNewTray(String overrideText) {
    final override = overrideText.trim();
    if (override.isNotEmpty) return override;
    return getPlanQuantityPerTray();
  }

  Future<String?> validateAndAddTray(String scannedCode, String overrideText) async {
    if (_state.selectedPlanLine == null) return 'Please select a work order first';
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid Tray';

    final alreadyScanned = _state.scannedTrays.any((t) => t.trayCode.trim() == code);
    if (alreadyScanned) return 'Already assigned';

    var available = _state.availableTraysDetail.where((t) {
      final trayCodeFromApi = (t.trayDetails?.trayCode ?? '').trim().toLowerCase();
      final scannedCodeClean = code.toLowerCase();
      return trayCodeFromApi == scannedCodeClean;
    }).toList();

    if (available.isEmpty) {
      try {
        final res = await _repo.fetchTrayDetailByCode(code);
        if (res.success && res.data != null) {
          final fetchedTray = res.data as TrayDetailsModel;
          available = [fetchedTray];
          final updatedAvailableList = List<TrayDetailsModel>.from(_state.availableTraysDetail)..add(fetchedTray);
          _state = _state.copyWith(availableTraysDetail: updatedAvailableList);
        }
      } catch (e) {
        debugPrint('Error fetching tray dynamically: $e');
      }
    }

    if (available.isEmpty) return 'Tray not available';

    final trayDetail = available.first.trayDetails;
    if (trayDetail?.active != true) return 'Tray is not active';
    if ((trayDetail?.trayType ?? 0) != 1) return 'Invalid Tray type.';

    // Check if the tray is currently reassigned in any active draft lot line
    bool isReassignedInDraft = false;
    for (final line in _state.allLotLines) {
      final bl = line['batchLines'] as Map<String, dynamic>? ?? line;

      final blTrayId = bl['trayId'] as int?;
      final blIsReassigned = bl['isReAssigned'] as bool? ?? false;

      if (blTrayId == trayDetail?.id && blIsReassigned) {
        final lineHeaderId = bl['batchHeaderId'];
        final isDraft = _state.allLotHeaders.any((h) {
          final bh = h['batchHeader'] as Map<String, dynamic>? ?? h;
          final isLocked = bh['lockFlag'] as bool? ?? false;
          return bh['id']?.toString() == lineHeaderId?.toString() && !isLocked;
        });
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
        trayDetail?.trayQuantity == 0 ||
        trayDetail?.trayQuantity == null;

    if (!isEmptied) {
      return 'Tray already scanned (Exists in Production Progress)';
    }

    int targetItemId = _state.selectedPlanLine?.item.id ?? 0;
    String colorDesc = _state.selectedPlanLine?.item.colorDescription ?? '';
    String sizeDesc = _state.selectedPlanLine?.item.sizeDescription ?? '';
    double perGarmentTube = _state.selectedPlanLine?.item.perGarmentTube ?? 0;

    if (targetItemId > 0) {
      final itemRes = await _repo.fetchItemDef(targetItemId);
      if (itemRes.success && itemRes.data != null) {
        final itemData = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
        if (itemData['colorDescription'] != null) colorDesc = itemData['colorDescription'];
        if (itemData['sizeDescription'] != null) sizeDesc = itemData['sizeDescription'];
        if (itemData['perGarmentTube'] != null) perGarmentTube = (itemData['perGarmentTube'] as num).toDouble();
      }
    }

    final list = List<ScannedTray>.from(_state.scannedTrays);
    list.add(
      ScannedTray(
        trayCode: code,
        trayUpdateId: trayDetail!.id,
        trayConcurrencyStamp: trayDetail.concurrencyStamp,
        colorDescription: colorDesc,
        sizeDescription: sizeDesc,
        perGarmentTube: perGarmentTube,
        quantity: getDefaultQuantityForNewTray(overrideText),
      ),
    );
    _state = _state.copyWith(scannedTrays: list);
    notifyListeners();
    return null;
  }

  double getSumPrimaryQuantityForWorkOrder(int workOrderLineId) {
    final globalLines = _state.allPlanLinesForWorkOrderLines[workOrderLineId];
    if (globalLines != null && globalLines.isNotEmpty) {
      return globalLines.fold<double>(0.0, (sum, line) => sum + line.planLine.primaryQuantity + line.planLine.sampleQty + line.planLine.cGradeQty);
    }
    return _state.allRawPlanLines
        .where((line) => line.planLine.workOrderLineId == workOrderLineId)
        .fold<double>(0.0, (sum, line) => sum + line.planLine.primaryQuantity + line.planLine.sampleQty + line.planLine.cGradeQty);
  }

  List<TrayDetailsModel> getFilteredAvailableTrays() {
    return _state.availableTraysDetail.where((t) {
      final trayDetail = t.trayDetails;
      if (trayDetail == null) return false;
      if (trayDetail.active != true) return false;
      if (trayDetail.trayType != 1) return false;
      
      final bool isEmptied = trayDetail.locatorId == null || trayDetail.trayQuantity == 0 || trayDetail.trayQuantity == null;
      if (!isEmptied) return false;
      
      bool isReassigned = false;
      for (final line in _state.allLotLines) {
        final bl = line['batchLines'] as Map<String, dynamic>? ?? line;

        final blTrayId = bl['trayId'] as int?;
        final blIsReassigned = bl['isReAssigned'] as bool? ?? false;

        if (blTrayId == trayDetail.id && blIsReassigned) {
          final lineHeaderId = bl['batchHeaderId'];
          final isDraft = _state.allLotHeaders.any((h) {
            final bh = h['batchHeader'] as Map<String, dynamic>? ?? h;
            final isLocked = bh['lockFlag'] as bool? ?? false;
            return bh['id']?.toString() == lineHeaderId?.toString() && !isLocked;
          });
          if (isDraft) {
            isReassigned = true;
            break;
          }
        }
      }
      return !isReassigned;
    }).toList();
  }

  Future<void> _updatePlanLineQuantity({
    double goodQty = 0,
    double goodPcs = 0,
    double sampleQty = 0,
    double cGradeQty = 0,
  }) async {
    try {
      final planLineId = _state.selectedPlanLine!.planLine.id;
      final resFetch = await _repo.fetchPlanLineById(planLineId);
      if (!resFetch.success || resFetch.data == null) {
        throw Exception('Could not fetch latest plan line: ${resFetch.message}');
      }
      final latestPlanLine = resFetch.data as PlanLine;

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
        if (latestPlanLine.orderNo != null) 'orderNo': latestPlanLine.orderNo,
        if (latestPlanLine.actualStartTime != null) 'actualStartTime': latestPlanLine.actualStartTime,
        if (latestPlanLine.actualEndTime != null) 'actualEndTime': latestPlanLine.actualEndTime,
        if (latestPlanLine.cutsomerPO != null) 'cutsomerPO': latestPlanLine.cutsomerPO,
        if (latestPlanLine.planLineCode != null) 'planLineCode': latestPlanLine.planLineCode,
        if (latestPlanLine.saleOrderMstId != null) 'saleOrderMstId': latestPlanLine.saleOrderMstId,
        if (latestPlanLine.saleOrderLineId != null) 'saleOrderLineId': latestPlanLine.saleOrderLineId,
        if (latestPlanLine.planHeaderId != null) 'planHeaderId': latestPlanLine.planHeaderId,
      };

      final updateResult = await _repo.updatePlanLine(updateData, planLineId);
      if (!updateResult.success) {
        throw Exception('Plan line update failed: ${updateResult.message}');
      }
    } catch (e) {
      debugPrint('_updatePlanLineQuantity error: $e');
      rethrow;
    }
  }

  Future<void> saveTrayAndProductionProgress({
    required Future<bool> Function() onConfirmOverproduction,
    required void Function() onSuccess,
    String? remarksText,
    String? singleQtyText,
  }) async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      if (_state.productionType == 'good') {
        if (_state.scannedTrays.isEmpty) {
          throw Exception('No trays scanned to save.');
        }

        final totalScannedTubes = _state.scannedTrays.fold<double>(
          0,
          (sum, tray) => sum + (double.tryParse(tray.quantity ?? '') ?? 0),
        );

        final targetWorkOrderLineId = _state.selectedPlanLine!.planLine.workOrderLineId;

        // Refresh and check that primary quantity does not exceed tubes after adjustment
        final apiResult = await _repo.loadWorkOrderBySerialNumber(_state.machineBarcode);
        if (!apiResult.success || apiResult.data == null) {
          throw Exception('Failed to refresh work order data: ${apiResult.message}');
        }
        
        final freshRawLines = List<PlanLineResponseModel>.from(apiResult.data);
        final globalRes = await _repo.fetchPlanLinesByWorkOrderLineId(targetWorkOrderLineId);
        if (!globalRes.success || globalRes.data == null) {
          throw Exception('Failed to refresh global plan lines: ${globalRes.message}');
        }
        final freshGlobalLines = List<PlanLineResponseModel>.from(globalRes.data);

        // Update state with fresh data
        _state = _state.copyWith(
          allRawPlanLines: freshRawLines,
          allPlanLinesForWorkOrderLines: {
            ..._state.allPlanLinesForWorkOrderLines,
            targetWorkOrderLineId: freshGlobalLines,
          },
        );

        // Re-locate selected plan line index
        final matchedIndex = freshRawLines.indexWhere((element) => element.planLine.id == _state.selectedPlanLine!.planLine.id);
        if (matchedIndex != -1) {
          _state = _state.copyWith(selectedPlanLine: freshRawLines[matchedIndex]);
        } else {
          final globalMatchedIndex = freshGlobalLines.indexWhere((element) => element.planLine.id == _state.selectedPlanLine!.planLine.id);
          if (globalMatchedIndex != -1) {
            _state = _state.copyWith(selectedPlanLine: freshGlobalLines[globalMatchedIndex]);
          }
        }

        double sumPrimaryQty = 0;
        for (final line in freshGlobalLines) {
          if (line.planLine.workOrderLineId == targetWorkOrderLineId) {
            sumPrimaryQty += line.planLine.primaryQuantity + line.planLine.sampleQty + line.planLine.cGradeQty;
          }
        }

        final double limit = _state.selectedPlanLine!.workOrderLine.tubesAfterAdjustment;
        final int extraAllowed = (limit * 0.1).ceil();
        final double maxAllowed = limit + extraAllowed;

        if (sumPrimaryQty + totalScannedTubes > maxAllowed) {
          throw Exception(
            'Cannot save. Total quantity including this scan (${(sumPrimaryQty + totalScannedTubes).toStringAsFixed(0)}) exceeds the maximum allowed limit with 10% extra allowance ($maxAllowed).'
          );
        }

        bool proceed = true;
        if (sumPrimaryQty + totalScannedTubes > limit) {
          // Temporarily set loading false to show confirmation dialog
          _state = _state.copyWith(isLoading: false);
          notifyListeners();
          proceed = await onConfirmOverproduction();
          _state = _state.copyWith(isLoading: true);
          notifyListeners();
        }

        if (!proceed) {
          _state = _state.copyWith(isLoading: false);
          notifyListeners();
          return;
        }

        // Save progress and update trays sequentially
        for (int i = 0; i < _state.scannedTrays.length; i++) {
          final tray = _state.scannedTrays[i];
          final trayResFetch = await _repo.fetchTrayById(tray.trayUpdateId!);
          if (!trayResFetch.success || trayResFetch.data == null) {
            throw Exception('Could not refresh tray details for ${tray.trayCode}: ${trayResFetch.message}');
          }

          final latestTray = trayResFetch.data as TrayDetailsModel;
          final latestTrayDetail = latestTray.trayDetails;

          final targetShiftId = _state.selectedPlanLine!.planLine.shiftId;
          final trayQty = double.tryParse(tray.quantity ?? '') ?? 5.0;

          Map<String, dynamic> planData = {
            'trayCode': latestTrayDetail?.trayCode,
            'trayType': 1,
            'shiftId': targetShiftId,
            'planLineId': _state.selectedPlanLine!.planLine.id,
            'workOrderHeaderId': _state.selectedPlanLine!.workOrderHeader.id,
            'workOrderLineId': _state.selectedPlanLine!.workOrderLine.id,
            'knitItemId': _state.selectedPlanLine!.planLine.itemId,
            "locatorId": 2,
            "active": true,
            "trayQuantity": trayQty.toInt(),
            'concurrencyStamp': latestTrayDetail?.concurrencyStamp,
            "resourceId": _state.selectedPlanLine!.resource.id,
          };

          Map<String, dynamic> productionProgressData = {
            "subOperation": "Knitting",
            "date": DateTime.now().toIso8601String(),
            "transactionType": 6,
            "operatorDescription": "system",
            "primaryQuantity": trayQty,
            "primaryUOM": _state.selectedPlanLine!.planLine.primaryUOM,
            "secondaryQuantity": (_state.selectedPlanLine!.item.perGarmentTube) * trayQty,
            "secondaryUOM": _state.selectedPlanLine!.planLine.secondaryUOM,
            "wipStatus": 0,
            "gbsFlag": false,
            "pbsFlag": false,
            "productGrade": 0,
            "productNature": 0,
            "isLastProcess": false,
            "isStarted": false,
            "lotMakingFlag": false,
            "reworkFlag": false,
            "operationId": _state.selectedPlanLine!.operation.id,
            "workOrderHeaderId": _state.selectedPlanLine!.workOrderHeader.id,
            "workOrderLineId": _state.selectedPlanLine!.workOrderLine.id,
            "itemId": _state.selectedPlanLine!.planLine.itemId,
            "shiftId": targetShiftId,
            "primaryTrayId": latestTrayDetail?.id,
            "secondaryTrayId": latestTrayDetail?.id,
            "machineId": _state.selectedPlanLine!.planLine.resourceId,
            "locatorId": 2,
            "holdFlag": tray.isHold,
            "holdDate": tray.isHold ? DateTime.now().toIso8601String() : null,
          };

          if (_state.selectedPlanLine!.planLine.planHeaderId != null) {
            productionProgressData["planHeaderId"] = _state.selectedPlanLine!.planLine.planHeaderId;
          }

          final trayRes = await _repo.updateTrayDetails(planData, latestTrayDetail!.id!);
          if (!trayRes.success) throw Exception(trayRes.message);

          final progRes = await _repo.saveProductionProgress(productionProgressData);
          if (!progRes.success) throw Exception(progRes.message);
        }

        final totalScannedPcs = _state.scannedTrays.fold<double>(
          0.0,
          (sum, tray) => sum + ((double.tryParse(tray.quantity ?? '') ?? 0) * tray.perGarmentTube),
        );

        await _updatePlanLineQuantity(goodQty: totalScannedTubes, goodPcs: totalScannedPcs);

        _state = _state.copyWith(
          scannedTrays: [],
          machineBarcode: '',
          clearPlanLines: true,
          clearSelectedPlanLine: true,
          productionType: 'good',
          isLoading: false,
        );
        notifyListeners();
        onSuccess();
      } else {
        // sample or c_grade
        final qtyText = singleQtyText?.trim() ?? '';
        final int? x = int.tryParse(qtyText);
        if (x == null || x <= 0) throw Exception('Please enter a valid quantity.');

        final targetWorkOrderLineId = _state.selectedPlanLine!.planLine.workOrderLineId;
        
        final apiResult = await _repo.loadWorkOrderBySerialNumber(_state.machineBarcode);
        if (!apiResult.success || apiResult.data == null) {
          throw Exception('Failed to refresh work order data: ${apiResult.message}');
        }
        
        final freshRawLines = List<PlanLineResponseModel>.from(apiResult.data);
        final globalRes = await _repo.fetchPlanLinesByWorkOrderLineId(targetWorkOrderLineId);
        if (!globalRes.success || globalRes.data == null) {
          throw Exception('Failed to refresh global plan lines: ${globalRes.message}');
        }
        final freshGlobalLines = List<PlanLineResponseModel>.from(globalRes.data);

        // Update state with fresh data
        _state = _state.copyWith(
          allRawPlanLines: freshRawLines,
          allPlanLinesForWorkOrderLines: {
            ..._state.allPlanLinesForWorkOrderLines,
            targetWorkOrderLineId: freshGlobalLines,
          },
        );

        // Re-locate selected plan line index
        final matchedIndex = freshRawLines.indexWhere((element) => element.planLine.id == _state.selectedPlanLine!.planLine.id);
        if (matchedIndex != -1) {
          _state = _state.copyWith(selectedPlanLine: freshRawLines[matchedIndex]);
        } else {
          final globalMatchedIndex = freshGlobalLines.indexWhere((element) => element.planLine.id == _state.selectedPlanLine!.planLine.id);
          if (globalMatchedIndex != -1) {
            _state = _state.copyWith(selectedPlanLine: freshGlobalLines[globalMatchedIndex]);
          }
        }

        double sumPrimaryQty = 0;
        for (final line in freshGlobalLines) {
          if (line.planLine.workOrderLineId == targetWorkOrderLineId) {
            sumPrimaryQty += line.planLine.primaryQuantity + line.planLine.sampleQty + line.planLine.cGradeQty;
          }
        }
        final double limit = _state.selectedPlanLine!.workOrderLine.tubesAfterAdjustment;
        final int extraAllowed = (limit * 0.1).ceil();
        final double maxAllowed = limit + extraAllowed;

        if (sumPrimaryQty + x > maxAllowed) {
          throw Exception(
            'Cannot save. Total quantity including this entry (${(sumPrimaryQty + x).toStringAsFixed(0)}) exceeds the maximum allowed limit with 10% extra allowance ($maxAllowed).'
          );
        }

        bool proceed = true;
        if (sumPrimaryQty + x > limit) {
          _state = _state.copyWith(isLoading: false);
          notifyListeners();
          proceed = await onConfirmOverproduction();
          _state = _state.copyWith(isLoading: true);
          notifyListeners();
        }

        if (!proceed) {
          _state = _state.copyWith(isLoading: false);
          notifyListeners();
          return;
        }

        final int nature = _state.productionType == 'sample' ? 1 : 0;
        final int grade = _state.productionType == 'c_grade' ? 2 : 0;

        Map<String, dynamic> productionProgressData = {
          "subOperation": "Knitting",
          "date": DateTime.now().toIso8601String(),
          "transactionType": 6,
          "operatorDescription": "system",
          "primaryQuantity": x.toDouble(),
          "primaryUOM": _state.selectedPlanLine!.planLine.primaryUOM,
          "secondaryQuantity": _state.productionType == 'c_grade' ? 0 : (x * _state.selectedPlanLine!.item.perGarmentTube),
          "secondaryUOM": _state.selectedPlanLine!.planLine.secondaryUOM,
          "wipStatus": 0,
          "gbsFlag": false,
          "pbsFlag": false,
          "productGrade": grade,
          "productNature": nature,
          "isLastProcess": false,
          "isStarted": false,
          "lotMakingFlag": false,
          "reworkFlag": false,
          "operationId": _state.selectedPlanLine!.operation.id,
          "workOrderHeaderId": _state.selectedPlanLine!.workOrderHeader.id,
          "workOrderLineId": _state.selectedPlanLine!.workOrderLine.id,
          "itemId": _state.selectedPlanLine!.planLine.itemId,
          "shiftId": _state.selectedPlanLine!.planLine.shiftId,
          "machineId": _state.selectedPlanLine!.planLine.resourceId,
          "locatorId": 2,
          "remarks": remarksText?.trim().isNotEmpty == true ? remarksText!.trim() : null,
        };

        if (_state.selectedPlanLine!.planLine.planHeaderId != null) {
          productionProgressData["planHeaderId"] = _state.selectedPlanLine!.planLine.planHeaderId;
        }

        final res = await _repo.saveProductionProgress(productionProgressData);
        if (res.success) {
          if (_state.productionType == 'sample') {
            await _updatePlanLineQuantity(sampleQty: x.toDouble());
          }
          _state = _state.copyWith(
            machineBarcode: '',
            clearPlanLines: true,
            clearSelectedPlanLine: true,
            productionType: 'good',
            isLoading: false,
          );
          notifyListeners();
          onSuccess();
        } else {
          throw Exception(res.message);
        }
      }
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      notifyListeners();
      rethrow;
    }
  }
}
