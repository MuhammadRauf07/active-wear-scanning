import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class GBSReceivingRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> getProductionProgress() async {
    final result = await _api.getList('/api/app/production-progresses');
    if (!result.success || result.data == null) return result;

    try {
      final data = result.data as List<Map<String, dynamic>>;
      final productionProgress = data.map((item) => ProductionProgressResponseModel.fromJson(item)).toList();
      return PlexApiResult(true, 200, "Success", productionProgress);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  ///
  Future<void> postWipTransactions(Map<String, dynamic> data) async {
    print("ProductionProgressData :: ${data.toString()}");

    await _api.post('/api/app/w-iPTransactions', body: data);
  }

  Future<PlexApiResult> updateProductionProgress(int id, Map<String, dynamic> data) async {
    final result = await _api.put('/api/app/production-progresses/$id', body: data);
    return result;
  }
}
