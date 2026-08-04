import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';

class InductionModel extends ProductionProgressResponseModel {
  InductionModel({
    required super.productionProgress,
    required super.operation,
    required super.item,
    super.processedItem,
    required super.machineModel,
    required super.primaryTrayModel,
    required super.shift,
    required super.workOrderHeader,
    required super.workOrderLine,
    super.planHeader,
    super.batchHeader,
  });

  factory InductionModel.fromJson(Map<String, dynamic> json) {
    final base = ProductionProgressResponseModel.fromJson(json);
    return InductionModel(
      productionProgress: base.productionProgress,
      operation: base.operation,
      item: base.item,
      processedItem: base.processedItem,
      machineModel: base.machineModel,
      primaryTrayModel: base.primaryTrayModel,
      shift: base.shift,
      workOrderHeader: base.workOrderHeader,
      workOrderLine: base.workOrderLine,
      planHeader: base.planHeader,
      batchHeader: base.batchHeader,
    );
  }

  @override
  InductionModel copyWith({
    ProductionProgress? productionProgress,
    Operation? operation,
    Shift? shift,
    MachineModel? machineModel,
    WorkOrderHeader? workOrderHeader,
    WorkOrderLine? workOrderLine,
    PrimaryTrayModel? primaryTrayModel,
    Item? item,
    Item? processedItem,
    PlanHeader? planHeader,
    LotHeaderModel? batchHeader,
  }) {
    return InductionModel(
      productionProgress: productionProgress ?? this.productionProgress,
      operation: operation ?? this.operation,
      shift: shift ?? this.shift,
      machineModel: machineModel ?? this.machineModel,
      workOrderHeader: workOrderHeader ?? this.workOrderHeader,
      workOrderLine: workOrderLine ?? this.workOrderLine,
      primaryTrayModel: primaryTrayModel ?? this.primaryTrayModel,
      item: item ?? this.item,
      processedItem: processedItem ?? this.processedItem,
      planHeader: planHeader ?? this.planHeader,
      batchHeader: batchHeader ?? this.batchHeader,
    );
  }
}
