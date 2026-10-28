import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/gbs/repo/gbs_receiving_repo.dart';

class CGradeGroup {
  final int workOrderHeaderId;
  final String workOrderCode;
  final int itemId;
  final String itemDescription;
  final double totalWeightKg;
  final DateTime? latestDate;
  final String remarks;
  final List<ProductionProgressResponseModel> records;

  CGradeGroup({
    required this.workOrderHeaderId,
    required this.workOrderCode,
    required this.itemId,
    required this.itemDescription,
    required this.totalWeightKg,
    required this.latestDate,
    required this.remarks,
    required this.records,
  });

  List<int> get allProgressIds =>
      records.map((r) => r.productionProgress.id).whereType<int>().toList();
}

class CGradeReceivingState {
  final bool isLoading;
  final String? errorMessage;
  final List<ProductionProgressResponseModel> availableProgresses;
  final WorkOrderHeader? selectedWorkOrder;
  final Set<int> selectedProgressIds;

  const CGradeReceivingState({
    this.isLoading = false,
    this.errorMessage,
    this.availableProgresses = const [],
    this.selectedWorkOrder,
    this.selectedProgressIds = const {},
  });

  CGradeReceivingState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<ProductionProgressResponseModel>? availableProgresses,
    WorkOrderHeader? selectedWorkOrder,
    bool clearSelectedWorkOrder = false,
    Set<int>? selectedProgressIds,
  }) {
    return CGradeReceivingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      availableProgresses: availableProgresses ?? this.availableProgresses,
      selectedWorkOrder: clearSelectedWorkOrder
          ? null
          : (selectedWorkOrder ?? this.selectedWorkOrder),
      selectedProgressIds: selectedProgressIds ?? this.selectedProgressIds,
    );
  }
}

class CGradeReceivingController extends ChangeNotifier {
  final GBSReceivingRepo _repo = GBSReceivingRepo();
  CGradeReceivingState _state = const CGradeReceivingState();

  CGradeReceivingState get state => _state;

  CGradeReceivingController() {
    fetchLatestEntries();
  }

  Future<void> fetchLatestEntries() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    var result = await _repo.getProductionProgress(
      params: {
        'LocatorId': '2',
        'MaxResultCount': '1000',
      },
    );
    if (!result.success || result.data == null || (result.data as List).isEmpty) {
      final fallback = await _repo.getProductionProgress(
        params: {'MaxResultCount': '1000'},
      );
      if (fallback.success && fallback.data != null && (fallback.data as List).isNotEmpty) {
        result = fallback;
      }
    }

    if (result.success && result.data != null) {
      final List<ProductionProgressResponseModel> list =
          result.data as List<ProductionProgressResponseModel>;
      final cGradeOnly = list
          .where(
            (t) =>
                t.productionProgress.holdFlag != true &&
                t.productionProgress.gbsFlag != true &&
                (t.productionProgress.productGrade == 2 ||
                 t.productionProgress.productNature == 2 ||
                 (t.productionProgress.subOperation != null &&
                  t.productionProgress.subOperation!.toLowerCase().contains('c-grade'))),
          )
          .toList();

      _state = _state.copyWith(
        availableProgresses: cGradeOnly,
        isLoading: false,
      );
    } else {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: result.message.isNotEmpty ? result.message : 'Failed to load C-Grade entries',
      );
    }
    notifyListeners();
  }

  Future<void> fetchLatestEntriesSilently() async {
    var result = await _repo.getProductionProgress(
      params: {
        'LocatorId': '2',
        'MaxResultCount': '1000',
      },
    );
    if (!result.success || result.data == null || (result.data as List).isEmpty) {
      final fallback = await _repo.getProductionProgress(
        params: {'MaxResultCount': '1000'},
      );
      if (fallback.success && fallback.data != null && (fallback.data as List).isNotEmpty) {
        result = fallback;
      }
    }

    if (result.success && result.data != null) {
      final List<ProductionProgressResponseModel> list =
          result.data as List<ProductionProgressResponseModel>;
      final cGradeOnly = list
          .where(
            (t) =>
                t.productionProgress.holdFlag != true &&
                t.productionProgress.gbsFlag != true &&
                (t.productionProgress.productGrade == 2 ||
                 t.productionProgress.productNature == 2 ||
                 (t.productionProgress.subOperation != null &&
                  t.productionProgress.subOperation!.toLowerCase().contains('c-grade'))),
          )
          .toList();

      _state = _state.copyWith(availableProgresses: cGradeOnly);
      notifyListeners();
    }
  }

  void selectWorkOrder(WorkOrderHeader? wo) {
    _state = _state.copyWith(
      selectedWorkOrder: wo,
      selectedProgressIds: {},
    );
    notifyListeners();
  }

  void toggleSelectedProgressId(int id, bool selected) {
    final updated = Set<int>.from(_state.selectedProgressIds);
    if (selected) {
      updated.add(id);
    } else {
      updated.remove(id);
    }
    _state = _state.copyWith(selectedProgressIds: updated);
    notifyListeners();
  }

  void toggleGroupProgressIds(List<int> ids, bool selected) {
    final updated = Set<int>.from(_state.selectedProgressIds);
    if (selected) {
      updated.addAll(ids);
    } else {
      updated.removeAll(ids);
    }
    _state = _state.copyWith(selectedProgressIds: updated);
    notifyListeners();
  }

  void toggleAllProgressIds(bool selectAll) {
    final Set<int> updated = {};
    if (selectAll) {
      updated.addAll(
        getFilteredEntries()
            .map((t) => t.productionProgress.id)
            .whereType<int>(),
      );
    }
    _state = _state.copyWith(selectedProgressIds: updated);
    notifyListeners();
  }

  List<ProductionProgressResponseModel> getFilteredEntries() {
    var list = _state.availableProgresses;
    if (_state.selectedWorkOrder != null) {
      list = list
          .where((t) => t.workOrderHeader.id == _state.selectedWorkOrder!.id)
          .toList();
    }
    return list;
  }

  List<CGradeGroup> getGroupedCGradeEntries() {
    final filtered = getFilteredEntries();
    final Map<String, List<ProductionProgressResponseModel>> groupsMap = {};

    for (final item in filtered) {
      final woId = item.workOrderHeader.id;
      final itemId = item.item.id;
      final key = "${woId}_$itemId";
      groupsMap.putIfAbsent(key, () => []).add(item);
    }

    final List<CGradeGroup> result = [];
    for (final entry in groupsMap.entries) {
      final list = entry.value;
      if (list.isEmpty) continue;

      final first = list.first;
      double totalWeightKg = 0;
      DateTime? maxDate;
      final Set<String> remarksSet = {};

      for (final r in list) {
        final pp = r.productionProgress;
        final primaryQty = (pp.primaryQuantity ?? 0) > 0
            ? (pp.primaryQuantity ?? 0)
            : (pp.waste ?? 0);
        totalWeightKg += primaryQty.toDouble();

        if (pp.date != null) {
          if (maxDate == null || pp.date!.isAfter(maxDate)) {
            maxDate = pp.date;
          }
        }

        if (pp.remarks != null && pp.remarks!.trim().isNotEmpty) {
          remarksSet.add(pp.remarks!.trim());
        }
      }

      result.add(
        CGradeGroup(
          workOrderHeaderId: first.workOrderHeader.id,
          workOrderCode: first.workOrderHeader.description.isNotEmpty
              ? first.workOrderHeader.description
              : first.workOrderHeader.workOrderCode,
          itemId: first.item.id,
          itemDescription: first.item.description,
          totalWeightKg: totalWeightKg,
          latestDate: maxDate,
          remarks: remarksSet.join(', '),
          records: list,
        ),
      );
    }

    return result;
  }

  Future<void> saveCGradeReceiving() async {
    if (_state.selectedProgressIds.isEmpty) return;

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final List<int> selectedIds = _state.selectedProgressIds.toList();
      const int targetLocatorId = 17;
      const String subOpProgress = "C Grade Received";
      const String subOpWip = "C Grade Receiving";

      for (final id in selectedIds) {
        final currentData = _state.availableProgresses
            .where((t) => t.productionProgress.id == id)
            .firstOrNull;
        if (currentData == null) continue;

        final Map<String, dynamic> wipPayload = {
          "subOperation": subOpWip,
          "transactionDate": DateTime.now().toIso8601String(),
          "transactionType": 6,
          "uom": currentData.workOrderLine.uom,
          "operatorDescription": "system",
          "primaryQuantity":
              currentData.productionProgress.primaryQuantity ?? 0,
          "secondaryQuantity":
              currentData.productionProgress.secondaryQuantity ?? 0,
          "primaryUOM": currentData.productionProgress.primaryUOM ?? 0,
          "secondaryUOM": currentData.productionProgress.secondaryUOM ?? 0,
          "code": currentData.item.code,
          "productGrade": currentData.productionProgress.productGrade ?? 0,
          "productNature": currentData.productionProgress.productNature ?? 0,
          "progressId": currentData.productionProgress.id,
          "operationId": currentData.operation.id,
          "workOrderHeaderId": currentData.workOrderHeader.id,
          "workOrderLineId": currentData.workOrderLine.id,
          "itemId": currentData.item.id,
          "shiftId": currentData.shift.id,
          "machineId": currentData.machineModel.id,
          "planHeaderId": currentData.planHeader?.id,
          "locatorId": targetLocatorId,
          "processedItemId":
              currentData.processedItem?.id ?? currentData.item.id,
        };

        await _repo.postWipTransactions(wipPayload);

        final Map<String, dynamic> updateProductionEntry = {
          "id": currentData.productionProgress.id,
          "concurrencyStamp": currentData.productionProgress.concurrencyStamp,
          "subOperation": subOpProgress,
          "date": DateTime.now().toIso8601String(),
          "transactionType": 6,
          "operatorDescription": "system",
          "primaryQuantity": currentData.productionProgress.primaryQuantity,
          "primaryUOM": currentData.productionProgress.primaryUOM,
          "secondaryQuantity":
              currentData.productionProgress.secondaryQuantity,
          "secondaryUOM": currentData.productionProgress.secondaryUOM,
          "wipStatus": currentData.productionProgress.wipStatus ?? 0,
          "gbsFlag": true,
          "pbsFlag": false,
          "progressCode": currentData.productionProgress.progressCode,
          "productGrade": currentData.productionProgress.productGrade,
          "productNature": currentData.productionProgress.productNature,
          "operationId": currentData.productionProgress.operationId,
          "workOrderHeaderId":
              currentData.productionProgress.workOrderHeaderId,
          "workOrderLineId": currentData.productionProgress.workOrderLineId,
          "itemId": currentData.productionProgress.itemId,
          "shiftId": currentData.productionProgress.shiftId,
          "machineId": currentData.productionProgress.machineId,
          "planHeaderId": currentData.productionProgress.planHeaderId,
          "locatorId": targetLocatorId,
          "batchHeaderId": currentData.productionProgress.batchHeaderId,
          "batchLineId": currentData.productionProgress.batchLinesId,
          "remarks": currentData.productionProgress.remarks,
        };
        updateProductionEntry.remove("batchLinesId");

        if (currentData.productionProgress.id != null) {
          final res = await _repo.updateProductionProgress(
            currentData.productionProgress.id!,
            updateProductionEntry,
          );
          if (!res.success) {
            throw Exception(res.message);
          }
        }
      }

      _state = _state.copyWith(
        selectedProgressIds: {},
        isLoading: false,
      );
      await fetchLatestEntriesSilently();
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}
