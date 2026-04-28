import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

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
}
