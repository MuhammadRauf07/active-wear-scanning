import 'package:active_wear_scanning/features/carton_packing/model/carton_packing_scanned_item.dart';

class CartonPackingState {
  final bool isLoading;
  final String? errorMessage;
  final List<PackingInstructionResponseModel> scannedCartons;
  final List<PackingInstructionHeader> activeCartonGroups;
  final Map<int, List<PackingInstructionLineResponse>> groupLinesCache;
  final int? expandedGroupId;
  final Set<int> packedCartonDetailIds;
  final Map<int, List<int>> groupDetailIdsCache;
  final int? activeSaleOrderId;
  final SaleOrderModel? activeSaleOrder;
  final String? activeCustomerName;

  const CartonPackingState({
    this.isLoading = false,
    this.errorMessage,
    this.scannedCartons = const [],
    this.activeCartonGroups = const [],
    this.groupLinesCache = const {},
    this.expandedGroupId,
    this.packedCartonDetailIds = const {},
    this.groupDetailIdsCache = const {},
    this.activeSaleOrderId,
    this.activeSaleOrder,
    this.activeCustomerName,
  });

  CartonPackingState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<PackingInstructionResponseModel>? scannedCartons,
    List<PackingInstructionHeader>? activeCartonGroups,
    Map<int, List<PackingInstructionLineResponse>>? groupLinesCache,
    int? expandedGroupId,
    Set<int>? packedCartonDetailIds,
    Map<int, List<int>>? groupDetailIdsCache,
    int? activeSaleOrderId,
    SaleOrderModel? activeSaleOrder,
    String? activeCustomerName,
    bool clearActiveSaleOrder = false,
    bool clearExpandedGroupId = false,
    bool clearError = false,
  }) {
    return CartonPackingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      scannedCartons: scannedCartons ?? this.scannedCartons,
      activeCartonGroups: activeCartonGroups ?? this.activeCartonGroups,
      groupLinesCache: groupLinesCache ?? this.groupLinesCache,
      expandedGroupId: clearExpandedGroupId ? null : (expandedGroupId ?? this.expandedGroupId),
      packedCartonDetailIds: packedCartonDetailIds ?? this.packedCartonDetailIds,
      groupDetailIdsCache: groupDetailIdsCache ?? this.groupDetailIdsCache,
      activeSaleOrderId: clearActiveSaleOrder ? null : (activeSaleOrderId ?? this.activeSaleOrderId),
      activeSaleOrder: clearActiveSaleOrder ? null : (activeSaleOrder ?? this.activeSaleOrder),
      activeCustomerName: clearActiveSaleOrder ? null : (activeCustomerName ?? this.activeCustomerName),
    );
  }
}
