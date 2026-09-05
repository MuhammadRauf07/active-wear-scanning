import 'package:active_wear_scanning/features/wip/model/wip_model.dart';

class WipState {
  final bool isLoading;
  final String? errorMessage;
  final List<WipOperationModel> operations;
  final Map<int, List<WipBatchModel>> operationBatches;
  final Map<int, bool> loadingDetails;
  final Set<int> expandedOperationIds;
  final Set<int> expandedBatchIds;

  const WipState({
    this.isLoading = false,
    this.errorMessage,
    this.operations = const [],
    this.operationBatches = const {},
    this.loadingDetails = const {},
    this.expandedOperationIds = const {},
    this.expandedBatchIds = const {},
  });

  WipState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<WipOperationModel>? operations,
    Map<int, List<WipBatchModel>>? operationBatches,
    Map<int, bool>? loadingDetails,
    Set<int>? expandedOperationIds,
    Set<int>? expandedBatchIds,
    bool clearError = false,
  }) {
    return WipState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      operations: operations ?? this.operations,
      operationBatches: operationBatches ?? this.operationBatches,
      loadingDetails: loadingDetails ?? this.loadingDetails,
      expandedOperationIds: expandedOperationIds ?? this.expandedOperationIds,
      expandedBatchIds: expandedBatchIds ?? this.expandedBatchIds,
    );
  }
}
