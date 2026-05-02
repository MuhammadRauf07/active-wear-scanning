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
  });

  factory ProductionProgressResponseModel.fromJson(Map<String, dynamic> json) {
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
