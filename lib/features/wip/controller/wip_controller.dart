import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/wip/model/wip_model.dart';
import 'package:active_wear_scanning/features/wip/model/wip_state.dart';
import 'package:active_wear_scanning/features/wip/repo/wip_repo.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';

class WipController extends ChangeNotifier {
  final WipRepo _wipRepo = WipRepo();

  WipState _state = const WipState();
  WipState get state => _state;

  final Map<int, String> _machineCodeCache = {};
  final Map<int, String> _trayIdToCode = {};

  WipController() {
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final opRes = await _wipRepo.fetchProcessingOperations();
      if (!opRes.success || opRes.data == null) {
        _state = _state.copyWith(
          isLoading: false,
          errorMessage: opRes.message,
        );
        notifyListeners();
        return;
      }

      final List<Operation> allOps = List<Operation>.from(opRes.data);
      final validOps = allOps.where((op) {
        final isProcessing = op.processNature == 1;
        final isNumeric = RegExp(r'^\d+$').hasMatch(op.code);
        return isProcessing && isNumeric;
      }).toList()
        ..sort((a, b) => int.parse(a.code).compareTo(int.parse(b.code)));

      // Fetch broad summary progress records to compute initial live operation metrics
      final progRes = await _wipRepo.fetchProductionProgress({
        'TransactionType': '2',
        'MaxResultCount': '1000',
      });

      final Map<int, List<ProductionProgressResponseModel>> recordsByOp = {};
      if (progRes.success && progRes.data != null) {
        final records = progRes.data as List<ProductionProgressResponseModel>;
        for (final r in records) {
          if (r.productionProgress.transactionType != 2) continue;
          if (r.productionProgress.wipStatus != 0) continue;
          if (r.productionProgress.locatorId == 18) continue;
          if ((r.productionProgress.subOperation ?? '').toLowerCase() == 'waste') continue;
          final opId = r.productionProgress.operationId;
          if (opId != null) {
            recordsByOp.putIfAbsent(opId, () => []).add(r);
          }
        }
      }

      final List<WipOperationModel> opModels = [];
      for (final op in validOps) {
        final list = recordsByOp[op.id] ?? [];
        final uniqueBatches = <int>{};
        final Map<String, ProductionProgressResponseModel> uniqueTrays = {};
        double totalTubes = 0.0;
        double totalWeight = 0.0;

        for (final r in list) {
          final bhId = r.productionProgress.batchHeaderId;
          if (bhId != null) {
            uniqueBatches.add(bhId);
          }
          final trayCode = (r.primaryTrayModel.trayCode ?? '').trim().toUpperCase();
          if (trayCode.isNotEmpty) {
            final existing = uniqueTrays[trayCode];
            if (existing == null || (r.productionProgress.id ?? 0) > (existing.productionProgress.id ?? 0)) {
              uniqueTrays[trayCode] = r;
            }
          }
        }

        for (final t in uniqueTrays.values) {
          final qty = t.productionProgress.primaryQuantity ?? 0;
          final tubes = (t.productionProgress.secondaryQuantity ?? qty).toDouble();
          final pw = t.item.pieceWeight ?? 0;
          totalTubes += tubes;
          totalWeight += qty * pw;
        }

        opModels.add(
          WipOperationModel(
            operation: op,
            batchCount: uniqueBatches.length,
            trayCount: uniqueTrays.length,
            totalTubes: totalTubes,
            totalWeight: totalWeight,
          ),
        );
      }

      _state = _state.copyWith(
        isLoading: false,
        operations: opModels,
      );
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Error loading WIP Monitoring: $e',
      );
    }
    notifyListeners();
  }

  Future<void> toggleOperationExpanded(int operationId) async {
    final currentExpanded = Set<int>.from(_state.expandedOperationIds);
    if (currentExpanded.contains(operationId)) {
      currentExpanded.remove(operationId);
      _state = _state.copyWith(expandedOperationIds: currentExpanded);
      notifyListeners();
    } else {
      currentExpanded.add(operationId);
      _state = _state.copyWith(expandedOperationIds: currentExpanded);
      notifyListeners();
      await fetchOperationBatches(operationId);
    }
  }

  void toggleBatchExpanded(int batchHeaderId) {
    final currentExpanded = Set<int>.from(_state.expandedBatchIds);
    if (currentExpanded.contains(batchHeaderId)) {
      currentExpanded.remove(batchHeaderId);
    } else {
      currentExpanded.add(batchHeaderId);
    }
    _state = _state.copyWith(expandedBatchIds: currentExpanded);
    notifyListeners();
  }

  Future<void> fetchOperationBatches(int operationId, {bool force = false}) async {
    if (!force && _state.operationBatches.containsKey(operationId)) return;

    final updatedLoading = Map<int, bool>.from(_state.loadingDetails)..[operationId] = true;
    _state = _state.copyWith(loadingDetails: updatedLoading);
    notifyListeners();

    try {
      final res = await _wipRepo.fetchProductionProgress({
        'OperationId': operationId.toString(),
        'TransactionType': '2',
        'MaxResultCount': '1000',
      });

      if (res.success && res.data != null) {
        final records = res.data as List<ProductionProgressResponseModel>;
        final Map<int, List<ProductionProgressResponseModel>> grouped = {};

        for (final r in records) {
          if (r.productionProgress.transactionType != 2) continue;
          if (r.productionProgress.wipStatus != 0) continue;
          if (r.productionProgress.operationId != operationId) continue;
          if (r.productionProgress.locatorId == 18) continue;
          if ((r.productionProgress.subOperation ?? '').toLowerCase() == 'waste') continue;
          if (r.primaryTrayModel.trayCode == null || r.primaryTrayModel.trayCode!.trim().isEmpty) continue;

          final bhId = r.productionProgress.batchHeaderId;
          if (bhId != null) {
            final groupList = grouped.putIfAbsent(bhId, () => []);
            final trayCode = r.primaryTrayModel.trayCode ?? 'UNKNOWN';
            final existingIdx = groupList.indexWhere((e) =>
                (e.primaryTrayModel.trayCode ?? 'UNKNOWN') == trayCode);
            if (existingIdx != -1) {
              if ((r.productionProgress.id ?? 0) >
                  (groupList[existingIdx].productionProgress.id ?? 0)) {
                groupList[existingIdx] = r;
              }
            } else {
              groupList.add(r);
            }
          }
        }

        // Process all batches concurrently in parallel
        final batchFutures = grouped.entries.map((entry) async {
          try {
            final bhId = entry.key;
            final groupRecords = entry.value;

            final results = await Future.wait([
              _wipRepo.fetchProductionProgress({
                'BatchHeaderId': bhId.toString(),
                'TransactionType': '2',
                'MaxResultCount': '1000',
              }),
              _wipRepo.fetchLotHeaderById(bhId),
              _wipRepo.fetchLotLines(batchHeaderId: bhId),
            ]);

            final bhProgRes = results[0];
            final bhRes = results[1];
            final blRes = results[2];

            // Filter active trays at current operationId
            List<ProductionProgressResponseModel> activeTraysAtCurrentOp = groupRecords;
            if (bhProgRes.success && bhProgRes.data != null) {
              final bhProgs = (bhProgRes.data as List<ProductionProgressResponseModel>)
                  .where((p) => p.productionProgress.transactionType == 2 &&
                                p.productionProgress.wipStatus == 0 &&
                                p.productionProgress.locatorId != 18 &&
                                (p.productionProgress.subOperation ?? '').toLowerCase() != 'waste' &&
                                p.primaryTrayModel.trayCode != null &&
                                p.primaryTrayModel.trayCode!.trim().isNotEmpty)
                  .toList();
              if (bhProgs.isNotEmpty) {
                final validTrays = <ProductionProgressResponseModel>[];
                for (final gr in groupRecords) {
                  final trayCode = gr.primaryTrayModel.trayCode ?? 'UNKNOWN';
                  final trayProgs = bhProgs.where((p) => (p.primaryTrayModel.trayCode ?? 'UNKNOWN') == trayCode).toList();
                  if (trayProgs.isNotEmpty) {
                    trayProgs.sort((a, b) => (b.productionProgress.id ?? 0).compareTo(a.productionProgress.id ?? 0));
                    final latestTrayOpId = trayProgs.first.productionProgress.operationId;
                    if (latestTrayOpId == operationId) {
                      validTrays.add(gr);
                    }
                  } else {
                    validTrays.add(gr);
                  }
                }
                if (validTrays.isEmpty) {
                  return null;
                }
                activeTraysAtCurrentOp = validTrays;
              }
            }

            if (!bhRes.success || bhRes.data == null) {
              return null;
            }

            final bhFull = LotHeaderResponseModel.fromJson(bhRes.data);

            // Machine code lookup
            String? machineCode =
                bhFull.machine?.brand ?? bhFull.machine?.resourceCode ?? bhFull.machine?.model;
            final mId = bhFull.batchHeader.machineId ??
                (bhRes.data is Map
                    ? int.tryParse((bhRes.data['batchHeader']?['machineId'] ??
                            bhRes.data['machineId'] ??
                            bhRes.data['resourceId'])
                        ?.toString() ??
                        '')
                    : null);
            if ((machineCode == null || machineCode.isEmpty || machineCode == '-') && mId != null && mId > 0) {
              if (_machineCodeCache.containsKey(mId)) {
                machineCode = _machineCodeCache[mId];
              } else {
                final mRes = await _wipRepo.fetchMachineById(mId);
                if (mRes.success && mRes.data != null) {
                  final mData = mRes.data as Map<String, dynamic>;
                  final mJson = (mData['resource'] is Map)
                      ? Map<String, dynamic>.from(mData['resource'] as Map)
                      : (mData['machine'] is Map)
                          ? Map<String, dynamic>.from(mData['machine'] as Map)
                          : mData;
                  final resolved = mJson['brand']?.toString() ??
                      mJson['name']?.toString() ??
                      mJson['code']?.toString() ??
                      mJson['resourceCode']?.toString() ??
                      mJson['description']?.toString() ??
                      mJson['model']?.toString();
                  if (resolved != null && resolved.isNotEmpty) {
                    _machineCodeCache[mId] = resolved;
                    machineCode = resolved;
                  }
                }
              }
            }

            if (machineCode == null || machineCode.isEmpty || machineCode == '-') {
              if (bhProgRes.success && bhProgRes.data != null) {
                final progs = bhProgRes.data as List<ProductionProgressResponseModel>;
                for (final p in progs) {
                  final b = p.machineModel.brand;
                  final rc = p.machineModel.resourceCode;
                  if (b != null && b.isNotEmpty && b != '-') {
                    machineCode = b;
                    break;
                  }
                  if (rc != null && rc.isNotEmpty && rc != '-') {
                    machineCode = rc;
                    break;
                  }
                }
              }
            }

            if (machineCode == null || machineCode.isEmpty || machineCode == '-') {
              for (final gr in activeTraysAtCurrentOp) {
                final mBrand = gr.machineModel.brand;
                final mResCode = gr.machineModel.resourceCode;
                if (mBrand != null && mBrand.isNotEmpty && mBrand != '-') {
                  machineCode = mBrand;
                  break;
                }
                if (mResCode != null && mResCode.isNotEmpty && mResCode != '-') {
                  machineCode = mResCode;
                  break;
                }
              }
            }
            machineCode ??= '-';

            // Calculate tubes & weight
            double totalTubes = 0.0;
            double totalWeight = 0.0;
            for (final gr in activeTraysAtCurrentOp) {
              final qty = gr.productionProgress.primaryQuantity ?? 0;
              final tubes = (gr.productionProgress.secondaryQuantity ?? qty).toDouble();
              final pw = gr.item.pieceWeight ?? 0;
              totalTubes += tubes;
              totalWeight += qty * pw;
            }

            final bool isStarted = activeTraysAtCurrentOp.any((r) => r.productionProgress.isStarted ?? false);
            final bool isRework = activeTraysAtCurrentOp.any((r) => r.productionProgress.reworkFlag ?? false);

            bool isReassigned = false;
            if (blRes.success && blRes.data != null) {
              final linesList = blRes.data as List;
              isReassigned = linesList.any((l) {
                final dBl = l['batchLines'] as Map<String, dynamic>? ?? l;
                return dBl['isReAssigned'] == true;
              });
            }

            String? trolleyCode;
            final trayDetailId = bhFull.batchHeader.trayDetailId;
            if (trayDetailId != null) {
              if (_trayIdToCode.containsKey(trayDetailId)) {
                trolleyCode = _trayIdToCode[trayDetailId];
              } else {
                final tRes = await _wipRepo.fetchTrayDetailById(trayDetailId);
                if (tRes.success && tRes.data != null) {
                  final tJson = tRes.data as Map;
                  final tdJson = tJson['trayDetails'] ?? tJson['trayDetail'] ?? tJson;
                  final tCode = tdJson['trayCode']?.toString();
                  if (tCode != null) {
                    _trayIdToCode[trayDetailId] = tCode;
                    trolleyCode = tCode;
                  }
                }
              }
            }

            final bool isDraft = activeTraysAtCurrentOp.any((r) =>
                r.productionProgress.pbsFlag == true || r.productionProgress.draftFlag == true);

            // Sort trays inside the batch by trayCode
            activeTraysAtCurrentOp.sort((a, b) =>
                (a.primaryTrayModel.trayCode ?? '').compareTo(b.primaryTrayModel.trayCode ?? ''));

            return WipBatchModel(
              batchHeaderId: bhId,
              batchCode: bhFull.batchHeader.batchHeaderCode ?? '-',
              machine: machineCode,
              color: bhFull.batchHeader.colorDescription ?? '-',
              trayCount: activeTraysAtCurrentOp.length,
              totalTubes: totalTubes,
              totalWeight: totalWeight,
              trolleyCode: trolleyCode,
              isStarted: isStarted,
              reworkFlag: isRework,
              isReassigned: isReassigned,
              isDraft: isDraft,
              trays: activeTraysAtCurrentOp,
            );
          } catch (itemErr) {
            debugPrint('Error processing WIP batch ${entry.key}: $itemErr');
            return null;
          }
        });

        final batchResults = await Future.wait(batchFutures);
        final List<WipBatchModel> batches = batchResults.whereType<WipBatchModel>().toList();

        final updatedBatches = Map<int, List<WipBatchModel>>.from(_state.operationBatches)
          ..[operationId] = batches;
        final updatedLoadingDone = Map<int, bool>.from(_state.loadingDetails)..[operationId] = false;

        _state = _state.copyWith(
          operationBatches: updatedBatches,
          loadingDetails: updatedLoadingDone,
        );
      }
    } catch (e) {
      debugPrint('Error fetching WIP operation batches: $e');
      final updatedLoadingDone = Map<int, bool>.from(_state.loadingDetails)..[operationId] = false;
      _state = _state.copyWith(loadingDetails: updatedLoadingDone);
    }
    notifyListeners();
  }
}
