import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/batch/model/batch_header_model.dart';

class ProductionProgressResponseModel {
  final ProductionProgress productionProgress;
  final Operation operation;
  final Shift shift;
  final MachineModel machineModel;
  final WorkOrderHeader workOrderHeader;
  final WorkOrderLine workOrderLine;
  final PrimaryTrayModel primaryTrayModel;
  final Item item;
  final Item? processedItem;
  final PlanHeader? planHeader;
  final BatchHeaderModel? batchHeader;
  final int? wipTransactionId; // ✅ Added to avoid extra API calls

  ProductionProgressResponseModel({
    required this.productionProgress,
    required this.operation,
    required this.shift,
    required this.machineModel,
    required this.workOrderHeader,
    required this.workOrderLine,
    required this.primaryTrayModel,
    required this.item,
    this.processedItem,
    this.planHeader,
    this.batchHeader,
    this.wipTransactionId,
  });

  factory ProductionProgressResponseModel.fromJson(Map<String, dynamic> json) {
    // Resolve wipTransactionId from various possible nested locations
    int? resolvedWipId;
    if (json.containsKey('wipTransactionId')) {
      resolvedWipId = int.tryParse(json['wipTransactionId']?.toString() ?? '');
    } else if (json.containsKey('wipTransaction')) {
      resolvedWipId = int.tryParse(json['wipTransaction']['id']?.toString() ?? '');
    }

    return ProductionProgressResponseModel(
      productionProgress: ProductionProgress.fromJson(json['productionProgress'] ?? {}),
      operation: Operation.fromJson(json['operation'] ?? {}),
      shift: Shift.fromJson(json['shift'] ?? {}),
      machineModel: MachineModel.fromJson(json['machine'] ?? {}),
      workOrderHeader: WorkOrderHeader.fromJson(json['workOrderHeader'] ?? {}),
      workOrderLine: WorkOrderLine.fromJson(json['workOrderLine'] ?? {}),
      item: Item.fromJson(json['item'] ?? {}),
      processedItem: json['processedItem'] != null ? Item.fromJson(json['processedItem']) : null,
      primaryTrayModel: PrimaryTrayModel.fromJson(json['primaryTray'] ?? {}),
      planHeader: json['planHeader'] != null ? PlanHeader.fromJson(json['planHeader']) : null,
      batchHeader: json['batchHeader'] != null ? BatchHeaderModel.fromJson(json['batchHeader']) : null,
      wipTransactionId: resolvedWipId,
    );
  }

  ProductionProgressResponseModel copyWith({
    ProductionProgress? productionProgress,
    Operation? operation,
    Shift? shift,
    MachineModel? machineModel,
    WorkOrderHeader? workOrderHeader,
    WorkOrderLine? workOrderLine,
    PrimaryTrayModel? primaryTrayModel,
    Item? item,
    Item? processedItem,
    PlanHeader? planHeader,
    BatchHeaderModel? batchHeader,
  }) {
    return ProductionProgressResponseModel(
      productionProgress: productionProgress ?? this.productionProgress,
      operation: operation ?? this.operation,
      shift: shift ?? this.shift,
      machineModel: machineModel ?? this.machineModel,
      workOrderHeader: workOrderHeader ?? this.workOrderHeader,
      workOrderLine: workOrderLine ?? this.workOrderLine,
      primaryTrayModel: primaryTrayModel ?? this.primaryTrayModel,
      item: item ?? this.item,
      processedItem: processedItem ?? this.processedItem,
      planHeader: planHeader ?? this.planHeader,
      batchHeader: batchHeader ?? this.batchHeader,
    );
  }
}
