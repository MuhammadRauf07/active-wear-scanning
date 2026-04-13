import 'package:active_wear_scanning/features/common-models/common_models.dart';

class ProductionProgressResponseModel {
  final ProductionProgress productionProgress;
  final Operation operation;
  final Shift shift;
  final MachineModel machineModel;
  final WorkOrderHeader workOrderHeader;
  final WorkOrderLine workOrderLine;
  final PrimaryTrayModel primaryTrayModel;
  final Item item;
  final PlanHeader planHeader;

  ProductionProgressResponseModel({
    required this.productionProgress,
    required this.operation,
    required this.shift,
    required this.machineModel,
    required this.workOrderHeader,
    required this.workOrderLine,
    required this.primaryTrayModel,
    required this.item,
    required this.planHeader,
  });

  factory ProductionProgressResponseModel.fromJson(Map<String, dynamic> json) {
    return ProductionProgressResponseModel(
      productionProgress: ProductionProgress.fromJson(json['productionProgress'] ?? {}),
      operation: Operation.fromJson(json['operation'] ?? {}),
      shift: Shift.fromJson(json['shift'] ?? {}),
      machineModel: MachineModel.fromJson(json['machine'] ?? {}),
      workOrderHeader: WorkOrderHeader.fromJson(json['workOrderHeader'] ?? {}),
      workOrderLine: WorkOrderLine.fromJson(json['workOrderLine'] ?? {}),
      item: Item.fromJson(json['item'] ?? {}),
      primaryTrayModel: PrimaryTrayModel.fromJson(json['primaryTray'] ?? {}),
      planHeader: PlanHeader.fromJson(json['planHeader'] ?? {}),
    );
  }
}
