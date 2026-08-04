class ProcessingOperationModel {
  final String code;
  final String name;
  final String? description;
  final String? identifierRef;
  final String concurrencyStamp;
  final String creationTime;
  final String? lastModificationTime;
  final String? creatorId;
  final String? lastModifierId;
  final bool? isLastProcess;
  final int? processNature;
  final int id;

  ProcessingOperationModel({
    required this.code,
    required this.name,
    required this.description,
    required this.identifierRef,
    required this.concurrencyStamp,
    required this.creationTime,
    required this.lastModificationTime,
    required this.creatorId,
    required this.lastModifierId,
    this.isLastProcess,
    this.processNature,
    required this.id,
  });

  factory ProcessingOperationModel.fromJson(Map<String, dynamic> json) {
    return ProcessingOperationModel(
      code: json['code'],
      name: json['name'],
      description: json['description'],
      identifierRef: json['identifierRef'],
      concurrencyStamp: json['concurrencyStamp'],
      creationTime: json['creationTime'],
      lastModificationTime: json['lastModificationTime'],
      creatorId: json['creatorId'],
      lastModifierId: json['lastModifierId'],
      isLastProcess: json['isLastProcess'],
      processNature: json['processNature'],
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }
}
