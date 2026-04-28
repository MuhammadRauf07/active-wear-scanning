import 'package:active_wear_scanning/features/common-models/common_models.dart';

class TrayTrackingDetailModel extends TrayDetail {
  TrayTrackingDetailModel({
    super.description,
    super.active,
    super.trayCode,
    super.trayQuantity,
    super.productGrade,
    super.productNature,
    super.trayType,
    super.shiftId,
    super.planLineId,
    super.resourceId,
    super.workOrderHeaderId,
    super.workOrderLineId,
    super.knitItemId,
    super.locatorId,
    super.batchHeaderId,
    super.batchLinesId,
    super.concurrencyStamp,
    super.lastModificationTime,
    super.lastModifierId,
    super.creationTime,
    super.creatorId,
    super.isReAssigned,
    super.id,
  });

  factory TrayTrackingDetailModel.fromJson(Map<String, dynamic> json) {
    final base = TrayDetail.fromJson(json);
    return TrayTrackingDetailModel(
      description: base.description,
      active: base.active,
      trayCode: base.trayCode,
      trayQuantity: base.trayQuantity,
      productGrade: base.productGrade,
      productNature: base.productNature,
      trayType: base.trayType,
      shiftId: base.shiftId,
      planLineId: base.planLineId,
      resourceId: base.resourceId,
      workOrderHeaderId: base.workOrderHeaderId,
      workOrderLineId: base.workOrderLineId,
      knitItemId: base.knitItemId,
      locatorId: base.locatorId,
      batchHeaderId: base.batchHeaderId,
      batchLinesId: base.batchLinesId,
      concurrencyStamp: base.concurrencyStamp,
      lastModificationTime: base.lastModificationTime,
      lastModifierId: base.lastModifierId,
      creationTime: base.creationTime,
      creatorId: base.creatorId,
      isReAssigned: base.isReAssigned,
      id: base.id,
    );
  }
}
