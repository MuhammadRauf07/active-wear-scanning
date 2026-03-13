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

class Resource {
  final String? location;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final DateTime? installationDate;
  final double? capacity;
  final String? status;
  final bool isActive;
  final String? resourceCode;
  final int costCenterLineId;
  final int resourceTypeId;
  final String concurrencyStamp;
  final int id;

  Resource({
    required this.location,
    required this.brand,
    required this.model,
    required this.serialNumber,
    required this.installationDate,
    required this.capacity,
    required this.status,
    required this.isActive,
    required this.resourceCode,
    required this.costCenterLineId,
    required this.resourceTypeId,
    required this.concurrencyStamp,
    required this.id,
  });

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      location: json['location'] as String?,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serialNumber'] as String?,
      installationDate: json['installationDate'] != null ? DateTime.parse(json['installationDate'] as String) : null,
      capacity: json['capacity'] != null ? (json['capacity'] as num).toDouble() : null,
      status: json['status'] as String?,
      isActive: json['isActive'] as bool,
      resourceCode: json['resourceCode'] as String?,
      costCenterLineId: json['costCenterLineId'] as int,
      resourceTypeId: json['resourceTypeId'] as int,
      concurrencyStamp: json['concurrencyStamp'] as String,
      id: json['id'] as int,
    );
  }
}

class CostCenterLine {
  final String code;
  final String name;
  final String? description;
  final int costCenterId;
  final String concurrencyStamp;
  final DateTime creationTime;
  final DateTime? lastModificationTime;
  final String? creatorId;
  final String? lastModifierId;
  final int id;

  CostCenterLine({
    required this.code,
    required this.name,
    required this.description,
    required this.costCenterId,
    required this.concurrencyStamp,
    required this.creationTime,
    required this.lastModificationTime,
    required this.creatorId,
    required this.lastModifierId,
    required this.id,
  });

  factory CostCenterLine.fromJson(Map<String, dynamic> json) {
    return CostCenterLine(
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      costCenterId: json['costCenterId'] as int,
      concurrencyStamp: json['concurrencyStamp'] as String,
      creationTime: DateTime.parse(json['creationTime'] as String),
      lastModificationTime: json['lastModificationTime'] != null ? DateTime.parse(json['lastModificationTime'] as String) : null,
      creatorId: json['creatorId'] as String?,
      lastModifierId: json['lastModifierId'] as String?,
      id: json['id'] as int,
    );
  }
}

class ResourceType {
  final String code;
  final String name;
  final String? description;
  final int costCenterLineId;
  final String concurrencyStamp;
  final int id;

  ResourceType({required this.code, required this.name, required this.description, required this.costCenterLineId, required this.concurrencyStamp, required this.id});

  factory ResourceType.fromJson(Map<String, dynamic> json) {
    return ResourceType(
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      costCenterLineId: json['costCenterLineId'] as int,
      concurrencyStamp: json['concurrencyStamp'] as String,
      id: json['id'] as int,
    );
  }
}
