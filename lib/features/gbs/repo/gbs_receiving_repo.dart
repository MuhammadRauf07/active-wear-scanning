import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/tray/model/tray_details_model.dart';
import 'package:flutter/cupertino.dart';

class GBSReceivingRepo {
  final ApiService _api = ApiService();

  // Future<PlexApiResult> getProductionProgress({Map<String, String>? params}) async {
  //   final result = await _api.getList('/api/app/production-progresses');
  //   if (!result.success || result.data == null) return result;
  //
  //   try {
  //     final data = result.data as List<Map<String, dynamic>>;
  //     final productionProgress = data.map((item) => ProductionProgressResponseModel.fromJson(item)).toList();
  //     return PlexApiResult(true, 200, "Success", productionProgress);
  //   } catch (e) {
  //     return PlexApiResult(false, 500, e.toString(), null);
  //   }
  // }
  Future<PlexApiResult> getProductionProgress({Map<String, String>? params}) async {
    final Map<String, String> p = params ?? {
      'LocatorId': '2',
      'TransactionType': '1',
      'MaxResultCount': '1000',
    };
    final queryString = Uri(queryParameters: p).query;

    final result = await _api.getList(
      '/api/app/production-progresses',
      query: p,
    );

    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? result.data['items'] : result.data;

      final productionProgress = rawData
          .map((item) => ProductionProgressResponseModel.fromJson(item))
          .toList();

      return PlexApiResult(true, 200, "Success", productionProgress);
    } catch (e) {
      debugPrint("❌ Repo Parse Error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  ///
  Future<void> postWipTransactions(Map<String, dynamic> data) async {
    print("ProductionProgressData :: ${data.toString()}");

    await _api.post('/api/app/w-iPTransactions', body: data);
  }

  Future<PlexApiResult> saveProductionProgress(Map<String, dynamic> data) async {
    final result = await _api.post('/api/app/production-progresses', body: data);
    return result;
  }

  Future<PlexApiResult> updateProductionProgress(int id, Map<String, dynamic> data) async {
    final result = await _api.put('/api/app/production-progresses/$id', body: data);
    return result;
  }

  Future<PlexApiResult> updateTrayDetails(Map<String, dynamic> data, int trayId) async {
    final result = await _api.put('/api/app/tray-details/$trayId', body: data);
    return result;
  }

  Future<PlexApiResult> fetchTrayDetailById(int trayId) async {
    final result = await _api.getObject('/api/app/tray-details/$trayId');
    return result;
  }

  Future<PlexApiResult> fetchAvailableTrayDetails() async {
    final result = await _api.getList('/api/app/tray-details?MaxResultCount=1000');
    if (!result.success || result.data == null) return result;

    try {
      final data = result.data as List;
      final list = <TrayDetailsModel>[];
      for (var i = 0; i < data.length; i++) {
        try {
          final item = Map<String, dynamic>.from(data[i] as Map);
          list.add(TrayDetailsModel.fromJson(item));
        } catch (e) {
          return PlexApiResult(false, 500, 'Parse error at index $i: $e', null);
        }
      }

      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchItemDef(int id) async {
    final result = await _api.getObject('/api/app/item-defs/$id');
    return result;
  }
}
