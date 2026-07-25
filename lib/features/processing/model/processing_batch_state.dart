import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class ProcessingBatchState {
  final bool isLoading;
  final String? errorMessage;
  final List<ProductionProgressResponseModel> trays;
  final Set<int> trayIdsWithWastage;
  final Map<int, ProductionProgressResponseModel> wastageByOriginalId;
  final bool isBatchStarted;
  final DateTime? issueTime;
  final DateTime? startTime;
  final String? trolleyCode;
  final int? trolleyDetailId;
  final bool isUpdatingTrolley;
  final bool isReassignedFromLines;
  final bool isReworkMode;
  final Set<int> selectedReworkTrayIds;
  final int? reworkTargetOpId;
  final String? reworkTargetOpName;
  final double? machineCapacity;
  final bool showTrays;
  final Set<int> failedTrayIds;

  const ProcessingBatchState({
    this.isLoading = false,
    this.errorMessage,
    this.trays = const [],
    this.trayIdsWithWastage = const {},
    this.wastageByOriginalId = const {},
    this.isBatchStarted = false,
    this.issueTime,
    this.startTime,
    this.trolleyCode,
    this.trolleyDetailId,
    this.isUpdatingTrolley = false,
    this.isReassignedFromLines = false,
    this.isReworkMode = false,
    this.selectedReworkTrayIds = const {},
    this.reworkTargetOpId,
    this.reworkTargetOpName,
    this.machineCapacity,
    this.showTrays = false,
    this.failedTrayIds = const {},
  });

  bool get isDraftBatch {
    return trays.isNotEmpty && trays.any((t) => t.productionProgress.draftFlag == true);
  }

  bool get isReassignedBatch {
    if (isDraftBatch) return false;
    final fromTray = trays.isNotEmpty && trays.any((t) => t.primaryTrayModel.isReAssigned == true);
    return isReassignedFromLines || fromTray;
  }

  bool get isReworkBatch {
    return trays.isNotEmpty && trays.any((t) => t.productionProgress.reworkFlag == true);
  }

  ProcessingBatchState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<ProductionProgressResponseModel>? trays,
    Set<int>? trayIdsWithWastage,
    Map<int, ProductionProgressResponseModel>? wastageByOriginalId,
    bool? isBatchStarted,
    DateTime? issueTime,
    DateTime? startTime,
    String? trolleyCode,
    int? trolleyDetailId,
    bool? isUpdatingTrolley,
    bool? isReassignedFromLines,
    bool? isReworkMode,
    Set<int>? selectedReworkTrayIds,
    int? reworkTargetOpId,
    String? reworkTargetOpName,
    double? machineCapacity,
    bool? showTrays,
    Set<int>? failedTrayIds,
    bool clearError = false,
  }) {
    return ProcessingBatchState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      trays: trays ?? this.trays,
      trayIdsWithWastage: trayIdsWithWastage ?? this.trayIdsWithWastage,
      wastageByOriginalId: wastageByOriginalId ?? this.wastageByOriginalId,
      isBatchStarted: isBatchStarted ?? this.isBatchStarted,
      issueTime: issueTime ?? this.issueTime,
      startTime: startTime ?? this.startTime,
      trolleyCode: trolleyCode ?? this.trolleyCode,
      trolleyDetailId: trolleyDetailId ?? this.trolleyDetailId,
      isUpdatingTrolley: isUpdatingTrolley ?? this.isUpdatingTrolley,
      isReassignedFromLines: isReassignedFromLines ?? this.isReassignedFromLines,
      isReworkMode: isReworkMode ?? this.isReworkMode,
      selectedReworkTrayIds: selectedReworkTrayIds ?? this.selectedReworkTrayIds,
      reworkTargetOpId: reworkTargetOpId ?? this.reworkTargetOpId,
      reworkTargetOpName: reworkTargetOpName ?? this.reworkTargetOpName,
      machineCapacity: machineCapacity ?? this.machineCapacity,
      showTrays: showTrays ?? this.showTrays,
      failedTrayIds: failedTrayIds ?? this.failedTrayIds,
    );
  }
}
