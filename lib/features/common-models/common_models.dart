class MachineModel {
  final String? location;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final DateTime? installationDate;
  final double? capacity;
  final int? status;
  final bool? isActive;
  final String? resourceCode;
  final int? costCenterLineId;
  final int? resourceTypeId;
  final String? concurrencyStamp;
  final int? id;

  MachineModel({
    this.location,
    this.brand,
    this.model,
    this.serialNumber,
    this.installationDate,
    this.capacity,
    this.status,
    this.isActive,
    this.resourceCode,
    this.costCenterLineId,
    this.resourceTypeId,
    this.concurrencyStamp,
    this.id,
  });

  factory MachineModel.fromJson(Map<String, dynamic> json) {
    return MachineModel(
      location: json['location'],
      brand: json['brand'],
      model: json['model'],
      serialNumber: json['serialNumber'],
      installationDate: json['installationDate'] != null ? DateTime.parse(json['installationDate']) : null,
      capacity: (json['capacity'] as num?)?.toDouble(),
      status: json['status'],
      isActive: json['isActive'],
      resourceCode: json['resourceCode'],
      costCenterLineId: json['costCenterLineId'],
      resourceTypeId: json['resourceTypeId'],
      concurrencyStamp: json['concurrencyStamp'],
      id: json['id'],
    );
  }
}

class ProductionProgress {
  final String? subOperation;
  final DateTime? date;
  final int? transactionType;
  final String? operatorDescription;
  final double? primaryQuantity;
  final int? primaryUOM;
  final double? secondaryQuantity;
  final int? secondaryUOM;
  final int? wipStatus;
  final bool? gbsFlag;
  final bool? pbsFlag;
  final String? progressCode;
  final int? productGrade;
  final int? productNature;
  final int? operationId;
  final int? workOrderHeaderId;
  final int? workOrderLineId;
  final int? processedItemId;
  final int? itemId;
  final int? shiftId;
  final int? primaryTrayId;
  final int? secondaryTrayId;
  final int? machineId;
  final int? planHeaderId;
  final int? locatorId;
  final String? concurrencyStamp;
  final DateTime? lastModificationTime;
  final String? lastModifierId;
  final DateTime? creationTime;
  final String? creatorId;
  final int? id;

  ProductionProgress({
    this.subOperation,
    this.date,
    this.transactionType,
    this.operatorDescription,
    this.primaryQuantity,
    this.primaryUOM,
    this.secondaryQuantity,
    this.secondaryUOM,
    this.wipStatus,
    this.gbsFlag,
    this.pbsFlag,
    this.progressCode,
    this.productGrade,
    this.productNature,
    this.operationId,
    this.workOrderHeaderId,
    this.workOrderLineId,
    this.processedItemId,
    this.itemId,
    this.shiftId,
    this.primaryTrayId,
    this.secondaryTrayId,
    this.machineId,
    this.planHeaderId,
    this.locatorId,
    this.concurrencyStamp,
    this.lastModificationTime,
    this.lastModifierId,
    this.creationTime,
    this.creatorId,
    this.id,
  });

  factory ProductionProgress.fromJson(Map<String, dynamic> json) {
    return ProductionProgress(
      subOperation: json['subOperation'],
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      transactionType: json['transactionType'],
      operatorDescription: json['operatorDescription'],
      primaryQuantity: (json['primaryQuantity'] as num?)?.toDouble(),
      primaryUOM: json['primaryUOM'],
      secondaryQuantity: (json['secondaryQuantity'] as num?)?.toDouble(),
      secondaryUOM: json['secondaryUOM'],
      wipStatus: json['wipStatus'],
      gbsFlag: json['gbsFlag'],
      pbsFlag: json['pbsFlag'],
      progressCode: json['progressCode'],
      productGrade: json['productGrade'],
      productNature: json['productNature'],
      operationId: json['operationId'],
      workOrderHeaderId: json['workOrderHeaderId'],
      workOrderLineId: json['workOrderLineId'],
      processedItemId: json['processedItemId'],
      itemId: json['itemId'],
      shiftId: json['shiftId'],
      primaryTrayId: json['primaryTrayId'],
      secondaryTrayId: json['secondaryTrayId'],
      machineId: json['machineId'],
      planHeaderId: json['planHeaderId'],
      locatorId: json['locatorId'],
      concurrencyStamp: json['concurrencyStamp'],
      lastModificationTime: json['lastModificationTime'] != null ? DateTime.parse(json['lastModificationTime']) : null,
      lastModifierId: json['lastModifierId'],
      creationTime: json['creationTime'] != null ? DateTime.parse(json['creationTime']) : null,
      creatorId: json['creatorId'],
      id: json['id'],
    );
  }
}

class Operation {
  final String code;
  final String name;
  final String? description;
  final String? identifierRef;
  final String concurrencyStamp;
  final String creationTime;
  final String? lastModificationTime;
  final String? creatorId;
  final String? lastModifierId;
  final int id;

  Operation({
    required this.code,
    required this.name,
    required this.description,
    required this.identifierRef,
    required this.concurrencyStamp,
    required this.creationTime,
    required this.lastModificationTime,
    required this.creatorId,
    required this.lastModifierId,
    required this.id,
  });

  factory Operation.fromJson(Map<String, dynamic> json) {
    return Operation(
      code: json['code'],
      name: json['name'],
      description: json['description'],
      identifierRef: json['identifierRef'],
      concurrencyStamp: json['concurrencyStamp'],
      creationTime: json['creationTime'],
      lastModificationTime: json['lastModificationTime'],
      creatorId: json['creatorId'],
      lastModifierId: json['lastModifierId'],
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }
}

class Shift {
  final String code;
  final String? description;
  final String startTime;
  final String endTime;
  final String? department;
  final String concurrencyStamp;
  final String creationTime;
  final String? lastModificationTime;
  final String? creatorId;
  final String? lastModifierId;
  final int id;

  Shift({
    required this.code,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.department,
    required this.concurrencyStamp,
    required this.creationTime,
    required this.lastModificationTime,
    required this.creatorId,
    required this.lastModifierId,
    required this.id,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      code: json['code'],
      description: json['description'],
      startTime: json['startTime'],
      endTime: json['endTIme'],
      department: json['department'],
      concurrencyStamp: json['concurrencyStamp'],
      creationTime: json['creationTime'],
      lastModificationTime: json['lastModificationTime'],
      creatorId: json['creatorId'],
      lastModifierId: json['lastModifierId'],
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }
}

class Resource {
  final String? location;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final bool isActive;
  final int costCenterLineId;
  final int resourceTypeId;
  final String concurrencyStamp;
  final int id;

  Resource({
    required this.location,
    required this.brand,
    required this.model,
    required this.serialNumber,
    required this.isActive,
    required this.costCenterLineId,
    required this.resourceTypeId,
    required this.concurrencyStamp,
    required this.id,
  });

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      location: json['location'],
      brand: json['brand'],
      model: json['model'],
      serialNumber: json['serialNumber'],
      isActive: json['isActive'],
      costCenterLineId: (json['costCenterLineId'] as num?)?.toInt() ?? 0,
      resourceTypeId: (json['resourceTypeId'] as num?)?.toInt() ?? 0,
      concurrencyStamp: json['concurrencyStamp']?.toString() ?? '',
      id: (json['id'] as num?)?.toInt() ?? 0,
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

class WorkOrderHeader {
  final String description;
  final String workOrderDate;
  final bool status;
  final bool lockFlag;
  final bool provisionalLock;
  final String workOrderCode;
  final String? customerPo;
  final int customerId;
  final int brandId;
  final int styleId;
  final String concurrencyStamp;
  final String creationTime;
  final String? lastModificationTime;
  final String? creatorId;
  final String? lastModifierId;
  final int id;

  WorkOrderHeader({
    required this.description,
    required this.workOrderDate,
    required this.status,
    required this.lockFlag,
    required this.provisionalLock,
    required this.workOrderCode,
    required this.customerPo,
    required this.customerId,
    required this.brandId,
    required this.styleId,
    required this.concurrencyStamp,
    required this.creationTime,
    required this.lastModificationTime,
    required this.creatorId,
    required this.lastModifierId,
    required this.id,
  });

  factory WorkOrderHeader.fromJson(Map<String, dynamic> json) {
    return WorkOrderHeader(
      description: json['description'],
      workOrderDate: json['workOrderDate'],
      status: json['status'],
      lockFlag: json['lockFlag'],
      provisionalLock: json['provisionalLock'],
      workOrderCode: json['workOrderCode'],
      customerPo: json['customerPo'],
      customerId: (json['customerId'] as num?)?.toInt() ?? 0,
      brandId: (json['brandId'] as num?)?.toInt() ?? 0,
      styleId: (json['styleId'] as num?)?.toInt() ?? 0,
      concurrencyStamp: json['concurrencyStamp'],
      creationTime: json['creationTime'],
      lastModificationTime: json['lastModificationTime'],
      creatorId: json['creatorId'],
      lastModifierId: json['lastModifierId'],
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkOrderLine {
  final int uom;
  final double yarnMargin;
  final double knitCGradeMargin;
  final double knittingMargin;
  final double dyeingMargin;
  final double stitchingMargin;
  final double requiredQuantity;
  final double excessQuantity;
  final bool status;
  final String remarks;
  final double planQuantity;
  final double totalPlanQuantity;
  final double requiredGarmentTubes;
  final double tubesAfterAdjustment;
  final double totalQtyAfterAdjustment;
  final double heatsetMargin;
  final int workOrderId;
  final int itemId;
  final String concurrencyStamp;
  final String creationTime;
  final String? lastModificationTime;
  final String? creatorId;
  final String? lastModifierId;
  final int id;

  WorkOrderLine({
    required this.uom,
    required this.yarnMargin,
    required this.knitCGradeMargin,
    required this.knittingMargin,
    required this.dyeingMargin,
    required this.stitchingMargin,
    required this.requiredQuantity,
    required this.excessQuantity,
    required this.status,
    required this.remarks,
    required this.planQuantity,
    required this.totalPlanQuantity,
    required this.requiredGarmentTubes,
    required this.tubesAfterAdjustment,
    required this.totalQtyAfterAdjustment,
    required this.heatsetMargin,
    required this.workOrderId,
    required this.itemId,
    required this.concurrencyStamp,
    required this.creationTime,
    required this.lastModificationTime,
    required this.creatorId,
    required this.lastModifierId,
    required this.id,
  });

  factory WorkOrderLine.fromJson(Map<String, dynamic> json) {
    return WorkOrderLine(
      uom: (json['uom'] as num?)?.toInt() ?? 0,
      yarnMargin: (json['yarnMargin'] as num?)?.toDouble() ?? 0,
      knitCGradeMargin: (json['knitCGradeMargin'] as num?)?.toDouble() ?? 0,
      knittingMargin: (json['knittingMargin'] as num?)?.toDouble() ?? 0,
      dyeingMargin: (json['dyeingMargin'] as num?)?.toDouble() ?? 0,
      stitchingMargin: (json['stitchingMargin'] as num?)?.toDouble() ?? 0,
      requiredQuantity: (json['requiredQuantity'] as num?)?.toDouble() ?? 0,
      excessQuantity: (json['excessQuantity'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? false,
      remarks: json['remarks']?.toString() ?? '',
      planQuantity: (json['planQuantity'] as num?)?.toDouble() ?? 0,
      totalPlanQuantity: (json['totalPlanQuantity'] as num?)?.toDouble() ?? 0,
      requiredGarmentTubes: (json['requiredGarmentTubes'] as num?)?.toDouble() ?? 0,
      tubesAfterAdjustment: (json['tubesAfterAdjustment'] as num?)?.toDouble() ?? 0,
      totalQtyAfterAdjustment: (json['totalQtyAfterAdjustment'] as num?)?.toDouble() ?? 0,
      heatsetMargin: (json['heatsetMargin'] as num?)?.toDouble() ?? 0,
      workOrderId: (json['workOrderId'] as num?)?.toInt() ?? 0,
      itemId: (json['itemId'] as num?)?.toInt() ?? 0,
      concurrencyStamp: json['concurrencyStamp']?.toString() ?? '',
      creationTime: json['creationTime']?.toString() ?? '',
      lastModificationTime: json['lastModificationTime']?.toString(),
      creatorId: json['creatorId']?.toString(),
      lastModifierId: json['lastModifierId']?.toString(),
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }
}

class Item {
  final String code;
  final String description;
  final bool active;
  final double sam;
  final double perGarmentTube;
  final String? sizeDescription;
  final String? componentDescription;
  final int itemCategoryId;
  final String concurrencyStamp;
  final bool isDeleted;
  final String creationTime;
  final String? lastModificationTime;
  final String? creatorId;
  final int id;

  Item({
    required this.code,
    required this.description,
    required this.active,
    required this.sam,
    required this.perGarmentTube,
    required this.sizeDescription,
    required this.componentDescription,
    required this.itemCategoryId,
    required this.concurrencyStamp,
    required this.isDeleted,
    required this.creationTime,
    required this.lastModificationTime,
    required this.creatorId,
    required this.id,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      code: json['code'],
      description: json['description'],
      active: json['active'],
      sam: (json['sam'] as num?)?.toDouble() ?? 0,
      perGarmentTube: (json['perGarmentTube'] as num?)?.toDouble() ?? 0,
      sizeDescription: json['sizeDescription'],
      componentDescription: json['componentDescription'],
      itemCategoryId: (json['itemCategoryId'] as num?)?.toInt() ?? 0,
      concurrencyStamp: json['concurrencyStamp'],
      isDeleted: json['isDeleted'],
      creationTime: json['creationTime'],
      lastModificationTime: json['lastModificationTime'],
      creatorId: json['creatorId'],
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }
}

class CostCenterLine {
  final String code;
  final String name;
  final String? description;
  final int costCenterId;
  final String concurrencyStamp;
  final String creationTime;
  final String? lastModificationTime;
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
      code: json['code'],
      name: json['name'],
      description: json['description'],
      costCenterId: json['costCenterId'],
      concurrencyStamp: json['concurrencyStamp'],
      creationTime: json['creationTime'],
      lastModificationTime: json['lastModificationTime'],
      creatorId: json['creatorId'],
      lastModifierId: json['lastModifierId'],
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlanHeader {
  final String date;
  final bool lockFlag;
  final int shiftId;
  final int departmentId;
  final int costCenterId;
  final int costCenterLineId;
  final int operationId;
  final String concurrencyStamp;
  final String creationTime;
  final String? lastModificationTime;
  final String? creatorId;
  final String? lastModifierId;
  final int id;

  PlanHeader({
    required this.date,
    required this.lockFlag,
    required this.shiftId,
    required this.departmentId,
    required this.costCenterId,
    required this.costCenterLineId,
    required this.operationId,
    required this.concurrencyStamp,
    required this.creationTime,
    required this.lastModificationTime,
    required this.creatorId,
    required this.lastModifierId,
    required this.id,
  });

  factory PlanHeader.fromJson(Map<String, dynamic> json) {
    return PlanHeader(
      date: json['date'],
      lockFlag: json['lockFlag'],
      shiftId: (json['shiftId'] as num?)?.toInt() ?? 0,
      departmentId: (json['departmentId'] as num?)?.toInt() ?? 0,
      costCenterId: (json['costCenterId'] as num?)?.toInt() ?? 0,
      costCenterLineId: (json['costCenterLineId'] as num?)?.toInt() ?? 0,
      operationId: (json['operationId'] as num?)?.toInt() ?? 0,
      concurrencyStamp: json['concurrencyStamp'],
      creationTime: json['creationTime'],
      lastModificationTime: json['lastModificationTime'],
      creatorId: json['creatorId'],
      lastModifierId: json['lastModifierId'],
      id: (json['id'] as num?)?.toInt() ?? 0,
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

class PlanLine {
  final String planDate;
  final String? orderNo;
  final double quantityPerTray;
  final String? actualStartTime;
  final String? actualEndTime;
  final bool cancelled;
  final int primaryUOM;
  final double primaryPlanQuantity;
  final double secondaryPlanQuantity;
  final int secondaryUOM;
  final double primaryQuantity;
  final double secondaryQuantity;
  final String? cutsomerPO;
  final double cycleTime;
  final int operationId;
  final int shiftId;
  final int resourceId;
  final int workOrderHeaderId;
  final int workOrderLineId;
  final int itemId;
  final int costCenterLineId;
  final int? saleOrderMstId;
  final int? saleOrderLineId;
  final int planHeaderId;
  final String concurrencyStamp;
  final String creationTime;
  final String? lastModificationTime;
  final String? creatorId;
  final String? lastModifierId;
  final int id;

  PlanLine({
    required this.planDate,
    required this.orderNo,
    required this.quantityPerTray,
    required this.actualStartTime,
    required this.actualEndTime,
    required this.cancelled,
    required this.primaryUOM,
    required this.primaryPlanQuantity,
    required this.secondaryPlanQuantity,
    required this.secondaryUOM,
    required this.primaryQuantity,
    required this.secondaryQuantity,
    required this.cutsomerPO,
    required this.cycleTime,
    required this.operationId,
    required this.shiftId,
    required this.resourceId,
    required this.workOrderHeaderId,
    required this.workOrderLineId,
    required this.itemId,
    required this.costCenterLineId,
    required this.saleOrderMstId,
    required this.saleOrderLineId,
    required this.planHeaderId,
    required this.concurrencyStamp,
    required this.creationTime,
    required this.lastModificationTime,
    required this.creatorId,
    required this.lastModifierId,
    required this.id,
  });

  factory PlanLine.fromJson(Map<String, dynamic> json) {
    return PlanLine(
      planDate: json['planDate']?.toString() ?? '',
      orderNo: json['orderNo']?.toString(),
      quantityPerTray: (json['quantityPerTray'] as num?)?.toDouble() ?? 0,
      actualStartTime: json['actualStartTime']?.toString(),
      actualEndTime: json['actualEndTime']?.toString(),
      cancelled: json['cancelled'],
      primaryUOM: (json['primaryUOM'] as num?)?.toInt() ?? 0,
      primaryPlanQuantity: (json['primaryPlanQuantity'] as num?)?.toDouble() ?? 0,
      secondaryPlanQuantity: (json['secondaryPlanQuantity'] as num?)?.toDouble() ?? 0,
      secondaryUOM: (json['secondaryUOM'] as num?)?.toInt() ?? 0,
      primaryQuantity: (json['primaryQuantity'] as num?)?.toDouble() ?? 0,
      secondaryQuantity: (json['secondaryQuantity'] as num?)?.toDouble() ?? 0,
      cutsomerPO: json['cutsomerPO'],
      cycleTime: (json['cycleTime'] as num?)?.toDouble() ?? 0,
      operationId: (json['operationId'] as num?)?.toInt() ?? 0,
      shiftId: (json['shiftId'] as num?)?.toInt() ?? 0,
      resourceId: (json['resourceId'] as num?)?.toInt() ?? 0,
      workOrderHeaderId: (json['workOrderHeaderId'] as num?)?.toInt() ?? 0,
      workOrderLineId: (json['workOrderLineId'] as num?)?.toInt() ?? 0,
      itemId: (json['itemId'] as num?)?.toInt() ?? 0,
      costCenterLineId: (json['costCenterLineId'] as num?)?.toInt() ?? 0,
      saleOrderMstId: (json['saleOrderMstId'] as num?)?.toInt(),
      saleOrderLineId: (json['saleOrderLineId'] as num?)?.toInt(),
      planHeaderId: (json['planHeaderId'] as num?)?.toInt() ?? 0,
      concurrencyStamp: json['concurrencyStamp']?.toString() ?? '',
      creationTime: json['creationTime']?.toString() ?? '',
      lastModificationTime: json['lastModificationTime']?.toString(),
      creatorId: json['creatorId']?.toString(),
      lastModifierId: json['lastModifierId']?.toString(),
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }
}

class PrimaryTrayModel {
  final String? description;
  final bool? active;
  final String? trayCode;
  final double? trayQuantity;
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

  PrimaryTrayModel({
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

  factory PrimaryTrayModel.fromJson(Map<String, dynamic> json) {
    return PrimaryTrayModel(
      description: json['description'],
      active: json['active'],
      trayCode: json['trayCode'],
      trayQuantity: (json['trayQuantity'] as num?)?.toDouble(),
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
