import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class ProcessingWasteState {
  final bool isLoading;
  final String? errorMessage;
  final List<ProductionProgressResponseModel> scannedTrays;
  final Map<int, Map<String, dynamic>> productionProgressMap;

  const ProcessingWasteState({
    this.isLoading = false,
    this.errorMessage,
    this.scannedTrays = const [],
    this.productionProgressMap = const {},
  });

  ProcessingWasteState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<ProductionProgressResponseModel>? scannedTrays,
    Map<int, Map<String, dynamic>>? productionProgressMap,
    bool clearError = false,
  }) {
    return ProcessingWasteState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      scannedTrays: scannedTrays ?? this.scannedTrays,
      productionProgressMap: productionProgressMap ?? this.productionProgressMap,
    );
  }
}
