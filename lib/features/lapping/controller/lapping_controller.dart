import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/lapping/model/lapping_model.dart';
import 'package:active_wear_scanning/features/lapping/model/work_order_summary.dart';
import 'package:active_wear_scanning/features/lapping/model/lapping_state.dart';
import 'package:active_wear_scanning/features/lapping/repo/lapping_repo.dart';
import 'package:active_wear_scanning/features/lot_making/repo/lot_repo.dart';
import 'package:active_wear_scanning/features/processing/repo/processing_repo.dart';

class LappingController extends ChangeNotifier {
  final _processingRepo = ProcessingRepo();
  final _lotRepo = LotRepo();
  final _lappingRepo = LappingRepo();

  final int batchHeaderId;
  final String batchCode;
  final int? machineId;
  final String machine;
  final String color;
  final int trayCount;
  final double totalWeight;
  final int currentOperationId;
  final int? nextOperationId;
  final String nextOperationName;

  LappingState _state = const LappingState();
  LappingState get state => _state;

  LappingController({
    required this.batchHeaderId,
    required this.batchCode,
    required this.machineId,
    required this.machine,
    required this.color,
    required this.trayCount,
    required this.totalWeight,
    required this.currentOperationId,
    required this.nextOperationId,
    required this.nextOperationName,
  }) {
    fetchBatchData();
  }

  bool get hasPreviousProcess => currentOperationId > 1;

  void setSelectedWorkOrderId(String? id) {
    _state = _state.copyWith(selectedWorkOrderId: id);
    notifyListeners();
  }

  Future<void> fetchBatchData() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final res = await _lappingRepo.fetchProductionProgress({
        'BatchHeaderId': batchHeaderId.toString(),
        'TransactionType': '2',
      });

      if (res.success && res.data != null) {
        final List<LappingModel> rawTrays = List<LappingModel>.from(res.data);

        final Map<String, LappingModel> uniqueTrays = {};
        final Map<String, List<LappingModel>> draftScannedTraysByWO = {};
        final Map<String, double> draftOverrides = {};
        final Map<String, double> loadedWasteQuantities = {};
        final Map<String, int?> loadedWasteProgressIds = {};
        final Map<String, int> loadedBatchLineIds = {};

        // Fetch batch lines for this batch header
        final List<Map<String, dynamic>> lotLines = [];
        final blRes = await _lotRepo.fetchLotLines(batchHeaderId: batchHeaderId);
        if (blRes.success && blRes.data != null) {
          final List rawLines = blRes.data is List ? blRes.data : [];
          lotLines.addAll(rawLines.cast<Map<String, dynamic>>());
        }

        // Reconstruct draft scanned trays list from batch lines (lotLines) where isReAssigned is true
        final draftLines = lotLines.where((line) {
          final Map blMap = line['batchLines'] ?? line;
          return blMap['isReAssigned'] == true;
        }).toList();

        for (final line in draftLines) {
          final Map bl = line['batchLines'] ?? line;
          final trayId = bl['trayId'] as int?;
          final double qty = (bl['primaryQuantity'] ?? 0.0).toDouble();
          final blId = bl['id'] as int?;
          final woId = bl['workOrderHeaderId'] as int?;
          final woLineId = bl['workOrderLineId'] as int?;
          final itemId = bl['itemId'] as int? ?? bl['processItemId'] as int?;

          if (trayId != null && woId != null) {
            final trayRes = await _lotRepo.fetchTrayDetailById(trayId);
            if (trayRes.success && trayRes.data != null) {
              final trayDetailMap = Map<String, dynamic>.from(trayRes.data['trayDetail'] ?? trayRes.data);
              final trayCode = trayDetailMap['trayCode'] as String? ?? '';
              
              final primaryTrayModel = PrimaryTrayModel(
                id: trayId,
                trayCode: trayCode,
                trayType: trayDetailMap['trayType'] as int? ?? 1,
                trayQuantity: (trayDetailMap['trayQuantity'] ?? 0.0).toDouble(),
                active: trayDetailMap['active'] as bool? ?? true,
                locatorId: trayDetailMap['locatorId'] as int?,
                isReAssigned: true,
                concurrencyStamp: trayDetailMap['concurrencyStamp'] as String?,
              );

              // Find template tray matching workOrderLineId or itemId in rawTrays to copy item-specific metadata
              final templateTray = rawTrays.firstWhere(
                (t) => (woLineId != null && t.workOrderLine.id == woLineId) ||
                       (itemId != null && (t.item.id == itemId || t.processedItem?.id == itemId)),
                orElse: () => rawTrays.firstWhere(
                  (t) => t.workOrderHeader.id == woId,
                  orElse: () => rawTrays.first,
                ),
              );

              final lappingModel = LappingModel(
                productionProgress: templateTray.productionProgress.copyWith(
                  id: bl['progressId'] as int?,
                  draftFlag: true,
                  operationId: currentOperationId,
                  transactionType: 2,
                  primaryTrayId: trayId,
                  primaryQuantity: qty,
                ),
                operation: templateTray.operation,
                item: templateTray.item,
                processedItem: templateTray.processedItem,
                machineModel: templateTray.machineModel,
                primaryTrayModel: primaryTrayModel,
                shift: templateTray.shift,
                workOrderHeader: templateTray.workOrderHeader,
                workOrderLine: templateTray.workOrderLine,
                planHeader: templateTray.planHeader,
                batchHeader: templateTray.batchHeader,
              );

              final itemDesc = lappingModel.processedItem?.description ?? lappingModel.item.description;
              if (itemDesc.isNotEmpty) {
                final compositeId = '${woId}_$itemDesc';
                draftScannedTraysByWO.putIfAbsent(compositeId, () => []);
                if (!draftScannedTraysByWO[compositeId]!.any((st) => st.primaryTrayModel.id == trayId)) {
                  draftScannedTraysByWO[compositeId]!.add(lappingModel);
                }

                final code = trayCode.toLowerCase();
                draftOverrides[code] = qty;
                if (blId != null) {
                  loadedBatchLineIds[code] = blId;
                }
              }
            }
          }
        }

        for (final tray in rawTrays) {
          if (tray.productionProgress.transactionType != 2) continue;

          // Detect waste records (no trayId, waste > 0, or subOperation = 'waste')
          if ((tray.productionProgress.subOperation ?? '').toLowerCase() == 'waste' ||
              (tray.productionProgress.waste ?? 0) > 0 ||
              tray.productionProgress.primaryTrayId == null) {
            final woId = tray.workOrderHeader.id;
            final itemDesc = tray.processedItem?.description ?? tray.item.description;
            if (itemDesc.isNotEmpty) {
              final compositeId = '${woId}_$itemDesc';
              loadedWasteQuantities[compositeId] = (tray.productionProgress.waste ?? tray.productionProgress.primaryQuantity ?? 0.0).toDouble();
              loadedWasteProgressIds[compositeId] = tray.productionProgress.id;
            }
            continue;
          }

          if (tray.productionProgress.operationId != currentOperationId) continue;

          final code = tray.primaryTrayModel.trayCode ?? 'UNKNOWN';
          if (!uniqueTrays.containsKey(code) || (tray.productionProgress.id ?? 0) > (uniqueTrays[code]!.productionProgress.id ?? 0)) {
            uniqueTrays[code] = tray;
          }
        }

        // Determine previous process operationId to find original incoming quantities
        final prevOps = rawTrays
            .map((t) => t.productionProgress.operationId)
            .where((opId) => opId != null && opId < currentOperationId)
            .toList();
        final int? prevOpId = prevOps.isEmpty ? null : prevOps.reduce((a, b) => a! > b! ? a : b);

        final Map<String, double> originalPiecesMap = {};
        for (final tray in rawTrays) {
          final isTargetOp = prevOpId != null
              ? (tray.productionProgress.operationId == prevOpId)
              : (tray.productionProgress.operationId == currentOperationId &&
                 tray.productionProgress.primaryTrayId != null);

          if (isTargetOp &&
              tray.productionProgress.transactionType == 2 &&
              (tray.productionProgress.subOperation ?? '').toLowerCase() != 'waste') {
            final woId = tray.workOrderHeader.id;
            final itemDesc = tray.processedItem?.description ?? tray.item.description;
            if (itemDesc.isNotEmpty) {
              final compositeId = '${woId}_$itemDesc';
              originalPiecesMap[compositeId] = (originalPiecesMap[compositeId] ?? 0.0) +
                  (tray.productionProgress.primaryQuantity ?? 0.0);
            }
          }
        }

        final fetchedTrays = uniqueTrays.values.toList();
        final Map<String, WorkOrderSummary> summaries = {};

        // Discover and initialize all work order summaries based on original quantities
        for (final tray in rawTrays) {
          final woId = tray.workOrderHeader.id;
          final itemDesc = tray.processedItem?.description ?? tray.item.description;
          if (itemDesc.isEmpty) continue;
          final compositeId = '${woId}_$itemDesc';

          if (!summaries.containsKey(compositeId)) {
            final origQty = originalPiecesMap[compositeId] ?? 0.0;
            summaries[compositeId] = WorkOrderSummary(
              id: compositeId,
              description: tray.workOrderHeader.description ?? '-',
              componentDescription: itemDesc,
              trayCount: 0,
              cumulativePieces: 0.0,
              originalPieces: origQty,
            );
          }
        }

        // Add available/unscanned tray counts and quantities
        for (final tray in fetchedTrays) {
          final woId = tray.workOrderHeader.id;
          final itemDesc = tray.processedItem?.description ?? tray.item.description;
          if (itemDesc.isEmpty) continue;
          final compositeId = '${woId}_$itemDesc';

          if (summaries.containsKey(compositeId)) {
            final existing = summaries[compositeId]!;
            summaries[compositeId] = WorkOrderSummary(
              id: compositeId,
              description: existing.description,
              componentDescription: existing.componentDescription,
              trayCount: existing.trayCount + 1,
              cumulativePieces: existing.cumulativePieces + (tray.productionProgress.primaryQuantity ?? 0),
              originalPieces: existing.originalPieces,
            );
          }
        }

        _state = _state.copyWith(
          trays: fetchedTrays,
          rawActiveTrays: rawTrays,
          workOrders: summaries,
          scannedTraysByWO: draftScannedTraysByWO,
          trayOverrideQuantities: draftOverrides,
          itemWasteQuantities: loadedWasteQuantities,
          itemWasteProgressIds: loadedWasteProgressIds,
          trayBatchLineIds: loadedBatchLineIds,
          resetDraftProgressIds: {},
          resetBatchLineIds: {},
          isLoading: false,
          clearSelectedWorkOrderId: true,
        );
      } else {
        _state = _state.copyWith(
          isLoading: false,
          errorMessage: res.message,
        );
      }
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    } finally {
      notifyListeners();
    }
  }

  Future<String?> onTrayScanned(String code, double inputPcs) async {
    final trayCode = code.trim().toLowerCase();
    if (trayCode.isEmpty) return 'Invalid tray code';

    final activeSummary = _state.workOrders[_state.selectedWorkOrderId];
    if (activeSummary == null) return 'No Active Work Order selected!';

    for (final woTrays in _state.scannedTraysByWO.values) {
      if (woTrays.any((t) => t.primaryTrayModel.trayCode?.toLowerCase() == trayCode)) {
        return 'Tray already scanned in this session!';
      }
    }

    final currentWOTrays = _state.scannedTraysByWO[_state.selectedWorkOrderId] ?? [];

    double totalScanned = currentWOTrays.fold(0, (sum, t) =>
        sum + (_state.trayOverrideQuantities[t.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0));

    if ((totalScanned + inputPcs) > activeSummary.cumulativePieces) {
      return 'Limit exceeded! Max: ${activeSummary.cumulativePieces}';
    }

    LappingModel? matchedTray = _state.trays.where((t) => t.primaryTrayModel.trayCode?.toLowerCase() == trayCode).firstOrNull ??
        _state.rawActiveTrays.where((t) => t.primaryTrayModel.trayCode?.toLowerCase() == trayCode).firstOrNull;

    // trayType validation — only Type 1 trays allowed
    if (matchedTray != null && (matchedTray.primaryTrayModel.trayType ?? 0) != 1) {
      return 'Invalid tray type.';
    }

    if (matchedTray == null) {
      final trayRes = await _lotRepo.fetchTrayDetailByCode(trayCode);
      if (trayRes.success && trayRes.data != null) {
        final trayMap = trayRes.data.containsKey('trayDetail') ? trayRes.data['trayDetail'] : trayRes.data;
        final int? existingBatch = trayMap['batchHeaderId'];
        if (existingBatch != null && existingBatch != 0 && existingBatch != batchHeaderId) {
          return 'Tray belongs to another batch ($existingBatch)';
        }

        final refTray = _state.trays.firstWhere((t) => '${t.workOrderHeader.id}_${t.processedItem?.description ?? t.item.description}' == _state.selectedWorkOrderId);

        matchedTray = LappingModel(
          productionProgress: ProductionProgress(
            id: null,
            primaryTrayId: trayMap['id'],
            locatorId: trayMap['locatorId'] ?? 2,
            primaryQuantity: inputPcs,
            transactionType: 2,
            processedItemId: refTray.productionProgress.processedItemId,
          ),
          operation: refTray.operation,
          shift: refTray.shift,
          machineModel: refTray.machineModel,
          workOrderHeader: refTray.workOrderHeader,
          workOrderLine: refTray.workOrderLine,
          item: refTray.item,
          processedItem: refTray.processedItem,
          primaryTrayModel: PrimaryTrayModel(
            id: trayMap['id'],
            trayCode: trayMap['trayCode'],
            concurrencyStamp: trayMap['concurrencyStamp'],
          ),
        );
      } else {
        return 'Tray not available in system!';
      }
    }

    // Fetch metadata from item-defs using main item ID
    final mainItemId = matchedTray.item.id;
    final processedItemId = matchedTray.productionProgress.processedItemId;
    String colorDesc = matchedTray.item.colorDescription ?? '';
    String sizeDesc = matchedTray.item.sizeDescription ?? '';
    double perGarmentTube = matchedTray.item.perGarmentTube;

    if (mainItemId > 0) {
      final itemRes = await _lappingRepo.fetchItemDef(mainItemId);
      if (itemRes.success && itemRes.data != null) {
        final itemData = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
        if (itemData['perGarmentTube'] != null) perGarmentTube = (itemData['perGarmentTube'] as num).toDouble();
        if (itemData['colorDescription'] != null) colorDesc = itemData['colorDescription'];
        if (itemData['sizeDescription'] != null) sizeDesc = itemData['sizeDescription'];
      }
    }

    // If color still empty, try processedItemId as fallback
    if (colorDesc.isEmpty && processedItemId != null && processedItemId > 0) {
      final processedRes = await _lappingRepo.fetchItemDef(processedItemId);
      if (processedRes.success && processedRes.data != null) {
        final pd = processedRes.data is Map ? processedRes.data as Map<String, dynamic> : {};
        if (pd['colorDescription'] != null) colorDesc = pd['colorDescription'];
        if (sizeDesc.isEmpty && pd['sizeDescription'] != null) sizeDesc = pd['sizeDescription'];
      }
    }

    // Rebuild matchedTray with enriched item
    final updatedItem = matchedTray.item.copyWith(
      colorDescription: colorDesc,
      sizeDescription: sizeDesc,
      perGarmentTube: perGarmentTube,
    );
    final double primaryPcs = perGarmentTube > 0 ? inputPcs * perGarmentTube : inputPcs;
    matchedTray = LappingModel(
      productionProgress: matchedTray.productionProgress.copyWith(
        primaryQuantity: primaryPcs,
        secondaryQuantity: inputPcs,
      ),
      operation: matchedTray.operation,
      shift: matchedTray.shift,
      machineModel: matchedTray.machineModel,
      workOrderHeader: matchedTray.workOrderHeader,
      workOrderLine: matchedTray.workOrderLine,
      primaryTrayModel: matchedTray.primaryTrayModel,
      item: updatedItem,
      processedItem: matchedTray.processedItem,
      planHeader: matchedTray.planHeader,
      batchHeader: matchedTray.batchHeader,
    );

    final updatedOverrides = Map<String, double>.from(_state.trayOverrideQuantities);
    updatedOverrides[trayCode] = inputPcs;

    final updatedScanned = Map<String, List<LappingModel>>.from(_state.scannedTraysByWO);
    updatedScanned.putIfAbsent(_state.selectedWorkOrderId!, () => []);
    updatedScanned[_state.selectedWorkOrderId!] = List<LappingModel>.from(updatedScanned[_state.selectedWorkOrderId!]!)..add(matchedTray);

    _state = _state.copyWith(
      trayOverrideQuantities: updatedOverrides,
      scannedTraysByWO: updatedScanned,
    );
    notifyListeners();
    return null;
  }

  void removeScannedTray(LappingModel t, String trayKey) {
    final updatedOverrides = Map<String, double>.from(_state.trayOverrideQuantities);
    updatedOverrides.remove(trayKey);

    final updatedScanned = Map<String, List<LappingModel>>.from(_state.scannedTraysByWO);
    final selectedId = _state.selectedWorkOrderId;
    if (selectedId != null && updatedScanned[selectedId] != null) {
      updatedScanned[selectedId] = List<LappingModel>.from(updatedScanned[selectedId]!)..remove(t);
    }

    final updatedReset = Set<int>.from(_state.resetDraftProgressIds);
    if (t.productionProgress.id != null) {
      updatedReset.add(t.productionProgress.id!);
    }

    final updatedResetLines = Set<int>.from(_state.resetBatchLineIds);
    final updatedBatchLineIds = Map<String, int>.from(_state.trayBatchLineIds);
    final code = t.primaryTrayModel.trayCode?.toLowerCase();
    if (code != null) {
      if (_state.trayBatchLineIds.containsKey(code)) {
        updatedResetLines.add(_state.trayBatchLineIds[code]!);
        updatedBatchLineIds.remove(code);
      }
    }

    _state = _state.copyWith(
      trayOverrideQuantities: updatedOverrides,
      scannedTraysByWO: updatedScanned,
      resetDraftProgressIds: updatedReset,
      resetBatchLineIds: updatedResetLines,
      trayBatchLineIds: updatedBatchLineIds,
    );
    notifyListeners();
  }

  void setWasteQuantity(String compositeId, double qty) {
    final updatedWaste = Map<String, double>.from(_state.itemWasteQuantities);
    if (qty <= 0) {
      updatedWaste.remove(compositeId);
    } else {
      updatedWaste[compositeId] = qty;
    }
    _state = _state.copyWith(itemWasteQuantities: updatedWaste);
    notifyListeners();
  }

  Future<void> retryHandover(Set<int> failedIds) {
    _state = _state.copyWith(failedHandoverTrayIds: failedIds);
    notifyListeners();
    return saveChanges();
  }

  Future<void> retryClosure(Set<int> failedIds) {
    _state = _state.copyWith(failedCloseLappingIds: failedIds);
    notifyListeners();
    return saveChanges();
  }

  void toggleReworkMode({required bool enabled}) {
    // Left for interface compatibility
  }

  Future<List<dynamic>> fetchSystemTraysAndLotMetadata() async {
    final trayRes = await _lotRepo.fetchTrayDetails();
    final headersRes = await _lotRepo.fetchLotHeaders();
    final linesRes = await _lotRepo.fetchLotLines();

    if (!trayRes.success || trayRes.data == null) {
      throw Exception('Failed to fetch system trays');
    }

    return [
      trayRes.data as List,
      headersRes.success && headersRes.data != null ? List<Map<String, dynamic>>.from(headersRes.data as List) : [],
      linesRes.success && linesRes.data != null ? List<Map<String, dynamic>>.from(linesRes.data as List) : [],
    ];
  }

  Future<void> saveChanges({bool isDraft = false}) async {
    final allScannedTrays = _state.scannedTraysByWO.values.expand((list) => list).toList();

    if (!isDraft) {
      if (allScannedTrays.isEmpty) {
        throw Exception('No Trays Scanned. Please scan at least one tray.');
      }

      // Completion validation & item-wise quantity matching validation
      for (final wo in _state.workOrders.values) {
        final compositeId = wo.id;
        final double reassignedQty = (_state.scannedTraysByWO[compositeId] ?? []).fold<double>(
          0.0,
          (sum, t) => sum + (_state.trayOverrideQuantities[t.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0.0),
        );
        final double wasteQty = _state.itemWasteQuantities[compositeId] ?? 0.0;
        final double originalQty = wo.originalPieces;

        if ((reassignedQty + wasteQty) != originalQty) {
          throw Exception(
            'Quantity mismatch for "${wo.componentDescription}".\n'
            'Came from previous process: ${originalQty.toInt()} tubes\n'
            'Reassigned scanned quantity: ${reassignedQty.toInt()} tubes\n'
            'Waste quantity entered: ${wasteQty.toInt()} tubes\n'
            'Total Scanned + Waste must equal the original incoming quantity.',
          );
        }
      }
    }

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      // --- Step 0: Delete/Reset Removed Batch Lines and Draft Progress Flags ---
      if (_state.resetBatchLineIds.isNotEmpty) {
        for (final blId in _state.resetBatchLineIds) {
          await _lotRepo.deleteLotLine(blId);
        }
      }

      if (_state.resetDraftProgressIds.isNotEmpty) {
        for (final resetId in _state.resetDraftProgressIds) {
          final freshRes = await _lotRepo.fetchProductionProgressById(resetId);
          if (freshRes.success && freshRes.data != null) {
            final Map<String, dynamic> rawMap = Map<String, dynamic>.from(freshRes.data is Map ? freshRes.data : {});
            final Map<String, dynamic> resetJson = rawMap.containsKey('productionProgress')
                ? Map<String, dynamic>.from(rawMap['productionProgress'] as Map)
                : rawMap;

            final String? stamp = (rawMap['concurrencyStamp'] ?? resetJson['concurrencyStamp'])?.toString();
            if (stamp != null && stamp.isNotEmpty) {
              resetJson['concurrencyStamp'] = stamp;
            }

            resetJson['draftFlag'] = false;
            resetJson['draftStatus'] = false;
            resetJson.remove('id');
            resetJson.remove('progressCode');
            resetJson.remove('creationTime');
            resetJson.remove('creatorId');
            resetJson.remove('lastModificationTime');
            resetJson.remove('lastModifierId');
            resetJson.remove('isFirstProcess');
            resetJson.remove('isLastProcess');
            resetJson.remove('lotMakingFlag');
            resetJson.remove('processCompletionTime');
            await _processingRepo.updateProductionProgress(resetId, resetJson);
          }
        }
      }

      _state = _state.copyWith(
        resetBatchLineIds: {},
        resetDraftProgressIds: {},
      );

      // Update draftStatus and draftFlag on all active Lapping progress records for this batch on save draft
      if (isDraft) {
        final activeLappingProgresses = _state.rawActiveTrays
            .where((t) => t.productionProgress.operationId == currentOperationId)
            .map((t) => t.productionProgress)
            .toList();

        final Set<int> updatedPpIds = {};
        for (final pp in activeLappingProgresses) {
          if (pp.id != null && !updatedPpIds.contains(pp.id)) {
            updatedPpIds.add(pp.id!);

            final freshRes = await _lotRepo.fetchProductionProgressById(pp.id!);
            if (freshRes.success && freshRes.data != null) {
              final Map<String, dynamic> rawMap = Map<String, dynamic>.from(freshRes.data is Map ? freshRes.data : {});
              final Map<String, dynamic> updateJson = rawMap.containsKey('productionProgress')
                  ? Map<String, dynamic>.from(rawMap['productionProgress'] as Map)
                  : rawMap;

              final String? stamp = (rawMap['concurrencyStamp'] ?? updateJson['concurrencyStamp'])?.toString();
              if (stamp != null && stamp.isNotEmpty) {
                updateJson['concurrencyStamp'] = stamp;
              }

              updateJson['draftFlag'] = true;
              updateJson['draftStatus'] = true;
              updateJson.remove('id');
              updateJson.remove('progressCode');
              updateJson.remove('creationTime');
              updateJson.remove('creatorId');
              updateJson.remove('lastModificationTime');
              updateJson.remove('lastModifierId');
              updateJson.remove('isFirstProcess');
              updateJson.remove('isLastProcess');
              updateJson.remove('lotMakingFlag');
              updateJson.remove('processCompletionTime');

              final updRes = await _processingRepo.updateProductionProgress(pp.id!, updateJson);
              if (!updRes.success) {
                dev.log("LappingController: Failed to update draftStatus on active Lapping record ${pp.id}: ${updRes.message}");
              }
            }
          }
        }
      }

      final assignedTrays = allScannedTrays;
      final baseProgress = assignedTrays.isNotEmpty ? assignedTrays.first.productionProgress : null;

      int targetLocatorId = baseProgress?.locatorId ?? 3;
      final int targetOpId = isDraft ? currentOperationId : (nextOperationId ?? currentOperationId);

      if (!isDraft && nextOperationId != null) {
        final locRes = await _lotRepo.fetchLocators(operationId: nextOperationId);
        if (locRes.success && locRes.data != null) {
          final List locList = locRes.data is Map ? (locRes.data['items'] ?? []) : locRes.data;
          final matchingEntry = locList.cast<Map>().firstWhere(
                (entry) => (entry['operation']?['id'] ?? entry['locator']?['operationId'])?.toString() == nextOperationId.toString(),
            orElse: () => {},
          );
          if (matchingEntry.isNotEmpty) {
            targetLocatorId = matchingEntry['locator']?['id'] as int? ?? (baseProgress?.locatorId ?? 3);
          }
        }
      }

      final Map<int, String> handoverErrors = {};

      Future<bool> processSingleTrayHandover(LappingModel scannedTray) async {
        final pp = scannedTray.productionProgress;

        try {
          final double trayQty = _state.trayOverrideQuantities[scannedTray.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0;
          final double pgt = scannedTray.item.perGarmentTube;
          final double primaryPcs = pgt > 0 ? trayQty * pgt : trayQty;

          if (isDraft) {
            // --- DRAFT PATH ---
            // Re-resolve the correct lapping progress record ID for this work order to link the draft batch line
            final originalLappingRecord = _state.rawActiveTrays.firstWhere(
              (t) => t.workOrderHeader.id == scannedTray.workOrderHeader.id && t.productionProgress.id != null,
              orElse: () => _state.rawActiveTrays.first,
            );
            final int? draftProgressId = originalLappingRecord.productionProgress.id;

            // Create/Update the batch line entry in draft
            final String code = scannedTray.primaryTrayModel.trayCode?.toLowerCase() ?? '';
            final int? blId = _state.trayBatchLineIds[code];

            final Map<String, dynamic> lotLinePayload = {
              "planDate": DateTime.now().toIso8601String(),
              "transactionDate": DateTime.now().toIso8601String(),
              "primaryQuantity": primaryPcs,
              "primaryUOM": pp.primaryUOM ?? 4,
              "secondaryQuantity": trayQty,
              "secondaryUOM": pp.secondaryUOM ?? 1,
              "batchLineCode": "BL-$batchHeaderId-${scannedTray.primaryTrayModel.id}",
              "batchHeaderId": batchHeaderId,
              "progressId": draftProgressId, // linked to Lapping progress record in draft
              "workOrderHeaderId": scannedTray.workOrderHeader.id,
              "workOrderLineId": scannedTray.workOrderLine.id,
              "itemId": scannedTray.item.id,
              "trayId": scannedTray.primaryTrayModel.id,
              "locatorId": targetLocatorId,
              "processItemId": scannedTray.processedItem?.id ?? pp.processedItemId ?? scannedTray.item.id,
              "active": true,
              "isReAssigned": true,
            };

            if (blId != null) {
              final blFetchRes = await _lotRepo.fetchLotLines(batchHeaderId: batchHeaderId);
              if (blFetchRes.success && blFetchRes.data != null) {
                final List rawList = blFetchRes.data is Map
                    ? (blFetchRes.data['items'] ?? [])
                    : (blFetchRes.data is List ? blFetchRes.data : []);
                final match = rawList.cast<Map>().firstWhere(
                  (item) => (item['batchLines']?['id'] ?? item['id'])?.toString() == blId.toString(),
                  orElse: () => {},
                );
                if (match.isNotEmpty) {
                  final blMap = match['batchLines'] ?? match;
                  if (blMap['concurrencyStamp'] != null) {
                    lotLinePayload['concurrencyStamp'] = blMap['concurrencyStamp'];
                  }
                }
              }

              final blRes = await _lotRepo.updateLotLine(blId, lotLinePayload);
              if (!blRes.success) {
                handoverErrors[scannedTray.primaryTrayModel.id!] = 'Draft batchline update failed: ${blRes.message}';
                return false;
              }
            } else {
              final blRes = await _lotRepo.createLotLine(lotLinePayload);
              if (!blRes.success) {
                handoverErrors[scannedTray.primaryTrayModel.id!] = 'Draft batchline create failed: ${blRes.message}';
                return false;
              }
            }
            return true;
          }

          // --- SUBMISSION PATH ---
          // 1. WIP TRANSACTION
          int? wipId;
          if (pp.id != null) {
            final nativeWipRes = await _lotRepo.fetchWipTransactionsByProgressId(pp.id!);
            if (nativeWipRes.success && nativeWipRes.data != null) {
              final List rawItems = nativeWipRes.data is Map ? (nativeWipRes.data['items'] ?? []) : nativeWipRes.data;
              final items = rawItems.cast<Map<String, dynamic>>();
              final match = items.firstWhere(
                (e) => (e['wipTransaction']?['progressId'] ?? e['progressId'] ?? e['wipTransaction']?['productionProgressId'] ?? e['productionProgressId'])?.toString() == pp.id.toString(),
                orElse: () => {},
              );
              if (match.isNotEmpty) {
                wipId = match['wipTransaction']?['id'] as int?;
              }
            }
          }

          // 2. UPDATE THE EXISTING LAPPING ENTRY (to reset draftFlag = false and update quantity)
          if (pp.id != null) {
            final freshRes = await _lotRepo.fetchProductionProgressById(pp.id!);
            if (freshRes.success && freshRes.data != null) {
              final Map<String, dynamic> rawMap = Map<String, dynamic>.from(freshRes.data is Map ? freshRes.data : {});
              final Map<String, dynamic> updateLappingJson = rawMap.containsKey('productionProgress')
                  ? Map<String, dynamic>.from(rawMap['productionProgress'] as Map)
                  : rawMap;

              final String? stamp = (rawMap['concurrencyStamp'] ?? updateLappingJson['concurrencyStamp'])?.toString();
              if (stamp != null && stamp.isNotEmpty) {
                updateLappingJson['concurrencyStamp'] = stamp;
              }

              if (!isDraft) {
                updateLappingJson['transactionType'] = 3;
                updateLappingJson['wipStatus'] = 1;
                updateLappingJson['draftFlag'] = false;
                updateLappingJson['draftStatus'] = false;
              }
              updateLappingJson['primaryQuantity'] = primaryPcs;
              updateLappingJson['secondaryQuantity'] = trayQty;
              updateLappingJson.remove('id');
              updateLappingJson.remove('progressCode');
              updateLappingJson.remove('creationTime');
              updateLappingJson.remove('creatorId');
              updateLappingJson.remove('lastModificationTime');
              updateLappingJson.remove('lastModifierId');
              updateLappingJson.remove('isFirstProcess');
              updateLappingJson.remove('isLastProcess');
              updateLappingJson.remove('lotMakingFlag');
              updateLappingJson.remove('processCompletionTime');

              var updRes = await _processingRepo.updateProductionProgress(pp.id!, updateLappingJson);

              // Retry once with fresh fetch if concurrency stamp or user change conflict occurs
              if (!updRes.success) {
                final refetchRes = await _lotRepo.fetchProductionProgressById(pp.id!);
                if (refetchRes.success && refetchRes.data != null) {
                  final Map<String, dynamic> rMap = Map<String, dynamic>.from(refetchRes.data is Map ? refetchRes.data : {});
                  final Map<String, dynamic> retryJson = rMap.containsKey('productionProgress')
                      ? Map<String, dynamic>.from(rMap['productionProgress'] as Map)
                      : rMap;
                  final String? freshStamp = (rMap['concurrencyStamp'] ?? retryJson['concurrencyStamp'])?.toString();
                  if (freshStamp != null && freshStamp.isNotEmpty) {
                    retryJson['concurrencyStamp'] = freshStamp;
                  }
                  if (!isDraft) {
                    retryJson['transactionType'] = 3;
                    retryJson['wipStatus'] = 1;
                    retryJson['draftFlag'] = false;
                    retryJson['draftStatus'] = false;
                  }
                  retryJson['primaryQuantity'] = primaryPcs;
                  retryJson['secondaryQuantity'] = trayQty;
                  retryJson.remove('id');
                  retryJson.remove('progressCode');
                  retryJson.remove('creationTime');
                  retryJson.remove('creatorId');
                  retryJson.remove('lastModificationTime');
                  retryJson.remove('lastModifierId');
                  retryJson.remove('isFirstProcess');
                  retryJson.remove('isLastProcess');
                  retryJson.remove('lotMakingFlag');
                  retryJson.remove('processCompletionTime');
                  updRes = await _processingRepo.updateProductionProgress(pp.id!, retryJson);
                }
              }

              if (!updRes.success) {
                handoverErrors[scannedTray.primaryTrayModel.id!] = 'Failed to reset draft status on lapping entry: ${updRes.message}';
                return false;
              }
            }
          }

          // 3. ALWAYS CREATE NEW HANDOVER ENTRY (with locator id of next process)
          int? targetProgressId;
          final Map<String, dynamic> nextJson = {
            "subOperation": "Handover",
            "date": DateTime.now().toIso8601String(),
            "transactionType": 2,
            "operatorDescription": "system",
            "primaryQuantity": primaryPcs,
            "primaryUOM": pp.primaryUOM ?? 4,
            "secondaryQuantity": trayQty,
            "secondaryUOM": pp.secondaryUOM ?? 1,
            "wipStatus": nextOperationId != null ? 0 : 1,
            "gbsFlag": false,
            "pbsFlag": false,
            "productGrade": pp.productGrade ?? 0,
            "productNature": pp.productNature ?? 0,
            "isLastProcess": false,
            "reworkFlag": pp.reworkFlag ?? false,
            "isStarted": false,
            "draftFlag": false,
            "draftStatus": false,
            "holdFlag": false,
            "operationId": targetOpId,
            "workOrderHeaderId": scannedTray.workOrderHeader.id,
            "workOrderLineId": scannedTray.workOrderLine.id,
            "processedItemId": scannedTray.processedItem?.id ?? pp.processedItemId ?? scannedTray.item.id,
            "itemId": scannedTray.item.id,
            "shiftId": pp.shiftId ?? 1,
            "primaryTrayId": scannedTray.primaryTrayModel.id,
            "secondaryTrayId": scannedTray.primaryTrayModel.id,
            "locatorId": targetLocatorId,
            "batchHeaderId": batchHeaderId,
          };

          if (pp.machineId != null || (_state.trays.isNotEmpty && _state.trays.first.productionProgress.machineId != null)) {
            nextJson["machineId"] = pp.machineId ?? _state.trays.first.productionProgress.machineId;
          }
          if (pp.waste != null) {
            nextJson["waste"] = pp.waste!.round();
          }
          if (pp.requiredQty != null) {
            nextJson["requiredQty"] = pp.requiredQty!.round();
          }

          final ppRes = await _processingRepo.createProductionProgress(nextJson);
          if (!ppRes.success) {
            handoverErrors[scannedTray.primaryTrayModel.id!] = 'Handover entry create failed: ${ppRes.message}';
            return false;
          }

          final dynamic ppData = ppRes.data;
          if (ppData is Map) {
            final rawId = int.tryParse(ppData['id']?.toString() ?? '');
            if (rawId != null && rawId > 0) targetProgressId = rawId;
          } else if (ppData is int && ppData > 0) {
            targetProgressId = ppData;
          }

          ProductionProgressResponseModel? latestHandoverPP;
          if (targetProgressId == null || targetProgressId == 0) {
            final refetchRes = await _processingRepo.fetchProductionProgress({
              'OperationId': targetOpId.toString(),
              'TransactionType': '2',
            });
            if (refetchRes.success && refetchRes.data != null) {
              final list = refetchRes.data as List<ProductionProgressResponseModel>;
              final matches = list.where((r) =>
                r.primaryTrayModel.id == scannedTray.primaryTrayModel.id &&
                (r.productionProgress.subOperation ?? '').toLowerCase() == 'handover'
              ).toList();
              if (matches.isNotEmpty) {
                matches.sort((a, b) => (a.productionProgress.id ?? 0).compareTo(b.productionProgress.id ?? 0));
                latestHandoverPP = matches.last;
                targetProgressId = latestHandoverPP.productionProgress.id;
              }
            }
          }

          if (targetProgressId == null || targetProgressId == 0) {
            handoverErrors[scannedTray.primaryTrayModel.id!] = 'Step 2.5 failed to resolve handover progress ID';
            return false;
          }

          // --- 3. CREATE/UPDATE BATCH LINE ---
          int? blId;
          final String code = scannedTray.primaryTrayModel.trayCode?.toLowerCase() ?? '';
          final int? existingBlId = _state.trayBatchLineIds[code];

          final Map<String, dynamic> lotLinePayload = {
            "planDate": DateTime.now().toIso8601String(),
            "transactionDate": DateTime.now().toIso8601String(),
            "primaryQuantity": primaryPcs,
            "primaryUOM": pp.primaryUOM ?? 4,
            "secondaryQuantity": trayQty,
            "secondaryUOM": pp.secondaryUOM ?? 1,
            "batchLineCode": "BL-$batchHeaderId-${scannedTray.primaryTrayModel.id}",
            "batchHeaderId": batchHeaderId,
            "progressId": targetProgressId,
            "workOrderHeaderId": scannedTray.workOrderHeader.id,
            "workOrderLineId": scannedTray.workOrderLine.id,
            "itemId": scannedTray.item.id,
            "trayId": scannedTray.primaryTrayModel.id,
            "locatorId": targetLocatorId,
            "processItemId": scannedTray.processedItem?.id ?? pp.processedItemId ?? scannedTray.item.id,
            "active": true,
            "isReAssigned": true,
          };
          if (wipId != null) {
            lotLinePayload["wipTransactionId"] = wipId;
          }

          if (existingBlId != null) {
            final blFetchRes = await _lotRepo.fetchLotLines(batchHeaderId: batchHeaderId);
            if (blFetchRes.success && blFetchRes.data != null) {
              final List rawList = blFetchRes.data is Map
                  ? (blFetchRes.data['items'] ?? [])
                  : (blFetchRes.data is List ? blFetchRes.data : []);
              final match = rawList.cast<Map>().firstWhere(
                (item) => (item['batchLines']?['id'] ?? item['id'])?.toString() == existingBlId.toString(),
                orElse: () => {},
              );
              if (match.isNotEmpty) {
                final blMap = match['batchLines'] ?? match;
                if (blMap['concurrencyStamp'] != null) {
                  lotLinePayload['concurrencyStamp'] = blMap['concurrencyStamp'];
                }
              }
            }

            final blRes = await _lotRepo.updateLotLine(existingBlId, lotLinePayload);
            if (!blRes.success) {
              handoverErrors[scannedTray.primaryTrayModel.id!] = 'Failed to update batch line to final progress: ${blRes.message}';
              return false;
            }
            blId = existingBlId;
          } else {
            final blRes = await _lotRepo.createLotLine(lotLinePayload);
            if (!blRes.success || blRes.data == null) {
              handoverErrors[scannedTray.primaryTrayModel.id!] = 'Step 3 create failed: ${blRes.message}';
              return false;
            }
            final rawBlData = blRes.data;
            blId = (rawBlData is Map) ? (rawBlData['batchLines']?['id'] ?? rawBlData['id']) : null;
          }

          if (blId == null || blId == 0) {
            final refetchBl = await _lotRepo.fetchLotLines(batchHeaderId: batchHeaderId);
            if (refetchBl.success && refetchBl.data != null) {
              final List rawList = refetchBl.data is Map
                  ? (refetchBl.data['items'] ?? [])
                  : (refetchBl.data is List ? refetchBl.data : []);
              final matches = rawList.where((item) {
                final Map blMap = item['batchLines'] ?? item;
                return blMap['trayId'] == scannedTray.primaryTrayModel.id;
              }).toList();
              if (matches.isNotEmpty) {
                final blMap = matches.last['batchLines'] ?? matches.last;
                blId = blMap['id'] as int?;
              }
            }
          }

          if (blId == null || blId == 0) {
            handoverErrors[scannedTray.primaryTrayModel.id!] = 'Step 3.5 failed to resolve batch line ID';
            return false;
          }

          // --- 3.7. UPDATE PRODUCTION PROGRESS batchLineId ---
          if (targetProgressId != null) {
            final freshPPRes = await _lotRepo.fetchProductionProgressById(targetProgressId);
            if (freshPPRes.success && freshPPRes.data != null) {
              final rawMap = Map<String, dynamic>.from(freshPPRes.data is Map ? freshPPRes.data : {});
              final Map<String, dynamic> finalJson = rawMap.containsKey('productionProgress')
                  ? Map<String, dynamic>.from(rawMap['productionProgress'] as Map)
                  : rawMap;

              final String? stamp = (rawMap['concurrencyStamp'] ?? finalJson['concurrencyStamp'])?.toString();
              if (stamp != null && stamp.isNotEmpty) {
                finalJson['concurrencyStamp'] = stamp;
              }

              finalJson['batchHeaderId'] = batchHeaderId;
              finalJson['batchLineId'] = blId;
              finalJson['batchLinesId'] = blId;
              finalJson.remove('id');
              finalJson.remove('progressCode');
              finalJson.remove('creationTime');
              finalJson.remove('creatorId');
              finalJson.remove('lastModificationTime');
              finalJson.remove('lastModifierId');
              finalJson.remove('isFirstProcess');
              finalJson.remove('isLastProcess');
              finalJson.remove('lotMakingFlag');
              finalJson.remove('processCompletionTime');
              await _processingRepo.updateProductionProgress(targetProgressId, finalJson);
            }

            final newWipRes = await _lotRepo.fetchWipTransactionsByProgressId(targetProgressId);
            if (newWipRes.success && newWipRes.data != null) {
              final List rawItems = newWipRes.data is Map ? (newWipRes.data['items'] ?? []) : newWipRes.data;
              final items = rawItems.cast<Map<String, dynamic>>();
              final match = items.firstWhere(
                (e) => (e['wipTransaction']?['progressId'] ?? e['progressId'] ?? e['wipTransaction']?['productionProgressId'] ?? e['productionProgressId'])?.toString() == targetProgressId.toString(),
                orElse: () => {},
              );
              if (match.isNotEmpty) {
                final newWipId = match['wipTransaction']?['id'] as int?;
                if (newWipId != null) {
                  final wipPayload = Map<String, dynamic>.from(match['wipTransaction'] ?? match);
                  wipPayload['batchLinesId'] = blId;
                  wipPayload['batchLineId'] = blId;
                  wipPayload.remove('id');
                  wipPayload.remove('concurrencyStamp');
                  await _lotRepo.updateWipTransaction(newWipId, wipPayload);
                }
              }
            }
          }

          // --- 4. UPDATE TRAY DETAILS ---
          final tRes = await _lotRepo.fetchTrayDetailById(scannedTray.primaryTrayModel.id!);
          if (tRes.success) {
            final tData = tRes.data['trayDetail'] ?? tRes.data;
            Map<String, dynamic> trayUpd = Map<String, dynamic>.from(tData);

            final fetchedStamp = trayUpd['concurrencyStamp'];
            final originalStamp = scannedTray.primaryTrayModel.concurrencyStamp;
            if (fetchedStamp == null && originalStamp != null) {
              trayUpd['concurrencyStamp'] = originalStamp;
            }

            trayUpd.removeWhere((key, value) =>
              ["creatorId", "creationTime", "lastModifierId", "lastModificationTime", "batchLinesId"].contains(key) ||
              value is Map ||
              value is List
            );

            trayUpd["trayQuantity"] = trayQty.toInt();
            trayUpd["batchHeaderId"] = batchHeaderId;
            trayUpd["isReAssigned"] = false;
            if (machineId != null) {
              trayUpd["resourceId"] = machineId;
            }
            trayUpd["locatorId"] = targetLocatorId;

            trayUpd["batchLineId"] = blId;

            var updTrayRes = await _lotRepo.updateTrayDetails(scannedTray.primaryTrayModel.id!, trayUpd);
            if (!updTrayRes.success) {
              final Map<String, dynamic> minimalTrayUpd = {
                "id": scannedTray.primaryTrayModel.id,
                "trayCode": scannedTray.primaryTrayModel.trayCode,
                "trayQuantity": trayQty.toInt(),
                "batchHeaderId": batchHeaderId,
                "locatorId": targetLocatorId,
                "isReAssigned": false,
                "workOrderHeaderId": trayUpd["workOrderHeaderId"],
                "workOrderLineId": trayUpd["workOrderLineId"],
                "knitItemId": trayUpd["knitItemId"],
                "concurrencyStamp": trayUpd['concurrencyStamp'] ?? originalStamp ?? fetchedStamp,
              };
              if (machineId != null) {
                minimalTrayUpd["resourceId"] = machineId;
              }
              minimalTrayUpd["batchLineId"] = blId;

              updTrayRes = await _lotRepo.updateTrayDetails(scannedTray.primaryTrayModel.id!, minimalTrayUpd);
            }

            if (!updTrayRes.success) {
              handoverErrors[scannedTray.primaryTrayModel.id!] = 'Step 4 updateTrayDetails failed: ${updTrayRes.message}';
              return false;
            }
            return true;
          } else {
            handoverErrors[scannedTray.primaryTrayModel.id!] = 'Step 4 fetchTrayDetailById failed: ${tRes.message}';
            return false;
          }
        } catch (e) {
          handoverErrors[scannedTray.primaryTrayModel.id!] = 'Exception: $e';
          return false;
        }
      }

      final handoversToProcess = _state.failedHandoverTrayIds.isEmpty
          ? assignedTrays
          : assignedTrays.where((t) => _state.failedHandoverTrayIds.contains(t.primaryTrayModel.id)).toList();

      final List<Future<bool>> handoverTasks = handoversToProcess.map((scannedTray) => processSingleTrayHandover(scannedTray)).toList();
      final List<bool> handoverResults = await Future.wait(handoverTasks);

      final newFailedHandoverTrayIds = <int>{};
      for (int i = 0; i < handoversToProcess.length; i++) {
        if (!handoverResults[i]) {
          newFailedHandoverTrayIds.add(handoversToProcess[i].primaryTrayModel.id!);
        }
      }

      final updatedFailedHandovers = Set<int>.from(_state.failedHandoverTrayIds);
      if (_state.failedHandoverTrayIds.isEmpty) {
        updatedFailedHandovers.addAll(newFailedHandoverTrayIds);
      } else {
        for (final t in handoversToProcess) {
          final id = t.primaryTrayModel.id!;
          if (newFailedHandoverTrayIds.contains(id)) {
            updatedFailedHandovers.add(id);
          } else {
            updatedFailedHandovers.remove(id);
          }
        }
      }

      _state = _state.copyWith(failedHandoverTrayIds: updatedFailedHandovers);

      if (updatedFailedHandovers.isNotEmpty) {
        final errorDetails = updatedFailedHandovers
            .map((id) => 'Tray $id:\n${handoverErrors[id] ?? "Unknown error"}')
            .join('\n\n');
        throw Exception(errorDetails);
      }

      // --- Step 5: Save/Update Waste Progress Records ---
      for (final wo in _state.workOrders.values) {
        final compositeId = wo.id;
        final double wasteQty = _state.itemWasteQuantities[compositeId] ?? 0.0;
        final int? existingId = _state.itemWasteProgressIds[compositeId];

        if (wasteQty > 0) {
          LappingModel? match = _state.rawActiveTrays.where((t) =>
            '${t.workOrderHeader.id}_${t.processedItem?.description ?? t.item.description}' == compositeId
          ).firstOrNull ?? _state.trays.where((t) =>
            '${t.workOrderHeader.id}_${t.processedItem?.description ?? t.item.description}' == compositeId
          ).firstOrNull;

          if (match != null) {
            if (existingId != null) {
              final freshRes = await _lotRepo.fetchProductionProgressById(existingId);
              if (freshRes.success && freshRes.data != null) {
                final rawMap = Map<String, dynamic>.from(freshRes.data is Map ? freshRes.data : {});
                final Map<String, dynamic> updateWasteJson = rawMap.containsKey('productionProgress')
                    ? Map<String, dynamic>.from(rawMap['productionProgress'] as Map)
                    : rawMap;

                final String? stamp = (rawMap['concurrencyStamp'] ?? updateWasteJson['concurrencyStamp'])?.toString();
                if (stamp != null && stamp.isNotEmpty) {
                  updateWasteJson['concurrencyStamp'] = stamp;
                }

                updateWasteJson['transactionType'] = 2;
                updateWasteJson['locatorId'] = 18;
                updateWasteJson['primaryQuantity'] = wasteQty.round();
                updateWasteJson['waste'] = wasteQty.round();
                updateWasteJson['draftFlag'] = isDraft;
                updateWasteJson['draftStatus'] = isDraft;
                updateWasteJson.remove('id');
                updateWasteJson.remove('progressCode');
                updateWasteJson.remove('creationTime');
                updateWasteJson.remove('creatorId');
                updateWasteJson.remove('lastModificationTime');
                updateWasteJson.remove('lastModifierId');
                updateWasteJson.remove('isFirstProcess');
                updateWasteJson.remove('isLastProcess');
                updateWasteJson.remove('lotMakingFlag');
                updateWasteJson.remove('processCompletionTime');

                await _processingRepo.updateProductionProgress(existingId, updateWasteJson);
              }
            } else {
              final Map<String, dynamic> wasteJson = {
                "subOperation": "Waste",
                "transactionType": 2,
                "primaryQuantity": wasteQty.round(),
                "secondaryQuantity": 0,
                "primaryUOM": match.productionProgress.primaryUOM ?? 4,
                "secondaryUOM": match.productionProgress.secondaryUOM ?? 1,
                "waste": wasteQty.round(),
                "pbsFlag": false,
                "draftFlag": isDraft,
                "draftStatus": isDraft,
                "gbsFlag": false,
                "productGrade": 0,
                "productNature": 0,
                "wipStatus": 0,
                "date": DateTime.now().toIso8601String(),
                "operatorDescription": "system",
                "operationId": currentOperationId,
                "locatorId": 18,
                "batchHeaderId": batchHeaderId,
                "workOrderHeaderId": match.workOrderHeader.id,
                "workOrderLineId": match.workOrderLine.id,
                "itemId": match.item.id,
                "processedItemId": match.processedItem?.id ?? match.item.id,
                "shiftId": 1,
                "isStarted": false,
                "isLastProcess": false,
                "reworkFlag": false,
                "lotMakingFlag": false,
              };
              await _processingRepo.createProductionProgress(wasteJson);
            }
          }
        } else if (existingId != null) {
          await _processingRepo.deleteProductionProgress(existingId);
        }
      }

      if (isDraft) {
        await fetchBatchData();
        return;
      }

      // --- Step 6: Concurrent Lapping Closure ---
      final lappingPpRes = await _lappingRepo.fetchProductionProgress({
        'BatchHeaderId': batchHeaderId.toString(),
        'TransactionType': '2',
        'MaxResultCount': '1000',
      });
      List<LappingModel> traysToClose = [];
      if (lappingPpRes.success && lappingPpRes.data != null) {
        final list = lappingPpRes.data as List<LappingModel>;
        traysToClose = list.where((r) =>
          (nextOperationId == null || r.productionProgress.operationId != nextOperationId) &&
          (r.productionProgress.subOperation ?? '').toLowerCase() != 'handover' &&
          (r.productionProgress.subOperation ?? '').toLowerCase() != 'waste' &&
          r.productionProgress.locatorId != 18
        ).toList();
      }
      if (traysToClose.isEmpty) {
        traysToClose = _state.trays.where((t) =>
          (t.productionProgress.subOperation ?? '').toLowerCase() != 'handover' &&
          (t.productionProgress.subOperation ?? '').toLowerCase() != 'waste' &&
          t.productionProgress.locatorId != 18
        ).toList();
      }

      final closuresToProcess = _state.failedCloseLappingIds.isEmpty
          ? traysToClose
          : traysToClose.where((t) => _state.failedCloseLappingIds.contains(t.productionProgress.id)).toList();

      final List<Future<bool>> closureTasks = closuresToProcess.map((realLappingPP) async {
        final ppId = realLappingPP.productionProgress.id;
        if (ppId != null && ppId > 0) {
          try {
            final freshRes = await _lotRepo.fetchProductionProgressById(ppId);
            if (freshRes.success && freshRes.data != null) {
              final rawMap = Map<String, dynamic>.from(freshRes.data is Map ? freshRes.data : {});
              final Map<String, dynamic> closeJson = rawMap.containsKey('productionProgress')
                  ? Map<String, dynamic>.from(rawMap['productionProgress'] as Map)
                  : rawMap;

              final String? stamp = (rawMap['concurrencyStamp'] ?? closeJson['concurrencyStamp'])?.toString();
              if (stamp != null && stamp.isNotEmpty) {
                closeJson['concurrencyStamp'] = stamp;
              }

              final int? locId = closeJson['locatorId'] as int? ?? realLappingPP.productionProgress.locatorId;
              final String subOp = (closeJson['subOperation'] ?? realLappingPP.productionProgress.subOperation ?? '').toString().toLowerCase();

              // Do not update transactionType to 3 for waste entries (locatorId 18)
              if (locId != 18 && subOp != 'waste') {
                closeJson['transactionType'] = 3;
                closeJson['wipStatus'] = 1;
              }

              closeJson.remove('id');
              closeJson.remove('progressCode');
              closeJson.remove('creationTime');
              closeJson.remove('creatorId');
              closeJson.remove('lastModificationTime');
              closeJson.remove('lastModifierId');
              closeJson.remove('isFirstProcess');
              closeJson.remove('isLastProcess');
              closeJson.remove('lotMakingFlag');
              closeJson.remove('processCompletionTime');

              final closeRes = await _processingRepo.updateProductionProgress(ppId, closeJson);
              return closeRes.success;
            }
          } catch (e) {
            return false;
          }
        }
        return true;
      }).toList();

      final List<bool> closureResults = await Future.wait(closureTasks);

      final newFailedCloseIds = <int>{};
      for (int i = 0; i < closuresToProcess.length; i++) {
        if (!closureResults[i]) {
          final id = closuresToProcess[i].productionProgress.id;
          if (id != null) newFailedCloseIds.add(id);
        }
      }

      final updatedFailedClosures = Set<int>.from(_state.failedCloseLappingIds);
      if (_state.failedCloseLappingIds.isEmpty) {
        updatedFailedClosures.addAll(newFailedCloseIds);
      } else {
        for (final t in closuresToProcess) {
          final id = t.productionProgress.id!;
          if (newFailedCloseIds.contains(id)) {
            updatedFailedClosures.add(id);
          } else {
            updatedFailedClosures.remove(id);
          }
        }
      }

      _state = _state.copyWith(failedCloseLappingIds: updatedFailedClosures);

      if (updatedFailedClosures.isNotEmpty) {
        throw Exception('${updatedFailedClosures.length} lapping closure(s) failed. Please check network and retry.');
      }

      _state = _state.copyWith(
        isLoading: false,
        scannedTraysByWO: {},
        trayOverrideQuantities: {},
        failedHandoverTrayIds: {},
        failedCloseLappingIds: {},
        resetDraftProgressIds: {},
      );
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}
