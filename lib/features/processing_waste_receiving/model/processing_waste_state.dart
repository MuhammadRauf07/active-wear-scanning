import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class ProcessingWasteState {
  final bool isLoading;
  final String? errorMessage;
  final List<ProductionProgressResponseModel> scannedTrays;
  final List<ProductionProgressResponseModel> availableWasteTrays;
  final List<Operation> operations;
  final int? selectedOperationId;
  final Map<int, Map<String, dynamic>> productionProgressMap;

  const ProcessingWasteState({
    this.isLoading = false,
    this.errorMessage,
    this.scannedTrays = const [],
    this.availableWasteTrays = const [],
    this.operations = const [],
    this.selectedOperationId,
    this.productionProgressMap = const {},
  });

  ProcessingWasteState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<ProductionProgressResponseModel>? scannedTrays,
    List<ProductionProgressResponseModel>? availableWasteTrays,
    List<Operation>? operations,
    int? selectedOperationId,
    bool clearSelectedOperation = false,
    Map<int, Map<String, dynamic>>? productionProgressMap,
    bool clearError = false,
  }) {
    return ProcessingWasteState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      scannedTrays: scannedTrays ?? this.scannedTrays,
      availableWasteTrays: availableWasteTrays ?? this.availableWasteTrays,
      operations: operations ?? this.operations,
      selectedOperationId: clearSelectedOperation ? null : (selectedOperationId ?? this.selectedOperationId),
      productionProgressMap: productionProgressMap ?? this.productionProgressMap,
    );
  }
}
