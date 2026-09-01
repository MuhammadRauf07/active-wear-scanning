import 'package:active_wear_scanning/features/lot_making/repo/lot_repo.dart';
import 'package:flutter/foundation.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:active_wear_scanning/features/gbs/model/gbs_scanned_tray.dart';
import 'package:active_wear_scanning/features/induction/model/induction_model.dart';
import 'package:active_wear_scanning/features/induction/model/induction_state.dart';
import 'package:active_wear_scanning/features/induction/repo/induction_repo.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';

class InductionController extends ChangeNotifier {
  final _inductionRepo = fromPlex<InductionRepo>();
  final _lotRepo = LotRepo();

  InductionState _state = const InductionState();
  InductionState get state => _state;

  InductionController() {
    initData();
  }

  Future<void> initData() async {
    await fetchAvailableTrays();
  }

  void selectBatch(LotHeaderModel? batch) {
    if (_state.selectedBatch?.id != batch?.id) {
      _state = _state.copyWith(
        selectedBatch: batch,
        scannedTrays: [],
      );
      notifyListeners();
    }
  }

  void removeScannedTray(int index) {
    if (index >= 0 && index < _state.scannedTrays.length) {
      final updated = List<GBSScannedTray>.from(_state.scannedTrays)..removeAt(index);
      _state = _state.copyWith(scannedTrays: updated);
      notifyListeners();
    }
  }

  Future<void> fetchAvailableTrays() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    // Fetch lot lines to identify all officially reassigned trays
    final blRes = await _lotRepo.fetchLotLines();
    final Set<int> reassignedTrayIds = {};
    final Map<int, int> reassignedTrayToBatchId = {};
    if (blRes.success && blRes.data != null) {
      final rawLines = blRes.data is List ? blRes.data as List : [];
      for (final l in rawLines) {
        final bl = l['batchLines'] as Map<String, dynamic>? ?? (l is Map<String, dynamic> ? l : {});
        if (bl['isReAssigned'] == true) {
          final trayId = bl['trayId'] as int?;
          final bhId = bl['batchHeaderId'] as int?;
          if (trayId != null) {
            reassignedTrayIds.add(trayId);
            if (bhId != null) reassignedTrayToBatchId[trayId] = bhId;
          }
        }
      }
    }

    final res = await _inductionRepo.getProductionProgress();
    if (res.success && res.data != null) {
      final allTrays = res.data as List<InductionModel>;
      
      // De-duplicate by primaryTrayId to keep ONLY the latest progress record for each tray
      final Map<int, InductionModel> latestByTray = {};
      for (final t in allTrays) {
        final trayId = t.productionProgress.primaryTrayId ?? t.primaryTrayModel.id;
        if (trayId != null) {
          if (!latestByTray.containsKey(trayId) || (t.productionProgress.id ?? 0) > (latestByTray[trayId]!.productionProgress.id ?? 0)) {
            latestByTray[trayId] = t;
          }
        }
      }

      final filtered = latestByTray.values.where((t) {
        final trayId = t.productionProgress.primaryTrayId ?? t.primaryTrayModel.id;
        final bool isReassigned = t.primaryTrayModel.isReAssigned == true ||
            (trayId != null && reassignedTrayIds.contains(trayId)) ||
            (t.productionProgress.subOperation?.toLowerCase() == 'handover');

        // Only show reassigned trays in Induction Store
        if (!isReassigned) return false;
        if (t.productionProgress.holdFlag == true) return false;
        if (t.productionProgress.pbsFlag == true) return false;
        return true;
      }).toList();

      final Map<int, LotHeaderModel> batchHeaderCache = {};
      final enrichedFiltered = <InductionModel>[];
      for (final t in filtered) {
        InductionModel itemToUse = t;
        final trayId = itemToUse.productionProgress.primaryTrayId ?? itemToUse.primaryTrayModel.id;
        final bhId = itemToUse.productionProgress.batchHeaderId ?? (trayId != null ? reassignedTrayToBatchId[trayId] : null);
        
        if ((itemToUse.batchHeader == null || itemToUse.batchHeader?.batchHeaderCode == null) && bhId != null && bhId > 0) {
          if (batchHeaderCache.containsKey(bhId)) {
            itemToUse = itemToUse.copyWith(batchHeader: batchHeaderCache[bhId]);
          } else {
            try {
              final bhRes = await _inductionRepo.fetchLotHeaderById(bhId);
              if (bhRes.success && bhRes.data != null) {
                final Map<String, dynamic> dataMap = Map<String, dynamic>.from(bhRes.data is Map ? bhRes.data : {});
                LotHeaderModel? bhModel;
                if (dataMap.containsKey('batchHeader') && dataMap['batchHeader'] != null) {
                  bhModel = LotHeaderModel.fromJson(Map<String, dynamic>.from(dataMap['batchHeader']));
                } else if (dataMap.containsKey('id') || dataMap.containsKey('batchHeaderCode')) {
                  bhModel = LotHeaderModel.fromJson(dataMap);
                }
                if (bhModel != null) {
                  batchHeaderCache[bhId] = bhModel;
                  itemToUse = itemToUse.copyWith(batchHeader: bhModel);
                }
              }
            } catch (e) {
              debugPrint("⚠️ Exception parsing LotHeader in InductionController: $e");
            }
          }
        }
        enrichedFiltered.add(itemToUse);
      }

      _state = _state.copyWith(
        availableTrays: enrichedFiltered,
        isLoading: false,
      );
    } else {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: res.message,
      );
    }
    notifyListeners();
  }

  Future<String?> validateTrayForInduction(String scannedCode) async {
    final code = scannedCode.trim().toLowerCase();
    if (code.isEmpty) return 'Invalid tray code';

    if (_state.selectedBatch == null) {
      return 'Please select a batch/lot number from the dropdown first';
    }

    final alreadyScanned = _state.scannedTrays.any(
      (t) => t.trayCode.trim().toLowerCase() == code,
    );
    if (alreadyScanned) return 'Already scanned';

    final res = await _inductionRepo.getProductionProgress();
    if (res.success && res.data != null) {
      final allTrays = res.data as List<InductionModel>;
      final Map<int, InductionModel> latestByTray = {};
      for (final t in allTrays) {
        final trayId = t.productionProgress.primaryTrayId ?? t.primaryTrayModel.id;
        if (trayId != null) {
          if (!latestByTray.containsKey(trayId) || (t.productionProgress.id ?? 0) > (latestByTray[trayId]!.productionProgress.id ?? 0)) {
            latestByTray[trayId] = t;
          }
        }
      }

      final holdMatch = latestByTray.values.where((t) {
        final tCode = (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase();
        final pCode = (t.productionProgress.progressCode ?? '').trim().toLowerCase();
        return tCode == code || pCode == code;
      }).firstOrNull;

      if (holdMatch != null && holdMatch.productionProgress.holdFlag == true) {
        return 'Tray ${holdMatch.primaryTrayModel.trayCode} is on HOLD in PBS and cannot be received in Induction Store.';
      }
    }

    final selectedBatchId = _state.selectedBatch?.id;
    final matchIndex = _state.availableTrays.indexWhere((t) {
      final tCode = (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase();
      final pCode = (t.productionProgress.progressCode ?? '').trim().toLowerCase();
      final isCodeMatch = tCode == code || pCode == code;
      final isBatchMatch = t.batchHeader?.id == selectedBatchId ||
          t.productionProgress.batchHeaderId == selectedBatchId;
      return isCodeMatch && isBatchMatch;
    });

    if (matchIndex == -1) {
      final batchName = _state.selectedBatch?.batchHeaderCode ?? '#${_state.selectedBatch?.id}';
      return 'Tray is not a reassigned tray for selected Batch $batchName';
    }

    final match = _state.availableTrays[matchIndex];

    if ((match.primaryTrayModel.trayType ?? 0) != 1) {
      return 'Invalid tray type.';
    }

    int targetItemId = match.productionProgress.processedItemId ?? match.item.id;
    String colorDesc = match.item.colorDescription ?? '';
    String sizeDesc = match.item.sizeDescription ?? '';

    if (targetItemId > 0) {
      final itemRes = await _inductionRepo.fetchItemDef(targetItemId);
      if (itemRes.success && itemRes.data != null) {
        final itemData = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
        if (itemData['colorDescription'] != null) colorDesc = itemData['colorDescription'];
        if (itemData['sizeDescription'] != null) sizeDesc = itemData['sizeDescription'];
      }
    }

    final newTray = GBSScannedTray(
      trayCode: match.primaryTrayModel.trayCode ?? '-',
      workOrderCode: match.workOrderHeader.workOrderCode,
      itemDescription: match.item.description,
      sizeDescription: sizeDesc,
      colorDescription: colorDesc,
      primaryQuantity: (match.productionProgress.primaryQuantity ?? 0).toStringAsFixed(0),
      pieceWeight: match.item.pieceWeight ?? 0.0,
      trayUpdateId: match.primaryTrayModel.id,
      trayConcurrencyStamp: match.primaryTrayModel.concurrencyStamp,
    );

    final updated = List<GBSScannedTray>.from(_state.scannedTrays)..add(newTray);
    _state = _state.copyWith(scannedTrays: updated);
    notifyListeners();
    return null;
  }

  Future<void> saveInductionChanges() async {
    if (_state.scannedTrays.isEmpty) return;

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      for (var scannedTray in _state.scannedTrays) {
        final currentTrayMatch = _state.availableTrays
            .where((t) => t.primaryTrayModel.id == scannedTray.trayUpdateId)
            .firstOrNull;

        if (currentTrayMatch == null) continue;

        final currentTrayData = currentTrayMatch;

        Map<String, dynamic> wipPayload = {
          "subOperation": "Induction Store",
          "transactionDate": DateTime.now().toIso8601String(),
          "transactionType": 1,
          "uom": currentTrayData.workOrderLine.uom,
          "operatorDescription": "system",
          "primaryQuantity": currentTrayData.productionProgress.primaryQuantity ?? 0,
          "secondaryQuantity": currentTrayData.productionProgress.secondaryQuantity ?? 0,
          "primaryUOM": currentTrayData.productionProgress.primaryUOM ?? 0,
          "secondaryUOM": currentTrayData.productionProgress.secondaryUOM ?? 0,
          "code": currentTrayData.item.code,
          "productGrade": currentTrayData.productionProgress.productGrade ?? 0,
          "productNature": currentTrayData.productionProgress.productNature ?? 0,
          "progressId": currentTrayData.productionProgress.id,
          "operationId": currentTrayData.productionProgress.operationId,
          "workOrderHeaderId": currentTrayData.workOrderHeader.id,
          "workOrderLineId": currentTrayData.workOrderLine.id,
          "itemId": currentTrayData.item.id,
          "shiftId": currentTrayData.shift.id,
          "primaryTrayId": currentTrayData.primaryTrayModel.id,
          "machineId": currentTrayData.machineModel.id,
          "planHeaderId": currentTrayData.productionProgress.planHeaderId ?? currentTrayData.planHeader?.id,
          "locatorId": 11,
          "batchHeaderId": currentTrayData.productionProgress.batchHeaderId,
          "batchLineId": currentTrayData.productionProgress.batchLinesId,
          "processitemd": currentTrayData.productionProgress.processedItemId ?? currentTrayData.item.id,
        };

        await _inductionRepo.postWipTransactions(wipPayload);

        Map<String, dynamic> updatePayload = currentTrayData.productionProgress.toJson();
        updatePayload['pbsFlag'] = true;
        updatePayload['pBSFlag'] = true;
        updatePayload['locatorId'] = 11;
        updatePayload['date'] = DateTime.now().toIso8601String();

        final res = await _inductionRepo.updateProductionProgress(
          currentTrayData.productionProgress.id!,
          updatePayload,
        );

        if (!res.success) {
          throw Exception('Failed to update tray ${scannedTray.trayCode}');
        }

        final trayRes = await _inductionRepo.fetchTrayDetailById(currentTrayData.primaryTrayModel.id!);
        if (trayRes.success) {
          final tData = trayRes.data.containsKey('trayDetail') ? trayRes.data['trayDetail'] : trayRes.data;
          Map<String, dynamic> trayUpd = Map<String, dynamic>.from(tData);
          trayUpd["locatorId"] = 11;
          trayUpd.removeWhere((key, value) => ["creatorId", "creationTime", "lastModifierId", "lastModificationTime"].contains(key));
          
          await _inductionRepo.updateTrayDetails(currentTrayData.primaryTrayModel.id!, trayUpd);
        }
      }
      _state = _state.copyWith(isLoading: false);
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}
