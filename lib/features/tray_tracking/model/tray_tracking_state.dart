import 'package:active_wear_scanning/features/common-models/common_models.dart';

class TrayTrackingState {
  final bool isLoading;
  final String? errorMessage;
  final TrayDetail? trayDetail;
  final String? batchCode;
  final String? color;
  final String? locatorName;
  final String? machineName;
  final String? itemDescription;
  final String? workOrderDescription;

  const TrayTrackingState({
    this.isLoading = false,
    this.errorMessage,
    this.trayDetail,
    this.batchCode,
    this.color,
    this.locatorName,
    this.machineName,
    this.itemDescription,
    this.workOrderDescription,
  });

  TrayTrackingState copyWith({
    bool? isLoading,
    String? errorMessage,
    TrayDetail? trayDetail,
    String? batchCode,
    String? color,
    String? locatorName,
    String? machineName,
    String? itemDescription,
    String? workOrderDescription,
    bool clearData = false,
    bool clearError = false,
  }) {
    if (clearData) {
      return TrayTrackingState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        trayDetail: null,
        batchCode: null,
        color: null,
        locatorName: null,
        machineName: null,
        itemDescription: null,
        workOrderDescription: null,
      );
    }
    return TrayTrackingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      trayDetail: trayDetail ?? this.trayDetail,
      batchCode: batchCode ?? this.batchCode,
      color: color ?? this.color,
      locatorName: locatorName ?? this.locatorName,
      machineName: machineName ?? this.machineName,
      itemDescription: itemDescription ?? this.itemDescription,
      workOrderDescription: workOrderDescription ?? this.workOrderDescription,
    );
  }
}
