import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class ProcessingRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchProcessingOperations() async {
    final result = await _api.getList('/api/app/operations');
    
    if (!result.success || result.data == null) return result;

    try {
      final data = result.data as List<Map<String, dynamic>>;
      final list = data.map((item) => Operation.fromJson(item)).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchProductionProgress(Map<String, String> query) async {
    final result = await _api.getList('/api/app/production-progresses', query: query);
    
    if (!result.success || result.data == null) return result;

    try {
      final data = result.data as List;
      final list = data.map((item) => ProductionProgressResponseModel.fromJson(item)).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }
}
