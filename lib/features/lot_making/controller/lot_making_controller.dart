import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
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

  LotMakingController({
    this.existingBatch,
    this.preloadedTrays,
  }) {
    final code = existingBatch?.batchHeader.batchHeaderCode ??
        "LOT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
    _state = _state.copyWith(lotCode: code);
    
    initData();
  }

  Future<void> initData() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      await fetchMachines();
      await fetchColors();
      await fetchProductionProgresses();
      await fetchLotProgressIds();
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
    _state = _state.copyWith(
      selectedColor: color,
      clearSelectedTray: true,
      clearReferenceRouting: true,
      scannedTrays: [],
    );
    notifyListeners();
  }

  Future<void> selectWorkOrder(WorkOrderHeader? wo) async {
    _state = _state.copyWith(
      selectedWorkOrder: wo,
      clearSelectedTray: true,
      clearReferenceRouting: _state.scannedTrays.isEmpty,
    );
    notifyListeners();

    if (wo?.id != null) {
      await ensureWorkOrderColorsCached(wo!.id!);
    }
  }

  Future<void> ensureWorkOrderColorsCached(int woId) async {
    if (_state.workOrderValidColors.containsKey(woId)) return;

    _state = _state.copyWith(isCachingColors: true);
    notifyListeners();

    try {
      final trays = _state.productionProgressTrays.where((t) {
        final progressId = t.productionProgress.id;
        final isCurrentBatchDbTray = progressId != null && _state.currentBatchDatabaseProgressIds.contains(progressId);
        return t.productionProgress.locatorId == 3 &&
            t.productionProgress.gbsFlag == true &&
            t.workOrderHeader?.id == woId &&
            (progressId == null || !_state.lotProgressIds.contains(progressId) || isCurrentBatchDbTray);
      }).toList();

      final lineIds = trays
          .map((t) => t.productionProgress.workOrderLineId ?? t.workOrderLine?.id)
          .whereType<int>()
          .toSet();

      final Set<String> validColors = {};
      final updatedPlanQuantities = Map<String, double>.from(_state.colorPlanQuantities);

      for (final lineId in lineIds) {
        final res = await _lotRepo.fetchAllWorkOrderLineDetails(lineId);
        if (res.success && res.data != null) {
          updatedPlanQuantities.removeWhere((key, _) => key.startsWith("${lineId}_"));
          final items = res.data as List;
          for (final item in items) {
            final detail = (item as Map)['workOrderLineDetail'];
            if (detail != null) {
              final colorDesc = detail['colorDescription']?.toString().trim().toUpperCase();
              final planQty = (detail['planQuantity'] as num?)?.toDouble() ?? 0.0;
              if (colorDesc != null && colorDesc.isNotEmpty) {
                validColors.add(colorDesc);
                final key = "${lineId}_$colorDesc";
                updatedPlanQuantities[key] = (updatedPlanQuantities[key] ?? 0.0) + planQty;
              }
            }
          }
        }
      }

      final updatedValidColors = Map<int, Set<String>>.from(_state.workOrderValidColors);
      updatedValidColors[woId] = validColors;

      _state = _state.copyWith(
        workOrderValidColors: updatedValidColors,
        colorPlanQuantities: updatedPlanQuantities,
        isCachingColors: false,
      );
    } catch (e) {
      dev.log('Error caching colors for WO $woId: $e');
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
      final updated = List<ProductionProgressResponseModel>.from(_state.scannedTrays)
        ..removeAt(index);
      _state = _state.copyWith(
        scannedTrays: updated,
        clearReferenceRouting: updated.isEmpty,
      );
      notifyListeners();
    }
  }

  List<WorkOrderHeader> getAvailableWorkOrders() {
    final Set<int> seenIds = {};
    final List<WorkOrderHeader> wos = [];

    final gbsTrays = _state.productionProgressTrays.where((t) {
      final progressId = t.productionProgress.id;
      final isCurrentBatchDbTray = progressId != null && _state.currentBatchDatabaseProgressIds.contains(progressId);
      final hasBatchHeader = t.productionProgress.batchHeaderId != null && t.productionProgress.batchHeaderId != 0;
      final isCurrentBatchHeader = existingBatch?.batchHeader.id != null && t.productionProgress.batchHeaderId == existingBatch!.batchHeader.id;
      final isAssignedToOtherLot = hasBatchHeader && !isCurrentBatchHeader;

      final qtys = getTrayQuantities(t);
      final remaining = qtys['remaining'] ?? 0.0;

      return t.productionProgress.locatorId == 3 &&
          t.productionProgress.gbsFlag == true &&
          t.workOrderHeader != null &&
          !isAssignedToOtherLot &&
          remaining > 0 &&
          (progressId == null || !_state.lotProgressIds.contains(progressId) || isCurrentBatchDbTray);
    }).toList();

    for (final tray in gbsTrays) {
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
    if (_state.selectedColor == null) return wos;
    final selectedColorDesc = _state.selectedColor!.segmentCode?.description?.toUpperCase();
    if (selectedColorDesc == null) return wos;

    return wos.where((wo) {
      final validColors = _state.workOrderValidColors[wo.id];
      if (validColors == null || !validColors.contains(selectedColorDesc)) return false;

      final trays = _state.productionProgressTrays.where((t) {
        if (t.workOrderHeader?.id != wo.id) return false;
        final lineId = t.productionProgress.workOrderLineId ?? t.workOrderLine?.id;
        if (lineId == null) return false;
        final planQty = _state.colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
        final qtys = getTrayQuantities(t);
        final remaining = qtys['remaining'] ?? 0.0;
        return planQty > 0.0 && remaining > 0;
      }).toList();

      return trays.isNotEmpty;
    }).toList();
  }

  List<LotColorModel> getFilteredColors() {
    if (_state.selectedWorkOrder == null) return _state.colors;
    final validColors = _state.workOrderValidColors[_state.selectedWorkOrder!.id];
    if (validColors == null) return [];

    return _state.colors.where((color) {
      final desc = color.segmentCode?.description?.toUpperCase();
      return desc != null && validColors.contains(desc);
    }).toList();
  }

  List<ProductionProgressResponseModel> getTraysForSelectedWorkOrder() {
    if (_state.selectedWorkOrder == null) return [];
    return _state.productionProgressTrays.where((t) {
      final progressId = t.productionProgress.id;
      final isCurrentBatchDbTray = progressId != null && _state.currentBatchDatabaseProgressIds.contains(progressId);
      final hasBatchHeader = t.productionProgress.batchHeaderId != null && t.productionProgress.batchHeaderId != 0;
      final isCurrentBatchHeader = existingBatch?.batchHeader.id != null && t.productionProgress.batchHeaderId == existingBatch!.batchHeader.id;
      final isAssignedToOtherLot = hasBatchHeader && !isCurrentBatchHeader;

      final qtys = getTrayQuantities(t);
      final remaining = qtys['remaining'] ?? 0.0;

      return t.productionProgress.locatorId == 3 &&
          t.productionProgress.gbsFlag == true &&
          t.workOrderHeader?.id == _state.selectedWorkOrder!.id &&
          !isAssignedToOtherLot &&
          remaining > 0 &&
          (progressId == null || !_state.lotProgressIds.contains(progressId) || isCurrentBatchDbTray);
    }).toList();
  }

  List<ProductionProgressResponseModel> getTraysForSelectedWorkOrderAndColor() {
    final trays = getTraysForSelectedWorkOrder();
    if (_state.selectedColor == null) return [];
    final selectedColorDesc = _state.selectedColor!.segmentCode?.description?.toUpperCase();
    if (selectedColorDesc == null) return [];

    return trays.where((t) {
      final lineId = t.productionProgress.workOrderLineId ?? t.workOrderLine?.id;
      if (lineId == null) return false;
      final planQty = _state.colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
      return planQty > 0.0;
    }).toList();
  }

  double getAlreadyAssignedTubesForWorkOrderLine(int workOrderLineId) {
    double sum = 0.0;
    final currentBatchId = existingBatch?.batchHeader.id;
    for (final t in _state.productionProgressTrays) {
      final lineId = t.productionProgress.workOrderLineId ?? t.workOrderLine?.id;
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
    final code = tray.primaryTrayModel.trayCode;
    final fallbackQty = tray.productionProgress.primaryQuantity ?? 0.0;
    if (code == null) {
      return {'actual': fallbackQty, 'alreadyScanned': 0.0, 'remaining': fallbackQty};
    }

    final trayProgresses = _state.productionProgressTrays.where((t) =>
        (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase() == code.trim().toLowerCase() &&
        t.productionProgress.locatorId == 3 &&
        t.productionProgress.gbsFlag == true
    ).toList();

    final actual = trayProgresses.fold<double>(0.0, (sum, t) => sum + (t.productionProgress.primaryQuantity ?? 0.0));

    final alreadyScanned = trayProgresses.where((t) {
      final hasBatch = t.productionProgress.batchHeaderId != null && t.productionProgress.batchHeaderId != 0;
      final isCurrent = existingBatch?.batchHeader.id != null && t.productionProgress.batchHeaderId == existingBatch!.batchHeader.id;
      return hasBatch && !isCurrent;
    }).fold<double>(0.0, (sum, t) => sum + (t.productionProgress.primaryQuantity ?? 0.0));

    final remaining = actual - alreadyScanned;

    return {
      'actual': actual,
      'alreadyScanned': alreadyScanned,
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
        errorMessage: result.message ?? 'Unknown error fetching production progresses',
      );
    }
    notifyListeners();
  }

  Future<void> _cacheColorsForGbsWorkOrders() async {
    _state = _state.copyWith(isCachingColors: true);
    notifyListeners();

    try {
      final wos = getAvailableWorkOrders();
      final updatedValidColors = Map<int, Set<String>>.from(_state.workOrderValidColors);
      final updatedPlanQuantities = Map<String, double>.from(_state.colorPlanQuantities);

      for (final wo in wos) {
        final woId = wo.id;
        if (woId == null || updatedValidColors.containsKey(woId)) continue;

        final trays = _state.productionProgressTrays.where((t) {
          final progressId = t.productionProgress.id;
          final isCurrentBatchDbTray = progressId != null && _state.currentBatchDatabaseProgressIds.contains(progressId);
          return t.productionProgress.locatorId == 3 &&
              t.productionProgress.gbsFlag == true &&
              t.workOrderHeader?.id == woId &&
              (progressId == null || !_state.lotProgressIds.contains(progressId) || isCurrentBatchDbTray);
        }).toList();

        final lineIds = trays
            .map((t) => t.productionProgress.workOrderLineId ?? t.workOrderLine?.id)
            .whereType<int>()
            .toSet();

        final Set<String> validColors = {};
        for (final lineId in lineIds) {
          final res = await _lotRepo.fetchAllWorkOrderLineDetails(lineId);
          if (res.success && res.data != null) {
            updatedPlanQuantities.removeWhere((key, _) => key.startsWith("${lineId}_"));
            final items = res.data as List;
            for (final item in items) {
              final detail = (item as Map)['workOrderLineDetail'];
              if (detail != null) {
                final colorDesc = detail['colorDescription']?.toString().trim().toUpperCase();
                final planQty = (detail['planQuantity'] as num?)?.toDouble() ?? 0.0;
                if (colorDesc != null && colorDesc.isNotEmpty) {
                  validColors.add(colorDesc);
                  final key = "${lineId}_$colorDesc";
                  updatedPlanQuantities[key] = (updatedPlanQuantities[key] ?? 0.0) + planQty;
                }
              }
            }
          }
        }
        updatedValidColors[woId] = validColors;
      }
      _state = _state.copyWith(
        workOrderValidColors: updatedValidColors,
        colorPlanQuantities: updatedPlanQuantities,
        isCachingColors: false,
      );
    } catch (e) {
      dev.log('Error caching colors: $e');
      _state = _state.copyWith(isCachingColors: false);
    }
    notifyListeners();
  }

  Future<void> _loadExistingLotTrays(List<ProductionProgressResponseModel> allProgresses) async {
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
        .where((p) => p.productionProgress.id != null && linkedProgressIds.contains(p.productionProgress.id))
        .toList();

    if (linkedTrays.isNotEmpty) {
      final updatedProgressIds = Set<int>.from(_state.currentBatchDatabaseProgressIds)..addAll(linkedProgressIds);
      final updatedScanned = List<ProductionProgressResponseModel>.from(_state.scannedTrays)..addAll(linkedTrays);

      _state = _state.copyWith(
        currentBatchDatabaseProgressIds: updatedProgressIds,
        scannedTrays: updatedScanned,
      );
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
      if (existingBatch?.machine != null) {
        final editMachineId = existingBatch!.machine!.id;
        final match = machinesList.where((m) => m.resource?.id == editMachineId).toList();
        if (match.isNotEmpty) selected = match.first;
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
      LotColorModel? selected;
      if (existingBatch?.colorCode != null) {
        final editColorId = existingBatch!.colorCode!.id;
        final match = colorsList.where((c) => c.segmentCode?.id == editColorId).toList();
        if (match.isNotEmpty) selected = match.first;
      }
      _state = _state.copyWith(
        colors: colorsList,
        selectedColor: selected,
        isLoadingColors: false,
      );
    } else {
      _state = _state.copyWith(
        isLoadingColors: false,
        errorMessage: result.message ?? 'Failed to fetch colors',
      );
    }
    notifyListeners();
  }

  Future<String?> validateTrayForScan(String scannedCode, double overrideQty) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid tray code';
    if (_state.selectedColor == null) return 'Please select a lot Color first';
    if (_state.scannedTrays.any((t) => (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase() == code.toLowerCase())) {
      return 'Already assigned';
    }

    final available = _state.productionProgressTrays.where((t) =>
        (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase() == code.toLowerCase() &&
        t.productionProgress.locatorId == 3 &&
        t.productionProgress.gbsFlag == true
    ).toList();

    if (available.isEmpty) return 'Tray not found or not checked out via GBS';

    final tray = available.firstWhere(
      (t) => !_state.lotProgressIds.contains(t.productionProgress.id),
      orElse: () => available.first,
    );

    if (_state.selectedWorkOrder == null) return 'Please select a Work Order first';
    if (tray.workOrderHeader.id != _state.selectedWorkOrder?.id) {
      return 'Tray belongs to another Work Order (${tray.workOrderHeader.workOrderCode})';
    }

    if ((tray.primaryTrayModel.trayType ?? 0) != 1) return 'Invalid tray type.';
    final progressId = tray.productionProgress.id;
    final isCurrentBatchDbTray = progressId != null && _state.currentBatchDatabaseProgressIds.contains(progressId);
    if (progressId != null && _state.lotProgressIds.contains(progressId) && !isCurrentBatchDbTray) {
      return 'Tray already assigned to a lot';
    }

    final workOrderLineId = tray.productionProgress.workOrderLineId ?? tray.workOrderLine?.id;
    final colorDescription = _state.selectedColor!.segmentCode?.description;
    if (colorDescription == null) return 'Selected Color has no description';

    final colorRes = await _lotRepo.fetchWorkOrderLineDetails(workOrderLineId!, colorDescription);
    if (!colorRes.success || colorRes.data == null) return 'Validation error: ${colorRes.message}';

    final items = colorRes.data as List?;
    if (items == null || items.isEmpty) return 'Invalid tray: Tray does not belong to the selected color';

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
    if (!routingRes.success || routingRes.data == null) return 'Routing validation error: ${routingRes.message}';

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
    final capacityKg = capacityRaw != null ? double.tryParse(capacityRaw.toString()) : null;
    if (capacityKg != null && capacityKg > 0) {
      final capacityGrams = capacityKg * 1000;
      final newQty = overrideQty > 0 ? overrideQty : (tray.productionProgress.primaryQuantity ?? 0);
      final pw = tray.item.pieceWeight ?? 0;
      double currentTotal = 0;
      for (int i = 0; i < _state.scannedTrays.length; i++) {
        final qty = _state.scannedTrays[i].productionProgress.primaryQuantity ?? 0;
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
      final newQty = overrideQty > 0 ? overrideQty : (tray.productionProgress.primaryQuantity ?? 0.0);
      double currentCumulative = 0.0;
      for (int i = 0; i < _state.scannedTrays.length; i++) {
        final t = _state.scannedTrays[i];
        final lineId = t.productionProgress.workOrderLineId ?? t.workOrderLine?.id;
        if (lineId == workOrderLineId) {
          currentCumulative += t.productionProgress.primaryQuantity ?? 0.0;
        }
      }
      final alreadyAssigned = getAlreadyAssignedTubesForWorkOrderLine(workOrderLineId);
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

    final updatedScanned = List<ProductionProgressResponseModel>.from(_state.scannedTrays)..add(tray);

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
          "colorDescription": _state.selectedColor?.segmentCode?.description ?? "N/A",
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
        final rawId = data['id'] ?? data['batchHeader']?['id'] ?? data['result']?['id'] ?? 0;
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
      }

      if (batchHeaderId == 0) {
        throw Exception('Invalid Lot ID generated.');
      }

      if (existingBatch != null) {
        final existingLinesRes = await _lotRepo.fetchLotLines(batchHeaderId: batchHeaderId);
        if (existingLinesRes.success && existingLinesRes.data != null) {
          final List rawList = existingLinesRes.data is Map
              ? (existingLinesRes.data['items'] ?? [])
              : (existingLinesRes.data is List ? existingLinesRes.data : []);

          final Set<int?> currentScannedTrayIds = _state.scannedTrays.map((t) => t.primaryTrayModel.id).toSet();

          for (final line in rawList) {
            final rawLineMap = Map<String, dynamic>.from(line as Map);
            final lineMap = rawLineMap.containsKey('batchLines') && rawLineMap['batchLines'] is Map
                ? Map<String, dynamic>.from(rawLineMap['batchLines'] as Map)
                : rawLineMap;

            final int? lineId = (lineMap['id'] ?? rawLineMap['id']) != null
                ? int.tryParse((lineMap['id'] ?? rawLineMap['id']).toString())
                : null;
            final int? trayId = (lineMap['trayId'] ?? rawLineMap['trayId']) != null
                ? int.tryParse((lineMap['trayId'] ?? rawLineMap['trayId']).toString())
                : null;
            final int? progressId = (lineMap['progressId'] ?? rawLineMap['progressId']) != null
                ? int.tryParse((lineMap['progressId'] ?? rawLineMap['progressId']).toString())
                : null;

            if (lineId != null && lineId > 0) {
              await _lotRepo.deleteLotLine(lineId);
            }

            if (trayId != null && !currentScannedTrayIds.contains(trayId)) {
              if (progressId != null && progressId > 0) {
                final ppFetch = await _lotRepo.fetchProductionProgressById(progressId);
                if (ppFetch.success && ppFetch.data != null) {
                  final ppMap = Map<String, dynamic>.from(ppFetch.data as Map);
                  ppMap['batchHeaderId'] = null;
                  ppMap['batchLineId'] = null;
                  ppMap.remove('id');
                  ppMap.remove('progressCode');
                  ppMap.remove('concurrencyStamp');
                  ppMap.remove('creationTime');
                  ppMap.remove('creatorId');
                  ppMap.remove('lastModificationTime');
                  ppMap.remove('lastModifierId');
                  await _lotRepo.updateProductionProgress(progressId, ppMap);
                }
              }

              final trayData = await _lotRepo.fetchTrayDetailById(trayId);
              if (trayData.success && trayData.data != null) {
                final tMap = Map<String, dynamic>.from(trayData.data as Map);
                tMap['batchHeaderId'] = null;
                tMap['batchLineId'] = null;
                tMap.remove('creatorId');
                tMap.remove('creationTime');
                tMap.remove('lastModifierId');
                tMap.remove('lastModificationTime');
                await _lotRepo.updateTrayDetails(trayId, tMap);
              }
            }
          }
        }
      }

      for (int i = 0; i < _state.scannedTrays.length; i++) {
        final tray = _state.scannedTrays[i];
        final qty = finalQuantities[i];

        final pp = tray.productionProgress;
        final originalQty = pp.primaryQuantity ?? 0.0;
        final isPartial = qty < originalQty;

        int resolvedProgressId = 0;

        if (isPartial) {
          final newPPPayload = pp.toJson();
          newPPPayload['primaryQuantity'] = qty.toDouble();
          final perTube = tray.item.perGarmentTube;
          if (perTube > 0) {
            newPPPayload['secondaryQuantity'] = qty * perTube;
          }

          newPPPayload['batchHeaderId'] = batchHeaderId;
          newPPPayload['transactionType'] = 6;
          if (_state.referenceMinOperationId != null) {
            newPPPayload['operationId'] = _state.referenceMinOperationId;
          }

          newPPPayload.remove('id');
          newPPPayload.remove('progressCode');
          newPPPayload.remove('creationTime');
          newPPPayload.remove('creatorId');
          newPPPayload.remove('lastModificationTime');
          newPPPayload.remove('lastModifierId');

          final resNewPP = await _lotRepo.postProductionProgress(newPPPayload);
          if (!resNewPP.success) {
            throw Exception('Failed to create partial production progress: ${resNewPP.message}');
          }

          if (resNewPP.data is Map) {
            resolvedProgressId = (resNewPP.data as Map)['id'] ?? 0;
          }
          if (resolvedProgressId == 0) {
            final allProgRes = await _lotRepo.fetchProductionProgress(query: {
              'LocatorId': '3',
              'maxResultCount': '1000',
            });
            if (allProgRes.success && allProgRes.data != null) {
              final List progresses = allProgRes.data as List;
              final matches = progresses.whereType<ProductionProgressResponseModel>().where((p) =>
                p.productionProgress.primaryQuantity == qty &&
                p.productionProgress.primaryTrayId == tray.primaryTrayModel.id &&
                p.productionProgress.workOrderLineId == (tray.workOrderLine?.id ?? tray.productionProgress.workOrderLineId)
              ).toList();
              if (matches.isNotEmpty) {
                matches.sort((a, b) => (b.productionProgress.id ?? 0).compareTo(a.productionProgress.id ?? 0));
                resolvedProgressId = matches.first.productionProgress.id ?? 0;
              }
            }
          }

          if (resolvedProgressId == 0) {
            throw Exception('Failed to resolve database ID for the new production progress.');
          }

          final originalPPPayload = pp.toJson();
          originalPPPayload['primaryQuantity'] = (originalQty - qty).toDouble();
          if (perTube > 0) {
            originalPPPayload['secondaryQuantity'] = (originalQty - qty) * perTube;
          }

          originalPPPayload.remove('id');
          originalPPPayload.remove('progressCode');
          originalPPPayload.remove('creationTime');
          originalPPPayload.remove('creatorId');
          originalPPPayload.remove('lastModificationTime');
          originalPPPayload.remove('lastModifierId');

          await _lotRepo.updateProductionProgress(pp.id!, originalPPPayload);
        } else {
          final ppPayload = pp.toJson();
          ppPayload['batchHeaderId'] = batchHeaderId;
          ppPayload['transactionType'] = 6;
          if (_state.referenceMinOperationId != null) {
            ppPayload['operationId'] = _state.referenceMinOperationId;
          }

          ppPayload.remove('id');
          ppPayload.remove('progressCode');
          ppPayload.remove('creationTime');
          ppPayload.remove('creatorId');
          ppPayload.remove('lastModificationTime');
          ppPayload.remove('lastModifierId');

          final resPP = await _lotRepo.updateProductionProgress(pp.id!, ppPayload);
          if (!resPP.success) {
            throw Exception(resPP.message ?? 'Failed to update production progress.');
          }
          resolvedProgressId = pp.id!;
        }

        final perTube = tray.item.perGarmentTube;
        double finalSecondaryQty = 0.0;
        if (isPartial) {
          if (perTube > 0) {
            finalSecondaryQty = qty * perTube;
          } else {
            final originalPPQty = tray.productionProgress.primaryQuantity ?? 1.0;
            final originalSecQty = tray.productionProgress.secondaryQuantity ?? 0.0;
            finalSecondaryQty = originalPPQty > 0 ? (qty * originalSecQty / originalPPQty) : 0.0;
          }
        } else {
          finalSecondaryQty = (tray.productionProgress.secondaryQuantity ?? 0).toDouble();
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
          "workOrderLineId": tray.workOrderLine?.id ?? tray.productionProgress.workOrderLineId,
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
            final ppFetchRes = await _lotRepo.fetchProductionProgressById(resolvedProgressId);
            if (ppFetchRes.success && ppFetchRes.data != null) {
              final responseModel = ProductionProgressResponseModel.fromJson(
                Map<String, dynamic>.from(ppFetchRes.data as Map),
              );
              final ppMap = responseModel.productionProgress.toJson();
              ppMap['batchLineId'] = batchLineDbId;
              ppMap.remove('batchLinesId');
              
              ppMap.remove('id');
              ppMap.remove('progressCode');
              ppMap.remove('concurrencyStamp');
              ppMap.remove('creationTime');
              ppMap.remove('creatorId');
              ppMap.remove('lastModificationTime');
              ppMap.remove('lastModifierId');

              await _lotRepo.updateProductionProgress(resolvedProgressId, ppMap);
            }
          }

          final double trayCapacity = (tray.primaryTrayModel.trayQuantity ?? 0).toDouble();
          final bool isPhysicallyFull = qty >= trayCapacity - 0.01;

          if (isPhysicallyFull) {
            final trayId = tray.primaryTrayModel.id;
            if (trayId != null) {
              final trayData = await _lotRepo.fetchTrayDetailById(trayId);
              if (trayData.success && trayData.data != null) {
                final map = Map<String, dynamic>.from(trayData.data as Map);
                map['batchHeaderId'] = batchHeaderId;
                map['batchLineId'] = batchLineDbId;
                map['trayQuantity'] = qty.toInt();
                await _lotRepo.updateTrayDetails(trayId, map);
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
