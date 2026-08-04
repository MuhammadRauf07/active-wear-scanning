import 'package:flutter/foundation.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/model/processing_waste_state.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/repo/processing_waste_repo.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class ProcessingWasteController extends ChangeNotifier {
  final _repo = fromPlex<ProcessingWasteRepo>();

  ProcessingWasteState _state = const ProcessingWasteState();
  ProcessingWasteState get state => _state;

  void removeScannedTray(int index) {
    if (index >= 0 && index < _state.scannedTrays.length) {
      final model = _state.scannedTrays[index];
      final progressId = model.productionProgress.id;

      final updatedScanned = List<ProductionProgressResponseModel>.from(_state.scannedTrays)..removeAt(index);
      final updatedMap = Map<int, Map<String, dynamic>>.from(_state.productionProgressMap)..remove(progressId);

      _state = _state.copyWith(
        scannedTrays: updatedScanned,
        productionProgressMap: updatedMap,
      );
      notifyListeners();
    }
  }

  Future<String?> validateScanCode(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid scanned code';

    final isAlreadyScanned = _state.scannedTrays.any(
      (item) => item.primaryTrayModel.trayCode?.trim().toLowerCase() == code.toLowerCase(),
    );
    if (isAlreadyScanned) return 'Tray already scanned in current session';

    // Fetch waste production progress for this tray from locator 18
    final progressResult = await _repo.fetchProductionProgress({
      'TrayCode': code,
      'LocatorId': '18',
      'MaxResultCount': '10',
      'SkipCount': '0',
    });

    if (!progressResult.success || progressResult.data == null) {
      return 'Verification Error: ${progressResult.message}';
    }

    final List rawList = progressResult.data is Map ? (progressResult.data['items'] ?? []) : progressResult.data;
    if (rawList.isEmpty) {
      return 'This tray does not have any processing waste logged!';
    }

    final firstItem = rawList.first;
    if (firstItem is! Map) {
      return 'Invalid progress data returned from backend';
    }

    final model = ProductionProgressResponseModel.fromJson(
      Map<String, dynamic>.from(firstItem),
    );

    final rawProgress = firstItem.containsKey('productionProgress')
        ? Map<String, dynamic>.from(firstItem['productionProgress'] as Map)
        : Map<String, dynamic>.from(firstItem);

    // Verify if it has already been received (toLocatorId == 19 or locatorId == 19)
    final toLocId = rawProgress['toLocatorId'] as int? ?? rawProgress['toLocator']?['id'] as int?;
    final locId = rawProgress['locatorId'] as int? ?? rawProgress['locator']?['id'] as int?;
    if (toLocId == 19 || locId == 19) {
      return 'Waste has already been received for this tray!';
    }

    final progressId = model.productionProgress.id ?? 0;
    if (progressId == 0) return 'Invalid production progress ID';

    final updatedScanned = List<ProductionProgressResponseModel>.from(_state.scannedTrays)..add(model);
    final updatedMap = Map<int, Map<String, dynamic>>.from(_state.productionProgressMap)..[progressId] = rawProgress;

    _state = _state.copyWith(
      scannedTrays: updatedScanned,
      productionProgressMap: updatedMap,
    );
    notifyListeners();
    return null;
  }

  Future<void> saveWasteReceivingData() async {
    if (_state.scannedTrays.isEmpty) return;

    _state = _state.copyWith(isLoading: true, clearError: false);
    notifyListeners();

    int successCount = 0;
    final List<String> failedItems = [];

    try {
      for (final model in _state.scannedTrays) {
        final progressId = model.productionProgress.id ?? 0;
        final rawProgress = _state.productionProgressMap[progressId];
        final trayCode = model.primaryTrayModel.trayCode ?? 'UNKNOWN';

        if (rawProgress == null || progressId == 0) {
          failedItems.add('$trayCode (Invalid-progress)');
          continue;
        }

        final Map<String, dynamic> updatePayload = Map<String, dynamic>.from(rawProgress);
        updatePayload['toLocatorId'] = 19; // Waste Store
        updatePayload['locatorId'] = 19;

        final updateRes = await _repo.updateProductionProgress(progressId, updatePayload);
        if (!updateRes.success) {
          failedItems.add('$trayCode (Progress-update-fail)');
          continue;
        }

        // Post negative WIP at locator 18
        final double wasteQty = (model.productionProgress.waste ?? 0.0).toDouble();
        final negativeWipPayload = {
          'subOperation': 'Locator Transfer',
          'transactionDate': DateTime.now().toIso8601String(),
          'transactionType': 1, // Issue / Out
          'operatorDescription': 'system',
          'primaryQuantity': -wasteQty,
          'secondaryQuantity': -wasteQty,
          'operationId': model.productionProgress.operationId,
          'shiftId': 1,
          'locatorId': 18,
          'toLocatorId': 19,
          'productionProgressId': progressId,
        };

        final negWipRes = await _repo.createWipTransaction(negativeWipPayload);
        if (!negWipRes.success) {
          failedItems.add('$trayCode (Negative-WIP-fail)');
          continue;
        }

        // Post positive WIP at locator 19
        final positiveWipPayload = {
          'subOperation': 'Waste Receiving',
          'transactionDate': DateTime.now().toIso8601String(),
          'transactionType': 0, // Receipt / In
          'operatorDescription': 'system',
          'primaryQuantity': wasteQty,
          'secondaryQuantity': wasteQty,
          'operationId': model.productionProgress.operationId,
          'shiftId': 1,
          'locatorId': 19,
          'toLocatorId': null,
          'productionProgressId': progressId,
        };

        final posWipRes = await _repo.createWipTransaction(positiveWipPayload);
        if (posWipRes.success) {
          successCount++;
        } else {
          failedItems.add('$trayCode (Positive-WIP-fail)');
        }
      }

      if (failedItems.isNotEmpty) {
        throw Exception(
          "Received $successCount waste tray(s) successfully. Failed: ${failedItems.join(', ')}"
        );
      }

      _state = _state.copyWith(isLoading: false, scannedTrays: [], productionProgressMap: {});
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString().replaceFirst("Exception: ", ""));
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}
