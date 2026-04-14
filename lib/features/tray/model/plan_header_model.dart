import 'package:active_wear_scanning/features/common-models/common_models.dart';

class PlanLineResponseModel {
  final PlanLine planLine;
  final Operation operation;
  final Shift shift;
  final Resource resource;
  final WorkOrderHeader workOrderHeader;
  final WorkOrderLine workOrderLine;
  final Item item;
  final CostCenterLine costCenterLine;
  final PlanHeader? planHeader;

  PlanLineResponseModel({
    required this.planLine,
    required this.operation,
    required this.shift,
    required this.resource,
    required this.workOrderHeader,
    required this.workOrderLine,
    required this.item,
    required this.costCenterLine,
    this.planHeader,
  });

  factory PlanLineResponseModel.fromJson(Map<String, dynamic> json) {
    return PlanLineResponseModel(
      planLine: PlanLine.fromJson(json['planLine']),
      operation: Operation.fromJson(json['operation']),
      shift: Shift.fromJson(json['shift']),
      resource: Resource.fromJson(json['resource']),
      workOrderHeader: WorkOrderHeader.fromJson(json['workOrderHeader']),
      workOrderLine: WorkOrderLine.fromJson(json['workOrderLine']),
      item: Item.fromJson(json['item']),
      costCenterLine: CostCenterLine.fromJson(json['costCenterLine']),
      planHeader: json['planHeader'] != null ? PlanHeader.fromJson(json['planHeader']) : null,
    );
  }
}

