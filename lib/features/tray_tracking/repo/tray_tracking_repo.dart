import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';

class TrayTrackingRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchTrayDetailByCode(String trayCode) async {
    final result = await _api.getList(
        '/api/app/tray-details',
        query: {'TrayCode': trayCode}
    );

    if (result.success && result.data != null) {
      final List data = result.data is Map ? (result.data['items'] ?? []) : (result.data as List);
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
    return await _api.getList('/api/app/production-progresses', query: query);
  }

  Future<PlexApiResult> fetchBatchHeaderById(int id) async {
    return await _api.getObject('/api/app/batch-headers/$id');
  }

  Future<PlexApiResult> fetchMachineById(int id) async {
    return await _api.getObject('/api/app/resources/$id');
  }

  Future<PlexApiResult> fetchLotLines({int? trayId, int? batchHeaderId}) async {
    final query = {
      'MaxResultCount': '1000',
      'maxResultCount': '1000',
      if (trayId != null) 'TrayId': trayId.toString(),
      if (trayId != null) 'trayId': trayId.toString(),
      if (batchHeaderId != null) 'BatchHeaderId': batchHeaderId.toString(),
      if (batchHeaderId != null) 'batchHeaderId': batchHeaderId.toString(),
    };
    return await _api.getList('/api/app/batch-liness', query: query);
  }
}
