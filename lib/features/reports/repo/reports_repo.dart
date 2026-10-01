import 'dart:developer' as dev;
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';
import 'package:active_wear_scanning/features/reports/model/report_models.dart';

class ReportsRepo {
  final ApiService _api = ApiService();

  // ---------------------------------------------------------------------------
  // 1. Knitting Report Data
  // ---------------------------------------------------------------------------
  Future<PlexApiResult> fetchKnittingPlanLines({
    String? planDate,
    int? shiftId,
    int? resourceId,
    int? workOrderHeaderId,
  }) async {
    final query = <String, dynamic>{
      'MaxResultCount': '1000',
    };
    if (planDate != null && planDate.isNotEmpty) query['PlanDate'] = planDate;
    if (shiftId != null) query['ShiftId'] = shiftId.toString();
    if (resourceId != null) query['ResourceId'] = resourceId.toString();
    if (workOrderHeaderId != null) query['WorkOrderHeaderId'] = workOrderHeaderId.toString();

    final result = await _api.getList('/api/app/plan-lines', query: query);
    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = rawData.map((item) {
        return PlanLine.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      dev.log("ReportsRepo fetchKnittingPlanLines error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchKnittingProductionProgress({
    String? date,
    int? shiftId,
  }) async {
    final query = <String, dynamic>{
      'MaxResultCount': '1000',
      'TransactionType': '1', // Knitting / GBS
    };
    if (date != null && date.isNotEmpty) query['Date'] = date;
    if (shiftId != null) query['ShiftId'] = shiftId.toString();

    return await _fetchProductionProgressList(query);
  }

  // ---------------------------------------------------------------------------
  // 2. Work Order Report Data
  // ---------------------------------------------------------------------------
  Future<PlexApiResult> fetchWorkOrderLines({
    int? workOrderLineId,
    int? batchHeaderId,
  }) async {
    final query = <String, dynamic>{
      'MaxResultCount': '1000',
    };
    if (workOrderLineId != null) query['WorkOrderLineId'] = workOrderLineId.toString();
    if (batchHeaderId != null) query['batchHeaderId'] = batchHeaderId.toString();

    final result = await _api.getList('/api/app/batch-liness', query: query);
    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = rawData.map((item) {
        return BatchLine.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      dev.log("ReportsRepo fetchWorkOrderLines error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchWorkOrderLineDetails({int? workOrderLineId}) async {
    final query = <String, dynamic>{
      'MaxResultCount': '1000',
    };
    if (workOrderLineId != null) query['WorkOrderLineId'] = workOrderLineId.toString();
    return await _api.getList('/api/app/work-order-line-details', query: query);
  }

  // ---------------------------------------------------------------------------
  // 3. Batch Report Data
  // ---------------------------------------------------------------------------
  Future<PlexApiResult> fetchBatchHeaders({
    String? batchCode,
    bool? lockFlag,
    String? planDate,
  }) async {
    final query = <String, dynamic>{
      'MaxResultCount': '1000',
    };
    if (batchCode != null && batchCode.isNotEmpty) query['BatchHeaderCode'] = batchCode;
    if (lockFlag != null) query['LockFlag'] = lockFlag.toString();
    if (planDate != null && planDate.isNotEmpty) query['PlanDate'] = planDate;

    final result = await _api.getList('/api/app/batch-headers', query: query);
    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = rawData.map((item) {
        return LotHeaderModel.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      dev.log("ReportsRepo fetchBatchHeaders error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchBatchRoutings({int? batchHeaderId}) async {
    final query = <String, dynamic>{
      'MaxResultCount': '1000',
    };
    if (batchHeaderId != null) query['BatchHeaderId'] = batchHeaderId.toString();
    return await _api.getList('/api/app/batch-header-routings', query: query);
  }

  Future<PlexApiResult> fetchDefectHistories({int? batchHeaderId}) async {
    final query = <String, dynamic>{
      'MaxResultCount': '1000',
    };
    if (batchHeaderId != null) query['BatchHeaderId'] = batchHeaderId.toString();
    return await _api.getList('/api/app/defect-histories', query: query);
  }

  // ---------------------------------------------------------------------------
  // 4. Induction Store & WIP Report Data
  // ---------------------------------------------------------------------------
  Future<PlexApiResult> fetchInductionProductionProgress({
    int? operationId,
    int? locatorId,
  }) async {
    final query = <String, dynamic>{
      'MaxResultCount': '1000',
    };
    if (operationId != null) query['OperationId'] = operationId.toString();
    if (locatorId != null) query['LocatorId'] = locatorId.toString();

    return await _fetchProductionProgressList(query);
  }

  Future<PlexApiResult> fetchWipTransactions() async {
    return await _api.getList('/api/app/w-iPTransactions?MaxResultCount=1000');
  }

  // ---------------------------------------------------------------------------
  // 5. Trays & Trolleys Report Data
  // ---------------------------------------------------------------------------
  Future<PlexApiResult> fetchTrayDetails({
    int? trayType, // 1 = Tray, 2 = Trolley
    bool? active,
    String? trayCode,
  }) async {
    final query = <String, dynamic>{
      'MaxResultCount': '1000',
    };
    if (trayType != null) query['TrayType'] = trayType.toString();
    if (active != null) query['Active'] = active.toString();
    if (trayCode != null && trayCode.isNotEmpty) query['TrayCode'] = trayCode;

    final result = await _api.getList('/api/app/tray-details', query: query);
    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = rawData.map((item) {
        return TrayDetail.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      dev.log("ReportsRepo fetchTrayDetails error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  // ---------------------------------------------------------------------------
  // Shared Lookups
  // ---------------------------------------------------------------------------
  Future<PlexApiResult> fetchMachines() async {
    final result = await _api.getList('/api/app/resources?MaxResultCount=1000');
    if (!result.success || result.data == null) return result;
    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = rawData.map((item) => MachineModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchShifts() async {
    final result = await _api.getList('/api/app/shifts?MaxResultCount=1000');
    if (!result.success || result.data == null) return result;
    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final list = rawData.map((item) => Shift.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchOperations() async {
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

  Future<PlexApiResult> fetchProductionProgressGeneric(Map<String, dynamic> query) async {
    return await _fetchProductionProgressList(query);
  }

  // ---------------------------------------------------------------------------
  // Internal Helper
  // ---------------------------------------------------------------------------
  Future<PlexApiResult> _fetchProductionProgressList(Map<String, dynamic> query) async {
    final Map<String, dynamic> finalQuery = {
      'MaxResultCount': '1000',
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
          dev.log("ReportsRepo parsing error on production progress: $e");
        }
      }
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }
}
