import 'package:active_wear_scanning/features/gbs/model/gbs_scanned_tray.dart';
import 'package:active_wear_scanning/features/induction/model/induction_model.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';

class InductionState {
  final bool isLoading;
  final String? errorMessage;
  final List<GBSScannedTray> scannedTrays;
  final List<InductionModel> availableTrays;
  final LotHeaderModel? selectedBatch;

  const InductionState({
    this.isLoading = false,
    this.errorMessage,
    this.scannedTrays = const [],
    this.availableTrays = const [],
    this.selectedBatch,
  });

  InductionState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<GBSScannedTray>? scannedTrays,
    List<InductionModel>? availableTrays,
    LotHeaderModel? selectedBatch,
    bool clearSelectedBatch = false,
    bool clearError = false,
  }) {
    return InductionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      scannedTrays: scannedTrays ?? this.scannedTrays,
      availableTrays: availableTrays ?? this.availableTrays,
      selectedBatch: clearSelectedBatch ? null : (selectedBatch ?? this.selectedBatch),
    );
  }
}
