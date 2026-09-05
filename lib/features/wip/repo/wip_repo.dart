import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/wip/model/wip_model.dart';

class WipRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchProcessingOperations() async {
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
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = rawData.map((item) {
        return ProductionProgressResponseModel.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchLotHeaderById(int id) async {
    return await _api.getObject('/api/app/batch-headers/$id');
  }

  Future<PlexApiResult> fetchMachineById(int id) async {
    return await _api.getObject('/api/app/resources/$id');
  }

  Future<PlexApiResult> fetchTrayDetailById(int id) async {
    return await _api.getObject('/api/app/tray-details/$id');
  }

  Future<PlexApiResult> fetchLotLines({required int batchHeaderId}) async {
    return await _api.getList('/api/app/batch-liness', query: {
      'batchHeaderId': batchHeaderId.toString(),
      'maxResultCount': '1000',
    });
  }

  Future<PlexApiResult> fetchLocators({int? operationId}) async {
    final query = operationId != null
        ? {'OperationId': operationId.toString(), 'MaxResultCount': '1000'}
        : {'MaxResultCount': '1000'};
    final result = await _api.getList('/api/app/locators', query: query);
    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = rawData.map((item) => LocatorResponse.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchWipDetails(int locatorId) async {
    final result = await _api.getList('/api/app/production-progresses', query: {
      'LocatorId': locatorId.toString(),
      'TransactionType': '2',
      'MaxResultCount': '1000',
      'logicalWH': 'FLOOR',
    });
    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = rawData.map((item) => ProductionProgressResponseModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }
}
