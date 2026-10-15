class LotColorModel {
  final SegmentCode? segmentCode;
  final SegmentType? segmentType;

  LotColorModel({this.segmentCode, this.segmentType});

  factory LotColorModel.fromJson(Map<String, dynamic> json) {
    SegmentCode? code;
    if (json['segmentCode'] is Map) {
      code = SegmentCode.fromJson(Map<String, dynamic>.from(json['segmentCode']));
    } else if (json['id'] != null || json['code'] != null || json['description'] != null || json['name'] != null || json['colorDescription'] != null) {
      code = SegmentCode.fromJson(json);
    }

    SegmentType? type;
    if (json['segmentType'] != null) {
      type = SegmentType.fromJson(json['segmentType']);
    } else if (json['segmentTypeDescription'] != null || json['segmentTypeCode'] != null) {
      type = SegmentType(
        code: json['segmentTypeCode']?.toString(),
        description: json['segmentTypeDescription']?.toString(),
      );
    }

    return LotColorModel(
      segmentCode: code,
      segmentType: type,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LotColorModel &&
          runtimeType == other.runtimeType &&
          segmentCode == other.segmentCode;

  @override
  int get hashCode => segmentCode?.hashCode ?? 0;

  @override
  String toString() => segmentCode?.description ?? segmentCode?.code ?? 'LotColorModel';
}

class SegmentCode {
  final int? id;
  final String? code;
  final String? description;
  final String? identifierRef;

  SegmentCode({this.id, this.code, this.description, this.identifierRef});

  factory SegmentCode.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['segmentCodeId'] ?? json['colorId'];
    return SegmentCode(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
      code: (json['code'] ?? json['colorCode'])?.toString(),
      description: (json['description'] ?? json['colorDescription'] ?? json['name'] ?? json['code'])?.toString(),
      identifierRef: json['identifierRef']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SegmentCode &&
          runtimeType == other.runtimeType &&
          (id != null && other.id != null
              ? id == other.id
              : (code != null && code == other.code) ||
                  (description != null && description == other.description));

  @override
  int get hashCode => id?.hashCode ?? description?.hashCode ?? code?.hashCode ?? 0;

  @override
  String toString() => description ?? code ?? 'SegmentCode($id)';
}

class SegmentType {
  final int? id;
  final String? code;
  final String? description;

  SegmentType({this.id, this.code, this.description});

  factory SegmentType.fromJson(dynamic json) {
    if (json == null) return SegmentType();
    if (json is String) {
      return SegmentType(code: json, description: json);
    }
    if (json is Map) {
      final rawId = json['id'] ?? json['segmentTypeId'];
      return SegmentType(
        id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
        code: json['code']?.toString(),
        description: (json['description'] ?? json['name'])?.toString(),
      );
    }
    return SegmentType();
  }

  @override
  String toString() => description ?? code ?? 'SegmentType($id)';
}

