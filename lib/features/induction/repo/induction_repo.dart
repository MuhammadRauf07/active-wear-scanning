import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
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
          'TransactionType': '3',
          'PBSFlag': 'false',
          'IsLastProcess': 'true',
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

      final productionProgress = rawData
          .map(
            (item) => InductionModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

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
}
