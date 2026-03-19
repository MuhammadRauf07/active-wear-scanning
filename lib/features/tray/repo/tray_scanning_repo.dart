import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/tray/model/plan_header_model.dart';
import 'package:active_wear_scanning/features/tray/model/resource_model.dart';
import 'package:active_wear_scanning/features/tray/model/tray_details_model.dart';

class TrayScanningRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchResource(String serialNumber) async {
    final result = await _api.getList('/api/app/resources', query: {'SerialNumber': serialNumber});
    if (!result.success || result.data == null) return result;

    try {
      final data = result.data as List<Map<String, dynamic>>;
      final resource = data.map((item) => ResourceResponseModel.fromJson(item)).toList();
      return PlexApiResult(true, 200, "Success", resource);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchPlanLines(int resourceId) async {
    final result = await _api.getList('/api/app/plan-lines', query: {'ResourceId': resourceId.toString()});

    if (!result.success || result.data == null) return result;

    print("PrintedResultOfPlanLines :: ${result.data.toString()}");


    try {

      final data = result.data as List<Map<String, dynamic>>;
      final list = data.map((item) => PlanLineResponseModel.fromJson(item)).toList();

      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> loadWorkOrderBySerialNumber(String serialNumber) async {
    final resourceResult = await fetchResource(serialNumber);
    if (!resourceResult.success || resourceResult.data == null) return resourceResult;

    final resource = resourceResult.data as List<ResourceResponseModel>;
    if (resource.isEmpty) return PlexApiResult(false, 500, 'No resource found', null);

    return fetchPlanLines(resource.first.resource.id);
  }

  Future<PlexApiResult> fetchAvailableTrayDetails() async {
    final result = await _api.getList('/api/app/tray-details');
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

  ///
  Future<void> updateTrayDetails(Map<String, dynamic> data, int trayUpdateId) async {
    print("ProductionProgressData :: ${data.toString()}");

    await _api.put('/api/app/tray-details/$trayUpdateId', body: data);
  }

  ///
  Future<void> saveProductionProgress(Map<String, dynamic> data) async {
    print("ProductionProgressData :: ${data.toString()}");

    await _api.post('/api/app/production-progresses', body: data);
  }
}
