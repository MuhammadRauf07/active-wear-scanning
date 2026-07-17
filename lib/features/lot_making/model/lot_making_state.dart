import 'package:active_wear_scanning/features/lot_making/model/lot_color_model.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_machine_model.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';

class LotMakingState {
  final bool isLoading;
  final String? errorMessage;
  final List<LotMachineModel> machines;
  final LotMachineModel? selectedMachine;
  final List<LotColorModel> colors;
  final LotColorModel? selectedColor;
  final bool isLoadingColors;
  final WorkOrderHeader? selectedWorkOrder;
  final ProductionProgressResponseModel? selectedTray;
  final Map<int, Set<String>> workOrderValidColors;
  final bool isCachingColors;
  final Map<String, double> colorPlanQuantities;
  final List<ProductionProgressResponseModel> scannedTrays;
  final List<ProductionProgressResponseModel> productionProgressTrays;
  final Set<int> lotProgressIds;
  final Set<int> currentBatchDatabaseProgressIds;
  final Map<int, int> trayProcessedItemId;
  final Set<String>? referenceRoutingCodes;
  final int? referenceRoutingCount;
  final int? referenceMinOperationId;
  final String lotCode;

  const LotMakingState({
    this.isLoading = false,
    this.errorMessage,
    this.machines = const [],
    this.selectedMachine,
    this.colors = const [],
    this.selectedColor,
    this.isLoadingColors = false,
    this.selectedWorkOrder,
    this.selectedTray,
    this.workOrderValidColors = const {},
    this.isCachingColors = false,
    this.colorPlanQuantities = const {},
    this.scannedTrays = const [],
    this.productionProgressTrays = const [],
    this.lotProgressIds = const {},
    this.currentBatchDatabaseProgressIds = const {},
    this.trayProcessedItemId = const {},
    this.referenceRoutingCodes,
    this.referenceRoutingCount,
    this.referenceMinOperationId,
    this.lotCode = '',
  });

  LotMakingState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<LotMachineModel>? machines,
    LotMachineModel? selectedMachine,
    List<LotColorModel>? colors,
    LotColorModel? selectedColor,
    bool? isLoadingColors,
    WorkOrderHeader? selectedWorkOrder,
    ProductionProgressResponseModel? selectedTray,
    Map<int, Set<String>>? workOrderValidColors,
    bool? isCachingColors,
    Map<String, double>? colorPlanQuantities,
    List<ProductionProgressResponseModel>? scannedTrays,
    List<ProductionProgressResponseModel>? productionProgressTrays,
    Set<int>? lotProgressIds,
    Set<int>? currentBatchDatabaseProgressIds,
    Map<int, int>? trayProcessedItemId,
    Set<String>? referenceRoutingCodes,
    int? referenceRoutingCount,
    int? referenceMinOperationId,
    String? lotCode,
    bool clearSelectedMachine = false,
    bool clearSelectedColor = false,
    bool clearSelectedWorkOrder = false,
    bool clearSelectedTray = false,
    bool clearReferenceRouting = false,
    bool clearError = false,
  }) {
    return LotMakingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      machines: machines ?? this.machines,
      selectedMachine: clearSelectedMachine ? null : (selectedMachine ?? this.selectedMachine),
      colors: colors ?? this.colors,
      selectedColor: clearSelectedColor ? null : (selectedColor ?? this.selectedColor),
      isLoadingColors: isLoadingColors ?? this.isLoadingColors,
      selectedWorkOrder: clearSelectedWorkOrder ? null : (selectedWorkOrder ?? this.selectedWorkOrder),
      selectedTray: clearSelectedTray ? null : (selectedTray ?? this.selectedTray),
      workOrderValidColors: workOrderValidColors ?? this.workOrderValidColors,
      isCachingColors: isCachingColors ?? this.isCachingColors,
      colorPlanQuantities: colorPlanQuantities ?? this.colorPlanQuantities,
      scannedTrays: scannedTrays ?? this.scannedTrays,
      productionProgressTrays: productionProgressTrays ?? this.productionProgressTrays,
      lotProgressIds: lotProgressIds ?? this.lotProgressIds,
      currentBatchDatabaseProgressIds: currentBatchDatabaseProgressIds ?? this.currentBatchDatabaseProgressIds,
      trayProcessedItemId: trayProcessedItemId ?? this.trayProcessedItemId,
      referenceRoutingCodes: clearReferenceRouting ? null : (referenceRoutingCodes ?? this.referenceRoutingCodes),
      referenceRoutingCount: clearReferenceRouting ? null : (referenceRoutingCount ?? this.referenceRoutingCount),
      referenceMinOperationId: clearReferenceRouting ? null : (referenceMinOperationId ?? this.referenceMinOperationId),
      lotCode: lotCode ?? this.lotCode,
    );
  }
}
