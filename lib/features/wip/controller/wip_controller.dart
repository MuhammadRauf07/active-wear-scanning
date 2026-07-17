import 'package:flutter/foundation.dart';
import 'package:active_wear_scanning/features/wip/model/wip_state.dart';
import 'package:active_wear_scanning/features/wip/model/wip_model.dart';
import 'package:active_wear_scanning/features/wip/model/wip_group.dart';
import 'package:active_wear_scanning/features/wip/repo/wip_repo.dart';
import 'package:active_wear_scanning/features/lot_making/repo/lot_repo.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';

class WipController extends ChangeNotifier {
  final _wipRepo = WipRepo();
  final _lotRepo = LotRepo();

  WipState _state = const WipState();
  WipState get state => _state;

  WipController() {
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    final result = await _wipRepo.fetchLocators();
    if (result.success && result.data != null) {
      final allLocs = result.data as List<LocatorResponse>;
      final filtered = allLocs.where((l) {
        final wh = l.locator.logicalWH?.toUpperCase() ?? '';
        final deptCode = l.department.code.toUpperCase();
        final desc = l.locator.description.toUpperCase();
        final code = l.locator.locatorCode.toUpperCase();

        final isFloor = wh.contains('FLOOR');
        final isKnitting = deptCode.contains('KNITTING') ||
                           desc.contains('KNITTING') ||
                           code.contains('KNITTING');
        return isFloor && !isKnitting;
      }).toList().reversed.toList();

      _state = _state.copyWith(
        locators: filtered,
        isLoading: false,
      );
    } else {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: result.message,
      );
    }
    notifyListeners();
  }

  Future<void> fetchWipData(int locatorId) async {
    if (_state.locatorTrays.containsKey(locatorId) && _state.locatorTrays[locatorId]!.isNotEmpty) return;

    final updatedLoading = Map<int, bool>.from(_state.loadingDetails)..[locatorId] = true;
    _state = _state.copyWith(loadingDetails: updatedLoading);
    notifyListeners();

    final result = await _wipRepo.fetchWipDetails(locatorId);
    if (result.success && result.data != null) {
      final rawList = result.data as List<ProductionProgressResponseModel>;
      final enrichedList = <ProductionProgressResponseModel>[];

      for (final tray in rawList) {
        final mainItemId = tray.item.id;
        double perGarmentTube = tray.item.perGarmentTube;
        String colorDesc = tray.item.colorDescription ?? '';
        String sizeDesc = tray.item.sizeDescription ?? '';

        if (mainItemId > 0) {
          final itemRes = await _lotRepo.fetchItemDef(mainItemId);
          if (itemRes.success && itemRes.data != null) {
            final d = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
            if (d['perGarmentTube'] != null) perGarmentTube = (d['perGarmentTube'] as num).toDouble();
            if (d['colorDescription'] != null) colorDesc = d['colorDescription'];
            if (d['sizeDescription'] != null) sizeDesc = d['sizeDescription'];
          }
        }

        final updatedItem = tray.item.copyWith(
          perGarmentTube: perGarmentTube,
          colorDescription: colorDesc,
          sizeDescription: sizeDesc,
        );

        MachineModel? finalMachine = tray.machineModel;
        final bhId = tray.productionProgress.batchHeaderId;
        final trayResourceId = tray.primaryTrayModel.resourceId;

        if (bhId != null) {
          final bhRes = await _lotRepo.fetchLotHeaderById(bhId);
          if (bhRes.success && bhRes.data != null) {
            final bhFull = LotHeaderResponseModel.fromJson(bhRes.data);
            if (bhFull.machine != null) {
              finalMachine = bhFull.machine;
            } else if (bhFull.batchHeader.machineId != null) {
              final mRes = await _lotRepo.fetchMachineById(bhFull.batchHeader.machineId!);
              if (mRes.success && mRes.data != null) {
                final mData = mRes.data as Map<String, dynamic>;
                finalMachine = MachineModel.fromJson(mData['resource'] ?? mData);
              }
            }
          }
        } else if (trayResourceId != null) {
          final mRes = await _lotRepo.fetchMachineById(trayResourceId);
          if (mRes.success && mRes.data != null) {
            final mData = mRes.data as Map<String, dynamic>;
            finalMachine = MachineModel.fromJson(mData['resource'] ?? mData);
          }
        }

        enrichedList.add(tray.copyWith(
          item: updatedItem,
          machineModel: finalMachine ?? tray.machineModel,
        ));
      }

      final updatedTrays = Map<int, List<ProductionProgressResponseModel>>.from(_state.locatorTrays)
        ..[locatorId] = enrichedList;
      final updatedLoadingDone = Map<int, bool>.from(_state.loadingDetails)..[locatorId] = false;

      _state = _state.copyWith(
        locatorTrays: updatedTrays,
        loadingDetails: updatedLoadingDone,
      );
    } else {
      final updatedLoadingDone = Map<int, bool>.from(_state.loadingDetails)..[locatorId] = false;
      _state = _state.copyWith(
        loadingDetails: updatedLoadingDone,
        errorMessage: result.message,
      );
    }
    notifyListeners();
  }

  List<WIPGroup> groupTrays(List<ProductionProgressResponseModel> trays, bool isKnitting, bool isProcessing) {
    final Map<String, WIPGroup> groups = {};

    for (final t in trays) {
      String key;
      if (isKnitting) {
        final wo = t.workOrderHeader.workOrderCode;
        final machine = t.machineModel.brand ?? t.machineModel.resourceCode ?? '-';
        final item = t.item.description;
        key = "${wo}_${machine}_$item";
        
        if (!groups.containsKey(key)) {
          groups[key] = WIPGroup(title1: wo, title2: machine, subtitle: item, trays: []);
        }
      } else if (isProcessing) {
        final lot = t.batchHeader?.batchHeaderCode ?? t.productionProgress.batchHeaderId?.toString() ?? '-';
        final machine = t.machineModel.brand ?? t.machineModel.resourceCode ?? '-';
        final color = t.batchHeader?.colorDescription ?? t.item.colorDescription ?? '-';
        key = "${lot}_${machine}_$color";
        
        if (!groups.containsKey(key)) {
          groups[key] = WIPGroup(title1: lot, title2: machine, title3: color, trays: []);
        }
      } else {
        final lot = t.batchHeader?.batchHeaderCode ?? t.productionProgress.batchHeaderId?.toString() ?? '-';
        final color = t.batchHeader?.colorDescription ?? t.item.colorDescription ?? '-';
        key = "${lot}_$color";
        
        if (!groups.containsKey(key)) {
          groups[key] = WIPGroup(title1: lot, title2: color, trays: []);
        }
      }
      groups[key]!.trays.add(t);
    }
    return groups.values.toList();
  }

  Future<double?> fetchMachineCapacity(int machineId) async {
    final res = await _lotRepo.fetchMachineById(machineId);
    if (res.success && res.data != null) {
      final mData = res.data as Map<String, dynamic>;
      final mJson = mData['resource'] ?? mData;
      return double.tryParse(mJson['capacity']?.toString() ?? '');
    }
    return null;
  }
}
