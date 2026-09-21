import 'package:flutter/foundation.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/model/processing_waste_state.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/repo/processing_waste_repo.dart';

class ProcessingWasteController extends ChangeNotifier {
  final _repo = fromPlex<ProcessingWasteRepo>();

  ProcessingWasteState _state = const ProcessingWasteState();
  ProcessingWasteState get state => _state;

  ProcessingWasteController() {
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      // 1. Fetch Operations (only processNature == 1)
      List<Operation> operations = [];
      final opsRes = await _repo.fetchOperations();
      if (opsRes.success && opsRes.data != null) {
        final List<Operation> allOps = List<Operation>.from(opsRes.data);
        operations = allOps.where((op) => op.processNature == 1).toList()
          ..sort((a, b) {
            if (a.seqNo != null && b.seqNo != null) return a.seqNo!.compareTo(b.seqNo!);
            final aNum = int.tryParse(a.code);
            final bNum = int.tryParse(b.code);
            if (aNum != null && bNum != null) return aNum.compareTo(bNum);
            return a.name.compareTo(b.name);
          });
      }

      // 2. Fetch Waste Production Progresses
      final progressRes = await _repo.fetchProductionProgress({
        'MaxResultCount': '1000',
      });

      final List<BatchWasteGroupItem> batchGroups = [];
      final Map<String, _BatchGroupAccumulator> accumulatorMap = {};

      if (progressRes.success && progressRes.data != null) {
        final List rawList = progressRes.data is Map
            ? (progressRes.data['items'] ?? [])
            : (progressRes.data is List ? progressRes.data : []);

        for (final item in rawList) {
          if (item is! Map) continue;
          try {
            final rawProgress = item.containsKey('productionProgress') && item['productionProgress'] is Map
                ? Map<String, dynamic>.from(item['productionProgress'] as Map)
                : Map<String, dynamic>.from(item);

            final model = ProductionProgressResponseModel.fromJson(Map<String, dynamic>.from(item));
            final pp = model.productionProgress;

            // Check if this record is waste
            final double wasteVal = (pp.waste ?? 0.0) > 0
                ? pp.waste!.toDouble()
                : ((pp.subOperation ?? '').toLowerCase() == 'waste' || pp.productGrade == 2 || pp.productGrade == 1
                    ? (pp.secondaryQuantity ?? pp.primaryQuantity ?? 0.0).toDouble()
                    : 0.0);

            if (wasteVal <= 0 && (pp.subOperation ?? '').toLowerCase() != 'waste') {
              continue; // Not a waste item
            }

            // Exclude already received items
            final toLocId = pp.locatorId ?? (rawProgress['toLocatorId'] as int?);
            final locId = pp.locatorId ?? (rawProgress['locatorId'] as int?);
            final wipStatus = pp.wipStatus ?? (rawProgress['wipStatus'] as int?);
            if (locId == 18 && toLocId == 18 && wipStatus == 1) {
              continue; // Fully received
            }

            // Find matching operation (must have processNature == 1)
            Operation? opMatch;
            final targetOpId = pp.operationId ?? (model.operation.id > 0 ? model.operation.id : null);
            if (targetOpId != null && operations.isNotEmpty) {
              opMatch = operations.where((o) => o.id == targetOpId).firstOrNull;
            }

            // Only process waste for operations whose processing nature is 1
            if (opMatch == null) {
              continue;
            }

            final opName = opMatch.name.isNotEmpty
                ? opMatch.name
                : (model.operation.name.isNotEmpty ? model.operation.name : 'Operation #${pp.operationId ?? "N/A"}');

            // Categorize into stage
            String stageName;
            String stageKey;
            if (opName.toLowerCase().contains('lapping')) {
              final subOp = (pp.subOperation ?? '').toLowerCase();
              final remarks = (pp.remarks ?? '').toLowerCase();
              if (subOp.contains('adjust') || remarks.contains('adjust')) {
                stageName = 'Lapping (Adjustments)';
                stageKey = 'lapping_adjustments';
              } else {
                stageName = 'Lapping (Batch)';
                stageKey = 'lapping_batch';
              }
            } else {
              stageName = opName;
              stageKey = 'op_${pp.operationId ?? 0}';
            }

            // Group by batch / work order / stage
            final batchId = pp.batchHeaderId ?? model.batchHeader?.id;
            final woId = pp.workOrderHeaderId ?? (model.workOrderHeader.id > 0 ? model.workOrderHeader.id : null);
            final groupKey = '${stageKey}_b_${batchId ?? "none"}_w_${woId ?? "none"}';

            final batchCode = model.batchHeader?.batchHeaderCode ??
                (batchId != null ? 'Batch #$batchId' : (rawProgress['batchCode']?.toString() ?? 'N/A'));
            final woCode = model.workOrderHeader.workOrderCode.isNotEmpty
                ? model.workOrderHeader.workOrderCode
                : (rawProgress['workOrderCode']?.toString() ?? (woId != null ? 'WO #$woId' : 'N/A'));
            final itemDesc = model.item.description.isNotEmpty
                ? model.item.description
                : ((model.processedItem != null && model.processedItem!.description.isNotEmpty)
                    ? model.processedItem!.description
                    : (rawProgress['itemDescription']?.toString() ?? 'N/A'));
            final sizeDesc = model.item.sizeDescription ?? (rawProgress['sizeDescription']?.toString() ?? 'N/A');
            final colorDesc = model.item.colorDescription ?? (rawProgress['colorDescription']?.toString() ?? 'N/A');
            final gradeStr = pp.productGrade == 2 ? 'Grade C' : (pp.productGrade == 1 ? 'Grade B' : 'Grade A');

            if (!accumulatorMap.containsKey(groupKey)) {
              accumulatorMap[groupKey] = _BatchGroupAccumulator(
                id: groupKey,
                batchHeaderId: batchId,
                batchCode: batchCode,
                workOrderHeaderId: woId,
                workOrderCode: woCode,
                workOrderLineId: pp.workOrderLineId ?? model.workOrderLine.id,
                operationId: pp.operationId ?? opMatch.id,
                operationName: opName,
                stageName: stageName,
                stageKey: stageKey,
                itemDescription: itemDesc,
                sizeDescription: sizeDesc,
                colorDescription: colorDesc,
                sourceLocatorId: locId,
                productGrade: gradeStr,
              );
            }

            final acc = accumulatorMap[groupKey]!;
            acc.totalTubes += wasteVal.round();
            acc.totalPrimaryQty += (pp.primaryQuantity ?? wasteVal).toDouble();
            acc.progressItems.add(model);
            acc.rawProgressMaps.add(rawProgress);
          } catch (e) {
            debugPrint("⚠️ Skipping invalid waste progress entry: $e");
          }
        }
      }

      for (final acc in accumulatorMap.values) {
        batchGroups.add(acc.toBatchWasteGroupItem());
      }

      // Sort batches by batchCode and stageName
      batchGroups.sort((a, b) => a.batchCode.compareTo(b.batchCode));

      // 3. Build Operation Dropdown Options with live counts
      final List<WasteOperationOption> operationOptions = [];

      // Total count & tubes across all operations
      final int totalAllTubes = batchGroups.fold(0, (sum, b) => sum + b.totalTubes);
      operationOptions.add(WasteOperationOption(
        key: 'all',
        label: 'All Operations',
        count: batchGroups.length,
        totalTubes: totalAllTubes,
      ));

      // Lapping stages
      final lappingBatchList = batchGroups.where((b) => b.stageKey == 'lapping_batch').toList();
      final lappingAdjList = batchGroups.where((b) => b.stageKey == 'lapping_adjustments').toList();

      operationOptions.add(WasteOperationOption(
        key: 'lapping_batch',
        label: 'Lapping (Batch)',
        stageType: 'batch',
        count: lappingBatchList.length,
        totalTubes: lappingBatchList.fold(0, (sum, b) => sum + b.totalTubes),
      ));

      operationOptions.add(WasteOperationOption(
        key: 'lapping_adjustments',
        label: 'Lapping (Adjustments)',
        stageType: 'adjustments',
        count: lappingAdjList.length,
        totalTubes: lappingAdjList.fold(0, (sum, b) => sum + b.totalTubes),
      ));

      // Other operations
      for (final op in operations) {
        if (op.name.toLowerCase().contains('lapping')) continue;
        final opKey = 'op_${op.id}';
        final opBatches = batchGroups.where((b) => b.operationId == op.id || b.stageKey == opKey).toList();
        operationOptions.add(WasteOperationOption(
          key: opKey,
          label: op.name,
          operationId: op.id,
          count: opBatches.length,
          totalTubes: opBatches.fold(0, (sum, b) => sum + b.totalTubes),
        ));
      }

      // Preserve or reset selection
      final currentSelectedKey = _state.selectedOperationKey;
      final validKey = operationOptions.any((o) => o.key == currentSelectedKey) ? currentSelectedKey : 'all';

      _state = _state.copyWith(
        isLoading: false,
        operations: operations,
        operationOptions: operationOptions,
        selectedOperationKey: validKey,
        allBatchGroups: batchGroups,
        selectedBatchGroupIds: {},
      );
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString());
    } finally {
      notifyListeners();
    }
  }

  void selectOperationFilter(String key) {
    if (_state.selectedOperationKey != key) {
      _state = _state.copyWith(
        selectedOperationKey: key,
        selectedBatchGroupIds: {}, // Clear selection on filter change
      );
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _state = _state.copyWith(searchQuery: query);
    notifyListeners();
  }

  void toggleBatchSelection(String batchGroupId) {
    final updated = Set<String>.from(_state.selectedBatchGroupIds);
    if (updated.contains(batchGroupId)) {
      updated.remove(batchGroupId);
    } else {
      updated.add(batchGroupId);
    }
    _state = _state.copyWith(selectedBatchGroupIds: updated);
    notifyListeners();
  }

  void toggleSelectAll(bool selected) {
    final updated = Set<String>.from(_state.selectedBatchGroupIds);
    final visibleBatches = _state.filteredBatchGroups;

    if (selected) {
      for (final batch in visibleBatches) {
        updated.add(batch.id);
      }
    } else {
      for (final batch in visibleBatches) {
        updated.remove(batch.id);
      }
    }

    _state = _state.copyWith(selectedBatchGroupIds: updated);
    notifyListeners();
  }

  Future<void> receiveWaste() async {
    if (_state.selectedBatchGroupIds.isEmpty) return;

    _state = _state.copyWith(isLoading: true, clearError: false);
    notifyListeners();

    int successBatches = 0;
    final List<String> failedBatches = [];

    try {
      final selectedBatches = _state.allBatchGroups.where((b) => _state.selectedBatchGroupIds.contains(b.id)).toList();

      for (final batch in selectedBatches) {
        bool batchFailed = false;

        for (int i = 0; i < batch.progressItems.length; i++) {
          final model = batch.progressItems[i];
          final rawProgress = i < batch.rawProgressMaps.length ? batch.rawProgressMaps[i] : <String, dynamic>{};
          final pp = model.productionProgress;
          final progressId = pp.id ?? (rawProgress['id'] as int?);

          if (progressId == null || progressId == 0) {
            batchFailed = true;
            failedBatches.add('${batch.batchCode} (Missing progress ID)');
            break;
          }

          final double wasteQty = (pp.waste ?? 0.0) > 0
              ? pp.waste!.toDouble()
              : (pp.secondaryQuantity ?? pp.primaryQuantity ?? 0.0).toDouble();

          final double primaryQty = (pp.primaryQuantity ?? wasteQty).toDouble();

          // 1. Post WIP Transaction to Locator 18 (Processing Waste Store)
          final wipPayload = <String, dynamic>{
            'subOperation': batch.stageName,
            'transactionDate': DateTime.now().toIso8601String(),
            'transactionType': 0, // 0 = Receipt / In
            'quality': '\u0000',
            'uom': pp.secondaryUOM ?? 1,
            'operatorDescription': 'system',
            'primaryQuantity': primaryQty,
            'secondaryQuantity': wasteQty,
            'operationId': pp.operationId ?? model.operation.id,
            'shiftId': pp.shiftId ?? 1,
            'locatorId': 18, // Locator 18 = Processing Waste Store
            'toLocatorId': 18,
            'isTransfer': false,
            'workOrderHeaderId': pp.workOrderHeaderId ?? model.workOrderHeader.id,
            'workOrderLineId': pp.workOrderLineId ?? model.workOrderLine.id,
            'itemId': pp.itemId ?? model.item.id,
            'batchHeaderId': pp.batchHeaderId ?? model.batchHeader?.id ?? batch.batchHeaderId,
            'progressId': progressId,
          };

          final wipRes = await _repo.createWipTransaction(wipPayload);
          if (!wipRes.success) {
            batchFailed = true;
            failedBatches.add('${batch.batchCode} (WIP-fail: ${wipRes.message})');
            break;
          }

          // 2. Update Production Progress record to Locator 18
          final updatePayload = Map<String, dynamic>.from(rawProgress);
          updatePayload['locatorId'] = 18;
          updatePayload['toLocatorId'] = 18;
          updatePayload['wipStatus'] = 1; // Received status
          updatePayload.remove('id');
          updatePayload.remove('progressCode');
          updatePayload.remove('creationTime');
          updatePayload.remove('creatorId');
          updatePayload.remove('lastModificationTime');
          updatePayload.remove('lastModifierId');

          final updateRes = await _repo.updateProductionProgress(progressId, updatePayload);
          if (!updateRes.success) {
            batchFailed = true;
            failedBatches.add('${batch.batchCode} (Progress-update-fail: ${updateRes.message})');
            break;
          }
        }

        if (!batchFailed) {
          successBatches++;
        }
      }

      if (failedBatches.isNotEmpty) {
        throw Exception(
          'Received $successBatches batch(es) successfully. Failed: ${failedBatches.join(', ')}'
        );
      }

      // Re-fetch all data on completion
      await fetchInitialData();
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString().replaceFirst('Exception: ', ''));
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}

class _BatchGroupAccumulator {
  final String id;
  final int? batchHeaderId;
  final String batchCode;
  final int? workOrderHeaderId;
  final String workOrderCode;
  final int? workOrderLineId;
  final int? operationId;
  final String operationName;
  final String stageName;
  final String stageKey;
  final String itemDescription;
  final String sizeDescription;
  final String colorDescription;
  final int? sourceLocatorId;
  final String productGrade;
  int totalTubes;
  double totalPrimaryQty;
  final List<ProductionProgressResponseModel> progressItems;
  final List<Map<String, dynamic>> rawProgressMaps;

  _BatchGroupAccumulator({
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
    this.sourceLocatorId,
    required this.productGrade,
  })  : totalTubes = 0,
        totalPrimaryQty = 0.0,
        progressItems = [],
        rawProgressMaps = [];

  BatchWasteGroupItem toBatchWasteGroupItem() {
    return BatchWasteGroupItem(
      id: id,
      batchHeaderId: batchHeaderId,
      batchCode: batchCode,
      workOrderHeaderId: workOrderHeaderId,
      workOrderCode: workOrderCode,
      workOrderLineId: workOrderLineId,
      operationId: operationId,
      operationName: operationName,
      stageName: stageName,
      stageKey: stageKey,
      itemDescription: itemDescription,
      sizeDescription: sizeDescription,
      colorDescription: colorDescription,
      totalTubes: totalTubes,
      totalPrimaryQty: totalPrimaryQty,
      sourceLocatorId: sourceLocatorId,
      productGrade: productGrade,
      progressItems: List.unmodifiable(progressItems),
      rawProgressMaps: List.unmodifiable(rawProgressMaps),
    );
  }
}
