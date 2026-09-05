import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_color_model.dart';

class LotHeaderResponseModel {
  final LotHeaderModel batchHeader;
  final MachineModel? machine;
  final SegmentCode? colorCode;
  final Shift? shift;

  LotHeaderResponseModel({required this.batchHeader, this.machine, this.colorCode, this.shift});

  factory LotHeaderResponseModel.fromJson(Map<String, dynamic> json) {
    final batchHeaderMap = json['batchHeader'] is Map ? Map<String, dynamic>.from(json['batchHeader']) : json;
    final rawMachine = json['machine'] ??
        json['resource'] ??
        json['machineModel'] ??
        batchHeaderMap['machine'] ??
        batchHeaderMap['resource'] ??
        batchHeaderMap['machineModel'];

    return LotHeaderResponseModel(
      batchHeader: LotHeaderModel.fromJson(batchHeaderMap),
      machine: (rawMachine != null && rawMachine is Map)
          ? MachineModel.fromJson(Map<String, dynamic>.from(rawMachine))
          : (json['resourceCode'] != null || json['brand'] != null || json['name'] != null || json['code'] != null)
              ? MachineModel.fromJson(json)
              : null,
      colorCode: (json['colorCode'] != null && json['colorCode'] is Map<String, dynamic>)
          ? SegmentCode.fromJson(json['colorCode'])
          : null,
      shift: json['shift'] != null ? Shift.fromJson(json['shift']) : null,
    );
  }
}

class LotHeaderModel {
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
  final int? trayDetailId;
  final String? concurrencyStamp;

  LotHeaderModel({
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
    this.trayDetailId,
    this.concurrencyStamp,
  });

  factory LotHeaderModel.fromJson(Map<String, dynamic> json) {
    final rawMachineId = json['machineId'] ??
        json['resourceId'] ??
        (json['batchHeader'] is Map ? (json['batchHeader']['machineId'] ?? json['batchHeader']['resourceId']) : null);

    return LotHeaderModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      creationTime: json['creationTime']?.toString(),
      creatorId: json['creatorId']?.toString(),
      lastModificationTime: json['lastModificationTime']?.toString(),
      lastModifierId: json['lastModifierId']?.toString(),
      planDate: json['planDate']?.toString(),
      colorDescription: json['colorDescription']?.toString() ??
          (json['batchHeader'] is Map ? json['batchHeader']['colorDescription']?.toString() : null),
      lockFlag: json['lockFlag'] as bool?,
      batchHeaderCode: json['batchHeaderCode']?.toString() ??
          (json['batchHeader'] is Map ? json['batchHeader']['batchHeaderCode']?.toString() : null),
      machineId: rawMachineId is int ? rawMachineId : int.tryParse(rawMachineId?.toString() ?? ''),
      colorCodeId: json['colorCode'] is int
          ? json['colorCode']
          : int.tryParse(json['colorCode']?.toString() ?? ''),
      shiftId: json['shiftId'] is int
          ? json['shiftId']
          : int.tryParse(json['shiftId']?.toString() ?? ''),
      trayDetailId: json['trayDetailId'] is int
          ? json['trayDetailId']
          : int.tryParse(json['trayDetailId']?.toString() ?? ''),
      concurrencyStamp: json['concurrencyStamp']?.toString(),
    );
  }
}
