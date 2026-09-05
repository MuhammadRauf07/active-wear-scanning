import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:active_wear_scanning/features/lot_making/repo/lot_repo.dart';
import 'package:active_wear_scanning/features/processing/repo/processing_repo.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/processing/model/processing_batch_state.dart';

import '../../common-models/common_models.dart';

class ProcessingBatchController extends ChangeNotifier {
  final int batchHeaderId;
  final int currentOperationId;
  final String batchCode;
  final int? machineId;
  final String machine;
  final String color;
  final int trayCount;
  final double totalWeight;
  final String operationName;
  final String nextOperationName;
  final int? nextOperationId;
  final bool hasPreviousProcess;

  final _processingRepo = ProcessingRepo();
  final _lotRepo = LotRepo();

  ProcessingBatchState _state = const ProcessingBatchState();
  ProcessingBatchState get state => _state;

  ProcessingBatchController({
    required this.batchHeaderId,
    required this.currentOperationId,
    required this.batchCode,
    this.machineId,
    required this.machine,
    required this.color,
    required this.trayCount,
    required this.totalWeight,
    required this.operationName,
    required this.nextOperationName,
    this.nextOperationId,
    required this.hasPreviousProcess,
  });

  Future<void> loadInitialData() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _fetchMachineCapacity();
      await _fetchBatchHeader();
      await fetchTrays();
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString());
      notifyListeners();
    }
  }

  Future<void> _fetchMachineCapacity() async {
    if (machineId == null) return;
    final res = await _lotRepo.fetchMachineById(machineId!);
    if (res.success && res.data != null) {
      final mData = res.data as Map<String, dynamic>;
      final mJson = mData['resource'] ?? mData;
      final cap = mJson['capacity'];
      if (cap != null) {
        _state = _state.copyWith(machineCapacity: double.tryParse(cap.toString()));
      }
    }
  }

  Future<void> _fetchBatchHeader() async {
    final res = await _lotRepo.fetchLotHeaderById(batchHeaderId);
    if (!res.success || res.data == null) return;
    final bh = LotHeaderResponseModel.fromJson(res.data as Map<String, dynamic>);
    final trayDetailId = bh.batchHeader.trayDetailId;
    if (trayDetailId != null) {
      final trayRes = await _lotRepo.fetchTrayDetailById(trayDetailId);
      if (trayRes.success && trayRes.data != null) {
        final trayRaw = trayRes.data as Map<String, dynamic>;
        final tdMap = (trayRaw['trayDetail'] is Map)
            ? Map<String, dynamic>.from(trayRaw['trayDetail'] as Map)
            : trayRaw;
        final code = tdMap['trayCode']?.toString();
        _state = _state.copyWith(
          trolleyCode: code,
          trolleyDetailId: trayDetailId,
        );
      }
    }
  }

  void toggleHoldTray(int trayId) {
    final updated = Set<int>.from(_state.holdTrayIds);
    if (updated.contains(trayId)) {
      updated.remove(trayId);
    } else {
      updated.add(trayId);
    }
    _state = _state.copyWith(holdTrayIds: updated);
    notifyListeners();
  }

  void selectAllHoldTrays(bool selected) {
    final updated = Set<int>.from(_state.holdTrayIds);
    for (final t in _state.trays) {
      if (t.productionProgress.holdFlag != true) {
        final trayId = t.primaryTrayModel.id ?? t.productionProgress.id;
        if (trayId != null) {
          if (selected) {
            updated.add(trayId);
          } else {
            updated.remove(trayId);
          }
        }
      }
    }
    _state = _state.copyWith(holdTrayIds: updated);
    notifyListeners();
  }

  Future<void> fetchTrays() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      final res = await _processingRepo.fetchProductionProgress({
        'BatchHeaderId': batchHeaderId.toString(),
        'OperationId': currentOperationId.toString(),
        'TransactionType': '2',
        'MaxResultCount': '1000',
      });

      bool isReassignedFromLines = false;
      final blRes = await _lotRepo.fetchLotLines(batchHeaderId: batchHeaderId);
      if (blRes.success && blRes.data != null) {
        final List lines = blRes.data as List;
        isReassignedFromLines = lines.any((l) {
          final bl = l['batchLines'] as Map<String, dynamic>? ?? l;
          return bl['isReAssigned'] == true;
        });
      }

      if (res.success && res.data != null) {
        final list = res.data as List<ProductionProgressResponseModel>;

        final wastageIds = list
            .where((t) => t.productionProgress.operationId == currentOperationId &&
                         (t.productionProgress.locatorId == 18 || (t.productionProgress.waste ?? 0) > 0))
            .map((t) => t.productionProgress.primaryTrayId)
            .whereType<int>()
            .toSet();

        final Map<int, ProductionProgressResponseModel> wastageByOriginalId = {};
        for (final t in list) {
          if (t.productionProgress.operationId != currentOperationId) continue;
          final subOp = t.productionProgress.subOperation;
          if (subOp != null) {
            final origId = int.tryParse(subOp);
            if (origId != null && t.productionProgress.locatorId == 18) {
              wastageByOriginalId[origId] = t;
            }
          }
        }

        // De-duplicate by Tray Code
        final Map<String, ProductionProgressResponseModel> uniqueTrays = {};
        for (final tray in list) {
          if (tray.productionProgress.transactionType != 2) continue;
          if (tray.productionProgress.wipStatus != 0) continue;
          if (tray.productionProgress.operationId != currentOperationId) continue;
          if (tray.productionProgress.locatorId == 18) continue;

          final code = tray.primaryTrayModel.trayCode ?? 'UNKNOWN';
          if (!uniqueTrays.containsKey(code) || (tray.productionProgress.id ?? 0) > (uniqueTrays[code]!.productionProgress.id ?? 0)) {
            uniqueTrays[code] = tray;
          }
        }
        final deDuplicatedList = uniqueTrays.values.toList();
        deDuplicatedList.sort((a, b) => (a.primaryTrayModel.trayCode ?? '').compareTo(b.primaryTrayModel.trayCode ?? ''));

        // Enrich each tray with metadata
        final enrichedList = <ProductionProgressResponseModel>[];
        for (final tray in deDuplicatedList) {
          final mainItemId = tray.item.id;
          final processedItemId = tray.productionProgress.processedItemId;

          String colorDesc = tray.item.colorDescription ?? '';
          String sizeDesc = tray.item.sizeDescription ?? '';
          double perGarmentTube = tray.item.perGarmentTube;

          if (mainItemId > 0) {
            final itemRes = await _lotRepo.fetchItemDef(mainItemId);
            if (itemRes.success && itemRes.data != null) {
              final itemData = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
              if (itemData['perGarmentTube'] != null) {
                perGarmentTube = (itemData['perGarmentTube'] as num).toDouble();
              }
              if (itemData['colorDescription'] != null) colorDesc = itemData['colorDescription'];
              if (itemData['sizeDescription'] != null) sizeDesc = itemData['sizeDescription'];
            }
          }

          if (colorDesc.isEmpty && processedItemId != null && processedItemId > 0) {
            final processedRes = await _lotRepo.fetchItemDef(processedItemId);
            if (processedRes.success && processedRes.data != null) {
              final pd = processedRes.data is Map ? processedRes.data as Map<String, dynamic> : {};
              if (pd['colorDescription'] != null) colorDesc = pd['colorDescription'];
              if (sizeDesc.isEmpty && pd['sizeDescription'] != null) sizeDesc = pd['sizeDescription'];
            }
          }

          final updatedItem = tray.item.copyWith(
            colorDescription: colorDesc,
            sizeDescription: sizeDesc,
            perGarmentTube: perGarmentTube,
          );
          enrichedList.add(tray.copyWith(item: updatedItem));
        }

        bool isBatchStarted = false;
        DateTime? issueTime;
        DateTime? startTime;

        if (enrichedList.isNotEmpty) {
          final pp = enrichedList.first.productionProgress;
          isBatchStarted = pp.isStarted == true;
          issueTime = pp.creationTime;
          startTime = pp.startDate;
        }

        final initialHoldTrayIds = <int>{};
        for (final t in enrichedList) {
          if (t.productionProgress.holdFlag == true) {
            if (t.primaryTrayModel.id != null) initialHoldTrayIds.add(t.primaryTrayModel.id!);
            if (t.productionProgress.id != null) initialHoldTrayIds.add(t.productionProgress.id!);
          }
        }

        _state = _state.copyWith(
          trays: enrichedList,
          holdTrayIds: initialHoldTrayIds,
          trayIdsWithWastage: wastageIds,
          wastageByOriginalId: wastageByOriginalId,
          isBatchStarted: isBatchStarted,
          issueTime: issueTime,
          startTime: startTime,
          isReassignedFromLines: isReassignedFromLines,
          isLoading: false,
          clearError: true,
        );
      } else {
        _state = _state.copyWith(isLoading: false, errorMessage: res.message);
      }
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString());
    }
    notifyListeners();
  }

  void toggleShowTrays() {
    _state = _state.copyWith(showTrays: !_state.showTrays);
    notifyListeners();
    if (_state.showTrays) {
      fetchTrays();
    }
  }

  Future<void> freeTrolley() async {
    _state = _state.copyWith(isUpdatingTrolley: true);
    notifyListeners();

    try {
      final bhRes = await _lotRepo.fetchLotHeaderById(batchHeaderId);
      if (!bhRes.success || bhRes.data == null) {
        throw Exception('Failed to fetch batch header');
      }
      final bh = LotHeaderResponseModel.fromJson(bhRes.data as Map<String, dynamic>).batchHeader;
      
      final updateRes = await _lotRepo.updateLotHeader(batchHeaderId, {
        'planDate': bh.planDate,
        'colorDescription': bh.colorDescription,
        'lockFlag': bh.lockFlag ?? false,
        'batchHeaderCode': bh.batchHeaderCode,
        'machineId': bh.machineId,
        'colorCode': bh.colorCodeId,
        'shiftId': bh.shiftId,
        'trayDetailId': null,
        'concurrencyStamp': bh.concurrencyStamp,
      });

      if (updateRes.success) {
        _state = _state.copyWith(
          trolleyCode: null,
          trolleyDetailId: null,
          isUpdatingTrolley: false,
          clearError: true,
        );
      } else {
        throw Exception('Free failed: ${updateRes.message}');
      }
    } catch (e) {
      _state = _state.copyWith(isUpdatingTrolley: false, errorMessage: e.toString());
    }
    notifyListeners();
  }

  Future<String?> attachTrolley(String code) async {
    _state = _state.copyWith(isUpdatingTrolley: true);
    notifyListeners();

    try {
      final result = await _lotRepo.fetchTrayDetailByCode(code);
      if (!result.success || result.data == null) {
        _state = _state.copyWith(isUpdatingTrolley: false);
        notifyListeners();
        return 'Trolley not found: $code';
      }

      final rawMap = result.data as Map<String, dynamic>;
      final tdMap = (rawMap['trayDetail'] is Map)
          ? Map<String, dynamic>.from(rawMap['trayDetail'] as Map)
          : rawMap;

      if (tdMap['active'] != true) {
        _state = _state.copyWith(isUpdatingTrolley: false);
        notifyListeners();
        return 'Trolley "$code" is not active';
      }

      if ((tdMap['trayType'] as int? ?? 0) != 4) {
        _state = _state.copyWith(isUpdatingTrolley: false);
        notifyListeners();
        return 'Invalid type. Only Type 4 (Trolley) is allowed.';
      }

      final trolleyId = tdMap['id'] as int?;
      if (trolleyId == null) {
        _state = _state.copyWith(isUpdatingTrolley: false);
        notifyListeners();
        return 'Could not resolve trolley ID';
      }

      final assignedBatchId = tdMap['batchHeaderId'] as int?;
      if (assignedBatchId != null && assignedBatchId != batchHeaderId) {
        _state = _state.copyWith(isUpdatingTrolley: false);
        notifyListeners();
        return 'Trolley already assigned to another batch (ID: $assignedBatchId)';
      }

      final bhRes = await _lotRepo.fetchLotHeaderById(batchHeaderId);
      if (!bhRes.success || bhRes.data == null) {
        _state = _state.copyWith(isUpdatingTrolley: false);
        notifyListeners();
        return 'Failed to fetch batch header';
      }

      final bh = LotHeaderResponseModel.fromJson(bhRes.data as Map<String, dynamic>).batchHeader;
      final updateRes = await _lotRepo.updateLotHeader(batchHeaderId, {
        'planDate': bh.planDate,
        'colorDescription': bh.colorDescription,
        'lockFlag': bh.lockFlag ?? false,
        'batchHeaderCode': bh.batchHeaderCode,
        'machineId': bh.machineId,
        'colorCode': bh.colorCodeId,
        'shiftId': bh.shiftId,
        'trayDetailId': trolleyId,
        'concurrencyStamp': bh.concurrencyStamp,
      });

      if (updateRes.success) {
        final resolvedCode = tdMap['trayCode']?.toString() ?? code;
        _state = _state.copyWith(
          trolleyCode: resolvedCode,
          trolleyDetailId: trolleyId,
          isUpdatingTrolley: false,
          clearError: true,
        );
        notifyListeners();
        return null; // success
      } else {
        _state = _state.copyWith(isUpdatingTrolley: false);
        notifyListeners();
        return 'Attach failed: ${updateRes.message}';
      }
    } catch (e) {
      _state = _state.copyWith(isUpdatingTrolley: false);
      notifyListeners();
      return 'Unexpected error: $e';
    }
  }

  Future<void> startBatch() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    final now = DateTime.now();
    bool anyFailed = false;

    try {
      for (final t in _state.trays) {
        final pp = t.productionProgress;
        final payload = pp.toJson()
          ..['isStarted'] = true
          ..['startDate'] = now.toIso8601String();

        payload.remove('id');
        payload.remove('progressCode');
        payload.remove('creationTime');
        payload.remove('creatorId');
        payload.remove('lastModificationTime');
        payload.remove('lastModifierId');

        final res = await _processingRepo.updateProductionProgress(pp.id!, payload);
        if (!res.success) anyFailed = true;
      }

      if (anyFailed) {
        throw Exception('Some trays failed to start. Please retry.');
      } else {
        _state = _state.copyWith(
          isBatchStarted: true,
          startTime: now,
          trays: [], // Force reload
        );
        notifyListeners();
        await fetchTrays();
      }
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString());
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateQuantity(int progressId, double newQty, [int productGrade = 1]) async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final tIdx = _state.trays.indexWhere((t) => t.productionProgress.id == progressId);
      if (tIdx == -1) throw Exception('Tray not found');
      final tray = _state.trays[tIdx];

      final double requiredTubes = tray.productionProgress.requiredQty?.toDouble() ??
          tray.productionProgress.secondaryQuantity?.toDouble() ??
          tray.productionProgress.primaryQuantity?.toDouble() ??
          0.0;
      final double wastageTubes = requiredTubes - newQty;
      final double pgt = tray.item.perGarmentTube;
      final double newPrimaryQty = pgt > 0 ? newQty * pgt : newQty;
      final double wastagePrimaryQty = pgt > 0 ? wastageTubes * pgt : wastageTubes;

      // 1. Update original production progress record
      final json = tray.productionProgress.toJson();
      json['secondaryQuantity'] = newQty;
      json['primaryQuantity'] = newPrimaryQty;
      if (wastageTubes > 0) {
        json['requiredQty'] = requiredTubes.toInt();
        json['waste'] = wastageTubes.toInt();
      } else {
        json['requiredQty'] = null;
        json['waste'] = null;
      }

      json.remove('id');
      json.remove('progressCode');
      json.remove('creationTime');
      json.remove('creatorId');
      json.remove('lastModificationTime');
      json.remove('lastModifierId');

      final res = await _processingRepo.updateProductionProgress(progressId, json);
      if (!res.success) {
        throw Exception(res.message);
      }

      // Sync the original line's quantity to its corresponding WIPTransaction
      try {
        final wipRes = await _lotRepo.fetchWipTransactionsByProgressId(progressId);
        if (wipRes.success && wipRes.data != null) {
          final List rawItems = wipRes.data is Map ? (wipRes.data['items'] ?? []) : wipRes.data;
          final items = rawItems.cast<Map<String, dynamic>>();
          final match = items.firstWhere(
            (e) => (e['wipTransaction']?['progressId'] ?? e['progressId'] ?? e['wipTransaction']?['productionProgressId'] ?? e['productionProgressId'])?.toString() == progressId.toString(),
            orElse: () => <String, dynamic>{},
          );
          if (match.isNotEmpty) {
            final wipId = match['wipTransaction']?['id'] as int?;
            if (wipId != null) {
              final wipPayload = Map<String, dynamic>.from(match['wipTransaction'] ?? match);
              wipPayload['secondaryQuantity'] = newQty;
              wipPayload['primaryQuantity'] = newPrimaryQty;
              wipPayload.remove('id');
              wipPayload.remove('concurrencyStamp');
              await _lotRepo.updateWipTransaction(wipId, wipPayload);
            }
          }
        }
      } catch (e) {
        debugPrint('Error syncing original WIP quantity: $e');
      }

      // 2. Manage the wastage record
      if (wastageTubes > 0) {
        final wastageRecord = _state.wastageByOriginalId[progressId];
        if (wastageRecord != null && wastageRecord.productionProgress.id != null) {
          // UPDATE existing wastage record
          final wJson = wastageRecord.productionProgress.toJson();
          wJson['secondaryQuantity'] = wastageTubes;
          wJson['primaryQuantity'] = wastagePrimaryQty;
          wJson['waste'] = 0;
          wJson['requiredQty'] = requiredTubes.toInt();
          wJson['locatorId'] = 18;
          wJson['productGrade'] = productGrade;

          wJson.remove('id');
          wJson.remove('progressCode');
          wJson.remove('creationTime');
          wJson.remove('creatorId');
          wJson.remove('lastModificationTime');
          wJson.remove('lastModifierId');

          final postRes = await _processingRepo.updateProductionProgress(wastageRecord.productionProgress.id!, wJson);
          if (!postRes.success) {
            throw Exception(postRes.message);
          }
        } else {
          // CREATE new wastage record
          final newJson = tray.productionProgress.toJson();
          newJson.remove('id');
          newJson.remove('progressCode');
          newJson.remove('concurrencyStamp');
          newJson.remove('creationTime');
          newJson.remove('creatorId');
          newJson.remove('lastModificationTime');
          newJson.remove('lastModifierId');

          newJson['secondaryQuantity'] = wastageTubes;
          newJson['primaryQuantity'] = wastagePrimaryQty;
          newJson['waste'] = 0;
          newJson['requiredQty'] = requiredTubes.toInt();
          newJson['locatorId'] = 18;
          newJson['productGrade'] = productGrade;
          newJson['transactionType'] = tray.productionProgress.transactionType ?? 2;
          newJson['subOperation'] = progressId.toString();
          newJson['isStarted'] = false;
          newJson['startDate'] = null;
          newJson['date'] = DateTime.now().toIso8601String();

          final postRes = await _processingRepo.createProductionProgress(newJson);
          if (!postRes.success) {
            throw Exception(postRes.message);
          }
        }
      } else {
        // newQty == requiredQty (wastage reduced to 0), delete the wastage record if exists
        final wastageRecord = _state.wastageByOriginalId[progressId];
        if (wastageRecord != null && wastageRecord.productionProgress.id != null) {
          final wId = wastageRecord.productionProgress.id!;
          await _processingRepo.deleteProductionProgress(wId);
        }
      }

      _state = _state.copyWith(trays: []); // Force reload
      notifyListeners();
      await fetchTrays();
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString());
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteWastage(int progressId) async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final tIdx = _state.trays.indexWhere((t) => t.productionProgress.id == progressId);
      if (tIdx == -1) throw Exception('Tray not found');
      final tray = _state.trays[tIdx];

      final double requiredTubes = tray.productionProgress.requiredQty?.toDouble() ??
          tray.productionProgress.secondaryQuantity?.toDouble() ??
          tray.productionProgress.primaryQuantity?.toDouble() ??
          0.0;
      final double pgt = tray.item.perGarmentTube;
      final double restoredPrimaryPcs = pgt > 0 ? requiredTubes * pgt : requiredTubes;

      // 1. Delete wastage entry
      final wastageRecord = _state.wastageByOriginalId[progressId];
      if (wastageRecord != null && wastageRecord.productionProgress.id != null) {
        final wId = wastageRecord.productionProgress.id!;
        final delRes = await _processingRepo.deleteProductionProgress(wId);
        if (!delRes.success) {
          throw Exception(delRes.message);
        }
      }

      // 2. Restore primary & secondary quantities on original progress entry and clear waste fields
      final json = tray.productionProgress.toJson();
      json['secondaryQuantity'] = requiredTubes;
      json['primaryQuantity'] = restoredPrimaryPcs;
      json['requiredQty'] = null;
      json['waste'] = null;

      json.remove('id');
      json.remove('progressCode');
      json.remove('creationTime');
      json.remove('creatorId');
      json.remove('lastModificationTime');
      json.remove('lastModifierId');

      final res = await _processingRepo.updateProductionProgress(progressId, json);
      if (!res.success) {
        throw Exception(res.message);
      }

      // Sync restored original quantity to its corresponding WIPTransaction
      try {
        final wipRes = await _lotRepo.fetchWipTransactionsByProgressId(progressId);
        if (wipRes.success && wipRes.data != null) {
          final List rawItems = wipRes.data is Map ? (wipRes.data['items'] ?? []) : wipRes.data;
          final items = rawItems.cast<Map<String, dynamic>>();
          final match = items.firstWhere(
            (e) => (e['wipTransaction']?['progressId'] ?? e['progressId'] ?? e['wipTransaction']?['productionProgressId'] ?? e['productionProgressId'])?.toString() == progressId.toString(),
            orElse: () => <String, dynamic>{},
          );
          if (match.isNotEmpty) {
            final wipId = match['wipTransaction']?['id'] as int?;
            if (wipId != null) {
              final wipPayload = Map<String, dynamic>.from(match['wipTransaction'] ?? match);
              wipPayload['secondaryQuantity'] = requiredTubes;
              wipPayload['primaryQuantity'] = restoredPrimaryPcs;
              wipPayload.remove('id');
              wipPayload.remove('concurrencyStamp');
              await _lotRepo.updateWipTransaction(wipId, wipPayload);
            }
          }
        }
      } catch (e) {
        debugPrint('Error syncing restored original WIP quantity: $e');
      }

      _state = _state.copyWith(trays: []); // Force reload
      notifyListeners();
      await fetchTrays();
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString());
      notifyListeners();
      rethrow;
    }
  }

  void toggleReworkTray(int progressId, bool selected) {
    final updatedSet = Set<int>.from(_state.selectedReworkTrayIds);
    if (selected) {
      updatedSet.add(progressId);
    } else {
      updatedSet.remove(progressId);
    }
    _state = _state.copyWith(selectedReworkTrayIds: updatedSet);
    notifyListeners();
  }

  void toggleReworkMode({required bool enabled, int? targetOpId, String? targetOpName}) {
    _state = _state.copyWith(
      isReworkMode: enabled,
      selectedReworkTrayIds: enabled ? _state.selectedReworkTrayIds : {},
      reworkTargetOpId: enabled ? targetOpId : null,
      reworkTargetOpName: enabled ? targetOpName : null,
      showTrays: enabled ? true : _state.showTrays,
    );
    notifyListeners();
  }

  void selectAllReworkTrays(bool selected) {
    final updatedSet = selected
        ? _state.trays.map((t) => t.productionProgress.id).whereType<int>().toSet()
        : <int>{};
    _state = _state.copyWith(selectedReworkTrayIds: updatedSet);
    notifyListeners();
  }

  Future<void> submitBatch(void Function(Map<String, dynamic> result) onSuccess) async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final baseProgress = _state.trays.isNotEmpty ? _state.trays.first.productionProgress : null;
      final targetOpId = nextOperationId ?? currentOperationId;
      int nextLocatorId = baseProgress?.locatorId ?? 10;

      final opsRes = await _processingRepo.fetchProcessingOperations();
      if (opsRes.success && opsRes.data != null) {
        final List<Operation> opsList = List<Operation>.from(opsRes.data);
        final matchOp = opsList.firstWhere(
          (o) => o.id == targetOpId,
          orElse: () => Operation(code: '', name: '', description: null, identifierRef: null, concurrencyStamp: '', creationTime: '', lastModificationTime: null, creatorId: null, lastModifierId: null, id: 0),
        );
        if (matchOp.id != 0) {
          final resolvedLocId = matchOp.locatorId ?? matchOp.locator?.id;
          if (resolvedLocId != null && resolvedLocId > 0) {
            nextLocatorId = resolvedLocId;
          }
        }
      }

      if (nextLocatorId == (baseProgress?.locatorId ?? 10)) {
        final locRes = await _processingRepo.fetchLocators(operationId: targetOpId);
        if (locRes.success && locRes.data != null) {
          final List locList = locRes.data is Map ? (locRes.data['items'] ?? []) : locRes.data;
          final match = locList.cast<Map>().firstWhere(
            (e) => (e['operation']?['id'] ?? e['locator']?['operationId'])?.toString() == targetOpId.toString(),
            orElse: () => {},
          );
          if (match.isNotEmpty) {
            nextLocatorId = match['locator']?['id'] as int? ?? nextLocatorId;
          }
        }
      }

      final List<int> newFailedTrayIds = [];
      final traysToProcess = _state.trays;

      // Check if user is attempting to submit trays that are already on HOLD in PBS without toggling/unholding
      for (final t in traysToProcess) {
        final pp = t.productionProgress;
        if (pp.holdFlag == true && !_state.holdTrayIds.contains(pp.primaryTrayId) && !_state.holdTrayIds.contains(pp.id)) {
          final trayCode = t.primaryTrayModel.trayCode ?? '${pp.primaryTrayId}';
          throw Exception('Tray $trayCode is on HOLD. Unhold it from Unhold Trays section to submit.');
        }
      }

      for (final t in traysToProcess) {
        final pp = t.productionProgress;
        final json = pp.toJson();
        final isRework = _state.isReworkMode && _state.selectedReworkTrayIds.contains(pp.id);

        try {
          if (isRework) {
            json['transactionType'] = 3;
            json['wipStatus'] = 1;
            json.remove('id');
            json.remove('progressCode');
            json.remove('creationTime');
            json.remove('creatorId');
            json.remove('lastModificationTime');
            json.remove('lastModifierId');
            
            final updRes = await _processingRepo.updateProductionProgress(pp.id!, json);
            if (!updRes.success) throw Exception('Update failed: ${updRes.message}');

            int rewLoc = pp.locatorId ?? 10;
            if (_state.reworkTargetOpId != null) {
              final opsRes = await _processingRepo.fetchProcessingOperations();
              if (opsRes.success && opsRes.data != null) {
                final List<Operation> opsList = List<Operation>.from(opsRes.data);
                final matchOp = opsList.firstWhere(
                  (o) => o.id == _state.reworkTargetOpId,
                  orElse: () => Operation(code: '', name: '', description: null, identifierRef: null, concurrencyStamp: '', creationTime: '', lastModificationTime: null, creatorId: null, lastModifierId: null, id: 0),
                );
                if (matchOp.id != 0) {
                  final resolvedLocId = matchOp.locatorId ?? matchOp.locator?.id;
                  if (resolvedLocId != null && resolvedLocId > 0) {
                    rewLoc = resolvedLocId;
                  }
                }
              }
            }

            final newJ = pp.toJson();
            newJ.remove('id');
            newJ.remove('progressCode');
            newJ.remove('concurrencyStamp');
            newJ.addAll({
              'transactionType': 2,
              'reworkFlag': true,
              'isStarted': false,
              'startDate': null,
              'machineId': null,
              'batchLineId': pp.batchLinesId,
              'batchLinesId': pp.batchLinesId,
              'isLastProcess': false,
              'operationId': _state.reworkTargetOpId,
              'locatorId': rewLoc,
              'date': DateTime.now().toIso8601String(),
              'waste': null,
              'requiredQty': null,
            });
            final crRes = await _processingRepo.createProductionProgress(newJ);
            if (!crRes.success) throw Exception('Create failed: ${crRes.message}');

            int? targetProgressId;
            final ppData = crRes.data;
            if (ppData is Map) {
              final rawId = int.tryParse(ppData['id']?.toString() ?? '');
              if (rawId != null && rawId > 0) targetProgressId = rawId;
            } else if (ppData is int && ppData > 0) {
              targetProgressId = ppData;
            }

            if (targetProgressId != null && targetProgressId > 0 && pp.batchLinesId != null) {
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
                    wipPayload['batchLinesId'] = pp.batchLinesId;
                    wipPayload['batchLineId'] = pp.batchLinesId;
                    wipPayload.remove('id');
                    wipPayload.remove('concurrencyStamp');
                    await _lotRepo.updateWipTransaction(newWipId, wipPayload);
                  }
                }
              }
            }
          } else {
            final bool isHold = _state.holdTrayIds.contains(pp.primaryTrayId) || _state.holdTrayIds.contains(pp.id) || pp.holdFlag == true;

            if (isHold) {
              // Tray remains in PBS as HOLD under the same batch
              final Map<String, dynamic> holdJson = pp.toJson();
              holdJson['holdFlag'] = true;
              holdJson['holdDate'] = DateTime.now().toIso8601String();
              holdJson['transactionType'] = 2;
              holdJson['wipStatus'] = 0;
              holdJson.remove('id');
              holdJson.remove('progressCode');
              holdJson.remove('creationTime');
              holdJson.remove('creatorId');
              holdJson.remove('lastModificationTime');
              holdJson.remove('lastModifierId');

              final updHoldRes = await _processingRepo.updateProductionProgress(pp.id!, holdJson);
              if (!updHoldRes.success) throw Exception('Hold update failed: ${updHoldRes.message}');
            } else {
              json['transactionType'] = 3;
              json['wipStatus'] = 1;
              if (nextOperationId == null) json['isLastProcess'] = true;
              json.remove('id');
              json.remove('progressCode');
              json.remove('creationTime');
              json.remove('creatorId');
              json.remove('lastModificationTime');
              json.remove('lastModifierId');
              
              final updRes = await _processingRepo.updateProductionProgress(pp.id!, json);
              if (!updRes.success) throw Exception('Update failed: ${updRes.message}');

              if (nextOperationId != null) {
                final Map<String, dynamic> newJ = pp.toJson();
                newJ.remove('id');
                newJ.remove('progressCode');
                newJ.remove('concurrencyStamp');
                newJ.addAll({
                  'transactionType': 2,
                  'draftFlag': false,
                  'draftStatus': false,
                  'draftDate': null,
                  'reworkFlag': pp.reworkFlag ?? false,
                  'isStarted': false,
                  'startDate': null,
                  'machineId': null,
                  'batchLineId': pp.batchLinesId,
                  'batchLinesId': pp.batchLinesId,
                  'isLastProcess': false,
                  'operationId': nextOperationId,
                  'locatorId': nextLocatorId,
                  'date': DateTime.now().toIso8601String(),
                  'holdFlag': false,
                  'waste': null,
                  'requiredQty': null,
                });
                final crRes = await _processingRepo.createProductionProgress(newJ);
                if (!crRes.success) throw Exception('Create failed: ${crRes.message}');

                int? targetProgressId;
                final ppData = crRes.data;
                if (ppData is Map) {
                  final rawId = int.tryParse(ppData['id']?.toString() ?? '');
                  if (rawId != null && rawId > 0) targetProgressId = rawId;
                } else if (ppData is int && ppData > 0) {
                  targetProgressId = ppData;
                }

                if (targetProgressId != null && targetProgressId > 0 && pp.batchLinesId != null) {
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
                        wipPayload['batchLinesId'] = pp.batchLinesId;
                        wipPayload['batchLineId'] = pp.batchLinesId;
                        wipPayload.remove('id');
                        wipPayload.remove('concurrencyStamp');
                        await _lotRepo.updateWipTransaction(newWipId, wipPayload);
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          dev.log('❌ Tray submission error for PP ${pp.id}: $e');
          newFailedTrayIds.add(pp.id!);
        }
      }

      final updatedFailedTrayIds = Set<int>.from(_state.failedTrayIds);
      if (_state.failedTrayIds.isEmpty) {
        updatedFailedTrayIds.addAll(newFailedTrayIds);
      } else {
        for (final t in traysToProcess) {
          final id = t.productionProgress.id!;
          if (newFailedTrayIds.contains(id)) {
            updatedFailedTrayIds.add(id);
          } else {
            updatedFailedTrayIds.remove(id);
          }
        }
      }

      _state = _state.copyWith(
        failedTrayIds: updatedFailedTrayIds,
        isLoading: false,
      );

      if (updatedFailedTrayIds.isNotEmpty) {
        throw Exception('${updatedFailedTrayIds.length} tray(s) failed to submit. Please check connection and retry.');
      }

      final List<int> targetOps = [];
      if (_state.isReworkMode && _state.reworkTargetOpId != null) {
        targetOps.add(_state.reworkTargetOpId!);
      }
      
      bool hasStandard = false;
      if (_state.isReworkMode) {
        hasStandard = _state.trays.any((t) => !_state.selectedReworkTrayIds.contains(t.productionProgress.id));
      } else {
        hasStandard = true;
      }
      
      if (hasStandard && nextOperationId != null) {
        if (!targetOps.contains(nextOperationId!)) {
          targetOps.add(nextOperationId!);
        }
      }

      final bool hasRemainingHeldTrays = _state.trays.any((t) => t.productionProgress.holdFlag == true);
      final int reworkCount = _state.isReworkMode ? _state.selectedReworkTrayIds.length : 0;
      final int standardCount = _state.isReworkMode
          ? (_state.trays.length - _state.selectedReworkTrayIds.length)
          : _state.trays.length;

      onSuccess({
        'submitted': true,
        'targetOps': targetOps,
        'isRework': _state.isReworkMode,
        'reworkTargetOpId': _state.reworkTargetOpId,
        'reworkTrayCount': reworkCount,
        'nextOpId': nextOperationId,
        'standardTrayCount': standardCount,
        'isReassigned': false,
        'hasRemainingHeldTrays': hasRemainingHeldTrays,
        'batchHeaderId': _state.trays.isNotEmpty ? _state.trays.first.productionProgress.batchHeaderId : null,
      });

    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString());
      notifyListeners();
      rethrow;
    }
  }
}
