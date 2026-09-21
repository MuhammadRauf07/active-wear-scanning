import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class WasteOperationOption {
  final String key;
  final String label;
  final int? operationId;
  final String? stageType; // 'batch', 'adjustments', or null
  final int count;
  final int totalTubes;

  const WasteOperationOption({
    required this.key,
    required this.label,
    this.operationId,
    this.stageType,
    this.count = 0,
    this.totalTubes = 0,
  });

  WasteOperationOption copyWith({
    String? key,
    String? label,
    int? operationId,
    String? stageType,
    int? count,
    int? totalTubes,
  }) {
    return WasteOperationOption(
      key: key ?? this.key,
      label: label ?? this.label,
      operationId: operationId ?? this.operationId,
      stageType: stageType ?? this.stageType,
      count: count ?? this.count,
      totalTubes: totalTubes ?? this.totalTubes,
    );
  }
}

class BatchWasteGroupItem {
  final String id;
  final int? batchHeaderId;
  final String batchCode;
  final int? workOrderHeaderId;
  final String workOrderCode;
  final int? workOrderLineId;
  final int? operationId;
  final String operationName;
  final String stageName; // e.g. "Lapping (Batch)", "Lapping (Adjustments)", "Heat Setting"
  final String stageKey; // e.g. "lapping_batch", "lapping_adjustments", "op_14"
  final String itemDescription;
  final String sizeDescription;
  final String colorDescription;
  final int totalTubes;
  final double totalPrimaryQty;
  final int? sourceLocatorId;
  final String productGrade;
  final List<ProductionProgressResponseModel> progressItems;
  final List<Map<String, dynamic>> rawProgressMaps;

  const BatchWasteGroupItem({
    required this.id,
    this.batchHeaderId,
    required this.batchCode,
    this.workOrderHeaderId,
    required this.workOrderCode,
    this.workOrderLineId,
    this.operationId,
    required this.operationName,
    required this.stageName,
    required this.stageKey,
    required this.itemDescription,
    required this.sizeDescription,
    required this.colorDescription,
    required this.totalTubes,
    required this.totalPrimaryQty,
    this.sourceLocatorId,
    required this.productGrade,
    required this.progressItems,
    required this.rawProgressMaps,
  });
}

class ProcessingWasteState {
  final bool isLoading;
  final String? errorMessage;
  final List<Operation> operations;
  final List<WasteOperationOption> operationOptions;
  final String selectedOperationKey;
  final List<BatchWasteGroupItem> allBatchGroups;
  final Set<String> selectedBatchGroupIds;
  final String searchQuery;

  const ProcessingWasteState({
    this.isLoading = false,
    this.errorMessage,
    this.operations = const [],
    this.operationOptions = const [
      WasteOperationOption(key: 'all', label: 'All Operations'),
    ],
    this.selectedOperationKey = 'all',
    this.allBatchGroups = const [],
    this.selectedBatchGroupIds = const {},
    this.searchQuery = '',
  });

  List<BatchWasteGroupItem> get filteredBatchGroups {
    return allBatchGroups.where((batch) {
      // Operation filter
      if (selectedOperationKey != 'all') {
        if (selectedOperationKey.startsWith('lapping_')) {
          if (batch.stageKey != selectedOperationKey) return false;
        } else if (selectedOperationKey.startsWith('op_')) {
          final targetOpId = int.tryParse(selectedOperationKey.replaceFirst('op_', ''));
          if (batch.operationId != targetOpId) return false;
        } else {
          if (batch.stageKey != selectedOperationKey) return false;
        }
      }

      // Search query filter
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final matchWO = batch.workOrderCode.toLowerCase().contains(q);
        final matchBatch = batch.batchCode.toLowerCase().contains(q);
        final matchItem = batch.itemDescription.toLowerCase().contains(q);
        final matchStage = batch.stageName.toLowerCase().contains(q);
        final matchSize = batch.sizeDescription.toLowerCase().contains(q);
        if (!matchWO && !matchBatch && !matchItem && !matchStage && !matchSize) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool get isAllSelected {
    final filtered = filteredBatchGroups;
    if (filtered.isEmpty) return false;
    return filtered.every((b) => selectedBatchGroupIds.contains(b.id));
  }

  int get selectedTubesCount {
    int total = 0;
    for (final batch in allBatchGroups) {
      if (selectedBatchGroupIds.contains(batch.id)) {
        total += batch.totalTubes;
      }
    }
    return total;
  }

  int get selectedBatchesCount {
    return selectedBatchGroupIds.length;
  }

  ProcessingWasteState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Operation>? operations,
    List<WasteOperationOption>? operationOptions,
    String? selectedOperationKey,
    List<BatchWasteGroupItem>? allBatchGroups,
    Set<String>? selectedBatchGroupIds,
    String? searchQuery,
    bool clearError = false,
  }) {
    return ProcessingWasteState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      operations: operations ?? this.operations,
      operationOptions: operationOptions ?? this.operationOptions,
      selectedOperationKey: selectedOperationKey ?? this.selectedOperationKey,
      allBatchGroups: allBatchGroups ?? this.allBatchGroups,
      selectedBatchGroupIds: selectedBatchGroupIds ?? this.selectedBatchGroupIds,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
