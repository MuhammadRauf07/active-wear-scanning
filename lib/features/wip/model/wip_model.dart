class LocatorResponse {
  final Locator locator;
  final Department department;
  final Operation? operation;

  LocatorResponse({
    required this.locator,
    required this.department,
    this.operation,
  });

  factory LocatorResponse.fromJson(Map<String, dynamic> json) {
    return LocatorResponse(
      locator: Locator.fromJson(json['locator']),
      department: Department.fromJson(json['department']),
      operation: json['operation'] != null ? Operation.fromJson(json['operation']) : null,
    );
  }
}

class Locator {
  final int id;
  final String description;
  final String locatorCode;
  final String? logicalWH;
  final int departmentId;
  final int? operationId;

  Locator({
    required this.id,
    required this.description,
    required this.locatorCode,
    this.logicalWH,
    required this.departmentId,
    this.operationId,
  });

  factory Locator.fromJson(Map<String, dynamic> json) {
    return Locator(
      id: json['id'],
      description: json['description'],
      locatorCode: json['locatorCode'],
      logicalWH: json['logicalWH'],
      departmentId: json['departmentId'],
      operationId: json['operationId'],
    );
  }
}

class Department {
  final int id;
  final String code;
  final String name;

  Department({
    required this.id,
    required this.code,
    required this.name,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'],
      code: json['code'],
      name: json['name'],
    );
  }
}

class Operation {
  final int id;
  final String code;
  final String name;

  Operation({
    required this.id,
    required this.code,
    required this.name,
  });

  factory Operation.fromJson(Map<String, dynamic> json) {
    return Operation(
      id: json['id'],
      code: json['code'],
      name: json['name'],
    );
  }
}

class WIPEntry {
  final String workOrder;
  final String? machine;
  final String? batchNo;
  final String item;
  final int traysCount;
  final int pcsCount;

  WIPEntry({
    required this.workOrder,
    this.machine,
    this.batchNo,
    required this.item,
    required this.traysCount,
    required this.pcsCount,
  });

  // Dummy factory for mocking/testing since user didn't provide WIP data API
  factory WIPEntry.fromJson(Map<String, dynamic> json) {
    return WIPEntry(
      workOrder: json['workOrder'] ?? '',
      machine: json['machine'],
      batchNo: json['batchNo'],
      item: json['item'] ?? '',
      traysCount: json['traysCount'] ?? 0,
      pcsCount: json['pcsCount'] ?? 0,
    );
  }
}
