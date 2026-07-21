import 'dart:developer' as dev;
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/lapping/model/lapping_model.dart';

import '../../../core/api/plex-result/plex_api_result.dart';

class LappingRepo {
  final ApiService _api = ApiService();
  Future<PlexApiResult> fetchTrayDetailByCode(String trayCode) async {
    final result = await _api.getList(
        '/api/app/tray-details?MaxResultCount=1000',
        query: {'TrayCode': trayCode}
    );

    if (result.success && result.data != null) {
      final List data = result.data is Map ? (result.data['items'] ?? []) : result.data;
      if (data.isNotEmpty) {
        return PlexApiResult(true, 200, "Success", data.first);
      } else {
        return PlexApiResult(false, 404, "Tray not found", null);
      }
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
