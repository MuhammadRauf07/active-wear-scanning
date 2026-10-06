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
    final Map<String, dynamic> target = (json['batchHeader'] is Map)
        ? Map<String, dynamic>.from(json['batchHeader'] as Map)
        : json;

    final rawMachineId = target['machineId'] ??
        target['resourceId'] ??
        json['machineId'] ??
        json['resourceId'] ??
        (json['machine'] is Map ? json['machine']['id'] : null);

    final rawId = target['id'] ?? json['id'];
    final rawColorCode = target['colorCode'] ?? target['colorCodeId'] ?? json['colorCode'] ?? json['colorCodeId'];
    final rawShiftId = target['shiftId'] ?? json['shiftId'];
    final rawTrayDetailId = target['trayDetailId'] ?? json['trayDetailId'];

    return LotHeaderModel(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
      creationTime: (target['creationTime'] ?? json['creationTime'])?.toString(),
      creatorId: (target['creatorId'] ?? json['creatorId'])?.toString(),
      lastModificationTime: (target['lastModificationTime'] ?? json['lastModificationTime'])?.toString(),
      lastModifierId: (target['lastModifierId'] ?? json['lastModifierId'])?.toString(),
      planDate: (target['planDate'] ?? json['planDate'])?.toString(),
      colorDescription: (target['colorDescription'] ?? json['colorDescription'])?.toString() ??
          (json['colorCode'] is Map ? json['colorCode']['description']?.toString() : null),
      lockFlag: (target['lockFlag'] ?? json['lockFlag']) as bool?,
      batchHeaderCode: (target['batchHeaderCode'] ?? json['batchHeaderCode'])?.toString() ??
          (target['code'] ?? json['code'])?.toString(),
      machineId: rawMachineId is int ? rawMachineId : int.tryParse(rawMachineId?.toString() ?? ''),
      colorCodeId: rawColorCode is int
          ? rawColorCode
          : int.tryParse(rawColorCode?.toString() ?? ''),
      shiftId: rawShiftId is int
          ? rawShiftId
          : int.tryParse(rawShiftId?.toString() ?? ''),
      trayDetailId: rawTrayDetailId is int
          ? rawTrayDetailId
          : int.tryParse(rawTrayDetailId?.toString() ?? ''),
      concurrencyStamp: (target['concurrencyStamp'] ?? json['concurrencyStamp'])?.toString(),
    );
  }
}
