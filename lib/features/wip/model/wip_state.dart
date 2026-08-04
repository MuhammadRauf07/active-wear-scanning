import 'package:active_wear_scanning/features/wip/model/wip_model.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class WipState {
  final bool isLoading;
  final String? errorMessage;
  final List<LocatorResponse> locators;
  final Map<int, List<ProductionProgressResponseModel>> locatorTrays;
  final Map<int, bool> loadingDetails;

  const WipState({
    this.isLoading = false,
    this.errorMessage,
    this.locators = const [],
    this.locatorTrays = const {},
    this.loadingDetails = const {},
  });

  WipState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<LocatorResponse>? locators,
    Map<int, List<ProductionProgressResponseModel>>? locatorTrays,
    Map<int, bool>? loadingDetails,
    bool clearError = false,
  }) {
    return WipState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      locators: locators ?? this.locators,
      locatorTrays: locatorTrays ?? this.locatorTrays,
      loadingDetails: loadingDetails ?? this.loadingDetails,
    );
  }
}
