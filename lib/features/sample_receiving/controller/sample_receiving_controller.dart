import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/gbs/repo/gbs_receiving_repo.dart';

class SampleGroup {
  final int workOrderHeaderId;
  final String workOrderCode;
  final int itemId;
  final String itemDescription;
  final double totalTubes;
  final double totalPcs;
  final double totalWeightGrams;
  final DateTime? latestDate;
  final String remarks;
  final List<ProductionProgressResponseModel> records;

  SampleGroup({
    required this.workOrderHeaderId,
    required this.workOrderCode,
    required this.itemId,
    required this.itemDescription,
    required this.totalTubes,
    required this.totalPcs,
    required this.totalWeightGrams,
    required this.latestDate,
    required this.remarks,
    required this.records,
  });

  List<int> get allProgressIds =>
      records.map((r) => r.productionProgress.id).whereType<int>().toList();
}

class SampleReceivingState {
  final bool isLoading;
  final String? errorMessage;
  final List<ProductionProgressResponseModel> availableProgresses;
  final WorkOrderHeader? selectedWorkOrder;
  final Set<int> selectedProgressIds;

  const SampleReceivingState({
    this.isLoading = false,
    this.errorMessage,
    this.availableProgresses = const [],
    this.selectedWorkOrder,
    this.selectedProgressIds = const {},
  });

  SampleReceivingState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<ProductionProgressResponseModel>? availableProgresses,
    WorkOrderHeader? selectedWorkOrder,
    bool clearSelectedWorkOrder = false,
    Set<int>? selectedProgressIds,
  }) {
    return SampleReceivingState(
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

class SampleReceivingController extends ChangeNotifier {
  final GBSReceivingRepo _repo = GBSReceivingRepo();
  SampleReceivingState _state = const SampleReceivingState();

  SampleReceivingState get state => _state;

  SampleReceivingController() {
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
      final sampleOnly = list
          .where(
            (t) =>
                t.productionProgress.holdFlag != true &&
                t.productionProgress.gbsFlag != true &&
                (t.productionProgress.productNature == 1 ||
                 t.productionProgress.productGrade == 1 ||
                 (t.productionProgress.subOperation != null &&
                  t.productionProgress.subOperation!.toLowerCase().contains('sample'))),
          )
          .toList();

      _state = _state.copyWith(
        availableProgresses: sampleOnly,
        isLoading: false,
      );
    } else {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: result.message.isNotEmpty ? result.message : 'Failed to load sample entries',
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
      final sampleOnly = list
          .where(
            (t) =>
                t.productionProgress.holdFlag != true &&
                t.productionProgress.gbsFlag != true &&
                (t.productionProgress.productNature == 1 ||
                 t.productionProgress.productGrade == 1 ||
                 (t.productionProgress.subOperation != null &&
                  t.productionProgress.subOperation!.toLowerCase().contains('sample'))),
          )
          .toList();

      _state = _state.copyWith(availableProgresses: sampleOnly);
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

  List<SampleGroup> getGroupedSampleEntries() {
    final filtered = getFilteredEntries();
    final Map<String, List<ProductionProgressResponseModel>> groupsMap = {};

    for (final item in filtered) {
      final woId = item.workOrderHeader.id;
      final itemId = item.item.id;
      final key = "${woId}_$itemId";
      groupsMap.putIfAbsent(key, () => []).add(item);
    }

    final List<SampleGroup> result = [];
    for (final entry in groupsMap.entries) {
      final list = entry.value;
      if (list.isEmpty) continue;

      final first = list.first;
      double tubes = 0;
      double pcs = 0;
      double weightGrams = 0;
      DateTime? maxDate;
      final Set<String> remarksSet = {};

      for (final r in list) {
        final pp = r.productionProgress;
        final primaryQty = (pp.primaryQuantity ?? 0) > 0
            ? (pp.primaryQuantity ?? 0)
            : (pp.waste ?? 0);

        tubes += primaryQty.toDouble();

        final secQty = pp.secondaryQuantity ?? 0;
        double itemPcs = 0;
        if (secQty > 0) {
          itemPcs = secQty.toDouble();
        } else if (r.item.perGarmentTube > 0) {
          itemPcs = (primaryQty * r.item.perGarmentTube).toDouble();
        } else {
          itemPcs = primaryQty.toDouble();
        }
        pcs += itemPcs;

        final double pw = r.item.pieceWeight ?? 0;
        weightGrams += itemPcs * pw;

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
        SampleGroup(
          workOrderHeaderId: first.workOrderHeader.id,
          workOrderCode: first.workOrderHeader.description.isNotEmpty
              ? first.workOrderHeader.description
              : first.workOrderHeader.workOrderCode,
          itemId: first.item.id,
          itemDescription: first.item.description,
          totalTubes: tubes,
          totalPcs: pcs,
          totalWeightGrams: weightGrams,
          latestDate: maxDate,
          remarks: remarksSet.join(', '),
          records: list,
        ),
      );
    }

    return result;
  }

  Future<void> saveSampleReceiving() async {
    if (_state.selectedProgressIds.isEmpty) return;

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final List<int> selectedIds = _state.selectedProgressIds.toList();
      const int targetLocatorId = 16;
      const String subOpProgress = "Sample Received";
      const String subOpWip = "Sample Receiving";

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
