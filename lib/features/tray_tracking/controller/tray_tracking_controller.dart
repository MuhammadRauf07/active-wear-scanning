import 'package:flutter/foundation.dart';
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/features/tray_tracking/model/tray_tracking_state.dart';
import 'package:active_wear_scanning/features/tray_tracking/model/tray_tracking_model.dart';
import 'package:active_wear_scanning/features/tray_tracking/repo/tray_tracking_repo.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';

class TrayTrackingController extends ChangeNotifier {
  final _trayTrackingRepo = TrayTrackingRepo();

  TrayTrackingState _state = const TrayTrackingState();
  TrayTrackingState get state => _state;

  Future<String?> onTrayScanned(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return "Please enter tray code";

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final res = await _trayTrackingRepo.fetchTrayDetailByCode(cleanCode);

      if (!res.success || res.data == null) {
        final errorMsg = res.message.isNotEmpty ? res.message : "Tray not found";
        _state = _state.copyWith(
          isLoading: false,
          errorMessage: errorMsg,
          clearData: true,
        );
        notifyListeners();
        return errorMsg;
      }

      final data = res.data is Map ? res.data as Map : {};
      final trayMap = data['trayDetail'] ?? data;
      final trayDetail = TrayTrackingDetailModel.fromJson(Map<String, dynamic>.from(trayMap));
      final int? trayId = trayDetail.id ??
          (trayMap['id'] is int ? trayMap['id'] as int : int.tryParse(trayMap['id']?.toString() ?? ''));

      String? batchCode;
      String? color;
      final batchMap = data['batchHeader'];
      if (batchMap is Map) {
        batchCode = batchMap['batchHeaderCode']?.toString();
        color = batchMap['colorDescription']?.toString();
      }

      String? locatorName = data['locator']?['description']?.toString() ??
          data['locator']?['name']?.toString() ??
          data['locator']?['code']?.toString();

      String? machineName = data['resource']?['brand']?.toString() ??
          data['resource']?['name']?.toString() ??
          data['resource']?['code']?.toString() ??
          data['resource']?['resourceCode']?.toString() ??
          data['resource']?['description']?.toString() ??
          data['machine']?['brand']?.toString() ??
          data['machine']?['name']?.toString();

      String? itemDescription = data['knitItem']?['description']?.toString() ??
          data['item']?['description']?.toString() ??
          trayMap['description']?.toString();

      String? workOrderDescription = data['workOrderHeader']?['description']?.toString() ??
          data['workOrderHeader']?['workOrderCode']?.toString();

      // Query live production progress and batch lines concurrently
      final List<ProductionProgressResponseModel> allProgs = [];
      List rawLotLines = [];

      final queries = <Future<PlexApiResult>>[
        if (trayId != null)
          _trayTrackingRepo.fetchProductionProgress({
            'PrimaryTrayId': trayId.toString(),
            'MaxResultCount': '100',
          }),
        _trayTrackingRepo.fetchProductionProgress({
          'TrayCode': cleanCode,
          'MaxResultCount': '100',
        }),
        _trayTrackingRepo.fetchProductionProgress({
          'MaxResultCount': '500',
        }),
        if (trayId != null)
          _trayTrackingRepo.fetchLotLines(trayId: trayId),
      ];

      final results = await Future.wait(queries);

      for (final r in results) {
        if (r.success && r.data != null) {
          if (r.data is List) {
            for (final item in r.data as List) {
              if (item is Map) {
                if (item.containsKey('productionProgress') || item.containsKey('primaryTray')) {
                  try {
                    allProgs.add(ProductionProgressResponseModel.fromJson(Map<String, dynamic>.from(item)));
                  } catch (_) {}
                } else if (item.containsKey('batchLines') || item.containsKey('batchHeaderId')) {
                  rawLotLines.add(item);
                }
              }
            }
          } else if (r.data is Map) {
            final items = (r.data['items'] is List) ? r.data['items'] as List : [];
            for (final item in items) {
              if (item is Map) {
                if (item.containsKey('productionProgress') || item.containsKey('primaryTray')) {
                  try {
                    allProgs.add(ProductionProgressResponseModel.fromJson(Map<String, dynamic>.from(item)));
                  } catch (_) {}
                } else if (item.containsKey('batchLines') || item.containsKey('batchHeaderId')) {
                  rawLotLines.add(item);
                }
              }
            }
          }
        }
      }

      // Filter and deduplicate progress records for THIS specific tray
      final Map<int, ProductionProgressResponseModel> uniqueProgsById = {};
      for (final p in allProgs) {
        final pTrayId = p.primaryTrayModel.id ?? p.productionProgress.primaryTrayId;
        final pTrayCode = (p.primaryTrayModel.trayCode ?? '').trim().toUpperCase();
        final isMatch = (trayId != null && pTrayId == trayId) ||
            (pTrayCode.isNotEmpty && pTrayCode == cleanCode.toUpperCase());

        if (isMatch) {
          final id = p.productionProgress.id ?? uniqueProgsById.length;
          uniqueProgsById[id] = p;
        }
      }

      final matchingProgs = uniqueProgsById.values.toList()
        ..sort((a, b) => (b.productionProgress.id ?? 0).compareTo(a.productionProgress.id ?? 0));

      ProductionProgressResponseModel? latestPP;
      if (matchingProgs.isNotEmpty) {
        latestPP = matchingProgs.first;

        if (latestPP.item.description.isNotEmpty) {
          itemDescription = latestPP.item.description;
        }
        if (latestPP.processedItem?.description != null && latestPP.processedItem!.description.isNotEmpty) {
          itemDescription = latestPP.processedItem!.description;
        }
        if (latestPP.workOrderHeader.workOrderCode.isNotEmpty) {
          workOrderDescription = latestPP.workOrderHeader.workOrderCode;
        }
        if (latestPP.operation.name.isNotEmpty) {
          locatorName = latestPP.operation.name;
        }
      }

      // Resolve batchHeaderId across all available sources
      int? bhId = latestPP?.productionProgress.batchHeaderId ??
          latestPP?.batchHeader?.id;

      if (bhId == null || bhId == 0) {
        for (final p in matchingProgs) {
          final id = p.productionProgress.batchHeaderId ?? p.batchHeader?.id;
          if (id != null && id > 0) {
            bhId = id;
            break;
          }
        }
      }

      if (bhId == null || bhId == 0) {
        for (final line in rawLotLines) {
          final Map bl = (line is Map && line.containsKey('batchLines'))
              ? (line['batchLines'] as Map)
              : (line is Map ? line : {});
          final lineTrayId = bl['trayId'] as int? ?? bl['primaryTrayId'] as int?;
          if (trayId != null && lineTrayId == trayId) {
            final lineBhId = bl['batchHeaderId'] as int?;
            if (lineBhId != null && lineBhId > 0) {
              bhId = lineBhId;
              break;
            }
          }
        }
      }

      if (bhId == null || bhId == 0) {
        final rawBhId = trayMap['batchHeaderId'] ?? data['batchHeaderId'];
        if (rawBhId != null) {
          bhId = rawBhId is int ? rawBhId : int.tryParse(rawBhId.toString());
        }
      }

      if (bhId != null && bhId > 0) {
        // --- POST-LAPPING / BATCHED STAGE ---
        batchCode = latestPP?.batchHeader?.batchHeaderCode ?? batchCode;
        color = latestPP?.batchHeader?.colorDescription ?? color;

        final bhRes = await _trayTrackingRepo.fetchBatchHeaderById(bhId);
        if (bhRes.success && bhRes.data != null) {
          final bhData = bhRes.data is Map ? bhRes.data as Map : {};
          final bhFull = LotHeaderResponseModel.fromJson(Map<String, dynamic>.from(bhData));

          batchCode = bhFull.batchHeader.batchHeaderCode ?? batchCode ?? 'BH-$bhId';
          color = bhFull.batchHeader.colorDescription ?? color;

          // Extract assigned Dyeing Machine
          String? dyeingMachine = bhFull.machine?.brand ??
              bhFull.machine?.resourceCode ??
              bhFull.machine?.model;

          final mId = bhFull.batchHeader.machineId ??
              int.tryParse((bhData['batchHeader']?['machineId'] ??
                      bhData['machineId'] ??
                      bhData['resourceId'] ??
                      bhData['batchHeader']?['resourceId'])
                  ?.toString() ??
                  '');

          if ((dyeingMachine == null || dyeingMachine.isEmpty || dyeingMachine == '-') && mId != null && mId > 0) {
            final mRes = await _trayTrackingRepo.fetchMachineById(mId);
            if (mRes.success && mRes.data != null) {
              final mData = mRes.data is Map ? (mRes.data as Map<String, dynamic>) : <String, dynamic>{};
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
                dyeingMachine = resolved;
              }
            }
          }

          if (dyeingMachine != null && dyeingMachine.isNotEmpty && dyeingMachine != '-') {
            machineName = dyeingMachine;
          }
        }

        // Fallback from latestPP.machineModel if still null
        if ((machineName == null || machineName.isEmpty || machineName == '-') &&
            latestPP != null &&
            latestPP.machineModel.brand != null &&
            latestPP.machineModel.brand!.isNotEmpty) {
          machineName = latestPP.machineModel.brand;
        }
      } else {
        // --- PRE-LOT STAGE (Knitting) ---
        // Machine is the origin Knitting Machine
        batchCode = null;
        color = null;
        if (latestPP != null &&
            latestPP.machineModel.brand != null &&
            latestPP.machineModel.brand!.isNotEmpty) {
          machineName = latestPP.machineModel.brand;
        } else if (latestPP != null &&
            latestPP.machineModel.resourceCode != null &&
            latestPP.machineModel.resourceCode!.isNotEmpty) {
          machineName = latestPP.machineModel.resourceCode;
        }
      }

      _state = _state.copyWith(
        isLoading: false,
        trayDetail: trayDetail,
        batchCode: batchCode,
        color: color,
        locatorName: locatorName,
        machineName: machineName,
        itemDescription: itemDescription,
        workOrderDescription: workOrderDescription,
      );
      notifyListeners();
      return null;
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Error tracking tray: $e',
        clearData: true,
      );
      notifyListeners();
      return 'Error tracking tray: $e';
    }
  }
}

