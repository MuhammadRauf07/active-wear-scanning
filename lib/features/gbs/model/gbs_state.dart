import 'package:active_wear_scanning/features/gbs/model/gbs_scanned_tray.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';

class GbsState {
  final bool isLoading;
  final String? errorMessage;
  final String receivingType;
  final List<GBSScannedTray> scannedTrays;
  final List<ProductionProgressResponseModel> availableTrayForGbs;
  final Set<int> selectedProgressIds;
  final WorkOrderHeader? selectedWorkOrder;
  final Item? selectedItem;

  const GbsState({
    this.isLoading = false,
    this.errorMessage,
    this.receivingType = 'gbs',
    this.scannedTrays = const [],
    this.availableTrayForGbs = const [],
    this.selectedProgressIds = const {},
    this.selectedWorkOrder,
    this.selectedItem,
  });

  GbsState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? receivingType,
    List<GBSScannedTray>? scannedTrays,
    List<ProductionProgressResponseModel>? availableTrayForGbs,
    Set<int>? selectedProgressIds,
    WorkOrderHeader? selectedWorkOrder,
    Item? selectedItem,
    bool clearSelectedWorkOrder = false,
    bool clearSelectedItem = false,
    bool clearError = false,
  }) {
    return GbsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      receivingType: receivingType ?? this.receivingType,
      scannedTrays: scannedTrays ?? this.scannedTrays,
      availableTrayForGbs: availableTrayForGbs ?? this.availableTrayForGbs,
      selectedProgressIds: selectedProgressIds ?? this.selectedProgressIds,
      selectedWorkOrder: clearSelectedWorkOrder ? null : (selectedWorkOrder ?? this.selectedWorkOrder),
      selectedItem: clearSelectedItem ? null : (selectedItem ?? this.selectedItem),
    );
  }
}
