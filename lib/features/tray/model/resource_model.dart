import 'package:active_wear_scanning/features/common-models/common_models.dart';

class ResourceResponseModel {
  final Resource resource;
  final CostCenterLine costCenterLine;
  final ResourceType resourceType;

  ResourceResponseModel({required this.resource, required this.costCenterLine, required this.resourceType});

  factory ResourceResponseModel.fromJson(Map<String, dynamic> json) {
    return ResourceResponseModel(
      resource: Resource.fromJson(json['resource'] as Map<String, dynamic>),
      costCenterLine: CostCenterLine.fromJson(json['costCenterLine'] as Map<String, dynamic>),
      resourceType: ResourceType.fromJson(json['resourceType'] as Map<String, dynamic>),
    );
  }
}


