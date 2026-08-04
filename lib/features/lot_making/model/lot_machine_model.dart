import 'package:active_wear_scanning/features/common-models/common_models.dart';

class LotMachineModel {
  final Resource? resource;
  final CostCenterLine? costCenterLine;
  final ResourceType? resourceType;

  LotMachineModel({
    this.resource,
    this.costCenterLine,
    this.resourceType,
  });

  factory LotMachineModel.fromJson(Map<String, dynamic> json) {
    return LotMachineModel(
      resource: json['resource'] != null ? Resource.fromJson(json['resource']) : null,
      costCenterLine: json['costCenterLine'] != null ? CostCenterLine.fromJson(json['costCenterLine']) : null,
      resourceType: json['resourceType'] != null ? ResourceType.fromJson(json['resourceType']) : null,
    );
  }
}
