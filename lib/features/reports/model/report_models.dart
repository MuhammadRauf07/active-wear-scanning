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
// 1. Work Order Full Status Report Models (Exact Match with Reference)
// ---------------------------------------------------------------------------
class WorkOrderHeaderSummary {
  final int id;
  final String workOrderCode;
  final String workOrderDate;
  final String description;
  final String customer;
  final String brand;
  final String style;
  final String? customerPo;
  final String? crdStartDate;
  final String? crdEndDate;
  final String status;
  final bool isLocked;
  final int totalBatches;
  final double totalRequiredTubes;
  final double totalPlannedTubes;
  final double totalKnittedTubes;

  WorkOrderHeaderSummary({
    required this.id,
    required this.workOrderCode,
    required this.workOrderDate,
    required this.description,
    required this.customer,
    required this.brand,
    required this.style,
    this.customerPo,
    this.crdStartDate,
    this.crdEndDate,
    required this.status,
    required this.isLocked,
    required this.totalBatches,
    required this.totalRequiredTubes,
    required this.totalPlannedTubes,
    required this.totalKnittedTubes,
  });
}

class WorkOrderItemColorStatusRow {
  final String itemDescription;
  final String sizeDescription;
  final String colorDescription;
  final String processedItemDescription;

  // Header metric tags
  final double woRequiredTubes; // WO.TB
  final double knitPlanTubes;   // P.TB
  final double knitAGradeTubes; // A.TB
  final double knitCGradeTubes; // C.TB
  final double sampleTubes;     // S.TB
  final int gbsReceivedTrays;   // GBS.TR
  final double gbsReceivedTubes;// GBS.TB
  final double gbsStockTubes;   // GBS.STK.TB

  // Stage Breakdown Columns (Trays, Tubes)
  final int freshLotMakingTrays;
  final double freshLotMakingTubes;

  final int reassignedLotMakingTrays;
  final double reassignedLotMakingTubes;

  final int freshWipTrays;
  final double freshWipTubes;

  final int reassignedWipTrays;
  final double reassignedWipTubes;

  final int readyToReceiveTrays;
  final double readyToReceiveTubes;

  final int riReceivedTrays;
  final double riReceivedTubes;

  final int riStockTrays;
  final double riStockTubes;

  final double allocatedTubes;

  WorkOrderItemColorStatusRow({
    required this.itemDescription,
    required this.sizeDescription,
    required this.colorDescription,
    required this.processedItemDescription,
    required this.woRequiredTubes,
    required this.knitPlanTubes,
    required this.knitAGradeTubes,
    required this.knitCGradeTubes,
    required this.sampleTubes,
    required this.gbsReceivedTrays,
    required this.gbsReceivedTubes,
    required this.gbsStockTubes,
    required this.freshLotMakingTrays,
    required this.freshLotMakingTubes,
    required this.reassignedLotMakingTrays,
    required this.reassignedLotMakingTubes,
    required this.freshWipTrays,
    required this.freshWipTubes,
    required this.reassignedWipTrays,
    required this.reassignedWipTubes,
    required this.readyToReceiveTrays,
    required this.readyToReceiveTubes,
    required this.riReceivedTrays,
    required this.riReceivedTubes,
    required this.riStockTrays,
    required this.riStockTubes,
    required this.allocatedTubes,
  });
}

// ---------------------------------------------------------------------------
// 2. Batch Report Item Model
// ---------------------------------------------------------------------------
class BatchReportItem {
  final LotHeaderModel batchHeader;
  final String batchCode;
  final String planDate;
  final String colorDescription;
  final bool isLocked;
  final int? trayDetailId;
  final String? trolleyCode;
  final bool isTrolleyFreed;
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
// 3. Induction Report Item Model
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
  final int productGrade;
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
// 4. Tray & Trolley Report Item Model
// ---------------------------------------------------------------------------
class TrayTrolleyReportItem {
  final TrayDetail trayDetail;
  final String assetCode;
  final String assetType;
  final bool isActive;
  final bool isReAssigned;
  final String status;
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
