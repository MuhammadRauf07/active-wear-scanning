import 'package:flutter/foundation.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/model/processing_waste_state.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/repo/processing_waste_repo.dart';
import 'package:active_wear_scanning/features/wip/model/wip_model.dart';

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
      final Set<int> processingOpIds = operations.isNotEmpty
          ? operations.map((o) => o.id).toSet()
          : {5, 7, 8, 12, 14, 16};
      final Map<int, Operation> opMap = {for (var op in operations) op.id: op};

      // 2. Fetch Locators of those operations whose processing nature is 1
      final Map<int, LocatorResponse> locMap = {};
      final locRes = await _repo.fetchLocators();
      if (locRes.success && locRes.data != null) {
        final List<LocatorResponse> allLocs = List<LocatorResponse>.from(locRes.data);
        for (final l in allLocs) {
          if (l.locator.active == false) continue;
          if (l.locator.id == 18) continue; // Exclude destination waste store

          // Resolve operationId for this locator
          int? opId = l.locator.operationId ?? l.operation?.id;
          if (opId == null) {
            if (l.locator.id == 23 || l.locator.id == 8) {
              opId = 7;
            } else if (l.locator.id == 6) {
              opId = 5;
            } else if (l.locator.id == 22) {
              opId = 12;
            } else if (l.locator.id == 20) {
              opId = 14;
            } else if (l.locator.id == 9) {
              opId = 8;
            } else if (l.locator.id == 19) {
              opId = 16;
            }
          }

          // Strictly filter: only locators who have operation IDs whose processNature is 1
          if (opId != null && processingOpIds.contains(opId)) {
            final op = opMap[opId] ?? l.operation;
            locMap[l.locator.id] = LocatorResponse(
              locator: l.locator,
              operation: op,
              department: l.department,
            );
          }
        }
      }

      // Also ensure default locators directly attached to the 6 operations are present in locMap
      for (final op in operations) {
        final loc = op.locator;
        if (loc != null && loc.id > 0 && loc.id != 18) {
          locMap.putIfAbsent(
            loc.id,
            () => LocatorResponse(
              locator: loc,
              operation: op,
            ),
          );
        } else if (op.locatorId != null && op.locatorId! > 0 && op.locatorId != 18) {
          locMap.putIfAbsent(
            op.locatorId!,
            () => LocatorResponse(
              locator: LocatorModel(
                id: op.locatorId!,
                description: op.name,
                logicalWH: op.name,
                location: op.name,
                active: true,
                operationId: op.id,
              ),
              operation: op,
            ),
          );
        }
      }

      // Guarantee Locator 23 ("Lapping (Reassign)") is present with Op 7 (Lapping)
      if (!locMap.containsKey(23)) {
        locMap[23] = LocatorResponse(
          locator: LocatorModel(
            id: 23,
            description: "Lapping (Reassign)",
            logicalWH: "Lapping (Reassign)",
            location: "Lapping (Reassign)",
            active: true,
            departmentId: 14,
            operationId: 7,
          ),
          operation: opMap[7],
        );
      }

      // Sort locators according to operation seqNo (Heat Set -> Dye -> Tumble -> Lapping -> QA -> PBS)
      final List<LocatorResponse> processingLocators = locMap.values.toList()
        ..sort((a, b) {
          final aOpId = a.locator.operationId ?? a.operation?.id ?? (a.locator.id == 23 || a.locator.id == 8 ? 7 : 0);
          final bOpId = b.locator.operationId ?? b.operation?.id ?? (b.locator.id == 23 || b.locator.id == 8 ? 7 : 0);
          final aSeq = opMap[aOpId]?.seqNo ?? 999;
          final bSeq = opMap[bOpId]?.seqNo ?? 999;
          if (aSeq != bSeq) return aSeq.compareTo(bSeq);
          return a.locator.id.compareTo(b.locator.id);
        });

      // 3. Fetch Waste Production Progresses
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
            final locId = pp.locatorId ?? (rawProgress['locatorId'] as int?) ?? (item['locator'] is Map ? item['locator']['id'] as int? : null);
            final toLocId = (rawProgress['toLocatorId'] as int?) ?? locId;
            final wipStatus = pp.wipStatus ?? (rawProgress['wipStatus'] as int?);
            if ((locId == 18 || toLocId == 18) && wipStatus == 1) {
              continue; // Fully received into waste store
            }

            // Find matching operation (must have processNature == 1)
            Operation? opMatch;
            final targetOpId = pp.operationId ?? (model.operation.id > 0 ? model.operation.id : null);
            if (targetOpId != null && operations.isNotEmpty) {
              opMatch = operations.where((o) => o.id == targetOpId).firstOrNull;
            }

            // Only process waste for operations whose processing nature is 1 (or matching processing locator)
            final bool isProcessing = opMatch != null ||
                processingLocators.any((l) => l.locator.id == locId || (targetOpId != null && l.locator.operationId == targetOpId)) ||
                locId == 23 ||
                locId == 8 ||
                targetOpId == 7;

            if (!isProcessing) {
              continue;
            }

            // Resolve effective locator for this waste record
            int? effectiveLocId = locId;
            final subOp = (pp.subOperation ?? '').toLowerCase();
            final remarks = (pp.remarks ?? '').toLowerCase();

            if (locId == 23 || subOp.contains('reassign') || remarks.contains('reassign')) {
              effectiveLocId = 23;
            } else if (effectiveLocId == null || !locMap.containsKey(effectiveLocId)) {
              if (targetOpId == 7 || (opMatch?.name.toLowerCase().contains('lapping') ?? false)) {
                effectiveLocId = (subOp.contains('reassign') || remarks.contains('reassign')) ? 23 : 8;
              } else if (targetOpId != null) {
                final defaultLoc = processingLocators.where((l) => (l.locator.operationId ?? l.operation?.id) == targetOpId).firstOrNull;
                effectiveLocId = defaultLoc?.locator.id ?? opMatch?.locatorId ?? opMatch?.locator?.id;
              }
            }

            // Find matching locator in processingLocators
            final matchedLoc = effectiveLocId != null ? locMap[effectiveLocId] : null;

            final String locName = matchedLoc?.locator.description ??
                matchedLoc?.locator.logicalWH ??
                (effectiveLocId == 23 ? 'Lapping (Reassign)' : (effectiveLocId == 8 ? 'Lapping' : (effectiveLocId != null ? 'Locator #$effectiveLocId' : (opMatch?.name ?? 'Processing'))));

            final String opName = matchedLoc?.operation?.name ??
                opMatch?.name ??
                (effectiveLocId == 23 || effectiveLocId == 8 ? 'Lapping' : 'Processing');

            final String stageName = locName;
            final String stageKey = effectiveLocId != null ? 'loc_$effectiveLocId' : 'op_${targetOpId ?? 0}';

            // Group by batch / work order / stage
            final batchId = pp.batchHeaderId ?? model.batchHeader?.id;
            final woId = pp.workOrderHeaderId ?? (model.workOrderHeader.id > 0 ? model.workOrderHeader.id : null);
            final groupKey = '${stageKey}_b_${batchId ?? "none"}_w_${woId ?? "none"}';

            final batchCode = model.batchHeader?.batchHeaderCode ??
                (batchId != null ? 'Batch #$batchId' : (rawProgress['batchCode']?.toString() ?? 'N/A'));
            final woCode = model.workOrderHeader.description.isNotEmpty
                ? model.workOrderHeader.description
                : (model.workOrderHeader.workOrderCode.isNotEmpty
                    ? model.workOrderHeader.workOrderCode
                    : (rawProgress['workOrderDescription']?.toString() ??
                        rawProgress['workOrderCode']?.toString() ??
                        (woId != null ? 'WO #$woId' : 'N/A')));
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
                operationId: pp.operationId ?? targetOpId ?? (matchedLoc?.locator.operationId ?? (opMatch?.id ?? 7)),
                operationName: opName,
                stageName: stageName,
                stageKey: stageKey,
                itemDescription: itemDesc,
                sizeDescription: sizeDesc,
                colorDescription: colorDesc,
                sourceLocatorId: effectiveLocId,
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

      // 4. Build Locator Dropdown Options with live counts
      final List<WasteOperationOption> operationOptions = [];

      // Total count & tubes across all locators
      final int totalAllTubes = batchGroups.fold(0, (sum, b) => sum + b.totalTubes);
      operationOptions.add(WasteOperationOption(
        key: 'all',
        label: 'All Locators',
        count: batchGroups.length,
        totalTubes: totalAllTubes,
      ));

      // Add options for all locators of operations whose processNature is 1
      for (final l in processingLocators) {
        final locId = l.locator.id;
        final locName = l.locator.description ?? l.locator.logicalWH ?? 'Locator #$locId';
        final opTitle = l.operation?.name ?? operations.where((o) => o.id == l.locator.operationId).firstOrNull?.name ?? 'Processing';
        final locBatches = batchGroups.where((b) => b.sourceLocatorId == locId).toList();

        operationOptions.add(WasteOperationOption(
          key: 'loc_$locId',
          label: locName,
          operationId: l.locator.operationId ?? l.operation?.id,
          locatorId: locId,
          stageType: opTitle,
          count: locBatches.length,
          totalTubes: locBatches.fold(0, (sum, b) => sum + b.totalTubes),
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
            'operationId': pp.operationId ?? batch.operationId ?? model.operation.id,
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
          final String? stamp = (rawProgress['concurrencyStamp'] ?? pp.concurrencyStamp)?.toString();
          if (stamp != null && stamp.isNotEmpty) {
            updatePayload['concurrencyStamp'] = stamp;
          }
          updatePayload.remove('id');
          updatePayload.remove('progressCode');
          updatePayload.remove('creationTime');
          updatePayload.remove('creatorId');
          updatePayload.remove('lastModificationTime');
          updatePayload.remove('lastModifierId');
          updatePayload.remove('isFirstProcess');
          updatePayload.remove('isLastProcess');
          updatePayload.remove('lotMakingFlag');
          updatePayload.remove('processCompletionTime');

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
