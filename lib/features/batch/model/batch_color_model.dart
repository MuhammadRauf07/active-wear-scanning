class BatchColorModel {
  final SegmentCode? segmentCode;
  final SegmentType? segmentType;

  BatchColorModel({this.segmentCode, this.segmentType});

  factory BatchColorModel.fromJson(Map<String, dynamic> json) {
    return BatchColorModel(
      segmentCode: json['segmentCode'] != null ? SegmentCode.fromJson(json['segmentCode']) : null,
      segmentType: json['segmentType'] != null ? SegmentType.fromJson(json['segmentType']) : null,
    );
  }
}

class SegmentCode {
  final int? id;
  final String? code;
  final String? description;
  final String? identifierRef;

  SegmentCode({this.id, this.code, this.description, this.identifierRef});

  factory SegmentCode.fromJson(Map<String, dynamic> json) {
    return SegmentCode(
      id: json['id'],
      code: json['code'],
      description: json['description'],
      identifierRef: json['identifierRef'],
    );
  }
}

class SegmentType {
  final int? id;
  final String? code;
  final String? description;

  SegmentType({this.id, this.code, this.description});

  factory SegmentType.fromJson(Map<String, dynamic> json) {
    return SegmentType(
      id: json['id'],
      code: json['code'],
      description: json['description'],
    );
  }
}
