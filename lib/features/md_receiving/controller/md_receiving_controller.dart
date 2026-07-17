import 'package:flutter/foundation.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:active_wear_scanning/features/md_receiving/model/md_receiving_state.dart';
import 'package:active_wear_scanning/features/carton_packing/model/carton_packing_scanned_item.dart';
import 'package:active_wear_scanning/features/md_receiving/repo/md_receiving_repo.dart';

class MdReceivingController extends ChangeNotifier {
  final _mdReceivingRepo = fromPlex<MdReceivingRepo>();

  MdReceivingState _state = const MdReceivingState();
  MdReceivingState get state => _state;

  void removeScannedCarton(int index) {
    if (index >= 0 && index < _state.scannedCartons.length) {
      final model = _state.scannedCartons[index];
      final lineDetailId = model.packingInstructionLineDetail.id;

      final updatedScanned = List<PackingInstructionResponseModel>.from(_state.scannedCartons)..removeAt(index);
      final updatedMap = Map<int, Map<String, dynamic>>.from(_state.productionProgressMap)..remove(lineDetailId);

      _state = _state.copyWith(
        scannedCartons: updatedScanned,
        productionProgressMap: updatedMap,
      );
      notifyListeners();
    }
  }

  Future<String?> validateScanCode(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid scanned code';

    final isAlreadyScanned = _state.scannedCartons.any(
      (item) => item.packingInstructionLineDetail.uniqueId.trim().toLowerCase() == code.toLowerCase(),
    );
    if (isAlreadyScanned) return 'Item already scanned in current session';

    final result = await _mdReceivingRepo.fetchPackingInstructionByUniqueId(code);
    if (!result.success || result.data == null) {
      return result.message;
    }

    final model = PackingInstructionResponseModel.fromJson(
      Map<String, dynamic>.from(result.data),
    );
    final lineDetailId = model.packingInstructionLineDetail.id;

    final progressResult = await _mdReceivingRepo.fetchProductionProgress({
      'PackingInstructionLineDetailId': lineDetailId.toString(),
      'SubOperation': 'Packing',
    });

    if (!progressResult.success || progressResult.data == null) {
      return 'Carton Verification Error: ${progressResult.message}';
    }

    final List rawList = progressResult.data is Map ? (progressResult.data['items'] ?? []) : progressResult.data;
    if (rawList.isEmpty) {
      return 'This carton must be scanned and saved in Carton Packing first!';
    }

    final firstItem = rawList.first;
    if (firstItem is! Map) {
      return 'Invalid progress data returned from backend';
    }

    final rawProgress = firstItem.containsKey('productionProgress')
        ? Map<String, dynamic>.from(firstItem['productionProgress'] as Map)
        : Map<String, dynamic>.from(firstItem);

    final updatedScanned = List<PackingInstructionResponseModel>.from(_state.scannedCartons)..add(model);
    final updatedMap = Map<int, Map<String, dynamic>>.from(_state.productionProgressMap)..[lineDetailId] = rawProgress;

    _state = _state.copyWith(
      scannedCartons: updatedScanned,
      productionProgressMap: updatedMap,
    );
    notifyListeners();
    return null;
  }

  Future<void> saveMdReceivingData() async {
    if (_state.scannedCartons.isEmpty) return;

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    int successCount = 0;
    final List<String> failedItems = [];

    try {
      for (final model in _state.scannedCartons) {
        final lineDetailId = model.packingInstructionLineDetail.id;
        final rawProgress = _state.productionProgressMap[lineDetailId];
        if (rawProgress == null) {
          failedItems.add('${model.packingInstructionLineDetail.uniqueId} (Missing-cache)');
          continue;
        }

        final int progressId = rawProgress['id'] as int? ?? 0;
        if (progressId == 0) {
          failedItems.add('${model.packingInstructionLineDetail.uniqueId} (Invalid-progress-id)');
          continue;
        }

        final Map<String, dynamic> updatePayload = Map<String, dynamic>.from(rawProgress);
        updatePayload['toLocatorId'] = 14;

        final updateRes = await _mdReceivingRepo.updateProductionProgress(progressId, updatePayload);
        if (!updateRes.success) {
          failedItems.add('${model.packingInstructionLineDetail.uniqueId} (Progress-update-fail)');
          continue;
        }

        final negativeWipPayload = {
          'subOperation': 'Locator Transfer',
          'transactionDate': DateTime.now().toIso8601String(),
          'transactionType': 1,
          'operatorDescription': 'system',
          'primaryQuantity': -1.0,
          'secondaryQuantity': -1.0,
          'operationId': 4,
          'shiftId': 1,
          'locatorId': 13,
          'toLocatorId': 14,
          'packingInstructionLineDetailId': lineDetailId,
          'progressId': progressId,
        };

        final negWipRes = await _mdReceivingRepo.createWipTransaction(negativeWipPayload);
        if (!negWipRes.success) {
          failedItems.add('${model.packingInstructionLineDetail.uniqueId} (Negative-WIP-fail)');
          continue;
        }

        final positiveWipPayload = {
          'subOperation': 'MD Receiving',
          'transactionDate': DateTime.now().toIso8601String(),
          'transactionType': 0,
          'operatorDescription': 'system',
          'primaryQuantity': 1.0,
          'secondaryQuantity': 1.0,
          'operationId': 4,
          'shiftId': 1,
          'locatorId': 14,
          'toLocatorId': null,
          'packingInstructionLineDetailId': lineDetailId,
          'progressId': progressId,
        };

        final posWipRes = await _mdReceivingRepo.createWipTransaction(positiveWipPayload);
        if (posWipRes.success) {
          successCount++;
        } else {
          failedItems.add('${model.packingInstructionLineDetail.uniqueId} (Positive-WIP-fail)');
        }
      }

      if (failedItems.isNotEmpty) {
        throw Exception(
          "Saved $successCount carton(s) successfully. Failed: ${failedItems.join(', ')}"
        );
      }

      _state = _state.copyWith(isLoading: false);
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString().replaceFirst("Exception: ", ""));
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}
