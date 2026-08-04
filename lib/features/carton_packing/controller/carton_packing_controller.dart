import 'package:flutter/foundation.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:active_wear_scanning/features/carton_packing/model/carton_packing_state.dart';
import 'package:active_wear_scanning/features/carton_packing/model/carton_packing_scanned_item.dart';
import 'package:active_wear_scanning/features/carton_packing/repo/carton_packing_repo.dart';

class CartonPackingController extends ChangeNotifier {
  final _cartonPackingRepo = fromPlex<CartonPackingRepo>();

  CartonPackingState _state = const CartonPackingState();
  CartonPackingState get state => _state;

  CartonPackingController() {
    fetchPackedCartonIds();
  }

  Future<void> fetchPackedCartonIds() async {
    try {
      final res = await _cartonPackingRepo.fetchProductionProgress({
        'SubOperation': 'Packing',
      });
      if (res.success && res.data != null) {
        final List rawList = res.data is Map ? (res.data['items'] ?? []) : res.data;
        final Set<int> packedIds = {};
        for (final item in rawList) {
          if (item is Map) {
            final pp = item['productionProgress'] ?? item;
            final id = pp['packingInstructionLineDetailId'] as int?;
            if (id != null) {
              packedIds.add(id);
            }
          }
        }
        _state = _state.copyWith(packedCartonDetailIds: packedIds);
      }
    } catch (e) {
      debugPrint("❌ Error fetching packed carton IDs: $e");
    }
    notifyListeners();
  }

  void toggleExpandedGroupId(int headerId) {
    if (_state.expandedGroupId == headerId) {
      _state = _state.copyWith(clearExpandedGroupId: true);
    } else {
      _state = _state.copyWith(expandedGroupId: headerId);
    }
    notifyListeners();
  }

  void removeScannedCarton(int index) {
    if (index >= 0 && index < _state.scannedCartons.length) {
      final model = _state.scannedCartons[index];
      final updated = List<PackingInstructionResponseModel>.from(_state.scannedCartons)..removeAt(index);

      if (updated.isEmpty) {
        _state = _state.copyWith(
          scannedCartons: [],
          activeCartonGroups: [],
          groupLinesCache: {},
          clearExpandedGroupId: true,
          clearActiveSaleOrder: true,
        );
      } else {
        final headerId = model.packingInstructionHeader.id;
        final remains = updated.any((c) => c.packingInstructionHeader.id == headerId);
        final List<PackingInstructionHeader> groups = List.from(_state.activeCartonGroups);
        final Map<int, List<PackingInstructionLineResponse>> cache = Map.from(_state.groupLinesCache);
        int? expandedId = _state.expandedGroupId;

        if (!remains) {
          groups.removeWhere((g) => g.id == headerId);
          cache.remove(headerId);
          if (expandedId == headerId) {
            expandedId = null;
          }
        }

        _state = _state.copyWith(
          scannedCartons: updated,
          activeCartonGroups: groups,
          groupLinesCache: cache,
          expandedGroupId: expandedId,
          clearExpandedGroupId: expandedId == null,
        );
      }
      notifyListeners();
    }
  }

  Future<String?> validateCartonForScan(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid carton code';

    final isAlreadyScanned = _state.scannedCartons.any(
      (item) => item.packingInstructionLineDetail.uniqueId.trim().toLowerCase() == code.toLowerCase(),
    );
    if (isAlreadyScanned) return 'Already assigned';

    final result = await _cartonPackingRepo.fetchPackingInstructionByUniqueId(code);
    if (result.success && result.data != null) {
      final model = result.data as PackingInstructionResponseModel;
      final header = model.packingInstructionHeader;
      final headerId = header.id;
      final saleOrderId = header.saleOrderMstId;
      final lineDetailId = model.packingInstructionLineDetail.id;

      if (_state.packedCartonDetailIds.contains(lineDetailId)) {
        return 'This carton is already packed and saved!';
      }

      if (_state.activeSaleOrderId != null && saleOrderId != _state.activeSaleOrderId) {
        return 'Carton belongs to a different Sale Order (Expected: ${_state.activeSaleOrderId}, scanned: $saleOrderId)!';
      }

      SaleOrderModel? activeSaleOrder = _state.activeSaleOrder;
      String? activeCustomerName = _state.activeCustomerName;
      int? activeSaleOrderId = _state.activeSaleOrderId;

      if (activeSaleOrderId == null) {
        final saleOrderResult = await _cartonPackingRepo.fetchSaleOrderById(saleOrderId);
        if (saleOrderResult.success && saleOrderResult.data != null) {
          activeSaleOrder = saleOrderResult.data as SaleOrderModel;
          final customerId = activeSaleOrder.customerId;

          final customerResult = await _cartonPackingRepo.fetchCustomerById(customerId);
          activeCustomerName = 'Unknown';
          if (customerResult.success && customerResult.data != null) {
            activeCustomerName = (customerResult.data as CustomerModel).name;
            if (activeCustomerName.isEmpty) {
              activeCustomerName = (customerResult.data as CustomerModel).description;
            }
          }
          activeSaleOrderId = saleOrderId;
        } else {
          activeSaleOrderId = saleOrderId;
          activeSaleOrder = SaleOrderModel(
            id: saleOrderId,
            orderNo: header.cartonGroup,
            customerPO: 'PO-$headerId',
          );
          activeCustomerName = 'Fallback Customer';
        }
      }

      final Map<int, List<PackingInstructionLineResponse>> linesCache = Map.from(_state.groupLinesCache);
      final List<PackingInstructionHeader> groups = List.from(_state.activeCartonGroups);

      if (!linesCache.containsKey(headerId)) {
        final linesResult = await _cartonPackingRepo.fetchPackingInstructionLines(headerId);
        if (linesResult.success && linesResult.data != null) {
          linesCache[headerId] = linesResult.data as List<PackingInstructionLineResponse>;
          if (!groups.any((g) => g.id == headerId)) {
            groups.add(header);
          }
        }
      }

      final Map<int, List<int>> detailsCache = Map.from(_state.groupDetailIdsCache);
      if (!detailsCache.containsKey(headerId)) {
        final detailsResult = await _cartonPackingRepo.fetchPackingInstructionDetailsByHeaderId(headerId);
        if (detailsResult.success && detailsResult.data != null) {
          final details = detailsResult.data as List<PackingInstructionResponseModel>;
          detailsCache[headerId] = details.map((d) => d.packingInstructionLineDetail.id).toList();
        }
      }

      final updatedScanned = List<PackingInstructionResponseModel>.from(_state.scannedCartons)..add(model);

      _state = _state.copyWith(
        activeSaleOrderId: activeSaleOrderId,
        activeSaleOrder: activeSaleOrder,
        activeCustomerName: activeCustomerName,
        groupLinesCache: linesCache,
        activeCartonGroups: groups,
        groupDetailIdsCache: detailsCache,
        expandedGroupId: headerId,
        scannedCartons: updatedScanned,
      );
      notifyListeners();
      return null;
    } else {
      return result.message;
    }
  }

  Future<void> saveCartonPackingData() async {
    if (_state.scannedCartons.isEmpty) return;

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    int successCount = 0;
    final List<String> failedCartons = [];

    try {
      for (final model in _state.scannedCartons) {
        final progressPayload = {
          'subOperation': 'Packing',
          'date': DateTime.now().toIso8601String(),
          'transactionType': 0,
          'operatorDescription': 'system',
          'primaryQuantity': 1.0,
          'secondaryQuantity': 1.0,
          'operationId': 4,
          'shiftId': 1,
          'locatorId': 13,
          'packingInstructionLineDetailId': model.packingInstructionLineDetail.id,
        };

        final res = await _cartonPackingRepo.createProductionProgress(progressPayload);
        if (res.success) {
          int? progressId;
          final dynamic data = res.data;
          if (data is Map) {
            progressId = data['id'] ?? data['productionProgress']?['id'];
          } else if (data is int) {
            progressId = data;
          }

          if (progressId == null || progressId == 0) {
            final refetchRes = await _cartonPackingRepo.fetchProductionProgress({
              'PackingInstructionLineDetailId': model.packingInstructionLineDetail.id.toString(),
            });
            if (refetchRes.success && refetchRes.data != null) {
              final List rawList = refetchRes.data is Map ? (refetchRes.data['items'] ?? []) : refetchRes.data;
              if (rawList.isNotEmpty && rawList.first is Map) {
                final firstItem = rawList.first;
                if (firstItem.containsKey('productionProgress')) {
                  progressId = firstItem['productionProgress']?['id'] as int?;
                } else {
                  progressId = firstItem['id'] as int?;
                }
              }
            }
          }

          final wipPayload = {
            'subOperation': 'Packing',
            'transactionDate': DateTime.now().toIso8601String(),
            'transactionType': 0,
            'operatorDescription': 'system',
            'primaryQuantity': 1.0,
            'secondaryQuantity': 1.0,
            'operationId': 4,
            'shiftId': 1,
            'locatorId': 13,
            'packingInstructionLineDetailId': model.packingInstructionLineDetail.id,
            if (progressId != null && progressId > 0) 'progressId': progressId,
          };

          final wipRes = await _cartonPackingRepo.createWipTransaction(wipPayload);
          if (wipRes.success) {
            successCount++;
          } else {
            failedCartons.add('${model.packingInstructionLineDetail.uniqueId} (WIP-fail)');
          }
        } else {
          failedCartons.add('${model.packingInstructionLineDetail.uniqueId} (PP-fail)');
        }
      }

      if (failedCartons.isNotEmpty) {
        throw Exception(
          "Saved $successCount carton(s) successfully. Failed cartons: ${failedCartons.join(', ')}"
        );
      }

      _state = _state.copyWith(isLoading: false);
      await fetchPackedCartonIds();
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString().replaceFirst("Exception: ", ""));
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}
