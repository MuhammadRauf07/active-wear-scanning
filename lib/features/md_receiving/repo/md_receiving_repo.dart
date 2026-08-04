import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:flutter/cupertino.dart';

class MdReceivingRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchInitialData() async {
    try {
      // Placeholder for future MD Receiving API endpoints
      return PlexApiResult(true, 200, "Success", null);
    } catch (e) {
      debugPrint("❌ MD Receiving Repo Error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> createProductionProgress(Map<String, dynamic> data) async {
    try {
      return await _api.post('/api/app/production-progresses', body: data);
    } catch (e) {
      debugPrint("❌ MD Receiving Create Production Progress error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> createWipTransaction(Map<String, dynamic> data) async {
    try {
      return await _api.post('/api/app/w-iPTransactions', body: data);
    } catch (e) {
      debugPrint("❌ MD Receiving Create WIP Transaction error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchProductionProgress(Map<String, String> query) async {
    try {
      final Map<String, String> finalQuery = {
        'MaxResultCount': '1000',
        'maxResultCount': '1000',
        ...query,
      };
      return await _api.getList('/api/app/production-progresses', query: finalQuery);
    } catch (e) {
      debugPrint("❌ MD Receiving Fetch Production Progress error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> updateProductionProgress(int id, Map<String, dynamic> data) async {
    try {
      return await _api.put('/api/app/production-progresses/$id', body: data);
    } catch (e) {
      debugPrint("❌ MD Receiving Update Production Progress error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchPackingInstructionByUniqueId(String uniqueId) async {
    try {
      final result = await _api.getList(
        '/api/app/packing-instruction-line-details',
        query: {
          'UniqueId': uniqueId,
          'MaxResultCount': '1',
        },
      );

      if (!result.success || result.data == null) return result;

      final List rawData = result.data is Map ? result.data['items'] : result.data;
      if (rawData.isEmpty) {
        return PlexApiResult(false, 404, "Carton Unique ID not found", null);
      }

      return PlexApiResult(true, 200, "Success", rawData.first);
    } catch (e) {
      debugPrint("❌ MD Receiving fetch Carton unique ID error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }
}
