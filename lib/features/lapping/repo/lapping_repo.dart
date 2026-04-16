import 'package:active_wear_scanning/core/api/services/api_service.dart';

import '../../../core/api/plex-result/plex_api_result.dart';

class LappingRepo {
  final ApiService _api = ApiService();
  Future<PlexApiResult> fetchTrayDetailByCode(String trayCode) async {
    final result = await _api.getList(
        '/api/app/tray-details',
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
  // Future Lapping-specific API calls can be added here
}
