import 'package:flutter/foundation.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/knitting_production/repo/knitting_production_repo.dart';
import 'package:active_wear_scanning/features/processing/repo/processing_repo.dart';
import 'package:active_wear_scanning/features/unhold_trays/model/unhold_trays_state.dart';

class UnholdTraysController extends ChangeNotifier {
  final _knittingRepo = fromPlex<KnittingProductionRepo>();
  final _processingRepo = ProcessingRepo();

  UnholdTraysState _state = const UnholdTraysState();
  UnholdTraysState get state => _state;

  UnholdTraysController() {
    initData();
  }

  Future<void> initData() async {
    await fetchHeldTrays();
  }

  void changeOrigin(String origin) {
    if (_state.selectedOrigin == origin) return;
    _state = _state.copyWith(
      selectedOrigin: origin,
      scannedTrays: [],
    );
    notifyListeners();
    fetchHeldTrays();
  }

  void removeScannedTray(int index) {
    if (index < 0 || index >= _state.scannedTrays.length) return;
    final updated = List<ProductionProgressResponseModel>.from(_state.scannedTrays)..removeAt(index);
    _state = _state.copyWith(scannedTrays: updated);
    notifyListeners();
  }

  Future<void> fetchHeldTrays() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    final res = await _knittingRepo.fetchProductionProgress();
    if (res.success && res.data != null) {
      final allTrays = res.data as List<ProductionProgressResponseModel>;
      final heldList = allTrays.where((t) {
        if (t.productionProgress.holdFlag != true) return false;

        final opId = t.productionProgress.operationId;
        final opCode = t.operation.code.toUpperCase();
        final opName = t.operation.name.toUpperCase();
        final subOp = (t.productionProgress.subOperation ?? '').toLowerCase();

        if (_state.selectedOrigin == 'knitting') {
          return opId == 1 || opId == 6 || opCode == 'KNT' || opName == 'KNITTING' || subOp == 'knitting';
        } else {
          return opId == 2 || opCode == 'PBS' || t.productionProgress.batchHeaderId != null;
        }
      }).toList();

      _state = _state.copyWith(
        heldTrays: heldList,
        isLoading: false,
      );
    } else {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: res.message.isNotEmpty ? res.message : 'Failed to fetch held trays',
      );
    }
    notifyListeners();
  }

  Future<String?> validateAndAddBarcodeScan(String scannedCode) async {
    final code = scannedCode.trim().toLowerCase();
    if (code.isEmpty) return 'Invalid tray code';

    // 1. Check if tray is in heldTrays for the selected origin
    final match = _state.heldTrays.where((t) {
      final tCode = (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase();
      final pCode = (t.productionProgress.progressCode ?? '').trim().toLowerCase();
      return tCode == code || pCode == code;
    }).firstOrNull;

    if (match == null) {
      return 'Tray is not on HOLD under ${_state.selectedOrigin == "knitting" ? "Knitting Production" : "PBS"}';
    }

    // 2. Check if already scanned
    final alreadyScanned = _state.scannedTrays.any((t) => t.productionProgress.id == match.productionProgress.id);
    if (alreadyScanned) {
      return 'Tray ${match.primaryTrayModel.trayCode ?? code} is already scanned';
    }

    // 3. Add to scannedTrays
    final updated = List<ProductionProgressResponseModel>.from(_state.scannedTrays)..add(match);
    _state = _state.copyWith(scannedTrays: updated);
    notifyListeners();
    return null;
  }

  Future<bool> saveChanges() async {
    if (_state.scannedTrays.isEmpty) return false;

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final nowStr = DateTime.now().toIso8601String();
      for (final match in _state.scannedTrays) {
        final id = match.productionProgress.id;
        if (id == null) continue;

        final payload = match.productionProgress.toJson();
        payload['holdFlag'] = false;
        payload['unHoldDate'] = nowStr;
        payload.remove('id');
        payload.remove('progressCode');
        payload.remove('creationTime');
        payload.remove('creatorId');
        payload.remove('lastModificationTime');
        payload.remove('lastModifierId');

        final res = await _processingRepo.updateProductionProgress(id, payload);
        if (!res.success) {
          throw Exception('Failed to unhold tray ${match.primaryTrayModel.trayCode}: ${res.message}');
        }
      }

      _state = _state.copyWith(
        scannedTrays: [],
        isLoading: false,
      );
      notifyListeners();
      await fetchHeldTrays();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitUnhold() => saveChanges();
}
