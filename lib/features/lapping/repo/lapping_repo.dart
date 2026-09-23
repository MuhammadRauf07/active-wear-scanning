import 'dart:developer' as dev;
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/knitting_production/model/tray_details_model.dart';
import 'package:active_wear_scanning/features/lapping/model/lapping_model.dart';
import '../../../core/api/plex-result/plex_api_result.dart';

class LappingRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchAvailableTrayDetails({int maxResultCount = 100, int skipCount = 0}) async {
    final result = await _api.getList('/api/app/tray-details', query: {
      'Active': 'true',
      'TrayType': '1',
      'MaxResultCount': maxResultCount.toString(),
      'SkipCount': skipCount.toString(),
    });

    if (!result.success || result.data == null) {
      return result;
    }

    final List allItems = result.data is Map
        ? (result.data['items'] ?? [])
        : (result.data is List ? result.data : []);

    if (allItems.isEmpty) {
      return PlexApiResult(false, 500, "No tray details found", null);
    }

    try {
      final list = <TrayDetailsModel>[];
      for (var i = 0; i < allItems.length; i++) {
        try {
          final item = Map<String, dynamic>.from(allItems[i] as Map);
          list.add(TrayDetailsModel.fromJson(item));
        } catch (e) {
          return PlexApiResult(false, 500, 'Parse error at index $i: $e', null);
        }
      }
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchTrayDetailByCode(String trayCode) async {
    final result = await _api.getList(
        '/api/app/tray-details?MaxResultCount=1000',
        query: {'TrayCode': trayCode}
    );

    if (result.success && result.data != null) {
      final List data = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final cleanQuery = trayCode.trim().toLowerCase();
      for (final elem in data) {
        final map = Map<String, dynamic>.from(elem as Map);
        final itemTray = map.containsKey('trayDetail')
            ? map['trayDetail']
            : (map.containsKey('trayDetails')
                ? map['trayDetails']
                : (map.containsKey('primaryTrayModel') ? map['primaryTrayModel'] : map));
        final code = (itemTray?['trayCode'] ?? map['trayCode'])?.toString().trim().toLowerCase();
        if (code == cleanQuery) {
          return PlexApiResult(true, 200, "Success", map);
        }
      }
      return PlexApiResult(false, 404, "Tray not found", null);
    }
    return result;
  }

  Future<PlexApiResult> fetchProductionProgress(Map<String, String> query) async {
    final Map<String, String> finalQuery = {
      'MaxResultCount': query['MaxResultCount'] ?? query['maxResultCount'] ?? '10',
      ...query,
    };
    final result = await _api.getList('/api/app/production-progresses', query: finalQuery);

    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = <LappingModel>[];
      for (final item in rawData) {
        try {
          list.add(LappingModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          dev.log("LappingRepo parsing error on production progress record: $e. Raw: $item");
        }
      }
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchItemDef(int id) async {
    final result = await _api.getObject('/api/app/item-defs/$id');
    return result;
  }
}
