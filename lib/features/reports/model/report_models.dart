import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';

// ---------------------------------------------------------------------------
// 0. Batch Line API Model
// ---------------------------------------------------------------------------
class BatchLine {
  final int? id;
  final int? batchHeaderId;
  final int? workOrderHeaderId;
  final int? workOrderLineId;
  final int? garmentTube;
  final double? planQuantity;
  final double? knittingMargin;
  final double? dyeingMargin;
  final double? stitchingMargin;

  BatchLine({
    this.id,
    this.batchHeaderId,
    this.workOrderHeaderId,
    this.workOrderLineId,
    this.garmentTube,
    this.planQuantity,
    this.knittingMargin,
    this.dyeingMargin,
    this.stitchingMargin,
  });

  factory BatchLine.fromJson(Map<String, dynamic> json) {
    return BatchLine(
      id: (json['id'] as num?)?.toInt(),
      batchHeaderId: (json['batchHeaderId'] as num?)?.toInt(),
      workOrderHeaderId: (json['workOrderHeaderId'] as num?)?.toInt(),
      workOrderLineId: (json['workOrderLineId'] as num?)?.toInt(),
      garmentTube: (json['garmentTube'] as num?)?.toInt() ?? (json['tubes'] as num?)?.toInt(),
      planQuantity: (json['planQuantity'] as num?)?.toDouble() ?? (json['quantity'] as num?)?.toDouble(),
      knittingMargin: (json['knittingMargin'] as num?)?.toDouble(),
      dyeingMargin: (json['dyeingMargin'] as num?)?.toDouble(),
      stitchingMargin: (json['stitchingMargin'] as num?)?.toDouble(),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Knitting Report Item Model
// ---------------------------------------------------------------------------
class KnittingReportItem {
  final PlanLine planLine;
  final MachineModel? machine;
  final Shift? shift;
  final WorkOrderHeader? workOrderHeader;
  final Item? item;
  final double planWeight;
  final double planTubes;
  final double actualWeight;
  final double actualTubes;
  final double sampleQty;
  final double cGradeQty;
  final double cycleTime;
  final double completionPercentage;

  KnittingReportItem({
    required this.planLine,
    this.machine,
    this.shift,
    this.workOrderHeader,
    this.item,
    required this.planWeight,
    required this.planTubes,
    required this.actualWeight,
    required this.actualTubes,
    required this.sampleQty,
    required this.cGradeQty,
    required this.cycleTime,
    required this.completionPercentage,
  });
}

// ---------------------------------------------------------------------------
// 2. Work Order Report Item Model
// ---------------------------------------------------------------------------
class WorkOrderReportItem {
  final int workOrderHeaderId;
  final String workOrderCode;
  final String? customerPo;
  final String? workOrderDate;
  final String? status;
  final double requiredTubes;
  final double planTubes;
  final double knittedTubes;
  final double packedTubes;
  final int totalBatches;
  final int completedBatches;
  final double knittingMargin;
  final double dyeingMargin;
  final double stitchingMargin;
  final double progressPercent;

  WorkOrderReportItem({
    required this.workOrderHeaderId,
    required this.workOrderCode,
    this.customerPo,
    this.workOrderDate,
    this.status,
    required this.requiredTubes,
    required this.planTubes,
    required this.knittedTubes,
    required this.packedTubes,
    required this.totalBatches,
    required this.completedBatches,
    required this.knittingMargin,
    required this.dyeingMargin,
    required this.stitchingMargin,
    required this.progressPercent,
  });
}

// ---------------------------------------------------------------------------
// 3. Batch Report Item Model
// ---------------------------------------------------------------------------
class BatchReportItem {
  final LotHeaderModel batchHeader;
  final String batchCode;
  final String planDate;
  final String colorDescription;
  final bool isLocked;
  final int? trayDetailId;
  final String? trolleyCode;
  final bool isTrolleyFreed; // True if reassigned/freed at lapping
  final double totalWeight;
  final double totalTubes;
  final int totalTrays;
  final int reworkCount;
  final int holdCount;
  final int defectCount;
  final String currentOperation;
  final String statusBadge;

  BatchReportItem({
    required this.batchHeader,
    required this.batchCode,
    required this.planDate,
    required this.colorDescription,
    required this.isLocked,
    this.trayDetailId,
    this.trolleyCode,
    required this.isTrolleyFreed,
    required this.totalWeight,
    required this.totalTubes,
    required this.totalTrays,
    required this.reworkCount,
    required this.holdCount,
    required this.defectCount,
    required this.currentOperation,
    required this.statusBadge,
  });
}

// ---------------------------------------------------------------------------
// 4. Induction Report Item Model
// ---------------------------------------------------------------------------
class InductionReportItem {
  final ProductionProgress progress;
  final String trayCode;
  final String locatorName;
  final String workOrderCode;
  final String itemDescription;
  final String colorDescription;
  final String sizeDescription;
  final double weight;
  final double tubes;
  final int productGrade; // 1 = Grade A, 2 = Grade B, etc.
  final DateTime? inductionDate;
  final bool isBatched;
  final int? batchHeaderId;

  InductionReportItem({
    required this.progress,
    required this.trayCode,
    required this.locatorName,
    required this.workOrderCode,
    required this.itemDescription,
    required this.colorDescription,
    required this.sizeDescription,
    required this.weight,
    required this.tubes,
    required this.productGrade,
    this.inductionDate,
    required this.isBatched,
    this.batchHeaderId,
  });
}

// ---------------------------------------------------------------------------
// 5. Tray & Trolley Report Item Model
// ---------------------------------------------------------------------------
class TrayTrolleyReportItem {
  final TrayDetail trayDetail;
  final String assetCode;
  final String assetType; // 'Tray' or 'Trolley'
  final bool isActive;
  final bool isReAssigned;
  final String status; // 'Available / Free', 'In Use', 'Inactive'
  final String? currentBatchCode;
  final String? currentWorkOrderCode;
  final String? locatorName;
  final double quantity;
  final DateTime? lastActiveTime;

  TrayTrolleyReportItem({
    required this.trayDetail,
    required this.assetCode,
    required this.assetType,
    required this.isActive,
    required this.isReAssigned,
    required this.status,
    this.currentBatchCode,
    this.currentWorkOrderCode,
    this.locatorName,
    required this.quantity,
    this.lastActiveTime,
  });
}
