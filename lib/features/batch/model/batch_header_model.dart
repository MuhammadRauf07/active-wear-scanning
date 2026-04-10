import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/batch/model/batch_color_model.dart';

class BatchHeaderResponseModel {
  final BatchHeaderModel batchHeader;
  final MachineModel? machine;
  final SegmentCode? colorCode;
  final Shift? shift;

  BatchHeaderResponseModel({required this.batchHeader, this.machine, this.colorCode, this.shift});

  factory BatchHeaderResponseModel.fromJson(Map<String, dynamic> json) {
    return BatchHeaderResponseModel(
      batchHeader: BatchHeaderModel.fromJson(json['batchHeader'] ?? json),
      machine: (json['machine'] != null) 
          ? MachineModel.fromJson(json['machine']) 
          : (json['resourceCode'] != null || json['brand'] != null) 
            ? MachineModel.fromJson(json)
            : null,
      colorCode: (json['colorCode'] != null && json['colorCode'] is Map<String, dynamic>) 
          ? SegmentCode.fromJson(json['colorCode']) 
          : null,
      shift: json['shift'] != null ? Shift.fromJson(json['shift']) : null,
    );
  }
}

class BatchHeaderModel {
  final int? id;
  final String? creationTime;
  final String? creatorId;
  final String? lastModificationTime;
  final String? lastModifierId;
  final String? planDate;
  final String? colorDescription;
  final bool? lockFlag;
  final String? batchHeaderCode;
  final int? machineId;
  final int? colorCodeId;
  final int? shiftId;
  final String? concurrencyStamp;

  BatchHeaderModel({
    this.id,
    this.creationTime,
    this.creatorId,
    this.lastModificationTime,
    this.lastModifierId,
    this.planDate,
    this.colorDescription,
    this.lockFlag,
    this.batchHeaderCode,
    this.machineId,
    this.colorCodeId,
    this.shiftId,
    this.concurrencyStamp,
  });

  factory BatchHeaderModel.fromJson(Map<String, dynamic> json) {
    return BatchHeaderModel(
      id: json['id'],
      creationTime: json['creationTime'],
      creatorId: json['creatorId'],
      lastModificationTime: json['lastModificationTime'],
      lastModifierId: json['lastModifierId'],
      planDate: json['planDate'],
      colorDescription: json['colorDescription'],
      lockFlag: json['lockFlag'],
      batchHeaderCode: json['batchHeaderCode'],
      machineId: json['machineId'],
      colorCodeId: json['colorCode'], // Mapping field correctly based on API
      shiftId: json['shiftId'],
      concurrencyStamp: json['concurrencyStamp'],
    );
  }
}
