import 'package:flutter/foundation.dart';
import 'package:active_wear_scanning/features/tray_tracking/model/tray_tracking_state.dart';
import 'package:active_wear_scanning/features/tray_tracking/model/tray_tracking_model.dart';
import 'package:active_wear_scanning/features/tray_tracking/repo/tray_tracking_repo.dart';

class TrayTrackingController extends ChangeNotifier {
  final _trayTrackingRepo = TrayTrackingRepo();

  TrayTrackingState _state = const TrayTrackingState();
  TrayTrackingState get state => _state;

  Future<String?> onTrayScanned(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return "Please enter tray code";

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    final res = await _trayTrackingRepo.fetchTrayDetailByCode(cleanCode);

    if (res.success && res.data != null) {
      final data = res.data is Map ? res.data as Map : {};
      final trayMap = data['trayDetail'] ?? data;
      final trayDetail = TrayTrackingDetailModel.fromJson(Map<String, dynamic>.from(trayMap));

      String? batchCode;
      String? color;
      final batchMap = data['batchHeader'];
      if (batchMap is Map) {
        batchCode = batchMap['batchHeaderCode'];
        color = batchMap['colorDescription'];
      }

      final locatorName = data['locator']?['description'];
      final machineName = data['resource']?['resourceCode'] ?? data['resource']?['brand'] ?? data['resource']?['description'];
      final itemDescription = data['knitItem']?['description'] ?? trayMap['description'];
      final workOrderDescription = data['workOrderHeader']?['description'];

      _state = _state.copyWith(
        isLoading: false,
        trayDetail: trayDetail,
        batchCode: batchCode,
        color: color,
        locatorName: locatorName,
        machineName: machineName,
        itemDescription: itemDescription,
        workOrderDescription: workOrderDescription,
      );
      notifyListeners();
      return null;
    } else {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: res.message,
        clearData: true,
      );
      notifyListeners();
      return res.message;
    }
  }
}
