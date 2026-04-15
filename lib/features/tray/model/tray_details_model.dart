import 'package:active_wear_scanning/features/common-models/common_models.dart';

class TrayDetailsModel {
  final PlanLine? planLine;
  final TrayDetail? trayDetails;
  final Operation? operation;
  final Shift? shift;
  final Resource? resource;
  final WorkOrderHeader? workOrderHeader;
  final WorkOrderLine? workOrderLine;
  final Item? item;
  final CostCenterLine? costCenterLine;
  final PlanHeader? planHeader;
  final Locator? locator;

  TrayDetailsModel({
    this.planLine,
    this.trayDetails,
    this.operation,
    this.shift,
    this.resource,
    this.workOrderHeader,
    this.workOrderLine,
    this.item,
    this.costCenterLine,
    this.planHeader,
    this.locator,
  });

  factory TrayDetailsModel.fromJson(Map<String, dynamic> json) {
    return TrayDetailsModel(
      planLine: json['planLine'] != null ? PlanLine.fromJson(json['planLine']) : null,
      trayDetails: json['trayDetail'] != null 
          ? TrayDetail.fromJson(json['trayDetail']) 
          : (json['trayCode'] != null ? TrayDetail.fromJson(json) : null),
      operation: json['operation'] != null ? Operation.fromJson(json['operation']) : null,
      shift: json['shift'] != null ? Shift.fromJson(json['shift']) : null,
      locator: json['locator'] != null ? Locator.fromJson(json['locator']) : null,
      resource: json['resource'] != null ? Resource.fromJson(json['resource']) : null,
      workOrderHeader: json['workOrderHeader'] != null ? WorkOrderHeader.fromJson(json['workOrderHeader']) : null,
      workOrderLine: json['workOrderLine'] != null ? WorkOrderLine.fromJson(json['workOrderLine']) : null,
      item: json['item'] != null ? Item.fromJson(json['item']) : null,
      costCenterLine: json['costCenterLine'] != null ? CostCenterLine.fromJson(json['costCenterLine']) : null,
      planHeader: json['planHeader'] != null ? PlanHeader.fromJson(json['planHeader']) : null,
    );
  }
}

