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
      final List data = result.data as List;
      if (data.isNotEmpty) {
        return PlexApiResult(true, 200, "Success", data.first);
      } else {
        return PlexApiResult(false, 404, "Tray not found", null);
      }
    }
    return result;
  }
  Future<PlexApiResult> fetchProductionProgress(Map<String, String> query) async {
    final result = await _api.getList('/api/app/production-progresses', query: query);

    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final productionProgress = rawData
          .map((item) => LappingModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      return PlexApiResult(true, 200, "Success", productionProgress);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }
}
