import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class WipBatchModel {
  final int batchHeaderId;
  final String batchCode;
  final String machine;
  final String color;
  final int trayCount;
  final double totalTubes;
  final double totalWeight;
  final String? trolleyCode;
  final bool isStarted;
  final bool reworkFlag;
  final bool isReassigned;
  final bool isDraft;
  final List<ProductionProgressResponseModel> trays;

  const WipBatchModel({
    required this.batchHeaderId,
    required this.batchCode,
    required this.machine,
    required this.color,
    required this.trayCount,
    required this.totalTubes,
    required this.totalWeight,
    this.trolleyCode,
    this.isStarted = false,
    this.reworkFlag = false,
    this.isReassigned = false,
    this.isDraft = false,
    this.trays = const [],
  });
}

class WipOperationModel {
  final Operation operation;
  final int batchCount;
  final int trayCount;
  final double totalTubes;
  final double totalWeight;

  const WipOperationModel({
    required this.operation,
    this.batchCount = 0,
    this.trayCount = 0,
    this.totalTubes = 0,
    this.totalWeight = 0,
  });

  WipOperationModel copyWith({
    Operation? operation,
    int? batchCount,
    int? trayCount,
    double? totalTubes,
    double? totalWeight,
  }) {
    return WipOperationModel(
      operation: operation ?? this.operation,
      batchCount: batchCount ?? this.batchCount,
      trayCount: trayCount ?? this.trayCount,
      totalTubes: totalTubes ?? this.totalTubes,
      totalWeight: totalWeight ?? this.totalWeight,
    );
  }
}

class LocatorResponse {
  final LocatorModel locator;
  final Department? department;
  final Operation? operation;

  LocatorResponse({
    required this.locator,
    this.department,
    this.operation,
  });

  factory LocatorResponse.fromJson(Map<String, dynamic> json) {
    return LocatorResponse(
      locator: LocatorModel.fromJson(Map<String, dynamic>.from(json['locator'] ?? json)),
      department: json['department'] != null ? Department.fromJson(Map<String, dynamic>.from(json['department'])) : null,
      operation: json['operation'] != null ? Operation.fromJson(Map<String, dynamic>.from(json['operation'])) : null,
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
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
