class PoStyleItem {
  final PoStyleModel poStyle;
  final PoAllocationLineModel? poAllocationLine;

  PoStyleItem({
    required this.poStyle,
    this.poAllocationLine,
  });

  factory PoStyleItem.fromJson(Map<String, dynamic> json) {
    return PoStyleItem(
      poStyle: PoStyleModel.fromJson(Map<String, dynamic>.from(json['poStyle'] as Map)),
      poAllocationLine: json['poAllocationLine'] != null
          ? PoAllocationLineModel.fromJson(Map<String, dynamic>.from(json['poAllocationLine'] as Map))
          : null,
    );
  }
}

class PoStyleModel {
  final String? operation;
  final String? bundleQrCode;
  final String? so;
  final String? po;
  final String? lot;
  final String? colorCode;
  final String? articleNo;
  final String? bundleNo;
  final int? userQuantity;
  final String? size;
  final String? masterQrReference;
  final String? lineCode;
  final String? customer;
  final String? regionCode;
  final int? quantity;
  final String? elevatedCode;
  final String? elevatedDesc;
  final String? line;
  final String? bundleMasterQrCode;
  final String? bundleScannedLine;
  final int? poAllocationLineId;
  final String? concurrencyStamp;
  final String? creationTime;
  final String? creatorId;
  final int id;

  PoStyleModel({
    this.operation,
    this.bundleQrCode,
    this.so,
    this.po,
    this.lot,
    this.colorCode,
    this.articleNo,
    this.bundleNo,
    this.userQuantity,
    this.size,
    this.masterQrReference,
    this.lineCode,
    this.customer,
    this.regionCode,
    this.quantity,
    this.elevatedCode,
    this.elevatedDesc,
    this.line,
    this.bundleMasterQrCode,
    this.bundleScannedLine,
    this.poAllocationLineId,
    this.concurrencyStamp,
    this.creationTime,
    this.creatorId,
    required this.id,
  });

  factory PoStyleModel.fromJson(Map<String, dynamic> json) {
    return PoStyleModel(
      operation: json['operation'],
      bundleQrCode: json['bundleQrCode'],
      so: json['so'],
      po: json['po'],
      lot: json['lot'],
      colorCode: json['colorCode'],
      articleNo: json['articleNo'],
      bundleNo: json['bundleNo'],
      userQuantity: (json['userQuantity'] as num?)?.toInt(),
      size: json['size'],
      masterQrReference: json['masterQrReference'],
      lineCode: json['lineCode'],
      customer: json['customer'],
      regionCode: json['regionCode'],
      quantity: (json['quantity'] as num?)?.toInt(),
      elevatedCode: json['elevatedCode'],
      elevatedDesc: json['elevatedDesc'],
      line: json['line'],
      bundleMasterQrCode: json['bundleMasterQrCode'],
      bundleScannedLine: json['bundleScannedLine'],
      poAllocationLineId: (json['poAllocationLineId'] as num?)?.toInt(),
      concurrencyStamp: json['concurrencyStamp'],
      creationTime: json['creationTime'],
      creatorId: json['creatorId'],
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'operation': operation,
      'bundleQrCode': bundleQrCode,
      'so': so,
      'po': po,
      'lot': lot,
      'colorCode': colorCode,
      'articleNo': articleNo,
      'bundleNo': bundleNo,
      'userQuantity': userQuantity,
      'size': size,
      'masterQrReference': masterQrReference,
      'lineCode': lineCode,
      'customer': customer,
      'regionCode': regionCode,
      'quantity': quantity,
      'elevatedCode': elevatedCode,
      'elevatedDesc': elevatedDesc,
      'line': line,
      'bundleMasterQrCode': bundleMasterQrCode,
      'bundleScannedLine': bundleScannedLine,
      'poAllocationLineId': poAllocationLineId,
      'concurrencyStamp': concurrencyStamp,
      'creationTime': creationTime,
      'creatorId': creatorId,
      'id': id,
    };
  }

  PoStyleModel copyWith({
    String? lineCode,
    String? line,
  }) {
    return PoStyleModel(
      operation: operation,
      bundleQrCode: bundleQrCode,
      so: so,
      po: po,
      lot: lot,
      colorCode: colorCode,
      articleNo: articleNo,
      bundleNo: bundleNo,
      userQuantity: userQuantity,
      size: size,
      masterQrReference: masterQrReference,
      lineCode: lineCode ?? this.lineCode,
      customer: customer,
      regionCode: regionCode,
      quantity: quantity,
      elevatedCode: elevatedCode,
      elevatedDesc: elevatedDesc,
      line: line ?? this.line,
      bundleMasterQrCode: bundleMasterQrCode,
      bundleScannedLine: bundleScannedLine,
      poAllocationLineId: poAllocationLineId,
      concurrencyStamp: concurrencyStamp,
      creationTime: creationTime,
      creatorId: creatorId,
      id: id,
    );
  }
}

class PoAllocationLineModel {
  final String? colorCode;
  final String? garmentDescription;
  final String? sizeDescription;
  final int? orderQuantity;
  final int? allocatedQuantity;
  final String? bundleMasterId;
  final int? allocatedGarmentQuantity;
  final bool? lockFlag;
  final int? poAllocationHeaderId;
  final int? garmentItemId;
  final String? concurrencyStamp;
  final String? creationTime;
  final String? creatorId;
  final int id;

  PoAllocationLineModel({
    this.colorCode,
    this.garmentDescription,
    this.sizeDescription,
    this.orderQuantity,
    this.allocatedQuantity,
    this.bundleMasterId,
    this.allocatedGarmentQuantity,
    this.lockFlag,
    this.poAllocationHeaderId,
    this.garmentItemId,
    this.concurrencyStamp,
    this.creationTime,
    this.creatorId,
    required this.id,
  });

  factory PoAllocationLineModel.fromJson(Map<String, dynamic> json) {
    return PoAllocationLineModel(
      colorCode: json['colorCode'],
      garmentDescription: json['garmentDescription'],
      sizeDescription: json['sizeDescription'],
      orderQuantity: (json['orderQuantity'] as num?)?.toInt(),
      allocatedQuantity: (json['allocatedQuantity'] as num?)?.toInt(),
      bundleMasterId: json['bundleMasterId'],
      allocatedGarmentQuantity: (json['allocatedGarmentQuantity'] as num?)?.toInt(),
      lockFlag: json['lockFlag'],
      poAllocationHeaderId: (json['poAllocationHeaderId'] as num?)?.toInt(),
      garmentItemId: (json['garmentItemId'] as num?)?.toInt(),
      concurrencyStamp: json['concurrencyStamp'],
      creationTime: json['creationTime'],
      creatorId: json['creatorId'],
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }
}
