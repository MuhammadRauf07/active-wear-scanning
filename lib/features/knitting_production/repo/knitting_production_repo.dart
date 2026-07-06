import 'dart:developer' as dev;
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/knitting_production/model/plan_header_model.dart';
import 'package:active_wear_scanning/features/knitting_production/model/resource_model.dart';
import 'package:active_wear_scanning/features/knitting_production/model/tray_details_model.dart';

class KnittingProductionRepo {
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

  Future<PlexApiResult> fetchProductionProgress() async {
    final result = await _api.getList(
        '/api/app/production-progresses',
        query: {'maxResultCount': '1000'}
    );
    if (!result.success || result.data == null) return result;

    try {
      final List data = result.data as List;
      final list = <ProductionProgressResponseModel>[];
      for (final item in data) {
        try {
          list.add(ProductionProgressResponseModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          dev.log("KnittingProductionRepo parsing error on production progress record: $e. Raw: $item");
        }
      }
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchPlanLines(int resourceId) async {
    final result = await _api.getList('/api/app/plan-lines', query: {'ResourceId': resourceId.toString()});

    if (!result.success || result.data == null) return result;

    dev.log("PrintedResultOfPlanLines :: ${result.data.toString()}");


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

  /// Fetch a single tray by its ID to get the latest concurrencyStamp
  Future<PlexApiResult> fetchTrayById(int trayId) async {
    final result = await _api.getObject('/api/app/tray-details/$trayId');
    if (!result.success || result.data == null) return result;
    try {
      final item = Map<String, dynamic>.from(result.data as Map);
      return PlexApiResult(true, 200, "Success", TrayDetailsModel.fromJson(item));
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  ///
  Future<PlexApiResult> updateTrayDetails(Map<String, dynamic> data, int trayUpdateId) async {
    dev.log("ProductionProgressData :: ${data.toString()}");

    return await _api.put('/api/app/tray-details/$trayUpdateId', body: data);
  }

  ///
  Future<PlexApiResult> saveProductionProgress(Map<String, dynamic> data) async {
    dev.log("ProductionProgressData :: ${data.toString()}");

    return await _api.post('/api/app/production-progresses', body: data);
  }

  Future<PlexApiResult> fetchItemDef(int id) async {
    final result = await _api.getObject('/api/app/item-defs/$id');
    return result;
  }

  /// Fetch a single plan-line by its ID to get the latest concurrencyStamp + quantities.
  /// Uses the list endpoint with Id filter and extracts items[0].planLine from the wrapper.
  Future<PlexApiResult> fetchPlanLineById(int planLineId) async {
    // 1. Try the single get endpoint: GET /api/app/plan-lines/{id}
    final singleResult = await _api.getObject('/api/app/plan-lines/$planLineId');
    if (singleResult.success && singleResult.data != null) {
      try {
        final data = Map<String, dynamic>.from(singleResult.data as Map);
        return PlexApiResult(true, 200, "Success", PlanLine.fromJson(data));
      } catch (e) {
        dev.log("fetchPlanLineById: failed to parse single plan-line: $e. Falling back to list endpoint.");
      }
    }

    // 2. Fallback: GET /api/app/plan-lines list endpoint and filter locally
    final result = await _api.getList('/api/app/plan-lines', query: {'Id': planLineId.toString()});
    if (!result.success || result.data == null) return result;
    try {
      final List data = result.data as List;
      for (final item in data) {
        final wrapper = Map<String, dynamic>.from(item as Map);
        final planLineJson = wrapper.containsKey('planLine')
            ? Map<String, dynamic>.from(wrapper['planLine'] as Map)
            : wrapper;
        
        final idVal = (planLineJson['id'] as num?)?.toInt();
        if (idVal == planLineId) {
          return PlexApiResult(true, 200, "Success", PlanLine.fromJson(planLineJson));
        }
      }
      return PlexApiResult(false, 404, 'Plan line $planLineId not found in list fallback', null);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  /// PUT updated quantities back to plan-line
  Future<PlexApiResult> updatePlanLine(Map<String, dynamic> data, int planLineId) async {
    dev.log("UpdatePlanLineData :: ${data.toString()}");
    return await _api.put('/api/app/plan-lines/$planLineId', body: data);
  }

  Future<PlexApiResult> fetchPlanLinesByWorkOrderLineId(int workOrderLineId) async {
    final result = await _api.getList('/api/app/plan-lines', query: {
      'WorkOrderLineId': workOrderLineId.toString(),
      'MaxResultCount': '1000',
    });

    if (!result.success || result.data == null) return result;

    dev.log("PrintedResultOfPlanLinesByWorkOrderLineId :: ${result.data.toString()}");

    try {
      final data = result.data as List;
      final list = data.map((item) => PlanLineResponseModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();

      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchShifts() async {
    final result = await _api.getList('/api/app/shifts');
    if (!result.success || result.data == null) return result;
    try {
      final data = result.data as List;
      final shifts = data.map((item) => Shift.fromJson(Map<String, dynamic>.from(item))).toList();
      return PlexApiResult(true, 200, "Success", shifts);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchLotHeaders() async {
    return await _api.getList('/api/app/batch-headers');
  }

  Future<PlexApiResult> fetchLotLines() async {
    return await _api.getList('/api/app/batch-liness?MaxResultCount=1000');
  }
}
