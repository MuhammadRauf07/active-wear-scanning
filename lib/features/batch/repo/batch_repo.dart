import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/batch/model/batch_color_model.dart';
import 'package:active_wear_scanning/features/batch/model/batch_machine_model.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class BatchRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchProductionProgress() async {
    final result = await _api.getList('/api/app/production-progresses');
    
    if (!result.success || result.data == null) return result;

    try {
      final data = result.data as List<Map<String, dynamic>>;
      final list = data.map((item) => ProductionProgressResponseModel.fromJson(item)).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> updateProductionProgress(int id, Map<String, dynamic> data) async {
    final result = await _api.put('/api/app/production-progresses/$id', body: data);
    return result;
  }

  Future<PlexApiResult> fetchBatchColors() async {
    final result = await _api.getList('/api/app/segment-codes', query: {'SegmentTypeId': '629'});
    
    if (!result.success || result.data == null) return result;

    try {
      final data = result.data as List<Map<String, dynamic>>;
      final list = data.map((item) => BatchColorModel.fromJson(item)).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchBatchMachines() async {
    final result = await _api.getList('/api/app/resources', query: {'ResourceTypeId': '2'});
    
    if (!result.success || result.data == null) return result;

    try {
      final data = result.data as List<Map<String, dynamic>>;
      final list = data.map((item) => BatchMachineModel.fromJson(item)).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }
}
