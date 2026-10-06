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
  // 1. Work Order Report Data
  // ---------------------------------------------------------------------------
  Future<PlexApiResult> fetchWorkOrderHeaders() async {
    final result = await _api.getList('/api/app/work-order-headers?MaxResultCount=1000');
    if (!result.success || result.data == null) {
      // Fallback endpoint if headers path is singular
      final fallback = await _api.getList('/api/app/work-orders?MaxResultCount=1000');
      if (fallback.success && fallback.data != null) return _parseWorkOrderHeaders(fallback.data);
      return result;
    }
    return _parseWorkOrderHeaders(result.data);
  }

  /// Fetches the Work Order Status PDF Report binary data
  Future<PlexApiResult> fetchWorkOrderPdf(int workOrderHeaderId) async {
    return await _api.getBytes('/api/app/reports/work-order-status-report-pdf/$workOrderHeaderId');
  }

  /// Fetches the Batch Detail PDF Report binary data
  Future<PlexApiResult> fetchBatchPdf(int batchHeaderId) async {
    return await _api.getBytes('/api/app/reports/batch-detail-report-pdf/$batchHeaderId');
  }

  PlexApiResult _parseWorkOrderHeaders(dynamic raw) {
    try {
      final List rawData = raw is Map ? (raw['items'] ?? []) : (raw is List ? raw : []);
      final list = rawData.map((item) {
        return WorkOrderHeader.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      dev.log("ReportsRepo _parseWorkOrderHeaders error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchWorkOrderLines({
    int? workOrderHeaderId,
    int? workOrderLineId,
    int? batchHeaderId,
  }) async {
    final query = <String, dynamic>{
      'MaxResultCount': '1000',
    };
    if (workOrderHeaderId != null) query['WorkOrderHeaderId'] = workOrderHeaderId.toString();
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
  // 2. Batch Report Data
  // ---------------------------------------------------------------------------
  Future<PlexApiResult> fetchBatchHeaders({
    String? batchCode,
    bool? lockFlag,
    String? planDate,
  }) async {
    final query = <String, dynamic>{
      'MaxResultCount': '1000',
      'maxResultCount': '1000',
    };
    if (batchCode != null && batchCode.isNotEmpty) {
      query['BatchHeaderCode'] = batchCode;
      query['batchHeaderCode'] = batchCode;
    }
    if (lockFlag != null) {
      query['LockFlag'] = lockFlag.toString();
      query['lockFlag'] = lockFlag.toString();
    }
    if (planDate != null && planDate.isNotEmpty) {
      query['PlanDate'] = planDate;
      query['planDate'] = planDate;
    }

    final result = await _api.getList('/api/app/batch-headers', query: query);
    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : (result.data is List ? result.data : []);
      final list = <LotHeaderModel>[];
      for (final item in rawData) {
        try {
          if (item is Map) {
            final model = LotHeaderModel.fromJson(Map<String, dynamic>.from(item));
            if (model.id != null && model.id! > 0) {
              list.add(model);
            }
          }
        } catch (itemErr) {
          print("Error parsing single LotHeaderModel: $itemErr");
        }
      }
      print("ReportsRepo fetchBatchHeaders parsed ${list.length} / ${rawData.length} batches");
      return PlexApiResult(true, 200, "Success", list);
    } catch (e, stack) {
      print("ReportsRepo fetchBatchHeaders error: $e\n$stack");
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
  // 3. Induction Store & WIP Report Data
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
  // 4. Trays & Trolleys Report Data
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
  Future<PlexApiResult> fetchCustomers() async {
    return await _api.getList('/api/app/customers?MaxResultCount=1000');
  }

  Future<PlexApiResult> fetchBrands() async {
    return await _api.getList('/api/app/brands?MaxResultCount=1000');
  }

  Future<PlexApiResult> fetchStyles() async {
    return await _api.getList('/api/app/styles?MaxResultCount=1000');
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
