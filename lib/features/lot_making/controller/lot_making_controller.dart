import 'dart:developer' as dev;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_color_model.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_machine_model.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_making_state.dart';
import 'package:active_wear_scanning/features/lot_making/repo/lot_repo.dart';

class LotMakingController extends ChangeNotifier {
  final _lotRepo = LotRepo();

  final LotHeaderResponseModel? existingBatch;
  final List<ProductionProgressResponseModel>? preloadedTrays;

  LotMakingState _state = const LotMakingState();
  LotMakingState get state => _state;

  late final Future<void> initFuture;

  LotMakingController({this.existingBatch, this.preloadedTrays}) {
    final code =
        existingBatch?.batchHeader.batchHeaderCode ??
        "LOT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
    _state = _state.copyWith(lotCode: code);

    initFuture = initData();
  }

  Future<void> initData() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      await Future.wait([
        fetchMachines(),
        fetchColors(),
        fetchLotProgressIds(),
      ]);
      await fetchProductionProgresses();
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }

  void selectMachine(LotMachineModel? machine) {
    _state = _state.copyWith(selectedMachine: machine);
    notifyListeners();
  }

  void selectColor(LotColorModel? color) {
    if (_state.selectedColor?.segmentCode?.id == color?.segmentCode?.id) return;
    _state = _state.copyWith(
      selectedColor: color,
      clearSelectedTray: true,
      clearReferenceRouting: true,
      scannedTrays: (existingBatch != null && _state.scannedTrays.isNotEmpty)
          ? _state.scannedTrays
          : [],
    );
    notifyListeners();
  }

  Future<void> selectWorkOrder(WorkOrderHeader? wo) async {
    final isDifferent = _state.selectedWorkOrder?.id != wo?.id;
    _state = _state.copyWith(
      selectedWorkOrder: wo,
      clearSelectedColor: isDifferent && _state.scannedTrays.isEmpty,
      clearSelectedTray: true,
      clearReferenceRouting: _state.scannedTrays.isEmpty,
    );
    notifyListeners();

    if (_state.colors.isEmpty) {
      await fetchColors();
    }

    final woId = wo?.id;
    if (woId != null) {
      await ensureWorkOrderColorsCached(woId, force: true);
    }
  }

  Future<void> ensureWorkOrderColorsCached(int woId, {bool force = false, bool silent = false}) async {
    if (!force &&
        _state.workOrderValidColors.containsKey(woId) &&
        _state.workOrderValidColors[woId] != null &&
        _state.workOrderValidColors[woId]!.isNotEmpty) {
      return;
    }

    if (!silent) {
      _state = _state.copyWith(isCachingColors: true);
      notifyListeners();
    }

    try {
      final Set<int> lineIds = {};
      final Set<String> validColors = {};
      final updatedPlanQuantities = Map<String, double>.from(
        _state.colorPlanQuantities,
      );

      // 1. Primary: Fetch line details directly for this work order
      // (matches /api/app/work-order-line-details?WorkOrderId=$woId)
      try {
        final directDetailsRes = await _lotRepo.fetchWorkOrderLineDetailsByWorkOrder(woId);
        if (directDetailsRes.success && directDetailsRes.data != null) {
          final items = directDetailsRes.data as List;
          for (final item in items) {
            final detail = (item is Map) ? (item['workOrderLineDetail'] ?? item) : null;
            final colorDesc = (detail?['colorDescription'] ??
                    item['processIItemd']?['colorDescription'] ??
                    item['garmentItem']?['colorDescription'])
                ?.toString()
                .trim()
                .toUpperCase();
            final planQty = (detail?['planQuantity'] as num?)?.toDouble() ?? 0.0;
            final lid = int.tryParse((detail?['workOrderLineId'] ?? item['workOrderLine']?['id'])?.toString() ?? '');
            if (colorDesc != null && colorDesc.isNotEmpty) {
              validColors.add(colorDesc);
              if (lid != null) {
                lineIds.add(lid);
                final key = "${lid}_$colorDesc";
                updatedPlanQuantities[key] = (updatedPlanQuantities[key] ?? 0.0) + planQty;
              }
            }
          }
        }
      } catch (e) {
        dev.log('Error fetching direct line details for WO $woId: $e');
      }

      // 2. Fetch all work order lines for this work order from API to discover any other lines
      try {
        final linesRes = await _lotRepo.fetchWorkOrderLines(workOrderId: woId);
        if (linesRes.success && linesRes.data != null) {
          final list = linesRes.data as List;
          for (final item in list) {
            final line = item is Map ? (item['workOrderLine'] ?? item) : null;
            final id = int.tryParse(line?['id']?.toString() ?? '');
            if (id != null) lineIds.add(id);
          }
        }
      } catch (e) {
        dev.log('Error fetching work order lines: $e');
      }

      // 3. Collect lineIds & colors from production progress trays for this work order
      for (final t in _state.productionProgressTrays) {
        if (t.workOrderHeader?.id == woId) {
          final lid = t.productionProgress.workOrderLineId ?? t.workOrderLine?.id;
          if (lid != null) lineIds.add(lid);
          final c = t.item.colorDescription?.trim().toUpperCase();
          if (c != null && c.isNotEmpty) validColors.add(c);
        }
      }

      // 4. If directDetailsRes did not find any colors, query each individual lineId
      if (validColors.isEmpty) {
        for (final lineId in lineIds) {
          final res = await _lotRepo.fetchAllWorkOrderLineDetails(lineId);
          if (res.success && res.data != null) {
            updatedPlanQuantities.removeWhere(
              (key, _) => key.startsWith("${lineId}_"),
            );
            final items = res.data as List;
            for (final item in items) {
              final detail = (item is Map) ? (item['workOrderLineDetail'] ?? item) : item;
              if (detail != null && detail is Map) {
                final colorDesc = (detail['colorDescription'] ??
                        item['processIItemd']?['colorDescription'] ??
                        item['garmentItem']?['colorDescription'])
                    ?.toString()
                    .trim()
                    .toUpperCase();
                final planQty =
                    (detail['planQuantity'] as num?)?.toDouble() ?? 0.0;
                if (colorDesc != null && colorDesc.isNotEmpty) {
                  validColors.add(colorDesc);
                  final key = "${lineId}_$colorDesc";
                  updatedPlanQuantities[key] =
                      (updatedPlanQuantities[key] ?? 0.0) + planQty;
                }
              }
            }
          }
        }
      }

      final updatedValidColors = Map<int, Set<String>>.from(
        _state.workOrderValidColors,
      );
      updatedValidColors[woId] = validColors;

      _state = _state.copyWith(
        workOrderValidColors: updatedValidColors,
        colorPlanQuantities: updatedPlanQuantities,
        isCachingColors: false,
      );
    } catch (e) {
      dev.log('Error in ensureWorkOrderColorsCached: $e');
      _state = _state.copyWith(isCachingColors: false);
    }
    notifyListeners();
  }


  void selectTray(ProductionProgressResponseModel? tray) {
    _state = _state.copyWith(selectedTray: tray);
    notifyListeners();
  }

  void removeScannedTray(int index) {
    if (index >= 0 && index < _state.scannedTrays.length) {
      final removed = _state.scannedTrays[index];
      final updated = List<ProductionProgressResponseModel>.from(
        _state.scannedTrays,
      )..removeAt(index);

      final updatedDbIds = Set<int>.from(_state.currentBatchDatabaseProgressIds);
      final updatedLotProgIds = Set<int>.from(_state.lotProgressIds);
      if (removed.productionProgress.id != null) {
        updatedDbIds.remove(removed.productionProgress.id);
        updatedLotProgIds.remove(removed.productionProgress.id);
      }

      _state = _state.copyWith(
        scannedTrays: updated,
        currentBatchDatabaseProgressIds: updatedDbIds,
        lotProgressIds: updatedLotProgIds,
        clearReferenceRouting: updated.isEmpty,
      );
      notifyListeners();
    }
  }

  List<WorkOrderHeader> getAvailableWorkOrders() {
    final Set<int> seenIds = {};
    final List<WorkOrderHeader> wos = [];

    // Always include selectedWorkOrder if already set (e.g. from draft lot)
    if (_state.selectedWorkOrder?.id != null) {
      seenIds.add(_state.selectedWorkOrder!.id!);
      wos.add(_state.selectedWorkOrder!);
    }

    final Map<String, ProductionProgressResponseModel> uniqueGbsTrays = {};
    for (final t in _state.productionProgressTrays) {
      if (t.productionProgress.locatorId != 3) continue;
      if (t.productionProgress.gbsFlag != true) continue;
      if (t.workOrderHeader == null) continue;

      final code = (t.primaryTrayModel.trayCode ?? '').trim().toUpperCase();
      if (code.isEmpty) continue;

      // Prefer unassigned progress record for this physical tray code
      if (!uniqueGbsTrays.containsKey(code)) {
        uniqueGbsTrays[code] = t;
      } else {
        final existingT = uniqueGbsTrays[code]!;
        final existingBh = existingT.productionProgress.batchHeaderId;
        final currentBh = t.productionProgress.batchHeaderId;
        if (existingBh != null && (currentBh == null || currentBh == 0)) {
          uniqueGbsTrays[code] = t;
        }
      }
    }

    for (final tray in uniqueGbsTrays.values) {
      final qtys = getTrayQuantities(tray);
      if ((qtys['remaining'] ?? 0.0) <= 0) continue;

      final id = tray.workOrderHeader.id;
      if (id != null && !seenIds.contains(id)) {
        seenIds.add(id);
        wos.add(tray.workOrderHeader);
      }
    }
    return wos;
  }

  List<WorkOrderHeader> getFilteredWorkOrders() {
    final wos = getAvailableWorkOrders();
    if (_state.selectedWorkOrder != null && !wos.any((w) => w.id == _state.selectedWorkOrder!.id)) {
      wos.insert(0, _state.selectedWorkOrder!);
    }
    if (_state.selectedColor == null) return wos;
    final selectedColorDesc = _state.selectedColor!.segmentCode?.description
        ?.toUpperCase();
    if (selectedColorDesc == null) return wos;

    return wos.where((wo) {
      if (_state.selectedWorkOrder != null && wo.id == _state.selectedWorkOrder!.id) {
        return true;
      }
      final validColors = _state.workOrderValidColors[wo.id];
      if (validColors == null || !validColors.contains(selectedColorDesc))
        return false;

      final trays = _state.productionProgressTrays.where((t) {
        if (t.workOrderHeader?.id != wo.id) return false;
        final lineId =
            t.productionProgress.workOrderLineId ?? t.workOrderLine?.id;
        if (lineId == null) return false;
        final planQty =
            _state.colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
        return planQty > 0.0;
      }).toList();

      return trays.isNotEmpty;
    }).toList();
  }

  List<LotColorModel> getFilteredColors() {
    if (_state.selectedWorkOrder == null) return _state.colors;
    final validColors =
        _state.workOrderValidColors[_state.selectedWorkOrder!.id];
    if (validColors == null || validColors.isEmpty) {
      return _state.selectedColor != null ? [_state.selectedColor!] : [];
    }

    final List<LotColorModel> filtered = [];
    final Set<String> matchedColors = {};

    for (final color in _state.colors) {
      final desc = color.segmentCode?.description?.trim().toUpperCase();
      if (desc != null && validColors.contains(desc)) {
        if (!matchedColors.contains(desc)) {
          filtered.add(color);
          matchedColors.add(desc);
        }
      }
    }

    // Ensure all distinct colors in work order line details are represented in the list
    for (final colorName in validColors) {
      if (!matchedColors.contains(colorName)) {
        filtered.add(
          LotColorModel(
            segmentCode: SegmentCode(
              description: colorName,
              code: colorName,
            ),
          ),
        );
        matchedColors.add(colorName);
      }
    }

    if (_state.selectedColor != null &&
        !filtered.any((c) =>
            c.segmentCode?.description?.trim().toUpperCase() ==
            _state.selectedColor!.segmentCode?.description?.trim().toUpperCase())) {
      filtered.insert(0, _state.selectedColor!);
    }

    return filtered;
  }

  List<ProductionProgressResponseModel> getTraysForSelectedWorkOrder() {
    if (_state.selectedWorkOrder == null) return [];

    final Map<String, ProductionProgressResponseModel> uniqueTrays = {};

    for (final t in _state.productionProgressTrays) {
      if (t.productionProgress.locatorId != 3) continue;
      if (t.productionProgress.gbsFlag != true) continue;
      if (t.workOrderHeader?.id != _state.selectedWorkOrder!.id) continue;

      final code = (t.primaryTrayModel.trayCode ?? '').trim().toUpperCase();
      if (code.isEmpty) continue;

      if (!uniqueTrays.containsKey(code)) {
        uniqueTrays[code] = t;
      } else {
        final existingT = uniqueTrays[code]!;
        final existingBh = existingT.productionProgress.batchHeaderId;
        final currentBh = t.productionProgress.batchHeaderId;
        if (existingBh != null && (currentBh == null || currentBh == 0)) {
          uniqueTrays[code] = t;
        }
      }
    }

    final deDuplicated = uniqueTrays.values.where((t) {
      final qtys = getTrayQuantities(t);
      return (qtys['remaining'] ?? 0.0) > 0;
    }).toList();

    deDuplicated.sort(
      (a, b) => (a.primaryTrayModel.trayCode ?? '').compareTo(
        b.primaryTrayModel.trayCode ?? '',
      ),
    );
    return deDuplicated;
  }

  List<ProductionProgressResponseModel> getTraysForSelectedWorkOrderAndColor() {
    final trays = getTraysForSelectedWorkOrder();
    if (_state.selectedColor == null) return [];
    final selectedColorDesc = _state.selectedColor!.segmentCode?.description
        ?.trim()
        .toUpperCase();
    if (selectedColorDesc == null || selectedColorDesc.isEmpty) return [];

    return trays.where((t) {
      final itemColor = t.item.colorDescription?.trim().toUpperCase();
      if (itemColor != null && itemColor == selectedColorDesc) return true;
      final lineId =
          t.productionProgress.workOrderLineId ?? t.workOrderLine?.id;
      if (lineId == null) return false;
      final planQty =
          _state.colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
      return planQty > 0.0;
    }).toList();
  }

  double getAlreadyAssignedTubesForWorkOrderLine(int workOrderLineId) {
    double sum = 0.0;
    final currentBatchId = existingBatch?.batchHeader.id;
    for (final t in _state.productionProgressTrays) {
      final lineId =
          t.productionProgress.workOrderLineId ?? t.workOrderLine?.id;
      if (lineId == workOrderLineId) {
        final bhId = t.productionProgress.batchHeaderId;
        if (bhId != null && bhId != 0 && bhId != currentBatchId) {
          sum += (t.productionProgress.primaryQuantity ?? 0.0);
        }
      }
    }
    return sum;
  }

  Map<String, double> getTrayQuantities(ProductionProgressResponseModel tray) {
    final code = (tray.primaryTrayModel.trayCode ?? '').trim().toUpperCase();
    final fallbackQty = tray.productionProgress.primaryQuantity ?? 0.0;
    if (code.isEmpty) {
      return {
        'actual': fallbackQty,
        'alreadyScanned': 0.0,
        'remaining': fallbackQty,
      };
    }

    final matchingTrays = _state.productionProgressTrays
        .where(
          (t) =>
              (t.primaryTrayModel.trayCode ?? '').trim().toUpperCase() ==
                  code &&
              t.productionProgress.locatorId == 3 &&
              t.productionProgress.gbsFlag == true,
        )
        .toList();

    if (matchingTrays.isEmpty) {
      return {
        'actual': fallbackQty,
        'alreadyScanned': 0.0,
        'remaining': fallbackQty,
      };
    }

    double physicalCapacity = (tray.primaryTrayModel.trayQuantity ?? 0).toDouble();
    if (physicalCapacity <= 0) {
      for (final t in matchingTrays) {
        final q = (t.primaryTrayModel.trayQuantity ?? 0).toDouble();
        if (q > physicalCapacity) physicalCapacity = q;
      }
    }

    double assignedToOtherLots = 0.0;
    double assignedToCurrentBatch = 0.0;
    final currentBatchId = existingBatch?.batchHeader.id;

    for (final t in matchingTrays) {
      final bhId = t.productionProgress.batchHeaderId;
      final q = (t.productionProgress.primaryQuantity ?? 0.0);
      if (bhId != null && bhId != 0) {
        if (currentBatchId != null && bhId == currentBatchId) {
          assignedToCurrentBatch += q;
        } else {
          assignedToOtherLots += q;
        }
      }
    }

    final unallocatedRecords = matchingTrays.where((t) {
      final bhId = t.productionProgress.batchHeaderId;
      return bhId == null || bhId == 0;
    }).toList();

    double unallocatedQty = unallocatedRecords.fold<double>(
      0.0,
      (sum, t) => sum + (t.productionProgress.primaryQuantity ?? 0.0),
    );

    // Calculate actual tray capacity safely:
    // 1) If physicalCapacity > 0 from tray_details, that is the true physical capacity.
    // 2) If physicalCapacity <= 0, determine whether progress records represent a split or unsplit tray.
    // If an unallocated record exists alongside allocated records (assignedToOtherLots > 0),
    // and unallocatedQty was not decremented (unallocatedQty + assignedToOtherLots > max(individual progress qty)),
    // then the unallocated record still holds the full unsplit capacity (e.g. 20, with 15 assigned).
    // In that case, actual is unallocatedQty (20), and true unallocated remaining is (unallocatedQty - assignedToOtherLots = 5).
    double actual;
    if (physicalCapacity > 0) {
      actual = physicalCapacity;
    } else {
      final double maxProgressQty = matchingTrays.fold<double>(
        0.0,
        (maxQ, t) => math.max(maxQ, t.productionProgress.primaryQuantity ?? 0.0),
      );
      if (assignedToOtherLots > 0 && unallocatedQty >= maxProgressQty && unallocatedQty > 0) {
        actual = unallocatedQty;
        unallocatedQty = math.max(0.0, unallocatedQty - assignedToOtherLots);
      } else {
        final double sumProgress = unallocatedQty + assignedToOtherLots + assignedToCurrentBatch;
        actual = sumProgress > 0 ? sumProgress : fallbackQty;
      }
    }

    if (unallocatedRecords.isEmpty && actual > (assignedToOtherLots + assignedToCurrentBatch)) {
      unallocatedQty = actual - (assignedToOtherLots + assignedToCurrentBatch);
    }

    final double maxPossibleRemaining = math.max(0.0, actual - assignedToOtherLots);
    final double remaining = (unallocatedQty + assignedToCurrentBatch).clamp(0.0, maxPossibleRemaining);

    double scannedInCurrentBatch = 0.0;
    final matchingScanned = _state.scannedTrays
        .where(
          (st) =>
              (st.primaryTrayModel.trayCode ?? '').trim().toUpperCase() == code,
        )
        .toList();

    if (matchingScanned.isNotEmpty) {
      scannedInCurrentBatch = matchingScanned.fold<double>(
        0.0,
        (sum, st) => sum + (st.productionProgress.primaryQuantity ?? 0.0),
      );
    }

    return {
      'actual': actual,
      'alreadyScanned': assignedToOtherLots > 0
          ? assignedToOtherLots
          : (assignedToCurrentBatch > 0 ? assignedToCurrentBatch : scannedInCurrentBatch),
      'remaining': remaining,
    };
  }

  Future<void> fetchProductionProgresses() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    final result = await _lotRepo.fetchProductionProgress();
    if (result.success && result.data != null) {
      final progresses = result.data as List<ProductionProgressResponseModel>;
      _state = _state.copyWith(productionProgressTrays: progresses);
      await _cacheColorsForGbsWorkOrders();
      if (existingBatch != null) {
        await _loadExistingLotTrays(progresses);
      }
      _state = _state.copyWith(isLoading: false);
    } else {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage:
            result.message ?? 'Unknown error fetching production progresses',
      );
    }
    notifyListeners();
  }

  Future<void> _cacheColorsForGbsWorkOrders() async {
    _state = _state.copyWith(isCachingColors: true);
    notifyListeners();

    try {
      final wos = getAvailableWorkOrders();
      for (final wo in wos) {
        final woId = wo.id;
        if (woId != null) {
          await ensureWorkOrderColorsCached(woId, silent: true);
        }
      }
    } catch (e) {
      dev.log('Error caching colors: $e');
    } finally {
      _state = _state.copyWith(isCachingColors: false);
      notifyListeners();
    }
  }

  Future<void> _loadExistingLotTrays(
    List<ProductionProgressResponseModel> allProgresses,
  ) async {
    final batchHeaderId = existingBatch!.batchHeader.id;
    if (batchHeaderId == null) return;

    final linesRes = await _lotRepo.fetchLotLines(batchHeaderId: batchHeaderId);
    if (!linesRes.success || linesRes.data == null) return;

    final rawLines = linesRes.data as List<Map<String, dynamic>>;
    final linkedProgressIds = rawLines
        .map((line) => line['batchLines']?['progressId'] as int?)
        .whereType<int>()
        .toSet();

    final linkedTrays = allProgresses
        .where(
          (p) =>
              p.productionProgress.id != null &&
              linkedProgressIds.contains(p.productionProgress.id),
        )
        .toList();

    final updatedProgressIds = Set<int>.from(
      _state.currentBatchDatabaseProgressIds,
    )..addAll(linkedProgressIds);
    final updatedScanned = List<ProductionProgressResponseModel>.from(
      _state.scannedTrays,
    )..addAll(linkedTrays);

    // 1. Resolve Work Order
    WorkOrderHeader? selectedWo = _state.selectedWorkOrder;
    if (selectedWo == null && linkedTrays.isNotEmpty) {
      selectedWo = linkedTrays.first.workOrderHeader;
    }
    if (selectedWo == null && rawLines.isNotEmpty) {
      final woId = rawLines.first['batchLines']?['workOrderHeaderId'] as int?;
      if (woId != null) {
        selectedWo = allProgresses.map((p) => p.workOrderHeader).where((w) => w?.id == woId).firstOrNull;
      }
    }

    // 2. Resolve Machine
    LotMachineModel? selectedMachine = _state.selectedMachine;
    if (selectedMachine == null && _state.machines.isNotEmpty) {
      final editMachineId = existingBatch?.machine?.id ?? existingBatch?.batchHeader.machineId;
      if (editMachineId != null) {
        selectedMachine = _state.machines.where((m) =>
          m.resource?.id == editMachineId
        ).firstOrNull;
      }
    }

    // 3. Resolve Color
    LotColorModel? selectedColor = _state.selectedColor;
    if (selectedColor == null && _state.colors.isNotEmpty) {
      final editColorId = existingBatch?.colorCode?.id ?? existingBatch?.batchHeader.colorCodeId;
      final editColorDesc = existingBatch?.colorCode?.description ??
          existingBatch?.batchHeader.colorDescription ??
          (linkedTrays.isNotEmpty ? linkedTrays.first.item.colorDescription : null);

      if (editColorId != null) {
        selectedColor = _state.colors.where((c) => c.segmentCode?.id == editColorId).firstOrNull;
      }
      if (selectedColor == null && editColorDesc != null && editColorDesc.isNotEmpty) {
        selectedColor = _state.colors.where((c) =>
          c.segmentCode?.description?.trim().toUpperCase() == editColorDesc.trim().toUpperCase()
        ).firstOrNull;
      }
    }

    _state = _state.copyWith(
      currentBatchDatabaseProgressIds: updatedProgressIds,
      scannedTrays: updatedScanned,
      selectedWorkOrder: selectedWo,
      selectedMachine: selectedMachine,
      selectedColor: selectedColor,
    );

    if (selectedWo?.id != null) {
      await ensureWorkOrderColorsCached(selectedWo!.id!);
    }
  }

  Future<void> fetchLotProgressIds() async {
    final result = await _lotRepo.fetchLotLines();
    if (result.success && result.data != null) {
      final lines = result.data as List<Map<String, dynamic>>;
      final ids = lines
          .map((l) => l['batchLines']?['progressId'] as int?)
          .whereType<int>()
          .toSet();
      final updatedIds = Set<int>.from(_state.lotProgressIds)..addAll(ids);
      _state = _state.copyWith(lotProgressIds: updatedIds);
    }
  }

  Future<void> fetchMachines() async {
    _state = _state.copyWith(isLoading: true);
    final result = await _lotRepo.fetchLotMachines();

    if (result.success && result.data != null) {
      final machinesList = result.data as List<LotMachineModel>;
      LotMachineModel? selected;
      if (existingBatch != null) {
        final editMachineId = existingBatch?.machine?.id ?? existingBatch?.batchHeader.machineId;
        if (editMachineId != null) {
          final match = machinesList
              .where((m) => m.resource?.id == editMachineId)
              .toList();
          if (match.isNotEmpty) selected = match.first;
        }
      }
      _state = _state.copyWith(
        machines: machinesList,
        selectedMachine: selected,
        isLoading: false,
      );
    } else {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: result.message ?? 'Failed to load machines',
      );
    }
    notifyListeners();
  }

  Future<void> fetchColors() async {
    _state = _state.copyWith(isLoadingColors: true);
    final result = await _lotRepo.fetchLotColors();

    if (result.success && result.data != null) {
      final colorsList = result.data as List<LotColorModel>;
      dev.log('LotMakingController fetchColors: loaded ${colorsList.length} colors');
      LotColorModel? selected;
      if (existingBatch != null) {
        final editColorId = existingBatch?.colorCode?.id ?? existingBatch?.batchHeader.colorCodeId;
        final editColorDesc = existingBatch?.colorCode?.description ?? existingBatch?.batchHeader.colorDescription;
        if (editColorId != null) {
          final match = colorsList
              .where((c) => c.segmentCode?.id == editColorId)
              .toList();
          if (match.isNotEmpty) selected = match.first;
        }
        if (selected == null && editColorDesc != null && editColorDesc.isNotEmpty) {
          final match = colorsList
              .where((c) => c.segmentCode?.description?.trim().toUpperCase() == editColorDesc.trim().toUpperCase())
              .toList();
          if (match.isNotEmpty) selected = match.first;
        }
      }
      _state = _state.copyWith(
        colors: colorsList,
        selectedColor: selected,
        isLoadingColors: false,
      );
    } else {
      dev.log('LotMakingController fetchColors error: ${result.message}');
      _state = _state.copyWith(
        isLoadingColors: false,
        errorMessage: result.message ?? 'Failed to fetch colors',
      );
    }
    notifyListeners();
  }

  Future<String?> validateTrayForScan(
    String scannedCode,
    double overrideQty,
  ) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid tray code';
    if (_state.selectedColor == null) return 'Please select a lot Color first';
    if (_state.scannedTrays.any(
      (t) =>
          (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase() ==
          code.toLowerCase(),
    )) {
      return 'Already assigned';
    }

    final available = _state.productionProgressTrays
        .where(
          (t) =>
              (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase() ==
                  code.toLowerCase() &&
              t.productionProgress.locatorId == 3 &&
              t.productionProgress.gbsFlag == true,
        )
        .toList();

    if (available.isEmpty) return 'Tray not found or not checked out via GBS';

    final qtys = getTrayQuantities(available.first);
    final remainingTubes = qtys['remaining'] ?? 0.0;
    if (remainingTubes <= 0) {
      return 'Tray is already fully assigned to a lot (0 remaining tubes)';
    }

    final tray = available.firstWhere(
      (t) {
        final bhId = t.productionProgress.batchHeaderId;
        final pId = t.productionProgress.id;
        final isCurrentDb = pId != null && _state.currentBatchDatabaseProgressIds.contains(pId);
        final isUnassigned = (bhId == null || bhId == 0) && (pId == null || !_state.lotProgressIds.contains(pId));
        return isUnassigned || isCurrentDb;
      },
      orElse: () => available.first,
    );

    if (_state.selectedWorkOrder == null)
      return 'Please select a Work Order first';
    if (tray.workOrderHeader.id != _state.selectedWorkOrder?.id) {
      final woDesc = tray.workOrderHeader.description.isNotEmpty
          ? tray.workOrderHeader.description
          : tray.workOrderHeader.workOrderCode;
      return 'Tray belongs to another Work Order ($woDesc)';
    }

    if ((tray.primaryTrayModel.trayType ?? 0) != 1) return 'Invalid tray type.';
    final progressId = tray.productionProgress.id;
    final isCurrentBatchDbTray =
        progressId != null &&
        _state.currentBatchDatabaseProgressIds.contains(progressId);
    if (progressId != null &&
        _state.lotProgressIds.contains(progressId) &&
        !isCurrentBatchDbTray &&
        remainingTubes <= 0) {
      return 'Tray already assigned to a lot';
    }

    final workOrderLineId =
        tray.productionProgress.workOrderLineId ?? tray.workOrderLine?.id;
    final colorDescription = _state.selectedColor!.segmentCode?.description;
    if (colorDescription == null) return 'Selected Color has no description';

    final colorRes = await _lotRepo.fetchWorkOrderLineDetails(
      workOrderLineId!,
      colorDescription,
    );
    if (!colorRes.success || colorRes.data == null)
      return 'Validation error: ${colorRes.message}';

    final items = colorRes.data as List?;
    if (items == null || items.isEmpty)
      return 'Invalid tray: Tray does not belong to the selected color';

    final firstItem = items.first as Map;
    final detail = firstItem['workOrderLineDetail'];
    final dynamic processIdRaw = firstItem['processIItemd'];
    int processedItemId;
    if (processIdRaw is int) {
      processedItemId = processIdRaw;
    } else if (processIdRaw is Map) {
      processedItemId = processIdRaw['id'];
    } else {
      processedItemId = detail['knitItemId'] ?? tray.item.id;
    }

    final routingRes = await _lotRepo.fetchItemRoutings(processedItemId);
    if (!routingRes.success || routingRes.data == null)
      return 'Routing validation error: ${routingRes.message}';

    final routingItems = routingRes.data as List;
    final routingCodes = routingItems
        .map((r) => (r as Map)['itemRouting']?['operationId']?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .toSet();
    final routingCount = routingItems.length;

    if (routingCount == 0) return 'Tray item has no route configured';

    Set<String>? refRoutingCodes = _state.referenceRoutingCodes;
    int? refRoutingCount = _state.referenceRoutingCount;
    int? refMinOpId = _state.referenceMinOperationId;

    if (refRoutingCodes == null) {
      refRoutingCodes = routingCodes;
      refRoutingCount = routingCount;
      int? minSeq;
      int? resolvedOpId;
      for (final r in routingItems) {
        final rMap = r as Map;
        final seq = rMap['itemRouting']?['seq'] as int?;
        final opId = rMap['itemRouting']?['operationId'] as int?;
        if (seq != null && opId != null) {
          if (minSeq == null || seq < minSeq) {
            minSeq = seq;
            resolvedOpId = opId;
          }
        }
      }
      refMinOpId = resolvedOpId;
    } else if (routingCount != refRoutingCount ||
        !routingCodes.containsAll(refRoutingCodes) ||
        !refRoutingCodes.containsAll(routingCodes)) {
      return 'Tray has a different route';
    }

    final capacityRaw = _state.selectedMachine?.resource?.capacity;
    final capacityKg = capacityRaw != null
        ? double.tryParse(capacityRaw.toString())
        : null;
    if (capacityKg != null && capacityKg > 0) {
      final capacityGrams = capacityKg * 1000;
      final newQty = overrideQty > 0
          ? overrideQty
          : remainingTubes;
      final pw = tray.item.pieceWeight ?? 0;
      double currentTotal = 0;
      for (int i = 0; i < _state.scannedTrays.length; i++) {
        final qty =
            _state.scannedTrays[i].productionProgress.primaryQuantity ?? 0;
        final p = _state.scannedTrays[i].item.pieceWeight ?? 0;
        currentTotal += qty * p;
      }
      if (currentTotal + (newQty * pw) > capacityGrams) {
        return 'Exceeds machine capacity';
      }
    }

    double planQty = 0.0;
    for (final item in items) {
      if (item is Map) {
        final det = item['workOrderLineDetail'];
        if (det is Map) {
          planQty += (det['planQuantity'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }
    if (planQty > 0.0) {
      final newQty = overrideQty > 0
          ? overrideQty
          : remainingTubes;
      double currentCumulative = 0.0;
      for (int i = 0; i < _state.scannedTrays.length; i++) {
        final t = _state.scannedTrays[i];
        final lineId =
            t.productionProgress.workOrderLineId ?? t.workOrderLine?.id;
        if (lineId == workOrderLineId) {
          currentCumulative += t.productionProgress.primaryQuantity ?? 0.0;
        }
      }
      final alreadyAssigned = getAlreadyAssignedTubesForWorkOrderLine(
        workOrderLineId,
      );
      final totalScanned = currentCumulative + newQty + alreadyAssigned;

      final int extraAllowed = (planQty * 0.1).ceil();
      final double maxAllowed = planQty + extraAllowed;
      if (totalScanned > maxAllowed) {
        return 'Cannot scan tray. Scanned quantity (${totalScanned.toStringAsFixed(0)}) exceeds the maximum plan limit including 10% extra allowance (${maxAllowed.toStringAsFixed(0)}) for color "$colorDescription" (Already assigned in other batches: ${alreadyAssigned.toStringAsFixed(0)}).';
      }
    }

    final updatedProcessed = Map<int, int>.from(_state.trayProcessedItemId);
    if (tray.primaryTrayModel.id != null) {
      updatedProcessed[tray.primaryTrayModel.id!] = processedItemId;
    }

    final updatedPP = tray.productionProgress.copyWith(
      primaryQuantity: remainingTubes,
      batchHeaderId: existingBatch?.batchHeader.id,
      batchLinesId: null,
    );
    final trayToAdd = ProductionProgressResponseModel(
      productionProgress: updatedPP,
      operation: tray.operation,
      shift: tray.shift,
      machineModel: tray.machineModel,
      workOrderHeader: tray.workOrderHeader,
      workOrderLine: tray.workOrderLine,
      primaryTrayModel: tray.primaryTrayModel,
      item: tray.item,
      processedItem: tray.processedItem,
      planHeader: tray.planHeader,
      batchHeader: tray.batchHeader,
    );

    final updatedScanned = List<ProductionProgressResponseModel>.from(
      _state.scannedTrays,
    )..add(trayToAdd);

    _state = _state.copyWith(
      trayProcessedItemId: updatedProcessed,
      scannedTrays: updatedScanned,
      referenceRoutingCodes: refRoutingCodes,
      referenceRoutingCount: refRoutingCount,
      referenceMinOperationId: refMinOpId,
    );
    notifyListeners();
    return null;
  }

  Future<void> saveLotChanges(List<double> finalQuantities) async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      int batchHeaderId;
      final batchCode = _state.lotCode;

      if (existingBatch == null) {
        final res = await _lotRepo.createLotHeader({
          "planDate": DateTime.now().toIso8601String(),
          "colorDescription":
              _state.selectedColor?.segmentCode?.description ?? "N/A",
          "batchHeaderCode": batchCode,
          "machineId": _state.selectedMachine?.resource?.id ?? 0,
          "colorCode": _state.selectedColor?.segmentCode?.id ?? 0,
          "shiftId": _state.scannedTrays.first.shift?.id,
          "trayDetailId": null,
          "lockFlag": false,
        });

        if (!res.success) {
          throw Exception(res.message ?? 'Failed to create lot');
        }

        final data = res.data as Map;
        final rawId =
            data['id'] ??
            data['batchHeader']?['id'] ??
            data['result']?['id'] ??
            0;
        batchHeaderId = int.tryParse(rawId.toString()) ?? 0;

        if (batchHeaderId == 0) {
          final allRes = await _lotRepo.fetchLotHeaders();
          if (allRes.success && allRes.data != null) {
            final List allBatches = allRes.data as List;
            for (var b in allBatches) {
              final bMap = b as Map;
              final bHeader = bMap['batchHeader'] ?? bMap;
              if (bHeader['batchHeaderCode'] == batchCode) {
                batchHeaderId = bHeader['id'] ?? 0;
                break;
              }
            }
          }
        }
      } else {
        batchHeaderId = existingBatch!.batchHeader.id!;
        final newMachineId = _state.selectedMachine?.resource?.id ??
            existingBatch!.batchHeader.machineId ??
            0;
        final newColorId = _state.selectedColor?.segmentCode?.id ??
            existingBatch!.batchHeader.colorCodeId ??
            0;
        final newColorDesc = _state.selectedColor?.segmentCode?.description ??
            existingBatch!.batchHeader.colorDescription ??
            "N/A";

        await _lotRepo.updateLotHeader(batchHeaderId, {
          "planDate": existingBatch!.batchHeader.planDate ??
              DateTime.now().toIso8601String(),
          "colorDescription": newColorDesc,
          "batchHeaderCode": batchCode,
          "machineId": newMachineId,
          "colorCode": newColorId,
          "shiftId": _state.scannedTrays.isNotEmpty
              ? _state.scannedTrays.first.shift?.id
              : existingBatch!.batchHeader.shiftId,
          "trayDetailId": existingBatch!.batchHeader.trayDetailId,
          "lockFlag": false,
          "concurrencyStamp": existingBatch!.batchHeader.concurrencyStamp,
        });
      }

      if (batchHeaderId == 0) {
        throw Exception('Invalid Lot ID generated.');
      }

      if (existingBatch != null) {
        final existingLinesRes = await _lotRepo.fetchLotLines(
          batchHeaderId: batchHeaderId,
        );
        if (existingLinesRes.success && existingLinesRes.data != null) {
          final List rawList = existingLinesRes.data is Map
              ? (existingLinesRes.data['items'] ?? [])
              : (existingLinesRes.data is List ? existingLinesRes.data : []);

          final Set<int?> currentScannedTrayIds = _state.scannedTrays
              .map((t) => t.primaryTrayModel.id)
              .toSet();

          for (final line in rawList) {
            final rawLineMap = Map<String, dynamic>.from(line as Map);
            final lineMap =
                rawLineMap.containsKey('batchLines') &&
                    rawLineMap['batchLines'] is Map
                ? Map<String, dynamic>.from(rawLineMap['batchLines'] as Map)
                : rawLineMap;

            final int? lineId = (lineMap['id'] ?? rawLineMap['id']) != null
                ? int.tryParse((lineMap['id'] ?? rawLineMap['id']).toString())
                : null;
            final int? trayId =
                (lineMap['trayId'] ?? rawLineMap['trayId']) != null
                ? int.tryParse(
                    (lineMap['trayId'] ?? rawLineMap['trayId']).toString(),
                  )
                : null;
            final int? progressId =
                (lineMap['progressId'] ??
                 rawLineMap['progressId'] ??
                 (rawLineMap['progress'] is Map
                     ? rawLineMap['progress']['id']
                     : null)) != null
                ? int.tryParse(
                    (lineMap['progressId'] ??
                     rawLineMap['progressId'] ??
                     (rawLineMap['progress'] is Map
                         ? rawLineMap['progress']['id']
                         : null))
                        .toString(),
                  )
                : null;

            if (lineId != null && lineId > 0) {
              await _lotRepo.deleteLotLine(lineId);
            }

            if (trayId != null && !currentScannedTrayIds.contains(trayId)) {
              final Set<int> pIdsToReset = {};
              if (progressId != null && progressId > 0) {
                pIdsToReset.add(progressId);
              }
              for (final pt in _state.productionProgressTrays) {
                if (pt.primaryTrayModel.id == trayId) {
                  final ptId = pt.productionProgress.id;
                  if (ptId != null && ptId > 0) {
                    if (pt.productionProgress.batchHeaderId == batchHeaderId ||
                        (progressId != null && ptId == progressId)) {
                      pIdsToReset.add(ptId);
                    }
                  }
                }
              }

              for (final pId in pIdsToReset) {
                final ppFetch = await _lotRepo.fetchProductionProgressById(pId);
                if (ppFetch.success && ppFetch.data != null) {
                  final rawPP = Map<String, dynamic>.from(ppFetch.data as Map);
                  final ppInner = rawPP.containsKey('productionProgress') &&
                          rawPP['productionProgress'] is Map
                      ? Map<String, dynamic>.from(
                          rawPP['productionProgress'] as Map,
                        )
                      : rawPP;
                  final ppObj = ProductionProgress.fromJson(ppInner);
                  final ppPayload = ppObj.toJson();

                  ppPayload['batchHeaderId'] = null;
                  ppPayload['batchLineId'] = null;
                  ppPayload['batchLinesId'] = null;
                  if (ppPayload['transactionType'] == 6) {
                    ppPayload['transactionType'] = 1;
                  }

                  ppPayload.remove('id');
                  ppPayload.remove('progressCode');
                  ppPayload.remove('concurrencyStamp');
                  ppPayload.remove('creationTime');
                  ppPayload.remove('creatorId');
                  ppPayload.remove('lastModificationTime');
                  ppPayload.remove('lastModifierId');

                  await _lotRepo.updateProductionProgress(pId, ppPayload);
                }
              }

              if (pIdsToReset.isNotEmpty) {
                final updatedTrays = _state.productionProgressTrays.map((t) {
                  if (pIdsToReset.contains(t.productionProgress.id)) {
                    final p = t.productionProgress;
                    final clearedPP = ProductionProgress(
                      subOperation: p.subOperation,
                      date: p.date,
                      transactionType:
                          p.transactionType == 6 ? 1 : p.transactionType,
                      operatorDescription: p.operatorDescription,
                      primaryQuantity: p.primaryQuantity,
                      primaryUOM: p.primaryUOM,
                      secondaryQuantity: p.secondaryQuantity,
                      secondaryUOM: p.secondaryUOM,
                      wipStatus: p.wipStatus,
                      gbsFlag: p.gbsFlag,
                      pbsFlag: p.pbsFlag,
                      isLastProcess: p.isLastProcess,
                      reworkFlag: p.reworkFlag,
                      isStarted: p.isStarted,
                      draftFlag: p.draftFlag,
                      startDate: p.startDate,
                      progressCode: p.progressCode,
                      productGrade: p.productGrade,
                      productNature: p.productNature,
                      operationId: p.operationId,
                      workOrderHeaderId: p.workOrderHeaderId,
                      workOrderLineId: p.workOrderLineId,
                      processedItemId: p.processedItemId,
                      itemId: p.itemId,
                      shiftId: p.shiftId,
                      primaryTrayId: p.primaryTrayId,
                      secondaryTrayId: p.secondaryTrayId,
                      machineId: p.machineId,
                      planHeaderId: p.planHeaderId,
                      locatorId: p.locatorId,
                      batchHeaderId: null,
                      batchLinesId: null,
                      concurrencyStamp: p.concurrencyStamp,
                      lastModificationTime: p.lastModificationTime,
                      lastModifierId: p.lastModifierId,
                      creationTime: p.creationTime,
                      creatorId: p.creatorId,
                      id: p.id,
                      remarks: p.remarks,
                      waste: p.waste,
                      requiredQty: p.requiredQty,
                      defectListId: p.defectListId,
                      holdFlag: p.holdFlag,
                      holdDate: p.holdDate,
                      unHoldDate: p.unHoldDate,
                    );
                    return ProductionProgressResponseModel(
                      productionProgress: clearedPP,
                      operation: t.operation,
                      shift: t.shift,
                      machineModel: t.machineModel,
                      workOrderHeader: t.workOrderHeader,
                      workOrderLine: t.workOrderLine,
                      primaryTrayModel: t.primaryTrayModel,
                      item: t.item,
                      processedItem: t.processedItem,
                      planHeader: t.planHeader,
                      batchHeader: null,
                    );
                  }
                  return t;
                }).toList();
                _state = _state.copyWith(productionProgressTrays: updatedTrays);
              }

              final trayData = await _lotRepo.fetchTrayDetailById(trayId);
              if (trayData.success && trayData.data != null) {
                final rawTray = Map<String, dynamic>.from(trayData.data as Map);
                final tMap = rawTray.containsKey('trayDetail') &&
                        rawTray['trayDetail'] is Map
                    ? Map<String, dynamic>.from(rawTray['trayDetail'] as Map)
                    : rawTray;
                tMap['batchHeaderId'] = null;
                tMap['batchLineId'] = null;
                tMap['batchLinesId'] = null;
                tMap.remove('id');
                tMap.remove('creatorId');
                tMap.remove('creationTime');
                tMap.remove('lastModifierId');
                tMap.remove('lastModificationTime');
                tMap.remove('concurrencyStamp');
                await _lotRepo.updateTrayDetails(trayId, tMap);
              }
            }
          }
        }
      }

      final dyeingMachineId = _state.selectedMachine?.resource?.id ??
          existingBatch?.batchHeader.machineId ??
          0;

      for (int i = 0; i < _state.scannedTrays.length; i++) {
        final tray = _state.scannedTrays[i];
        final qty = finalQuantities[i];

        final pp = tray.productionProgress;
        final originalQty = pp.primaryQuantity ?? 0.0;
        final isPartial = qty < originalQty;

        int resolvedProgressId = 0;

        if (isPartial) {
          // 1. Fetch fresh record from DB to get the latest concurrencyStamp and state
          final freshRes = await _lotRepo.fetchProductionProgressById(pp.id!);
          Map<String, dynamic> originalPPPayload;
          if (freshRes.success && freshRes.data != null) {
            final Map<String, dynamic> rawMap = Map<String, dynamic>.from(freshRes.data is Map ? freshRes.data : {});
            originalPPPayload = rawMap.containsKey('productionProgress')
                ? Map<String, dynamic>.from(rawMap['productionProgress'] as Map)
                : rawMap;

            final String? stamp = (rawMap['concurrencyStamp'] ?? originalPPPayload['concurrencyStamp'])?.toString();
            if (stamp != null && stamp.isNotEmpty) {
              originalPPPayload['concurrencyStamp'] = stamp;
            }
          } else {
            originalPPPayload = pp.toJson();
          }

          // 2. Prepare payload for the NEW partial progress (allocated to this lot)
          final newPPPayload = Map<String, dynamic>.from(originalPPPayload);
          newPPPayload['primaryQuantity'] = qty.toDouble();
          final perTube = tray.item.perGarmentTube;
          if (perTube > 0) {
            newPPPayload['secondaryQuantity'] = qty * perTube;
          }

          newPPPayload['batchHeaderId'] = batchHeaderId;
          newPPPayload['transactionType'] = 6;
          if (dyeingMachineId > 0) {
            newPPPayload['machineId'] = dyeingMachineId;
          }

          newPPPayload.remove('id');
          newPPPayload.remove('progressCode');
          newPPPayload.remove('creationTime');
          newPPPayload.remove('creatorId');
          newPPPayload.remove('lastModificationTime');
          newPPPayload.remove('lastModifierId');
          newPPPayload.remove('batchLinesId');
          newPPPayload.remove('isFirstProcess');
          newPPPayload.remove('isLastProcess');
          newPPPayload.remove('lotMakingFlag');
          newPPPayload.remove('processCompletionTime');

          final resNewPP = await _lotRepo.postProductionProgress(newPPPayload);
          if (!resNewPP.success) {
            throw Exception(
              'Failed to create partial production progress: ${resNewPP.message}',
            );
          }

          if (resNewPP.data is Map) {
            resolvedProgressId = (resNewPP.data as Map)['id'] ?? 0;
          }
          if (resolvedProgressId == 0) {
            final allProgRes = await _lotRepo.fetchProductionProgress(
              query: {'LocatorId': '3', 'maxResultCount': '1000'},
            );
            if (allProgRes.success && allProgRes.data != null) {
              final List progresses = allProgRes.data as List;
              final matches = progresses
                  .whereType<ProductionProgressResponseModel>()
                  .where(
                    (p) =>
                        p.productionProgress.primaryQuantity == qty &&
                        p.productionProgress.primaryTrayId ==
                            tray.primaryTrayModel.id &&
                        p.productionProgress.workOrderLineId ==
                            (tray.workOrderLine?.id ??
                                tray.productionProgress.workOrderLineId),
                  )
                  .toList();
              if (matches.isNotEmpty) {
                matches.sort(
                  (a, b) => (b.productionProgress.id ?? 0).compareTo(
                    a.productionProgress.id ?? 0,
                  ),
                );
                resolvedProgressId = matches.first.productionProgress.id ?? 0;
              }
            }
          }

          if (resolvedProgressId == 0) {
            throw Exception(
              'Failed to resolve database ID for the new production progress.',
            );
          }

          // 3. Update the ORIGINAL progress to the remaining tubes (e.g. 20 - 15 = 5)
          final double remainingQty = math.max(0.0, originalQty - qty);
          final freshOrigRes = await _lotRepo.fetchProductionProgressById(pp.id!);
          Map<String, dynamic> updateOrigPayload;
          if (freshOrigRes.success && freshOrigRes.data != null) {
            final Map<String, dynamic> rawMap = Map<String, dynamic>.from(freshOrigRes.data is Map ? freshOrigRes.data : {});
            updateOrigPayload = rawMap.containsKey('productionProgress')
                ? Map<String, dynamic>.from(rawMap['productionProgress'] as Map)
                : rawMap;

            final String? stamp = (rawMap['concurrencyStamp'] ?? updateOrigPayload['concurrencyStamp'])?.toString();
            if (stamp != null && stamp.isNotEmpty) {
              updateOrigPayload['concurrencyStamp'] = stamp;
            }
          } else {
            updateOrigPayload = pp.toJson();
          }

          updateOrigPayload['primaryQuantity'] = remainingQty;
          if (perTube > 0) {
            updateOrigPayload['secondaryQuantity'] = remainingQty * perTube;
          }

          // Unassign the remaining slice so it is immediately free for subsequent lots
          updateOrigPayload['batchHeaderId'] = null;
          updateOrigPayload['batchLineId'] = null;
          updateOrigPayload['batchLinesId'] = null;
          updateOrigPayload['transactionType'] = 1;
          updateOrigPayload['locatorId'] = 3;
          updateOrigPayload['gbsFlag'] = true;

          updateOrigPayload.remove('id');
          updateOrigPayload.remove('progressCode');
          updateOrigPayload.remove('creationTime');
          updateOrigPayload.remove('creatorId');
          updateOrigPayload.remove('lastModificationTime');
          updateOrigPayload.remove('lastModifierId');
          updateOrigPayload.remove('isFirstProcess');
          updateOrigPayload.remove('isLastProcess');
          updateOrigPayload.remove('lotMakingFlag');
          updateOrigPayload.remove('processCompletionTime');

          var resOrig = await _lotRepo.updateProductionProgress(pp.id!, updateOrigPayload);
          if (!resOrig.success) {
            // Retry without concurrencyStamp if concurrency conflict occurs
            final retryPayload = Map<String, dynamic>.from(updateOrigPayload);
            retryPayload.remove('concurrencyStamp');
            resOrig = await _lotRepo.updateProductionProgress(pp.id!, retryPayload);
          }

          if (!resOrig.success) {
            throw Exception(
              'Failed to update remaining tubes on tray (${pp.id}): ${resOrig.message}',
            );
          }

          // Immediately reflect reduced quantity in local memory
          final updatedTraysList = _state.productionProgressTrays.map((t) {
            if (t.productionProgress.id == pp.id) {
              final newProg = t.productionProgress.copyWith(
                primaryQuantity: remainingQty,
                secondaryQuantity: perTube > 0 ? (remainingQty * perTube) : t.productionProgress.secondaryQuantity,
                batchHeaderId: null,
                batchLinesId: null,
                transactionType: 1,
              );
              return t.copyWith(productionProgress: newProg);
            }
            return t;
          }).toList();
          _state = _state.copyWith(productionProgressTrays: updatedTraysList);
        } else {
          final ppPayload = pp.toJson();
          ppPayload['batchHeaderId'] = batchHeaderId;
          ppPayload['transactionType'] = 6;
          if (dyeingMachineId > 0) {
            ppPayload['machineId'] = dyeingMachineId;
          }

          ppPayload.remove('id');
          ppPayload.remove('progressCode');
          ppPayload.remove('creationTime');
          ppPayload.remove('creatorId');
          ppPayload.remove('lastModificationTime');
          ppPayload.remove('lastModifierId');

          final resPP = await _lotRepo.updateProductionProgress(
            pp.id!,
            ppPayload,
          );
          if (!resPP.success) {
            throw Exception(
              resPP.message ?? 'Failed to update production progress.',
            );
          }
          resolvedProgressId = pp.id!;
        }

        final perTube = tray.item.perGarmentTube;
        double finalSecondaryQty = 0.0;
        if (isPartial) {
          if (perTube > 0) {
            finalSecondaryQty = qty * perTube;
          } else {
            final originalPPQty =
                tray.productionProgress.primaryQuantity ?? 1.0;
            final originalSecQty =
                tray.productionProgress.secondaryQuantity ?? 0.0;
            finalSecondaryQty = originalPPQty > 0
                ? (qty * originalSecQty / originalPPQty)
                : 0.0;
          }
        } else {
          finalSecondaryQty = (tray.productionProgress.secondaryQuantity ?? 0)
              .toDouble();
        }

        final linePayload = {
          "planDate": DateTime.now().toIso8601String(),
          "transactionDate": DateTime.now().toIso8601String(),
          "primaryQuantity": qty.toDouble(),
          "primaryUOM": tray.productionProgress.primaryUOM ?? 0,
          "secondaryQuantity": finalSecondaryQty,
          "secondaryUOM": tray.productionProgress.secondaryUOM ?? 0,
          "batchLineCode": "BL-$batchHeaderId-${tray.primaryTrayModel.id}",
          "active": true,
          "isReAssigned": false,
          "batchHeaderId": batchHeaderId,
          "progressId": resolvedProgressId,
          "workOrderHeaderId": tray.workOrderHeader.id,
          "workOrderLineId":
              tray.workOrderLine?.id ?? tray.productionProgress.workOrderLineId,
          "itemId": tray.item.id,
          "trayId": tray.primaryTrayModel.id,
          "locatorId": tray.productionProgress.locatorId,
          "processItemId": _state.trayProcessedItemId[tray.primaryTrayModel.id],
        };

        final resLine = await _lotRepo.createLotLine(linePayload);

        if (resLine.success && resLine.data != null) {
          final lineId = (resLine.data as Map)['id'];
          final int batchLineDbId = int.tryParse(lineId.toString()) ?? 0;

          if (batchLineDbId > 0 && resolvedProgressId > 0) {
            final ppFetchRes = await _lotRepo.fetchProductionProgressById(
              resolvedProgressId,
            );

            if (ppFetchRes.success && ppFetchRes.data != null) {
              final responseModel = ProductionProgressResponseModel.fromJson(
                Map<String, dynamic>.from(ppFetchRes.data as Map),
              );
              final ppMap = responseModel.productionProgress.toJson();
              ppMap['batchLineId'] = batchLineDbId;
              ppMap['batchLinesId'] = batchLineDbId;
              if (dyeingMachineId > 0) {
                ppMap['machineId'] = dyeingMachineId;
              }

              ppMap.remove('id');
              ppMap.remove('progressCode');
              ppMap.remove('concurrencyStamp');
              ppMap.remove('creationTime');
              ppMap.remove('creatorId');
              ppMap.remove('lastModificationTime');
              ppMap.remove('lastModifierId');

              await _lotRepo.updateProductionProgress(
                resolvedProgressId,
                ppMap,
              );
            }
          }

          final double originalTrayQty = (tray.primaryTrayModel.trayQuantity ?? 0).toDouble();
          final double effectiveCapacity = originalTrayQty > 0 ? originalTrayQty : originalQty;
          final bool isPhysicallyFull = !isPartial && (qty >= effectiveCapacity - 0.01);

          final trayId = tray.primaryTrayModel.id;
          if (trayId != null) {
            if (isPhysicallyFull) {
              final trayData = await _lotRepo.fetchTrayDetailById(trayId);
              if (trayData.success && trayData.data != null) {
                final map = Map<String, dynamic>.from(trayData.data as Map);
                map['batchHeaderId'] = batchHeaderId;
                map['batchLineId'] = batchLineDbId;
                map['trayQuantity'] = qty.toInt();
                await _lotRepo.updateTrayDetails(trayId, map);
              }
            } else if (isPartial) {
              // Ensure partial tray is not locked to this batch header in tray_details
              final trayData = await _lotRepo.fetchTrayDetailById(trayId);
              if (trayData.success && trayData.data != null) {
                final map = Map<String, dynamic>.from(trayData.data as Map);
                if (map['batchHeaderId'] != null) {
                  map['batchHeaderId'] = null;
                  map['batchLineId'] = null;
                  await _lotRepo.updateTrayDetails(trayId, map);
                }
              }
            }
          }
        }
      }
      _state = _state.copyWith(isLoading: false);
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}
