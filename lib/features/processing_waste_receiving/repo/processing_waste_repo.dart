import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';

class ProcessingWasteRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchProductionProgress(Map<String, String> query) async {
    final result = await _api.getList('/api/app/production-progresses', query: query);
    return result;
  }

  Future<PlexApiResult> updateProductionProgress(int id, Map<String, dynamic> data) async {
    return await _api.put('/api/app/production-progresses/$id', body: data);
  }

  Future<PlexApiResult> createWipTransaction(Map<String, dynamic> data) async {
    return await _api.post('/api/app/wip-transactions', body: data);
  }
}
