import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import 'package:active_wear_scanning/features/carton_packing/model/carton_packing_scanned_item.dart';
import 'package:flutter/cupertino.dart';

class CartonPackingRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchInitialData() async {
    try {
      // Placeholder for future carton packing api endpoint
      return PlexApiResult(true, 200, "Success", null);
    } catch (e) {
      debugPrint("❌ Carton Packing Repo Error: $e");
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

      final item = PackingInstructionResponseModel.fromJson(
        Map<String, dynamic>.from(rawData.first as Map),
      );

      return PlexApiResult(true, 200, "Success", item);
    } catch (e) {
      debugPrint("❌ Repo Parse Error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchSaleOrderById(int id) async {
    try {
      final result = await _api.getObject('/api/app/sale-order-msts/$id');
      if (!result.success || result.data == null) return result;

      final item = SaleOrderModel.fromJson(Map<String, dynamic>.from(result.data as Map));
      return PlexApiResult(true, 200, "Success", item);
    } catch (e) {
      debugPrint("❌ Sale Order Parse Error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchCustomerById(int id) async {
    try {
      final result = await _api.getObject('/api/app/customers/$id');
      if (!result.success || result.data == null) return result;

      final item = CustomerModel.fromJson(Map<String, dynamic>.from(result.data as Map));
      return PlexApiResult(true, 200, "Success", item);
    } catch (e) {
      debugPrint("❌ Customer Parse Error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  Future<PlexApiResult> fetchPackingInstructionLines(int headerId) async {
    try {
      final result = await _api.getList(
        '/api/app/packing-instruction-lines',
        query: {
          'PackingInstructionHeaderId': headerId.toString(),
        },
      );

      if (!result.success || result.data == null) return result;

      final List rawData = result.data is Map ? result.data['items'] : result.data;
      final items = rawData
          .map((e) => PackingInstructionLineResponse.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      return PlexApiResult(true, 200, "Success", items);
    } catch (e) {
      debugPrint("❌ Packing Instruction Lines Parse Error: $e");
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }
}


