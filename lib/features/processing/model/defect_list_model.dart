class DefectListModel {
  final int id;
  final String? code;
  final String? description;
  final int? defectNature;
  final int? defectMappingId;
  final int? defectTypeId;
  final int? customerId;
  final String? concurrencyStamp;
  final String? creationTime;
  final String? creatorId;

  DefectListModel({
    required this.id,
    this.code,
    this.description,
    this.defectNature,
    this.defectMappingId,
    this.defectTypeId,
    this.customerId,
    this.concurrencyStamp,
    this.creationTime,
    this.creatorId,
  });

  factory DefectListModel.fromJson(Map<String, dynamic> json) {
    return DefectListModel(
      id: json['id'] as int? ?? (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      code: json['code'] as String?,
      description: json['description'] as String?,
      defectNature: json['defectNature'] as int?,
      defectMappingId: json['defectMappingId'] as int?,
      defectTypeId: json['defectTypeId'] as int?,
      customerId: json['customerId'] as int?,
      concurrencyStamp: json['concurrencyStamp'] as String?,
      creationTime: json['creationTime'] as String?,
      creatorId: json['creatorId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'description': description,
    'defectNature': defectNature,
    'defectMappingId': defectMappingId,
    'defectTypeId': defectTypeId,
    'customerId': customerId,
    'concurrencyStamp': concurrencyStamp,
    'creationTime': creationTime,
    'creatorId': creatorId,
  };
}

class DefectTypeModel {
  final int id;
  final String? name;
  final String? code;
  final String? description;
  final int? defectTypeMappingId;
  final int? defectCategoryId;

  DefectTypeModel({
    required this.id,
    this.name,
    this.code,
    this.description,
    this.defectTypeMappingId,
    this.defectCategoryId,
  });

  factory DefectTypeModel.fromJson(Map<String, dynamic> json) {
    return DefectTypeModel(
      id: json['id'] as int? ?? (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      defectTypeMappingId: json['defectTypeMappingId'] as int?,
      defectCategoryId: json['defectCategoryId'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'description': description,
    'defectTypeMappingId': defectTypeMappingId,
    'defectCategoryId': defectCategoryId,
  };
}

class DefectListItemModel {
  final DefectListModel defectList;
  final DefectTypeModel? defectType;

  DefectListItemModel({
    required this.defectList,
    this.defectType,
  });

  factory DefectListItemModel.fromJson(Map<String, dynamic> json) {
    return DefectListItemModel(
      defectList: json['defectList'] != null
          ? DefectListModel.fromJson(Map<String, dynamic>.from(json['defectList'] as Map))
          : DefectListModel.fromJson(json),
      defectType: json['defectType'] != null
          ? DefectTypeModel.fromJson(Map<String, dynamic>.from(json['defectType'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'defectList': defectList.toJson(),
    if (defectType != null) 'defectType': defectType!.toJson(),
  };
}
