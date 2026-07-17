import 'package:flutter/foundation.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/features/stitching_line_schedule/model/stitching_line_schedule_state.dart';
import 'package:active_wear_scanning/features/stitching_line_schedule/model/stitching_line_schedule_model.dart';
import 'package:active_wear_scanning/features/stitching_line_schedule/repo/stitching_line_schedule_repo.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';

class StitchingLineScheduleController extends ChangeNotifier {
  final _stitchingLineScheduleRepo = fromPlex<StitchingLineScheduleRepo>();

  StitchingLineScheduleState _state = const StitchingLineScheduleState();
  StitchingLineScheduleState get state => _state;

  StitchingLineScheduleController() {
    fetchStitchingLineSchedules();
  }

  Future<void> fetchStitchingLineSchedules() async {
    _state = _state.copyWith(
      isLoadingStitchingLineSchedules: true,
      customers: [],
      selectedCustomer: null,
      customerPOs: [],
      selectedCustomerPO: null,
      articles: [],
      selectedArticle: null,
      selectedStitchingLineScheduleIds: {},
      allocationMode: null,
      clearSelectedCustomer: true,
      clearSelectedCustomerPO: true,
      clearSelectedArticle: true,
      clearSelectedCostCenterLine: true,
      clearAllocationMode: true,
      clearError: true,
    );
    notifyListeners();

    final res = await _stitchingLineScheduleRepo.fetchStitchingLineSchedules();
    if (res.success && res.data != null) {
      final allStyles = res.data as List<StitchingLineScheduleItem>;
      final uniqueCustomers = allStyles
          .map((item) => item.stitchingLineSchedule.customer)
          .whereType<String>()
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      uniqueCustomers.sort();
      _state = _state.copyWith(
        stitchingLineSchedules: allStyles,
        customers: uniqueCustomers,
        isLoadingStitchingLineSchedules: false,
      );
    } else {
      _state = _state.copyWith(
        isLoadingStitchingLineSchedules: false,
        errorMessage: res.message,
      );
    }
    notifyListeners();
  }

  Future<void> fetchCostCenterLines() async {
    _state = _state.copyWith(
      isLoadingCostCenterLines: true,
      costCenterLines: [],
      selectedCostCenterLine: null,
      allocationMode: null,
      clearSelectedCostCenterLine: true,
      clearAllocationMode: true,
    );
    notifyListeners();

    final res = await _stitchingLineScheduleRepo.fetchCostCenterLines();
    if (res.success && res.data != null) {
      _state = _state.copyWith(
        costCenterLines: res.data as List<CostCenterLine>,
        isLoadingCostCenterLines: false,
      );
    } else {
      _state = _state.copyWith(
        isLoadingCostCenterLines: false,
        errorMessage: res.message,
      );
    }
    notifyListeners();
  }

  void onCustomerChanged(String? val) {
    _state = _state.copyWith(
      selectedCustomer: val,
      customerPOs: [],
      selectedCustomerPO: null,
      articles: [],
      selectedArticle: null,
      selectedStitchingLineScheduleIds: {},
      costCenterLines: [],
      selectedCostCenterLine: null,
      allocationMode: null,
      clearSelectedCustomerPO: val == null,
      clearSelectedArticle: true,
      clearSelectedCostCenterLine: true,
      clearAllocationMode: true,
    );

    if (val != null) {
      final uniquePOs = _state.stitchingLineSchedules
          .where((item) => item.stitchingLineSchedule.customer == val)
          .map((item) => item.stitchingLineSchedule.po)
          .whereType<String>()
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();
      uniquePOs.sort();
      _state = _state.copyWith(customerPOs: uniquePOs);
    }
    notifyListeners();
  }

  void onCustomerPOChanged(String? val) {
    _state = _state.copyWith(
      selectedCustomerPO: val,
      articles: [],
      selectedArticle: null,
      selectedStitchingLineScheduleIds: {},
      costCenterLines: [],
      selectedCostCenterLine: null,
      allocationMode: null,
      clearSelectedArticle: val == null,
      clearSelectedCostCenterLine: true,
      clearAllocationMode: true,
    );

    if (val != null && _state.selectedCustomer != null) {
      final uniqueArticles = _state.stitchingLineSchedules
          .where((item) => item.stitchingLineSchedule.customer == _state.selectedCustomer && item.stitchingLineSchedule.po == val)
          .map((item) => item.stitchingLineSchedule.articleNo)
          .whereType<String>()
          .where((a) => a.isNotEmpty)
          .toSet()
          .toList();
      uniqueArticles.sort();
      _state = _state.copyWith(articles: uniqueArticles);
    }
    notifyListeners();
  }

  void onArticleChanged(String? val) async {
    _state = _state.copyWith(
      selectedArticle: val,
      selectedStitchingLineScheduleIds: {},
      costCenterLines: [],
      selectedCostCenterLine: null,
      allocationMode: null,
      clearSelectedCostCenterLine: true,
      clearAllocationMode: true,
    );
    notifyListeners();

    if (val != null) {
      await fetchCostCenterLines();
    }
  }

  void selectCostCenterLine(CostCenterLine? val) {
    _state = _state.copyWith(
      selectedCostCenterLine: val,
      allocationMode: null,
      selectedStitchingLineScheduleIds: {},
      clearAllocationMode: true,
    );
    notifyListeners();
  }

  void changeAllocationMode(String mode) {
    _state = _state.copyWith(
      allocationMode: mode,
      selectedStitchingLineScheduleIds: {},
    );
    notifyListeners();
  }

  void toggleScheduleSelection(int id, bool selected) {
    final updated = Set<int>.from(_state.selectedStitchingLineScheduleIds);
    if (selected) {
      updated.add(id);
    } else {
      updated.remove(id);
    }
    _state = _state.copyWith(selectedStitchingLineScheduleIds: updated);
    notifyListeners();
  }

  void toggleAllSelectableSchedules(bool selectAll) {
    final updated = Set<int>.from(_state.selectedStitchingLineScheduleIds);
    final selectable = getFilteredStitchingLineSchedules().where(isRowSelectable).toList();
    if (selectAll) {
      updated.addAll(selectable.map((i) => i.stitchingLineSchedule.id));
    } else {
      for (final i in selectable) {
        updated.remove(i.stitchingLineSchedule.id);
      }
    }
    _state = _state.copyWith(selectedStitchingLineScheduleIds: updated);
    notifyListeners();
  }

  List<StitchingLineScheduleItem> getFilteredStitchingLineSchedules() {
    if (_state.selectedCustomer == null || _state.selectedCustomerPO == null || _state.selectedArticle == null) return [];
    return _state.stitchingLineSchedules
        .where((item) =>
            item.stitchingLineSchedule.customer == _state.selectedCustomer &&
            item.stitchingLineSchedule.po == _state.selectedCustomerPO &&
            item.stitchingLineSchedule.articleNo == _state.selectedArticle)
        .toList();
  }

  bool isRowSelectable(StitchingLineScheduleItem item) {
    if (_state.allocationMode == 'allocate') {
      return item.stitchingLineSchedule.line == null || item.stitchingLineSchedule.line!.isEmpty;
    } else if (_state.allocationMode == 're-allocate') {
      return item.stitchingLineSchedule.line != null && item.stitchingLineSchedule.line!.isNotEmpty;
    }
    return false;
  }

  Future<void> saveChanges() async {
    if (_state.selectedCostCenterLine == null || _state.selectedStitchingLineScheduleIds.isEmpty) return;

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    final selectedItems = _state.stitchingLineSchedules
        .where((item) => _state.selectedStitchingLineScheduleIds.contains(item.stitchingLineSchedule.id))
        .toList();
    final List<Future<PlexApiResult>> updateFutures = [];

    for (final item in selectedItems) {
      final updatedModel = item.stitchingLineSchedule.copyWith(
        lineCode: _state.selectedCostCenterLine!.name,
        line: _state.selectedCostCenterLine!.description,
      );
      updateFutures.add(_stitchingLineScheduleRepo.updateStitchingLineSchedule(item.stitchingLineSchedule.id, updatedModel.toJson()));
    }

    try {
      final results = await Future.wait(updateFutures);
      int successCount = 0;
      final List<String> errors = [];

      for (var i = 0; i < results.length; i++) {
        final res = results[i];
        if (res.success) {
          successCount++;
        } else {
          errors.add(res.message);
        }
      }

      if (successCount != results.length) {
        throw Exception(
          'Updated $successCount/${results.length} stitching lines. Errors: ${errors.join(", ")}'
        );
      }

      _state = _state.copyWith(isLoading: false);
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString().replaceFirst("Exception: ", ""));
      await fetchStitchingLineSchedules();
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}
