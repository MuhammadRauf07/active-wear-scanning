import 'dart:developer' as dev;
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_color_model.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_machine_model.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class LotRepo {
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
          dev.log("LotRepo parsing error on production progress record: $e. Raw: $item");
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
    final result = await _api.getList('/api/app/tray-details', query: {
      'MaxResultCount': '1000',
      'SkipCount': '0',
    });

    if (!result.success || result.data == null) {
      return result;
    }

    final List allItems = result.data is Map
        ? (result.data['items'] ?? [])
        : (result.data is List ? result.data : []);

    return PlexApiResult(true, 200, "Success", allItems);
  }

  Future<PlexApiResult> fetchTrayDetailById(int trayId) async {
    final result = await _api.getObject('/api/app/tray-details/$trayId');
    return result;
  }

  Future<PlexApiResult> createLotHeader(Map<String, dynamic> data) async {
    final result = await _api.post('/api/app/batch-headers', body: data);
    return result;
  }

  Future<PlexApiResult> deleteLotHeader(int id) async {
    final result = await _api.delete('/api/app/batch-headers/$id');
    return result;
  }

  Future<PlexApiResult> updateLotHeader(int id, Map<String, dynamic> data) async {
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

  Future<PlexApiResult> fetchLotHeaders() async {
    final result = await _api.getList('/api/app/batch-headers');
    return result;
  }

  Future<PlexApiResult> fetchLotHeaderById(int id) async {
    final result = await _api.getObject('/api/app/batch-headers/$id');
    return result;
  }

  Future<PlexApiResult> fetchLotLines({int? batchHeaderId}) async {
    final query = {
      'maxResultCount': '1000',
      if (batchHeaderId != null) 'batchHeaderId': batchHeaderId.toString(),
    };
    final result = await _api.getList('/api/app/batch-liness', query: query);
    return result;
  }

  Future<PlexApiResult> createLotLine(Map<String, dynamic> data) async {
    final result = await _api.post('/api/app/batch-liness', body: data);
    return result;
  }

  Future<PlexApiResult> deleteLotLine(int id) async {
    final result = await _api.delete('/api/app/batch-liness/$id');
    return result;
  }

  Future<PlexApiResult> updateLotLine(int id, Map<String, dynamic> data) async {
    final result = await _api.put('/api/app/batch-liness/$id', body: data);
    return result;
  }

  Future<PlexApiResult> fetchLotLinesByProgressId(int progressId) async {
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

  Future<PlexApiResult> fetchLotColors() async {
    final result = await _api.getList('/api/app/segment-codes', query: {
      'SegmentTypeDescription': 'COLORS',
      'MaxResultCount': '1000',
    });
    
    if (!result.success || result.data == null) return result;

    try {
      final data = result.data as List;
      final list = data
          .map((item) => LotColorModel.fromJson(Map<String, dynamic>.from(item)))
          .where((color) =>
              color.segmentType?.description?.toUpperCase() == 'COLORS' ||
              color.segmentType?.code?.toUpperCase() == 'COLORS')
          .toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchLotMachines() async {
    final result = await _api.getList('/api/app/resources', query: {'ResourceTypeId': '2'});
    
    if (!result.success || result.data == null) return result;

    try {
      final data = result.data as List;
      final list = data.map((item) => LotMachineModel.fromJson(Map<String, dynamic>.from(item))).toList();
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

  Future<PlexApiResult> fetchAllWorkOrderLineDetails(int workOrderLineId) async {
    final query = {
      'WorkOrderLineId': workOrderLineId.toString(),
      'MaxResultCount': '1000',
    };
    return await _api.getList('/api/app/work-order-line-details', query: query);
  }

  Future<PlexApiResult> fetchItemRoutings(int itemDefId) async {
    final query = {
      'ItemDefId': itemDefId.toString(),
    };
    final result = await _api.getList('/api/app/item-routings', query: query);
    return result;
  }

  Future<PlexApiResult> postLotHeaderRouting(Map<String, dynamic> data) async {
    final result = await _api.post('/api/app/batch-header-routings', body: data);
    return result;
  }

  Future<PlexApiResult> updateWipTransaction(int id, Map<String, dynamic> data) async {
    return await _api.put('/api/app/w-iPTransactions/$id', body: data);
  }

  Future<PlexApiResult> deleteWipTransaction(int id) async {
    return await _api.delete('/api/app/w-iPTransactions/$id');
  }

  Future<PlexApiResult> fetchLocators({int? operationId}) async {
    final query = operationId != null ? {'OperationId': operationId.toString()} : <String, dynamic>{};
    final result = await _api.getList('/api/app/locators', query: query);
    return result;
  }
}
