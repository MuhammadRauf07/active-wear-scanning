import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/api/services/api_service.dart';
import '../model/wip_model.dart';

class WipRepo {
  final ApiService _api = ApiService();

  Future<PlexApiResult> fetchLocators() async {
    final result = await _api.getList('/api/app/locators?MaxResultCount=1000');
    
    if (!result.success || result.data == null) return result;

    try {
      final List<dynamic> data = result.data as List;
      final list = data.map((item) => LocatorResponse.fromJson(item as Map<String, dynamic>)).toList();
      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }

  // Generic method to fetch WIP data. 
  // Depending on its department, the data structure might vary, but for UI purposes 
  // we'll fetch them as WIPEntry.
  Future<PlexApiResult> fetchWipDetails(int locatorId) async {
    // Note: Assuming there is a WIP endpoint or using production-progress as proxy
    // For now, using production-progress since it's the standard for 'current stock' in stages
    final result = await _api.getList('/api/app/production-progresses', query: {
      'LocatorId': locatorId.toString(),
      'MaxResultCount': '1000',
      'logicalWH': 'FLOOR'
    });
    
    if (!result.success || result.data == null) return result;

    try {
      final List<dynamic> data = result.data as List;
      // Map to WIPEntry format for the screen
      final list = data.map((item) {
        // Adapt from productionProgress structure if needed
        // This is a placeholder logic to transform raw API to WIP table columns
        return WIPEntry(
          workOrder: item['workOrderHeader']?['workOrderCode'] ?? '-',
          machine: item['machineModel']?['name'] ?? '-',
          batchNo: item['productionProgress']?['progressCode'] ?? '-',
          item: item['item']?['description'] ?? '-',
          traysCount: 1, // Usually one entry per tray in production-progress
          pcsCount: (item['productionProgress']?['primaryQuantity'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      return PlexApiResult(true, 200, "Success", list);
    } catch (e) {
      return PlexApiResult(false, 500, e.toString(), null);
    }
  }
}
