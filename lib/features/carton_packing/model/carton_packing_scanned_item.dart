class PackingInstructionLineDetail {
  final String uniqueId;
  final int packingInstructionHeaderId;
  final String? concurrencyStamp;
  final int id;

  PackingInstructionLineDetail({
    this.uniqueId = '',
    this.packingInstructionHeaderId = 0,
    this.concurrencyStamp,
    this.id = 0,
  });

  factory PackingInstructionLineDetail.fromJson(Map<String, dynamic> json) {
    return PackingInstructionLineDetail(
      uniqueId: json['uniqueId'] ?? '',
      packingInstructionHeaderId: json['packingInstructionHeaderId'] ?? 0,
      concurrencyStamp: json['concurrencyStamp'],
      id: json['id'] ?? 0,
    );
  }
}

class PackingInstructionHeader {
  final String cartonGroup;
  final int packingType;
  final int packsPerCarton;
  final int noCartons;
  final double weight;
  final double grossWeight;
  final double netWeight;
  final int measurementUom;
  final double length;
  final double width;
  final double height;
  final String shippingMark;
  final String instructions;
  final double volume;
  final String sizeDescription;
  final int totalPacks;
  final String printingColor;
  final bool lockFlag;
  final int saleOrderMstId;
  final String? concurrencyStamp;
  final int id;

  PackingInstructionHeader({
    this.cartonGroup = '',
    this.packingType = 0,
    this.packsPerCarton = 0,
    this.noCartons = 0,
    this.weight = 0.0,
    this.grossWeight = 0.0,
    this.netWeight = 0.0,
    this.measurementUom = 0,
    this.length = 0.0,
    this.width = 0.0,
    this.height = 0.0,
    this.shippingMark = '',
    this.instructions = '',
    this.volume = 0.0,
    this.sizeDescription = '',
    this.totalPacks = 0,
    this.printingColor = '',
    this.lockFlag = false,
    this.saleOrderMstId = 0,
    this.concurrencyStamp,
    this.id = 0,
  });

  factory PackingInstructionHeader.fromJson(Map<String, dynamic> json) {
    return PackingInstructionHeader(
      cartonGroup: json['cartonGroup'] ?? '',
      packingType: json['packingType'] ?? 0,
      packsPerCarton: json['packsPerCarton'] ?? 0,
      noCartons: json['noCartons'] ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      grossWeight: (json['grossWeight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (json['netWeight'] as num?)?.toDouble() ?? 0.0,
      measurementUom: json['measurementUom'] ?? 0,
      length: (json['length'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      shippingMark: json['shippingMark'] ?? '',
      instructions: json['instructions'] ?? '',
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      sizeDescription: json['sizeDescription'] ?? '',
      totalPacks: json['totalPacks'] ?? 0,
      printingColor: json['printingColor'] ?? '',
      lockFlag: json['lockFlag'] ?? false,
      saleOrderMstId: json['saleOrderMstId'] ?? 0,
      concurrencyStamp: json['concurrencyStamp'],
      id: json['id'] ?? 0,
    );
  }
}

class PackingInstructionResponseModel {
  final PackingInstructionLineDetail packingInstructionLineDetail;
  final PackingInstructionHeader packingInstructionHeader;

  PackingInstructionResponseModel({
    required this.packingInstructionLineDetail,
    required this.packingInstructionHeader,
  });

  factory PackingInstructionResponseModel.fromJson(Map<String, dynamic> json) {
    return PackingInstructionResponseModel(
      packingInstructionLineDetail: PackingInstructionLineDetail.fromJson(
        json['packingInstructionLineDetail'] is Map
            ? Map<String, dynamic>.from(json['packingInstructionLineDetail'] as Map)
            : {},
      ),
      packingInstructionHeader: PackingInstructionHeader.fromJson(
        json['packingInstructionHeader'] is Map
            ? Map<String, dynamic>.from(json['packingInstructionHeader'] as Map)
            : {},
      ),
    );
  }
}

class SaleOrderModel {
  final int id;
  final String orderNo;
  final int orderStatus;
  final int orderType;
  final String customerPO;
  final String poDate;
  final String deliveryAddress;
  final int shipMode;
  final int currency;
  final String? deliveryDate;
  final bool lockFlag;
  final bool tnaLock;
  final int customerOrderType;
  final int area;
  final String? loadingDate;
  final String? shipmentDate;
  final String? crdDate;
  final int customerId;
  final int tnaTemplateHeaderId;
  final int brand;
  final int style;
  final int customerSiteId;
  final int paymentTermId;
  final String? concurrencyStamp;

  SaleOrderModel({
    this.id = 0,
    this.orderNo = '',
    this.orderStatus = 0,
    this.orderType = 0,
    this.customerPO = '',
    this.poDate = '',
    this.deliveryAddress = '',
    this.shipMode = 0,
    this.currency = 0,
    this.deliveryDate,
    this.lockFlag = false,
    this.tnaLock = false,
    this.customerOrderType = 0,
    this.area = 0,
    this.loadingDate,
    this.shipmentDate,
    this.crdDate,
    this.customerId = 0,
    this.tnaTemplateHeaderId = 0,
    this.brand = 0,
    this.style = 0,
    this.customerSiteId = 0,
    this.paymentTermId = 0,
    this.concurrencyStamp,
  });

  factory SaleOrderModel.fromJson(Map<String, dynamic> json) {
    return SaleOrderModel(
      id: json['id'] ?? 0,
      orderNo: json['orderNo'] ?? '',
      orderStatus: json['orderStatus'] ?? 0,
      orderType: json['orderType'] ?? 0,
      customerPO: json['customerPO'] ?? '',
      poDate: json['poDate'] ?? '',
      deliveryAddress: json['deliveryAddress'] ?? '',
      shipMode: json['shipMode'] ?? 0,
      currency: json['currency'] ?? 0,
      deliveryDate: json['deliveryDate'],
      lockFlag: json['lockFlag'] ?? false,
      tnaLock: json['tnaLock'] ?? false,
      customerOrderType: json['customerOrderType'] ?? 0,
      area: json['area'] ?? 0,
      loadingDate: json['loadingDate'],
      shipmentDate: json['shipmentDate'],
      crdDate: json['crdDate'],
      customerId: json['customerId'] ?? 0,
      tnaTemplateHeaderId: json['tnaTemplateHeaderId'] ?? 0,
      brand: json['brand'] ?? 0,
      style: json['style'] ?? 0,
      customerSiteId: json['customerSiteId'] ?? 0,
      paymentTermId: json['paymentTermId'] ?? 0,
      concurrencyStamp: json['concurrencyStamp'],
    );
  }
}

class CustomerModel {
  final int id;
  final String code;
  final String name;
  final String description;

  CustomerModel({
    this.id = 0,
    this.code = '',
    this.name = '',
    this.description = '',
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class PackingInstructionLine {
  final int packRatio;
  final String code;
  final int itemDefId;
  final int packingInstructionHeaderId;
  final int id;

  PackingInstructionLine({
    this.packRatio = 0,
    this.code = '',
    this.itemDefId = 0,
    this.packingInstructionHeaderId = 0,
    this.id = 0,
  });

  factory PackingInstructionLine.fromJson(Map<String, dynamic> json) {
    return PackingInstructionLine(
      packRatio: json['packRatio'] ?? 0,
      code: json['code'] ?? '',
      itemDefId: json['itemDefId'] ?? 0,
      packingInstructionHeaderId: json['packingInstructionHeaderId'] ?? 0,
      id: json['id'] ?? 0,
    );
  }
}

class ItemDefModel {
  final String code;
  final String description;
  final String colorDescription;
  final String sizeDescription;
  final int id;

  ItemDefModel({
    this.code = '',
    this.description = '',
    this.colorDescription = '',
    this.sizeDescription = '',
    this.id = 0,
  });

  factory ItemDefModel.fromJson(Map<String, dynamic> json) {
    return ItemDefModel(
      code: json['code'] ?? '',
      description: json['description'] ?? '',
      colorDescription: json['colorDescription'] ?? '',
      sizeDescription: json['sizeDescription'] ?? '',
      id: json['id'] ?? 0,
    );
  }
}

class PackingInstructionLineResponse {
  final PackingInstructionLine packingInstructionLine;
  final ItemDefModel itemDef;
  final PackingInstructionHeader packingInstructionHeader;

  PackingInstructionLineResponse({
    required this.packingInstructionLine,
    required this.itemDef,
    required this.packingInstructionHeader,
  });

  factory PackingInstructionLineResponse.fromJson(Map<String, dynamic> json) {
    return PackingInstructionLineResponse(
      packingInstructionLine: PackingInstructionLine.fromJson(
        json['packingInstructionLine'] is Map
            ? Map<String, dynamic>.from(json['packingInstructionLine'] as Map)
            : {},
      ),
      itemDef: ItemDefModel.fromJson(
        json['itemDef'] is Map
            ? Map<String, dynamic>.from(json['itemDef'] as Map)
            : {},
      ),
      packingInstructionHeader: PackingInstructionHeader.fromJson(
        json['packingInstructionHeader'] is Map
            ? Map<String, dynamic>.from(json['packingInstructionHeader'] as Map)
            : {},
      ),
    );
  }
}


