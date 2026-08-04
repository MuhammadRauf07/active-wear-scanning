import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class UnholdTraysState {
  final bool isLoading;
  final String? errorMessage;
  final String selectedOrigin; // 'knitting' or 'pbs'
  final List<ProductionProgressResponseModel> heldTrays;
  final List<ProductionProgressResponseModel> scannedTrays;

  const UnholdTraysState({
    this.isLoading = false,
    this.errorMessage,
    this.selectedOrigin = 'knitting',
    this.heldTrays = const [],
    this.scannedTrays = const [],
  });

  UnholdTraysState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? selectedOrigin,
    List<ProductionProgressResponseModel>? heldTrays,
    List<ProductionProgressResponseModel>? scannedTrays,
    bool clearError = false,
  }) {
    return UnholdTraysState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedOrigin: selectedOrigin ?? this.selectedOrigin,
      heldTrays: heldTrays ?? this.heldTrays,
      scannedTrays: scannedTrays ?? this.scannedTrays,
    );
  }
}
