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

  Future<PlexApiResult> fetchProductionProgressById(int id) async {
    final result = await _api.getObject('/api/app/production-progresses/$id');
    return result;
  }

  Future<PlexApiResult> updateTrayDetails(int trayId, Map<String, dynamic> data) async {
    final result = await _api.put('/api/app/tray-details/$trayId', body: data);
    return result;
  }

  Future<PlexApiResult> createTrayDetail(Map<String, dynamic> data) async {
    final result = await _api.post('/api/app/tray-details', body: data);
    return result;
  }

  Future<PlexApiResult> fetchTrayDetails() async {
    final result = await _api.getList('/api/app/tray-details');
    return result;
  }

  Future<PlexApiResult> fetchTrayDetailById(int trayId) async {
    final result = await _api.getObject('/api/app/tray-details/$trayId');
    return result;
  }

  Future<PlexApiResult> createBatchHeader(Map<String, dynamic> data) async {
    final result = await _api.post('/api/app/batch-headers', body: data);
    return result;
  }

  Future<PlexApiResult> deleteBatchHeader(int id) async {
    final result = await _api.delete('/api/app/batch-headers/$id');
    return result;
  }

  Future<PlexApiResult> updateBatchHeader(int id, Map<String, dynamic> data) async {
    final result = await _api.put('/api/app/batch-headers/$id', body: data);
    return result;
  }

  Future<PlexApiResult> postWipTransaction(Map<String, dynamic> data) async {
    final result = await _api.post('/api/app/w-iPTransactions', body: data);
    return result;
  }

  Future<PlexApiResult> postProductionProgress(Map<String, dynamic> data) async {
    final result = await _api.post('/api/app/production-progresses', body: data);
    return result;
  }

  Future<PlexApiResult> fetchBatchHeaders() async {
    final result = await _api.getList('/api/app/batch-headers');
    return result;
  }

  Future<PlexApiResult> fetchBatchHeaderById(int id) async {
    final result = await _api.getObject('/api/app/batch-headers/$id');
    return result;
  }

  Future<PlexApiResult> fetchBatchLines({int? batchHeaderId}) async {
    final query = batchHeaderId != null ? {'BatchHeaderId': batchHeaderId.toString()} : <String, dynamic>{};
    final result = await _api.getList('/api/app/batch-liness', query: query);
    return result;
  }

  Future<PlexApiResult> createBatchLine(Map<String, dynamic> data) async {
    final result = await _api.post('/api/app/batch-liness', body: data);
    return result;
  }

  Future<PlexApiResult> deleteBatchLine(int id) async {
    final result = await _api.delete('/api/app/batch-liness/$id');
    return result;
  }

  Future<PlexApiResult> updateBatchLine(int id, Map<String, dynamic> data) async {
    final result = await _api.put('/api/app/batch-liness/$id', body: data);
    return result;
  }

  Future<PlexApiResult> fetchBatchLinesByProgressId(int progressId) async {
    final result = await _api.getList('/api/app/batch-liness', query: {'ProgressId': progressId.toString()});
    return result;
  }

  /// Finds the WIP transaction linked to a given progressId.
  /// Returns the raw list so the caller can extract the wipTransaction.id.
  Future<PlexApiResult> fetchWipTransactionsByProgressId(int progressId) async {
    final result = await _api.getList('/api/app/w-iPTransactions', query: {'ProgressId': progressId.toString()});
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

  Future<PlexApiResult> fetchWorkOrderLineDetails(int workOrderLineId, String colorDescription) async {
    final query = {
      'WorkOrderLineId': workOrderLineId.toString(),
      'ColorDescription': colorDescription,
    };
    
    // Using the exact URL provided by the user (the GET list endpoint handles query params)
    final result = await _api.getList('/api/app/work-order-line-details', query: query);
    
    return result;
  }

  Future<PlexApiResult> fetchItemRoutings(int itemDefId) async {
    final query = {
      'ItemDefId': itemDefId.toString(),
    };
    final result = await _api.getList('/api/app/item-routings', query: query);
    return result;
  }

  Future<PlexApiResult> postBatchHeaderRouting(Map<String, dynamic> data) async {
    final result = await _api.post('/api/app/batch-header-routings', body: data);
    return result;
  }
}
