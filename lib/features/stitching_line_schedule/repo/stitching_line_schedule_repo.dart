import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/stitching_line_schedule/model/stitching_line_schedule_model.dart';
import 'package:flutter/foundation.dart';

class StitchingLineScheduleRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchStitchingLineSchedules() async {
    final result = await _api.getList('/api/app/po-styles', query: {
      'MaxResultCount': '1000',
    });
    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final List<StitchingLineScheduleItem> list = [];
      for (var i = 0; i < rawData.length; i++) {
        try {
          final item = Map<String, dynamic>.from(rawData[i] as Map);
          list.add(StitchingLineScheduleItem.fromJson(item));
        } catch (e) {
          return PlexApiResult(false, 500, 'Parse error at index $i: $e', null);
        }
      }
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      debugPrint("❌ StitchingLineScheduleRepo fetchStitchingLineSchedules Parse Error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchCostCenterLines() async {
    final result = await _api.getList('/api/app/cost-center-lines', query: {
      'MaxResultCount': '1000',
    });
    if (!result.success || result.data == null) return result;

    try {
      final List rawData = result.data is Map ? (result.data['items'] ?? []) : result.data;
      final List<CostCenterLine> list = [];
      for (var i = 0; i < rawData.length; i++) {
        try {
          final item = Map<String, dynamic>.from(rawData[i] as Map);
          if (item.containsKey('costCenterLine') && item['costCenterLine'] != null) {
            final lineData = Map<String, dynamic>.from(item['costCenterLine'] as Map);
            list.add(CostCenterLine.fromJson(lineData));
          }
        } catch (e) {
          return PlexApiResult(false, 500, 'Parse error at index $i: $e', null);
        }
      }
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      debugPrint("❌ StitchingLineScheduleRepo CostCenterLines Parse Error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> updateStitchingLineSchedule(int id, Map<String, dynamic> data) async {
    return await _api.put('/api/app/po-styles/$id', body: data);
  }

  Future<PlexApiResult> fetchSewingMappings({required String po}) async {
    final encodedPo = Uri.encodeComponent(po);
    final result = await _api.getList('/api/app/sewing-mappings?po=$encodedPo&MaxResultCount=1000');
    return result;
  }

  Future<PlexApiResult> updateSewingMapping(int id, Map<String, dynamic> data) async {
    return await _api.put('/api/app/sewing-mappings/$id', body: data);
  }
}
