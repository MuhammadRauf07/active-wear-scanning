import 'package:active_wear_scanning/features/lapping/model/lapping_model.dart';
import 'package:active_wear_scanning/features/lapping/model/work_order_summary.dart';

class LappingState {
  final bool isLoading;
  final String? errorMessage;
  final List<LappingModel> trays;
  final List<LappingModel> rawActiveTrays;
  final Map<String, WorkOrderSummary> workOrders;
  final String? selectedWorkOrderId;
  final Map<String, List<LappingModel>> scannedTraysByWO;
  final Set<int> failedHandoverTrayIds;
  final Set<int> failedCloseLappingIds;
  final Map<String, double> trayOverrideQuantities;
  final Set<int> resetDraftProgressIds;
  final Map<String, double> itemWasteQuantities;
  final Map<String, int?> itemWasteProgressIds;
  final Map<String, int> trayBatchLineIds;
  final Set<int> resetBatchLineIds;

  const LappingState({
    this.isLoading = false,
    this.errorMessage,
    this.trays = const [],
    this.rawActiveTrays = const [],
    this.workOrders = const {},
    this.selectedWorkOrderId,
    this.scannedTraysByWO = const {},
    this.failedHandoverTrayIds = const {},
    this.failedCloseLappingIds = const {},
    this.trayOverrideQuantities = const {},
    this.resetDraftProgressIds = const {},
    this.itemWasteQuantities = const {},
    this.itemWasteProgressIds = const {},
    this.trayBatchLineIds = const {},
    this.resetBatchLineIds = const {},
  });

  LappingState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<LappingModel>? trays,
    List<LappingModel>? rawActiveTrays,
    Map<String, WorkOrderSummary>? workOrders,
    String? selectedWorkOrderId,
    Map<String, List<LappingModel>>? scannedTraysByWO,
    Set<int>? failedHandoverTrayIds,
    Set<int>? failedCloseLappingIds,
    Map<String, double>? trayOverrideQuantities,
    Set<int>? resetDraftProgressIds,
    Map<String, double>? itemWasteQuantities,
    Map<String, int?>? itemWasteProgressIds,
    Map<String, int>? trayBatchLineIds,
    Set<int>? resetBatchLineIds,
    bool clearSelectedWorkOrderId = false,
    bool clearError = false,
  }) {
    return LappingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      trays: trays ?? this.trays,
      rawActiveTrays: rawActiveTrays ?? this.rawActiveTrays,
      workOrders: workOrders ?? this.workOrders,
      selectedWorkOrderId: clearSelectedWorkOrderId ? null : (selectedWorkOrderId ?? this.selectedWorkOrderId),
      scannedTraysByWO: scannedTraysByWO ?? this.scannedTraysByWO,
      failedHandoverTrayIds: failedHandoverTrayIds ?? this.failedHandoverTrayIds,
      failedCloseLappingIds: failedCloseLappingIds ?? this.failedCloseLappingIds,
      trayOverrideQuantities: trayOverrideQuantities ?? this.trayOverrideQuantities,
      resetDraftProgressIds: resetDraftProgressIds ?? this.resetDraftProgressIds,
      itemWasteQuantities: itemWasteQuantities ?? this.itemWasteQuantities,
      itemWasteProgressIds: itemWasteProgressIds ?? this.itemWasteProgressIds,
      trayBatchLineIds: trayBatchLineIds ?? this.trayBatchLineIds,
      resetBatchLineIds: resetBatchLineIds ?? this.resetBatchLineIds,
    );
  }
}
