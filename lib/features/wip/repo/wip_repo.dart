import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import '../model/wip_model.dart';

class WipRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchLocators() async {
    final result = await _api.getList('/api/app/locators?MaxResultCount=1000');
    
    if (!result.success || result.data == null) return result;

    try {
      final List<dynamic> data = result.data as List;
      final list = data.map((item) => LocatorResponse.fromJson(item as Map<String, dynamic>)).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  // Generic method to fetch WIP data. 
  // Depending on its department, the data structure might vary, but for UI purposes 
  // we'll fetch them as WIPEntry.
  Future<PlexApiResult> fetchWipDetails(int locatorId) async {
    final result = await _api.getList('/api/app/production-progresses', query: {
      'LocatorId': locatorId.toString(),
      'MaxResultCount': '1000',
      'logicalWH': 'FLOOR'
    });
    
    if (!result.success || result.data == null) return result;

    try {
      final List<dynamic> data = result.data as List;
      final list = data.map((item) => ProductionProgressResponseModel.fromJson(item as Map<String, dynamic>)).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }
}
