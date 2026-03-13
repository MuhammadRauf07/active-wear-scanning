import 'package:active_wear_scanning/features/tray/model/plan_header_model.dart';

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
      trayDetails: json['trayDetail'] != null ? TrayDetail.fromJson(json['trayDetail']) : null,
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

class TrayDetail {
  final String? description;
  final bool? active;
  final String? trayCode;
  final int? trayQuantity;
  final int? productGrade;
  final int? productNature;
  final int? trayType;
  final int? shiftId;
  final int? planLineId;
  final int? resourceId;
  final int? workOrderHeaderId;
  final int? workOrderLineId;
  final int? knitItemId;
  final int? locatorId;
  final int? batchHeaderId;
  final int? batchLinesId;
  final String? concurrencyStamp;
  final DateTime? lastModificationTime;
  final String? lastModifierId;
  final DateTime? creationTime;
  final String? creatorId;
  final int? id;

  TrayDetail({
    this.description,
    this.active,
    this.trayCode,
    this.trayQuantity,
    this.productGrade,
    this.productNature,
    this.trayType,
    this.shiftId,
    this.planLineId,
    this.resourceId,
    this.workOrderHeaderId,
    this.workOrderLineId,
    this.knitItemId,
    this.locatorId,
    this.batchHeaderId,
    this.batchLinesId,
    this.concurrencyStamp,
    this.lastModificationTime,
    this.lastModifierId,
    this.creationTime,
    this.creatorId,
    this.id,
  });

  factory TrayDetail.fromJson(Map<String, dynamic> json) {
    return TrayDetail(
      description: json['description'],
      active: json['active'],
      trayCode: json['trayCode'],
      trayQuantity: json['trayQuantity'],
      productGrade: json['productGrade'],
      productNature: json['productNature'],
      trayType: json['trayType'],
      shiftId: json['shiftId'],
      planLineId: json['planLineId'],
      resourceId: json['resourceId'],
      workOrderHeaderId: json['workOrderHeaderId'],
      workOrderLineId: json['workOrderLineId'],
      knitItemId: json['knitItemId'],
      locatorId: json['locatorId'],
      batchHeaderId: json['batchHeaderId'],
      batchLinesId: json['batchLinesId'],
      concurrencyStamp: json['concurrencyStamp'],
      lastModificationTime: json['lastModificationTime'] != null ? DateTime.parse(json['lastModificationTime']) : null,
      lastModifierId: json['lastModifierId'],
      creationTime: json['creationTime'] != null ? DateTime.parse(json['creationTime']) : null,
      creatorId: json['creatorId'],
      id: json['id'],
    );
  }
}

class Locator {
  final String? description;
  final String? logicalWH;
  final String? location;
  final bool? active;
  final String? locatorCode;
  final int? departmentId;
  final String? concurrencyStamp;
  final DateTime? lastModificationTime;
  final String? lastModifierId;
  final DateTime? creationTime;
  final String? creatorId;
  final int? id;

  Locator({
    this.description,
    this.logicalWH,
    this.location,
    this.active,
    this.locatorCode,
    this.departmentId,
    this.concurrencyStamp,
    this.lastModificationTime,
    this.lastModifierId,
    this.creationTime,
    this.creatorId,
    this.id,
  });

  factory Locator.fromJson(Map<String, dynamic> json) {
    return Locator(
      id: json['id'],
      creatorId: json['creatorId'],
      description: json['description'],
      logicalWH: json['logicalWH'],
      location: json['location'],
      active: json['active'],
      locatorCode: json['locatorCode'],
      departmentId: json['departmentId'],
      lastModifierId: json['lastModifierId'],
      concurrencyStamp: json['concurrencyStamp'],
      creationTime: json['creationTime'] != null ? DateTime.parse(json['creationTime']) : null,
      lastModificationTime: json['lastModificationTime'] != null ? DateTime.parse(json['lastModificationTime']) : null,
    );
  }
}
