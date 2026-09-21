import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';

class ProcessingWasteRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchOperations() async {
    final result = await _api.getList('/api/app/operations?MaxResultCount=1000');
    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = rawData.map((item) {
        final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item as Map);
        final Map<String, dynamic> opJson = itemMap.containsKey('operation') && itemMap['operation'] != null
            ? Map<String, dynamic>.from(itemMap['operation'] as Map)
            : itemMap;
        if (itemMap.containsKey('locator') && itemMap['locator'] != null && !opJson.containsKey('locator')) {
          opJson['locator'] = itemMap['locator'];
        }
        return Operation.fromJson(opJson);
      }).where((op) => op.processNature == 1).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchProductionProgress(Map<String, String> query) async {
    final Map<String, String> finalQuery = {
      'MaxResultCount': query['MaxResultCount'] ?? '1000',
      ...query,
    };
    final result = await _api.getList('/api/app/production-progresses', query: finalQuery);
    return result;
  }

  Future<PlexApiResult> updateProductionProgress(int id, Map<String, dynamic> data) async {
    return await _api.put('/api/app/production-progresses/$id', body: data);
  }

  Future<PlexApiResult> createWipTransaction(Map<String, dynamic> data) async {
    return await _api.post('/api/app/w-iPTransactions', body: data);
  }
}
