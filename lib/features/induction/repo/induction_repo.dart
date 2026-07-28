import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/induction/model/induction_model.dart';
import 'package:flutter/foundation.dart';

class InductionRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> getProductionProgress({
    Map<String, String>? params,
  }) async {
    // Default filters for Induction Store as requested
    final Map<String, String> p =
        params ??
        {
          'MaxResultCount': '1000',
        };

    final result = await _api.getList(
      '/api/app/production-progresses',
      query: p,
    );

    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map
          ? (result.data['items'] ?? [])
          : result.data;

      final List<InductionModel> productionProgress = [];
      for (final item in rawData) {
        try {
          if (item is Map) {
            productionProgress.add(
              InductionModel.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        } catch (e) {
          debugPrint("⚠️ Skipping unparseable item in Induction Repo: $e");
        }
      }

      return PlexApiResult(true, 200, "Success", productionProgress);
    } catch (e) {
      debugPrint("❌ Induction Repo Parse Error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> updateProductionProgress(
    int id,
    Map<String, dynamic> data,
  ) async {
    final result = await _api.put(
      '/api/app/production-progresses/$id',
      body: data,
    );
    return result;
  }

  Future<void> postWipTransactions(Map<String, dynamic> data) async {
    debugPrint("InductionWipData: ${data.toString()}");
    await _api.post('/api/app/w-iPTransactions', body: data);
  }

  Future<PlexApiResult> fetchTrayDetailById(int id) async {
    return await _api.getObject('/api/app/tray-details/$id');
  }

  Future<PlexApiResult> updateTrayDetails(int id, Map<String, dynamic> data) async {
    return await _api.put('/api/app/tray-details/$id', body: data);
  }

  Future<PlexApiResult> fetchItemDef(int id) async {
    final result = await _api.getObject('/api/app/item-defs/$id');
    return result;
  }

  Future<PlexApiResult> fetchLotHeaderById(int id) async {
    return await _api.getObject('/api/app/lot-headers/$id');
  }
}
