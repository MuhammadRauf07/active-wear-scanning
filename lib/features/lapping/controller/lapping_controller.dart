import 'package:flutter/foundation.dart';
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
        for (final tray in rawTrays) {
          if (tray.productionProgress.transactionType != 2) continue;
          if (tray.productionProgress.operationId != currentOperationId) continue;

          final code = tray.primaryTrayModel.trayCode ?? 'UNKNOWN';
          if (!uniqueTrays.containsKey(code) || (tray.productionProgress.id ?? 0) > (uniqueTrays[code]!.productionProgress.id ?? 0)) {
            uniqueTrays[code] = tray;
          }
        }

        final fetchedTrays = uniqueTrays.values.toList();
        final Map<String, WorkOrderSummary> summaries = {};

        for (final tray in fetchedTrays) {
          final woId = tray.workOrderHeader.id;
          final itemDesc = tray.processedItem?.description ?? tray.item.description;

          if (itemDesc.isNotEmpty) {
            final compositeId = '${woId}_$itemDesc';

            if (summaries.containsKey(compositeId)) {
              final existing = summaries[compositeId]!;
              summaries[compositeId] = WorkOrderSummary(
                id: compositeId,
                description: existing.description,
                componentDescription: existing.componentDescription,
                trayCount: existing.trayCount + 1,
                cumulativePieces: existing.cumulativePieces + (tray.productionProgress.primaryQuantity ?? 0),
              );
            } else {
              final woDesc = tray.workOrderHeader.description;
              summaries[compositeId] = WorkOrderSummary(
                id: compositeId,
                description: woDesc,
                componentDescription: itemDesc,
                trayCount: 1,
                cumulativePieces: tray.productionProgress.primaryQuantity ?? 0,
              );
            }
          }
        }

        _state = _state.copyWith(
          trays: fetchedTrays,
          rawActiveTrays: rawTrays,
          workOrders: summaries,
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
    }
    notifyListeners();
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
    matchedTray = LappingModel(
      productionProgress: matchedTray.productionProgress,
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

    _state = _state.copyWith(
      trayOverrideQuantities: updatedOverrides,
      scannedTraysByWO: updatedScanned,
    );
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

  Future<void> saveChanges() async {
    final allScannedTrays = _state.scannedTraysByWO.values.expand((list) => list).toList();

    if (allScannedTrays.isEmpty) {
      throw Exception('No Trays Scanned. Please scan at least one tray.');
    }

    // Completion validation
    for (final wo in _state.workOrders.values) {
      if ((_state.scannedTraysByWO[wo.id] ?? []).isEmpty) {
        throw Exception('Incomplete. Missing trays for "${wo.componentDescription}"');
      }
    }

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final assignedTrays = allScannedTrays;
      final baseProgress = assignedTrays.first.productionProgress;
      int nextLocatorId = baseProgress.locatorId ?? 3;
      final handoverOpId = nextOperationId ?? baseProgress.operationId;

      if (handoverOpId != null) {
        final locRes = await _lotRepo.fetchLocators(operationId: handoverOpId);
        if (locRes.success && locRes.data != null) {
          final List locList = locRes.data is Map ? (locRes.data['items'] ?? []) : locRes.data;
          final matchingEntry = locList.cast<Map>().firstWhere(
                (entry) => (entry['operation']?['id'] ?? entry['locator']?['operationId'])?.toString() == handoverOpId.toString(),
            orElse: () => {},
          );
          if (matchingEntry.isNotEmpty) {
            nextLocatorId = matchingEntry['locator']?['id'] as int? ?? (baseProgress.locatorId ?? 3);
          }
        }
      }

      final Map<int, String> handoverErrors = {};

      Future<bool> processSingleTrayHandover(LappingModel scannedTray) async {
        final pp = scannedTray.productionProgress;

        try {
          final double trayQty = _state.trayOverrideQuantities[scannedTray.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0;

          // --- 1. WIP TRANSACTION ---
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

          // --- 2. CREATE HANDOVER PRODUCTION PROGRESS ---
          Map<String, dynamic> nextJson = pp.toJson();
          nextJson.remove('id');
          nextJson.remove('progressCode');
          nextJson.remove('concurrencyStamp');
          nextJson.remove('batchLinesId');
          nextJson.remove('batchLineId');

          nextJson.addAll({
            "subOperation": "Handover",
            "transactionType": 2,
            "primaryTrayId": scannedTray.primaryTrayModel.id,
            "secondaryTrayId": scannedTray.primaryTrayModel.id,
            "primaryQuantity": trayQty,
            "secondaryQuantity": pp.secondaryQuantity ?? 0,
            "primaryUOM": pp.primaryUOM ?? 4,
            "secondaryUOM": pp.secondaryUOM ?? 1,
            "productGrade": pp.productGrade ?? 0,
            "productNature": pp.productNature ?? 0,
            "shiftId": pp.shiftId ?? 1,
            "machineId": pp.machineId ?? (_state.trays.isNotEmpty ? _state.trays.first.productionProgress.machineId : null),
            "isLastProcess": false,
            "isStarted": false,
            "reworkFlag": pp.reworkFlag ?? false,
            "lotMakingFlag": false,
            "locatorId": nextLocatorId,
            "operationId": handoverOpId ?? pp.operationId,
            "wipStatus": nextOperationId != null ? 0 : 1,
            "gbsFlag": false,
            "pbsFlag": false,
            "date": DateTime.now().toIso8601String(),
            "operatorDescription": "system",
            "processedItemId": scannedTray.processedItem?.id ?? pp.processedItemId ?? scannedTray.item.id,
            "itemId": scannedTray.item.id,
            "workOrderHeaderId": scannedTray.workOrderHeader.id,
            "workOrderLineId": scannedTray.workOrderLine.id,
            "batchHeaderId": batchHeaderId,
          });
          nextJson.remove("planHeaderId");

          final ppRes = await _processingRepo.createProductionProgress(nextJson);
          if (!ppRes.success) {
            handoverErrors[scannedTray.primaryTrayModel.id!] = 'Step 2 failed: ${ppRes.message}';
            return false;
          }

          final dynamic ppData = ppRes.data;
          int? targetProgressId;
          if (ppData is Map) {
            final rawId = int.tryParse(ppData['id']?.toString() ?? '');
            if (rawId != null && rawId > 0) targetProgressId = rawId;
          } else if (ppData is int && ppData > 0) {
            targetProgressId = ppData;
          }

          ProductionProgressResponseModel? latestHandoverPP;
          if (targetProgressId == null || targetProgressId == 0) {
            final refetchRes = await _processingRepo.fetchProductionProgress({
              'OperationId': (handoverOpId ?? pp.operationId).toString(),
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
            handoverErrors[scannedTray.primaryTrayModel.id!] = 'Step 2.5 failed to resolve progress ID';
            return false;
          }

          // --- 3. CREATE BATCH LINE ---
          int? blId;
          final Map<String, dynamic> lotLinePayload = {
            "planDate": DateTime.now().toIso8601String(),
            "transactionDate": DateTime.now().toIso8601String(),
            "primaryQuantity": trayQty,
            "primaryUOM": pp.primaryUOM ?? 4,
            "secondaryQuantity": 0,
            "secondaryUOM": pp.secondaryUOM ?? 1,
            "batchLineCode": "BL-$batchHeaderId-${scannedTray.primaryTrayModel.id}",
            "batchHeaderId": batchHeaderId,
            "progressId": targetProgressId,
            "workOrderHeaderId": scannedTray.workOrderHeader.id,
            "workOrderLineId": scannedTray.workOrderLine.id,
            "itemId": scannedTray.item.id,
            "trayId": scannedTray.primaryTrayModel.id,
            "locatorId": nextLocatorId,
            "processItemId": scannedTray.processedItem?.id ?? pp.processedItemId ?? scannedTray.item.id,
            "active": true,
            "isReAssigned": true,
          };
          if (wipId != null) {
            lotLinePayload["wipTransactionId"] = wipId;
          }

          final blRes = await _lotRepo.createLotLine(lotLinePayload);
          if (!blRes.success || blRes.data == null) {
            handoverErrors[scannedTray.primaryTrayModel.id!] = 'Step 3 failed: ${blRes.message}';
            return false;
          }
          final rawBlData = blRes.data;
          blId = (rawBlData is Map) ? (rawBlData['batchLines']?['id'] ?? rawBlData['id']) : null;

          if (blId == null || blId == 0) {
            final refetchBl = await _lotRepo.fetchLotLines(batchHeaderId: batchHeaderId);
            if (refetchBl.success && refetchBl.data != null) {
              final List rawList = refetchBl.data is List ? refetchBl.data : [];
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
          if (latestHandoverPP == null) {
            final refetchRes = await _processingRepo.fetchProductionProgress({
              'OperationId': (handoverOpId ?? pp.operationId).toString(),
              'TransactionType': '2',
            });
            if (refetchRes.success && refetchRes.data != null) {
              final list = refetchRes.data as List<ProductionProgressResponseModel>;
              final matches = list.where((r) => r.productionProgress.id == targetProgressId).toList();
              if (matches.isNotEmpty) {
                latestHandoverPP = matches.first;
              }
            }
          }

          if (latestHandoverPP != null) {
            final finalJson = latestHandoverPP.productionProgress.toJson();
            finalJson['batchHeaderId'] = batchHeaderId;
            finalJson['batchLineId'] = blId;
            finalJson['batchLinesId'] = blId;
            finalJson.remove('id');
            finalJson.remove('progressCode');
            finalJson.remove('creationTime');
            finalJson.remove('creatorId');
            finalJson.remove('lastModificationTime');
            finalJson.remove('lastModifierId');
            final finalRes = await _processingRepo.updateProductionProgress(targetProgressId, finalJson);
            if (!finalRes.success) {
              handoverErrors[scannedTray.primaryTrayModel.id!] = 'Step 3.7 update failed: ${finalRes.message}';
              return false;
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
            trayUpd["locatorId"] = nextLocatorId;

            trayUpd["batchLineId"] = blId;

            var updTrayRes = await _lotRepo.updateTrayDetails(scannedTray.primaryTrayModel.id!, trayUpd);
            if (!updTrayRes.success) {
              final Map<String, dynamic> minimalTrayUpd = {
                "id": scannedTray.primaryTrayModel.id,
                "trayCode": scannedTray.primaryTrayModel.trayCode,
                "trayQuantity": trayQty.toInt(),
                "batchHeaderId": batchHeaderId,
                "locatorId": nextLocatorId,
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

      // --- Step 6: Concurrent Lapping Closure ---
      final lappingPpRes = await _lappingRepo.fetchProductionProgress({
        'BatchHeaderId': batchHeaderId.toString(),
        'TransactionType': '2',
      });
      List<LappingModel> traysToClose = [];
      if (lappingPpRes.success && lappingPpRes.data != null) {
        final list = lappingPpRes.data as List<LappingModel>;
        traysToClose = list.where((r) =>
          (nextOperationId == null || r.productionProgress.operationId != nextOperationId) &&
          (r.productionProgress.subOperation ?? '').toLowerCase() != 'handover'
        ).toList();
      }
      if (traysToClose.isEmpty) {
        traysToClose = _state.trays.where((t) => (t.productionProgress.subOperation ?? '').toLowerCase() != 'handover').toList();
      }

      final closuresToProcess = _state.failedCloseLappingIds.isEmpty
          ? traysToClose
          : traysToClose.where((t) => _state.failedCloseLappingIds.contains(t.productionProgress.id)).toList();

      final List<Future<bool>> closureTasks = closuresToProcess.map((realLappingPP) async {
        if (realLappingPP.productionProgress.id != null && realLappingPP.productionProgress.id! > 0) {
          try {
            final closeJson = realLappingPP.productionProgress.toJson();
            closeJson['transactionType'] = 3;
            closeJson['wipStatus'] = 1;
            closeJson.remove('id');
            closeJson.remove('progressCode');
            closeJson.remove('creationTime');
            closeJson.remove('creatorId');
            closeJson.remove('lastModificationTime');
            closeJson.remove('lastModifierId');
            final closeRes = await _processingRepo.updateProductionProgress(
              realLappingPP.productionProgress.id!, closeJson,
            );
            return closeRes.success;
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
