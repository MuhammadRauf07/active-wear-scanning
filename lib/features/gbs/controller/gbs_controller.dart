import 'package:flutter/foundation.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:active_wear_scanning/features/gbs/model/gbs_scanned_tray.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/gbs/model/gbs_state.dart';
import 'package:active_wear_scanning/features/gbs/repo/gbs_receiving_repo.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';

class GbsController extends ChangeNotifier {
  final _trayScanningRepo = fromPlex<GBSReceivingRepo>();

  GbsState _state = const GbsState();
  GbsState get state => _state;

  GbsController() {
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    await fetchLatestTraysSilently();
    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }

  Future<void> fetchLatestTraysSilently() async {
    final apiResult = await _trayScanningRepo.getProductionProgress(
      params: {
        'LocatorId': '2',
        'MaxResultCount': '1000',
      },
    );
    if (apiResult.success && apiResult.data != null) {
      final List<ProductionProgressResponseModel> allTrays = apiResult.data as List<ProductionProgressResponseModel>;
      _state = _state.copyWith(availableTrayForGbs: allTrays);
    }
    notifyListeners();
  }

  void selectWorkOrder(WorkOrderHeader? wo) {
    _state = _state.copyWith(
      selectedWorkOrder: wo,
      clearSelectedItem: true,
      selectedProgressIds: {},
    );
    notifyListeners();
  }

  void selectItem(Item? item) {
    _state = _state.copyWith(
      selectedItem: item,
      selectedProgressIds: {},
    );
    notifyListeners();
  }

  void changeReceivingType(String newType) {
    if (_state.receivingType == newType) return;
    _state = _state.copyWith(
      receivingType: newType,
      scannedTrays: [],
      selectedProgressIds: {},
      clearSelectedWorkOrder: true,
      clearSelectedItem: true,
    );
    notifyListeners();
  }

  void removeScannedTray(int index) {
    if (index >= 0 && index < _state.scannedTrays.length) {
      final updated = List<GBSScannedTray>.from(_state.scannedTrays)..removeAt(index);
      _state = _state.copyWith(scannedTrays: updated);
      notifyListeners();
    }
  }

  void toggleSelectedProgressId(int id, bool selected) {
    final updated = Set<int>.from(_state.selectedProgressIds);
    if (selected) {
      updated.add(id);
    } else {
      updated.remove(id);
    }
    _state = _state.copyWith(selectedProgressIds: updated);
    notifyListeners();
  }

  void toggleAllProgressIds(bool selectAll) {
    final Set<int> updated = {};
    if (selectAll) {
      updated.addAll(
        getFilteredTrays().map((t) => t.productionProgress.id).whereType<int>(),
      );
    }
    _state = _state.copyWith(selectedProgressIds: updated);
    notifyListeners();
  }

  List<ProductionProgressResponseModel> getUnfilteredTraysForReceiving() {
    final unheldTrays = _state.availableTrayForGbs.where((t) => t.productionProgress.holdFlag != true).toList();
    if (_state.receivingType == 'sample') {
      return unheldTrays.where((t) => t.productionProgress.productNature == 1).toList();
    } else if (_state.receivingType == 'c_grade') {
      return unheldTrays.where((t) => t.productionProgress.productGrade == 2).toList();
    } else {
      return unheldTrays.where((t) => t.productionProgress.productNature != 1 && t.productionProgress.productGrade != 2).toList();
    }
  }

  List<ProductionProgressResponseModel> getFilteredTrays() {
    final baseList = getUnfilteredTraysForReceiving();
    var list = baseList;
    if (_state.selectedWorkOrder != null) {
      list = list.where((t) => t.workOrderHeader.id == _state.selectedWorkOrder!.id).toList();
    }
    return list;
  }

  Future<String?> validateTrayForReceiving(String scannedCode) async {
    final code = scannedCode.trim().toLowerCase();
    if (code.isEmpty) return 'Invalid tray code';

    final alreadyScanned = _state.scannedTrays.any((t) => t.trayCode.trim().toLowerCase() == code);
    if (alreadyScanned) return 'Already assigned';

    final holdMatch = _state.availableTrayForGbs.where((t) {
      final String tCode = (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase();
      final String pCode = (t.productionProgress.progressCode ?? '').trim().toLowerCase();
      if (tCode == code || pCode == code) return true;
      String cleanTCode = tCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').replaceAll(RegExp(r'^0+'), '');
      String cleanScanned = code.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').replaceAll(RegExp(r'^0+'), '');
      return (cleanTCode.isNotEmpty && cleanTCode == cleanScanned) || (tCode.endsWith(code) && code.length > 3);
    }).firstOrNull;

    if (holdMatch != null && holdMatch.productionProgress.holdFlag == true) {
      return 'Tray ${holdMatch.primaryTrayModel.trayCode} is on HOLD in Knitting Production and cannot be received.';
    }

    final match = getFilteredTrays().where((t) {
      final String tCode = (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase();
      final String pCode = (t.productionProgress.progressCode ?? '').trim().toLowerCase();

      if (tCode == code || pCode == code) return true;

      String cleanTCode = tCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').replaceAll(RegExp(r'^0+'), '');
      String cleanScanned = code.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').replaceAll(RegExp(r'^0+'), '');

      if (cleanTCode.isNotEmpty && cleanTCode == cleanScanned) return true;

      if (tCode.endsWith(code) && code.length > 3) return true;

      return false;
    }).firstOrNull;

    if (match == null) {
      return 'Tray not available';
    }

    if (_state.selectedWorkOrder != null && match.workOrderHeader.id != _state.selectedWorkOrder?.id) {
      return 'Tray belongs to another Work Order (${match.workOrderHeader.workOrderCode})';
    }

    if ((match.primaryTrayModel.trayType ?? 0) != 1) {
      return 'Invalid tray type.';
    }

    int targetItemId = match.productionProgress.processedItemId ?? match.item.id;
    String colorDesc = match.item.colorDescription ?? '';
    String sizeDesc = match.item.sizeDescription ?? '';
    double perGarmentTube = match.item.perGarmentTube;

    if (targetItemId > 0) {
      final itemRes = await _trayScanningRepo.fetchItemDef(targetItemId);
      if (itemRes.success && itemRes.data != null) {
        final itemData = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
        if (itemData['colorDescription'] != null) colorDesc = itemData['colorDescription'];
        if (itemData['sizeDescription'] != null) sizeDesc = itemData['sizeDescription'];
        if (itemData['perGarmentTube'] != null) perGarmentTube = (itemData['perGarmentTube'] as num).toDouble();
      }
    }

    final newTray = GBSScannedTray(
      itemDescription: match.item.description,
      componentDescription: match.item.componentDescription ?? '',
      sizeDescription: sizeDesc,
      colorDescription: colorDesc,
      workOrderCode: match.workOrderHeader.workOrderCode,
      primaryQuantity: match.productionProgress.primaryQuantity?.toStringAsFixed(0) ?? '0',
      pieceWeight: match.item.pieceWeight ?? 0.0,
      perGarmentTube: perGarmentTube,
      trayCode: scannedCode.trim(),
      trayUpdateId: match.primaryTrayModel.id,
      trayConcurrencyStamp: match.primaryTrayModel.concurrencyStamp,
    );

    final updated = List<GBSScannedTray>.from(_state.scannedTrays)..add(newTray);
    _state = _state.copyWith(scannedTrays: updated);
    notifyListeners();
    return null;
  }

  Future<void> saveSampleOrCGradeProgress() async {
    if (_state.selectedProgressIds.isEmpty) return;

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final List<int> selectedIds = _state.selectedProgressIds.toList();
      final int targetLocatorId = _state.receivingType == 'sample' ? 16 : 17;
      final String subOpProgress = _state.receivingType == 'sample' ? "Sample Received" : "C Grade Received";
      final String subOpWip = _state.receivingType == 'sample' ? "Sample Receiving" : "C Grade Receiving";

      for (final id in selectedIds) {
        final currentData = _state.availableTrayForGbs.where((t) => t.productionProgress.id == id).firstOrNull;
        if (currentData == null) continue;

        Map<String, dynamic> wipPayload = {
          "subOperation": subOpWip,
          "transactionDate": DateTime.now().toIso8601String(),
          "transactionType": 6,
          "uom": currentData.workOrderLine.uom,
          "operatorDescription": "system",
          "primaryQuantity": currentData.productionProgress.primaryQuantity ?? 0,
          "secondaryQuantity": currentData.productionProgress.secondaryQuantity ?? 0,
          "primaryUOM": currentData.productionProgress.primaryUOM ?? 0,
          "secondaryUOM": currentData.productionProgress.secondaryUOM ?? 0,
          "code": currentData.item.code,
          "productGrade": currentData.productionProgress.productGrade ?? 0,
          "productNature": currentData.productionProgress.productNature ?? 0,
          "progressId": currentData.productionProgress.id,
          "operationId": currentData.operation.id,
          "workOrderHeaderId": currentData.workOrderHeader.id,
          "workOrderLineId": currentData.workOrderLine.id,
          "itemId": currentData.item.id,
          "shiftId": currentData.shift.id,
          "machineId": currentData.machineModel.id,
          "planHeaderId": currentData.planHeader?.id,
          "locatorId": targetLocatorId,
          "processedItemId": currentData.processedItem?.id ?? currentData.item.id,
        };

        await _trayScanningRepo.postWipTransactions(wipPayload);

        Map<String, dynamic> updateProductionEntry = {
          "id": currentData.productionProgress.id,
          "concurrencyStamp": currentData.productionProgress.concurrencyStamp,
          "subOperation": subOpProgress,
          "date": DateTime.now().toIso8601String(),
          "transactionType": 6,
          "operatorDescription": "system",
          "primaryQuantity": currentData.productionProgress.primaryQuantity,
          "primaryUOM": currentData.productionProgress.primaryUOM,
          "secondaryQuantity": currentData.productionProgress.secondaryQuantity,
          "secondaryUOM": currentData.productionProgress.secondaryUOM,
          "wipStatus": currentData.productionProgress.wipStatus ?? 0,
          "gbsFlag": true,
          "pbsFlag": false,
          "progressCode": currentData.productionProgress.progressCode,
          "productGrade": currentData.productionProgress.productGrade,
          "productNature": currentData.productionProgress.productNature,
          "operationId": currentData.productionProgress.operationId,
          "workOrderHeaderId": currentData.productionProgress.workOrderHeaderId,
          "workOrderLineId": currentData.productionProgress.workOrderLineId,
          "itemId": currentData.productionProgress.itemId,
          "shiftId": currentData.productionProgress.shiftId,
          "machineId": currentData.productionProgress.machineId,
          "planHeaderId": currentData.productionProgress.planHeaderId,
          "locatorId": targetLocatorId,
          "batchHeaderId": currentData.productionProgress.batchHeaderId,
          "batchLineId": currentData.productionProgress.batchLinesId,
          "remarks": currentData.productionProgress.remarks,
        };
        updateProductionEntry.remove("batchLinesId");

        if (currentData.productionProgress.id != null) {
          final res = await _trayScanningRepo.updateProductionProgress(
            currentData.productionProgress.id!,
            updateProductionEntry,
          );
          if (!res.success) {
            throw Exception(res.message);
          }
        }
      }
      _state = _state.copyWith(
        selectedProgressIds: {},
        isLoading: false,
      );
      await fetchLatestTraysSilently();
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> saveWipTransactionsAndUpdateTray() async {
    if (_state.scannedTrays.isEmpty) return;

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      for (int i = 0; i < _state.scannedTrays.length; i++) {
        final currentTrayData = _state.availableTrayForGbs.where(
          (t) => t.productionProgress.primaryTrayId == _state.scannedTrays[i].trayUpdateId
        ).firstOrNull;

        if (currentTrayData == null) continue;

        Map<String, dynamic> wipPayload = {
          "subOperation": "GBS Receiving",
          "transactionDate": DateTime.now().toIso8601String(),
          "transactionType": 6,
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
          "operationId": currentTrayData.operation.id,
          "workOrderHeaderId": currentTrayData.workOrderHeader.id,
          "workOrderLineId": currentTrayData.workOrderLine.id,
          "itemId": currentTrayData.item.id,
          "shiftId": currentTrayData.shift.id,
          "primaryTrayId": currentTrayData.primaryTrayModel.id,
          "machineId": currentTrayData.machineModel.id,
          "planHeaderId": currentTrayData.planHeader?.id,
          "locatorId": 3,
          "processedItemId": currentTrayData.processedItem?.id ?? currentTrayData.item.id,
        };

        await _trayScanningRepo.postWipTransactions(wipPayload);
        Map<String, dynamic> updateProductionEntry = {
          "id": currentTrayData.productionProgress.id,
          "concurrencyStamp": currentTrayData.productionProgress.concurrencyStamp,
          "subOperation": "GBS Received",
          "date": DateTime.now().toIso8601String(),
          "transactionType": 6,
          "operatorDescription": "system",
          "primaryQuantity": currentTrayData.productionProgress.primaryQuantity,
          "primaryUOM": currentTrayData.productionProgress.primaryUOM,
          "secondaryQuantity": currentTrayData.productionProgress.secondaryQuantity,
          "secondaryUOM": currentTrayData.productionProgress.secondaryUOM,
          "wipStatus": currentTrayData.productionProgress.wipStatus ?? 0,
          "gbsFlag": true,
          "pbsFlag": false,
          "progressCode": currentTrayData.productionProgress.progressCode,
          "productGrade": currentTrayData.productionProgress.productGrade,
          "productNature": currentTrayData.productionProgress.productNature,
          "operationId": currentTrayData.productionProgress.operationId,
          "workOrderHeaderId": currentTrayData.productionProgress.workOrderHeaderId,
          "workOrderLineId": currentTrayData.productionProgress.workOrderLineId,
          "itemId": currentTrayData.productionProgress.itemId,
          "shiftId": currentTrayData.productionProgress.shiftId,
          "primaryTrayId": currentTrayData.productionProgress.primaryTrayId,
          "secondaryTrayId": currentTrayData.productionProgress.secondaryTrayId,
          "machineId": currentTrayData.productionProgress.machineId,
          "planHeaderId": currentTrayData.productionProgress.planHeaderId,
          "locatorId": 3,
          "batchHeaderId": currentTrayData.productionProgress.batchHeaderId,
          "batchLineId": currentTrayData.productionProgress.batchLinesId,
        };
        updateProductionEntry.remove("batchLinesId");

        if (currentTrayData.productionProgress.id != null) {
          await _trayScanningRepo.updateProductionProgress(
            currentTrayData.productionProgress.id!,
            updateProductionEntry,
          );
        }

        if (_state.scannedTrays[i].trayUpdateId != null) {
          final getTrayRes = await _trayScanningRepo.fetchTrayDetailById(_state.scannedTrays[i].trayUpdateId!);
          if (getTrayRes.success && getTrayRes.data != null) {
            Map<String, dynamic> rawTrayPayload = Map<String, dynamic>.from(
              getTrayRes.data.containsKey('trayDetail') ? getTrayRes.data['trayDetail'] : getTrayRes.data
            );
            rawTrayPayload["locatorId"] = 3;
            rawTrayPayload.removeWhere((key, value) => ["creatorId", "creationTime", "lastModifierId", "lastModificationTime"].contains(key));
            await _trayScanningRepo.updateTrayDetails(rawTrayPayload, _state.scannedTrays[i].trayUpdateId!);
          }
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
