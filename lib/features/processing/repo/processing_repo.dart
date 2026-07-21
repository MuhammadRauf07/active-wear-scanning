import 'dart:developer' as dev;
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class ProcessingRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchProcessingOperations() async {
    final result = await _api.getList('/api/app/operations?MaxResultCount=1000');
    
    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = rawData.map((item) {
        final Map<String, dynamic> opMap = Map<String, dynamic>.from(item as Map);
        final opJson = opMap.containsKey('operation') ? (opMap['operation'] as Map<String, dynamic>) : opMap;
        return Operation.fromJson(opJson);
      }).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchProductionProgress(Map<String, String> query) async {
    final Map<String, String> finalQuery = {
      'MaxResultCount': query['MaxResultCount'] ?? query['maxResultCount'] ?? '10',
      ...query,
    };
    final result = await _api.getList('/api/app/production-progresses', query: finalQuery);
    
    if (!result.success || result.data == null) return result;

    try {
      final List data = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = <ProductionProgressResponseModel>[];
      for (final item in data) {
        try {
          list.add(ProductionProgressResponseModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          dev.log("ProcessingRepo parsing error on production progress record: $e. Raw: $item");
        }
      }
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> updateProductionProgress(int id, Map<String, dynamic> data) async {
    return await _api.put('/api/app/production-progresses/$id', body: data);
  }

  Future<PlexApiResult> createProductionProgress(Map<String, dynamic> data) async {
    return await _api.post('/api/app/production-progresses', body: data);
  }

  Future<PlexApiResult> deleteProductionProgress(int id) async {
    return await _api.delete('/api/app/production-progresses/$id');
  }

  Future<PlexApiResult> fetchLocators({int? operationId}) async {
    final query = operationId != null ? {'OperationId': operationId.toString()} : <String, dynamic>{};
    return await _api.getList('/api/app/locators', query: query);
  }
}
