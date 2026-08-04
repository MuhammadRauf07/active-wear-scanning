import 'package:active_wear_scanning/features/carton_packing/model/carton_packing_scanned_item.dart';

class MdReceivingState {
  final bool isLoading;
  final String? errorMessage;
  final List<PackingInstructionResponseModel> scannedCartons;
  final Map<int, Map<String, dynamic>> productionProgressMap;

  const MdReceivingState({
    this.isLoading = false,
    this.errorMessage,
    this.scannedCartons = const [],
    this.productionProgressMap = const {},
  });

  MdReceivingState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<PackingInstructionResponseModel>? scannedCartons,
    Map<int, Map<String, dynamic>>? productionProgressMap,
    bool clearError = false,
  }) {
    return MdReceivingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      scannedCartons: scannedCartons ?? this.scannedCartons,
      productionProgressMap: productionProgressMap ?? this.productionProgressMap,
    );
  }
}
