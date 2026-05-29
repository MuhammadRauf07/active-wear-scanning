import 'dart:developer' as dev;
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/batch/model/batch_color_model.dart';
import 'package:active_wear_scanning/features/batch/model/batch_machine_model.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class BatchRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchProductionProgress({Map<String, String>? query}) async {
    final Map<String, String> q = query ?? {
      'LocatorId': '3',
      'maxResultCount': '1000',
    };
    final result = await _api.getList(
        '/api/app/production-progresses',
        query: q
    );
    
    if (!result.success || result.data == null) return result;

    try {
      final List data = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = <ProductionProgressResponseModel>[];
      for (final item in data) {
        try {
          list.add(ProductionProgressResponseModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          dev.log("BatchRepo parsing error on production progress record: $e. Raw: $item");
        }
      }
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }
  Future<PlexApiResult> fetchTrayDetailByCode(String trayCode) async {
    final result = await _api.getList(
        '/api/app/tray-details',
        query: {'TrayCode': trayCode}
    );

    if (result.success && result.data != null) {
      final List data = result.data is Map ? (result.data['items'] ?? []) : result.data;
      if (data.isNotEmpty) {
        return PlexApiResult(true, 200, "Success", data.first);
      } else {
        return PlexApiResult(false, 404, "Tray not found", null);
      }
    }
    return result;
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
    final query = {
      'maxResultCount': '1000',
      if (batchHeaderId != null) 'batchHeaderId': batchHeaderId.toString(),
    };
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
    final result = await _api.getList(
      '/api/app/batch-liness', 
      query: {
        'progressId': progressId.toString(),
        'maxResultCount': '1000',
      }
    );
    return result;
  }

  /// Finds the WIP transaction linked to a given progressId.
  /// Returns the raw list so the caller can extract the wipTransaction.id.
  Future<PlexApiResult> fetchWipTransactionsByProgressId(int progressId) async {
    // Fetching a larger list without the problematic filter to allow in-memory filtering
    final result = await _api.getList(
      '/api/app/w-iPTransactions', 
      query: {
        'maxResultCount': '1000',
      }
    );
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

  Future<PlexApiResult> fetchItemDef(int id) async {
    final result = await _api.getObject('/api/app/item-defs/$id');
    return result;
  }

  Future<PlexApiResult> fetchMachineById(int id) async {
    return await _api.getObject('/api/app/resources/$id');
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

  Future<PlexApiResult> fetchLocators({int? operationId}) async {
    final query = operationId != null ? {'OperationId': operationId.toString()} : <String, dynamic>{};
    final result = await _api.getList('/api/app/locators', query: query);
    return result;
  }
}
