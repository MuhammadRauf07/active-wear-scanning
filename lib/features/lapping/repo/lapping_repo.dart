import 'package:active_wear_scanning/core/api/services/api_service.dart';

import '../../../core/api/plex-result/plex_api_result.dart';

class LappingRepo {
  final ApiService _api = ApiService();
  Future<PlexApiResult> fetchTrayDetailByCode(String trayCode) async {
    // Aapke endpoint ke mutabiq query parameter pass karein
    // Agar endpoint different hai toh usay update kar lein
    final result = await _api.getList(
        '/api/app/tray-details',
        query: {'TrayCode': trayCode}
    );

    if (result.success && result.data != null) {
      final List data = result.data as List;
      if (data.isNotEmpty) {
        // Pehla record return karein kyunke tray code unique hota hai
        return PlexApiResult(true, 200, "Success", data.first);
      } else {
        return PlexApiResult(false, 404, "Tray not found", null);
      }
    }
    return result;
  }
  // Future Lapping-specific API calls can be added here
}
