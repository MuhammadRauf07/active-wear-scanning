import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/utils/barcode_buffer_parser.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/empty_scan_state.dart';
import 'package:active_wear_scanning/core/widgets/tray_table_header.dart';
import 'package:active_wear_scanning/features/gbs/presentation/widgets/gbs_tray_row.dart';
import 'package:active_wear_scanning/features/gbs/model/gbs_scanned_tray.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/gbs/repo/gbs_receiving_repo.dart';
import 'package:flutter/material.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import '../../../core/widgets/scanner_always_open.dart';

class GBSReceivingScreen extends StatefulWidget {
  const GBSReceivingScreen({super.key});

  @override
  State<GBSReceivingScreen> createState() => _GBSReceivingScreenState();
}

class _GBSReceivingScreenState extends State<GBSReceivingScreen> {
  final List<GBSScannedTray> _scannedTrays = [];
  final _trayScanningRepo = fromPlex<GBSReceivingRepo>();
  List<ProductionProgressResponseModel> availableTrayForGbs = [];
  String _receivingType = 'gbs';
  final Set<int> _selectedProgressIds = {};

  static final _tableHeaderStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700);

  // Centralized Bluetooth Scanner Support
  final _barcodeParser = BarcodeBufferParser();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onInitialDataFetch();
      }
    });
    _fetchLatestTraysSilently();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    return _barcodeParser.handleKey(event, _processBluetoothScan);
  }

  Future<void> _processBluetoothScan(String scannedCode) async {
    final error = await _validateTrayForReceiving(scannedCode);
    if (error != null && mounted) {
      _showError(error);
    }
  }

  Future<void> _onInitialDataFetch() async {
    if (mounted) AppLoader.show(context);
    await _fetchLatestTraysSilently();
    if (mounted) AppLoader.hide(context);
  }

  Future<void> _fetchLatestTraysSilently() async {
    final apiResult = await _trayScanningRepo.getProductionProgress(
      params: {
        'LocatorId': '2',
        'MaxResultCount': '1000',
      },
    );
    if (mounted && apiResult.success && apiResult.data != null) {
      final List<ProductionProgressResponseModel> allTrays = apiResult.data as List<ProductionProgressResponseModel>;
      
      // 🕵️ DEBUG LOGGING
      debugPrint("🔍 RAW API SUCCESS. Total items from server: ${allTrays.length}");
      for (var tray in allTrays) {
        debugPrint("📋 Tray Code: ${tray.primaryTrayModel.trayCode} | Locator: ${tray.productionProgress.locatorId} | Type: ${tray.productionProgress.transactionType} | GBS: ${tray.productionProgress.gbsFlag}");
      }

      setState(() {
        // Local filtering: Any tray at Locator 2 is receivable
        availableTrayForGbs = allTrays.toList();
        
        debugPrint("🔄 GBS Data Refreshed: ${availableTrayForGbs.length} matching trays found.");
      });
    } else {
      debugPrint("❌ API FAIL OR NULL: ${apiResult.message}");
    }
  }

  Future<void> _onScanTray() async {
    await _fetchLatestTraysSilently();
    if (!mounted) return;

    await ScannerAlwaysOpen.show(
      context,
      title: 'GBS Tray Receiving',
      onResult: (scannedCode) {
        return _validateTrayForReceiving(scannedCode);
      },
      scannedItemsBuilder: (context) {
        return StatefulBuilder(
          builder: (context, setSubState) {
            if (_scannedTrays.isEmpty) {
              return const Center(
                child: Text(
                  'No trays scanned yet',
                  style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFB0BEC5),
                  width: 1.5,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  const TrayTableHeader(actionColumnWidth: 44),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _scannedTrays.length,
                      itemBuilder: (context, index) {
                        final reversedIndex = _scannedTrays.length - 1 - index;
                        return GBSTrayRow(
                          index: reversedIndex,
                          tray: _scannedTrays[reversedIndex],
                          onRemove: () {
                            setState(() {
                              _scannedTrays.removeAt(reversedIndex);
                            });
                            setSubState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    setState(() {});
  }

  Future<String?> _validateTrayForReceiving(String scannedCode) async {

    final code = scannedCode.trim().toLowerCase();
    if (code.isEmpty) return 'Invalid tray code';

    final alreadyScanned = _scannedTrays.any((t) => t.trayCode.trim().toLowerCase() == code);
    if (alreadyScanned) return 'Already assigned';

    // 2. Flexible Matching Logic
    final match = _filteredTrays.where((t) {
      final String tCode = (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase();
      final String pCode = (t.productionProgress.progressCode ?? '').trim().toLowerCase();

      if (tCode == code || pCode == code) return true;

      String cleanTCode = tCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').replaceAll(RegExp(r'^0+'), '');
      String cleanScanned = code.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').replaceAll(RegExp(r'^0+'), '');

      if (cleanTCode.isNotEmpty && cleanTCode == cleanScanned) return true;

      if (tCode.endsWith(code) && code.length > 3) return true;

      return false;
    }).firstOrNull;

    if (match == null) {
      debugPrint("❌ No Match! Scanned: '$code' | memory mein: ${availableTrayForGbs.map((e) => e.primaryTrayModel.trayCode).toList()}");
      return 'Tray not available';
    }

    if ((match.primaryTrayModel.trayType ?? 0) != 1) {
      return 'Invalid tray type.';
    }

    int targetItemId = match.productionProgress.processedItemId ?? match.item.id;
    String colorDesc = match.item.colorDescription ?? '';
    String sizeDesc = match.item.sizeDescription ?? '';
    double perGarmentTube = match.item.perGarmentTube;

    if (targetItemId > 0) {
      if (mounted) AppLoader.show(context, message: "Fetching item details...");
      final itemRes = await _trayScanningRepo.fetchItemDef(targetItemId);
      if (mounted) AppLoader.hide(context);
      
      if (itemRes.success && itemRes.data != null) {
        final itemData = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
        if (itemData['colorDescription'] != null) colorDesc = itemData['colorDescription'];
        if (itemData['sizeDescription'] != null) sizeDesc = itemData['sizeDescription'];
        if (itemData['perGarmentTube'] != null) perGarmentTube = (itemData['perGarmentTube'] as num).toDouble();
      }
    }

    setState(() {
      _scannedTrays.add(
        GBSScannedTray(
          itemDescription: match.item.description ?? '-',
          componentDescription: match.item.componentDescription ?? '',
          sizeDescription: sizeDesc,
          colorDescription: colorDesc,
          workOrderCode: match.workOrderHeader.workOrderCode ?? '-',
          primaryQuantity: match.productionProgress.primaryQuantity?.toStringAsFixed(0) ?? '0',
          pieceWeight: match.item.pieceWeight ?? 0.0,
          perGarmentTube: perGarmentTube,
          trayCode: scannedCode.trim(),
          trayUpdateId: match.primaryTrayModel.id,
          trayConcurrencyStamp: match.primaryTrayModel.concurrencyStamp,
        ),
      );
    });
    HapticFeedbackHelper.scanSuccess();
    return null;
  }

  bool get _isSaveEnabled {
    if (_receivingType == 'gbs') {
      return _scannedTrays.isNotEmpty;
    } else {
      return _selectedProgressIds.isNotEmpty;
    }
  }

  bool get _isAllSelected {
    final filtered = _filteredTrays;
    if (filtered.isEmpty) return false;
    return filtered.every((t) => _selectedProgressIds.contains(t.productionProgress.id));
  }

  List<ProductionProgressResponseModel> get _filteredTrays {
    if (_receivingType == 'sample') {
      return availableTrayForGbs.where((t) => t.productionProgress.productNature == 1).toList();
    } else if (_receivingType == 'c_grade') {
      return availableTrayForGbs.where((t) => t.productionProgress.productGrade == 2).toList();
    } else {
      return availableTrayForGbs.where((t) => t.productionProgress.productNature != 1 && t.productionProgress.productGrade != 2).toList();
    }
  }

  Future<void> saveSampleOrCGradeProgress() async {
    if (_selectedProgressIds.isEmpty) return;

    AppLoader.show(context, message: 'Saving Changes...');
    bool isAllSuccess = true;

    try {
      final List<int> selectedIds = _selectedProgressIds.toList();
      final int targetLocatorId = _receivingType == 'sample' ? 16 : 17;
      final String subOpProgress = _receivingType == 'sample' ? "Sample Received" : "C Grade Received";
      final String subOpWip = _receivingType == 'sample' ? "Sample Receiving" : "C Grade Receiving";

      for (final id in selectedIds) {
        final currentData = availableTrayForGbs.where((t) => t.productionProgress.id == id).firstOrNull;
        if (currentData == null) continue;

        // WIP Transaction Payload
        Map<String, dynamic> wipPayload = {
          "subOperation": subOpWip,
          "transactionDate": DateTime.now().toIso8601String(),
          "transactionType": 6,
          "uom": currentData.workOrderLine.uom ?? 0,
          "operatorDescription": "system",
          "primaryQuantity": currentData.productionProgress.primaryQuantity ?? 0,
          "secondaryQuantity": currentData.productionProgress.secondaryQuantity ?? 0,
          "primaryUOM": currentData.productionProgress.primaryUOM ?? 0,
          "secondaryUOM": currentData.productionProgress.secondaryUOM ?? 0,
          "code": currentData.item.code ?? "",
          "productGrade": currentData.productionProgress.productGrade ?? 0,
          "productNature": currentData.productionProgress.productNature ?? 0,
          "progressId": currentData.productionProgress.id,
          "operationId": currentData.operation.id,
          "workOrderHeaderId": currentData.workOrderHeader.id,
          "workOrderLineId": currentData.workOrderLine.id,
          "itemId": currentData.item.id,
          "shiftId": currentData.shift.id,
          "machineId": currentData.machineModel.id,
          "planHeaderId": currentData.planHeader?.id,
          "locatorId": targetLocatorId,
          "processedItemId": currentData.processedItem?.id ?? currentData.item.id,
        };

        await _trayScanningRepo.postWipTransactions(wipPayload);

        Map<String, dynamic> updateProductionEntry = {
          "id": currentData.productionProgress.id,
          "concurrencyStamp": currentData.productionProgress.concurrencyStamp,
          "subOperation": subOpProgress,
          "date": DateTime.now().toIso8601String(),
          "transactionType": 6,
          "operatorDescription": "system",
          "primaryQuantity": currentData.productionProgress.primaryQuantity,
          "primaryUOM": currentData.productionProgress.primaryUOM,
          "secondaryQuantity": currentData.productionProgress.secondaryQuantity,
          "secondaryUOM": currentData.productionProgress.secondaryUOM,
          "wipStatus": currentData.productionProgress.wipStatus ?? 0,
          "gbsFlag": true,
          "pbsFlag": false,
          "progressCode": currentData.productionProgress.progressCode,
          "productGrade": currentData.productionProgress.productGrade,
          "productNature": currentData.productionProgress.productNature,
          "operationId": currentData.productionProgress.operationId,
          "workOrderHeaderId": currentData.productionProgress.workOrderHeaderId,
          "workOrderLineId": currentData.productionProgress.workOrderLineId,
          "itemId": currentData.productionProgress.itemId,
          "shiftId": currentData.productionProgress.shiftId,
          "machineId": currentData.productionProgress.machineId,
          "planHeaderId": currentData.productionProgress.planHeaderId,
          "locatorId": targetLocatorId,
          "batchHeaderId": currentData.productionProgress.batchHeaderId,
          "batchLineId": currentData.productionProgress.batchLinesId,
          "remarks": currentData.productionProgress.remarks,
        };
        updateProductionEntry.remove("batchLinesId");

        if (currentData.productionProgress.id != null) {
          final res = await _trayScanningRepo.updateProductionProgress(
            currentData.productionProgress.id!,
            updateProductionEntry,
          );
          if (!res.success) {
            throw Exception(res.message);
          }
        }
      }
    } catch (e) {
      isAllSuccess = false;
      debugPrint("❌ GBS Save Error: $e");
    } finally {
      AppLoader.hide(context);
      if (mounted) {
        if (isAllSuccess) {
          HapticFeedbackHelper.scanSuccess();
          AppSnackBar.showSuccess(context, message: 'Saved successfully');
          setState(() {
            _selectedProgressIds.clear();
          });
          _fetchLatestTraysSilently();
        } else {
          _showError("Failed to save some items. Please check logs.");
        }
      }
    }
  }

  /// MAIN SAVE LOGIC (Fixed Black Screen & Added ProcessedItem)
  Future<void> saveWipTransactionsAndUpdateTray() async {
    if (_scannedTrays.isEmpty) return;

    AppLoader.show(context);
    bool isAllSuccess = true;

    try {
      for (int i = 0; i < _scannedTrays.length; i++) {
        final currentTrayData = availableTrayForGbs.where(
                (t) => t.productionProgress.primaryTrayId == _scannedTrays[i].trayUpdateId
        ).firstOrNull;

        if (currentTrayData == null) continue;

        // WIP Transaction Payload
        Map<String, dynamic> wipPayload = {
          "subOperation": "GBS Receiving",
          "transactionDate": DateTime.now().toIso8601String(),
          "transactionType": 6,
          "uom": currentTrayData.workOrderLine.uom ?? 0,
          "operatorDescription": "system",
          "primaryQuantity": currentTrayData.productionProgress.primaryQuantity ?? 0,
          "secondaryQuantity": currentTrayData.productionProgress.secondaryQuantity ?? 0,
          "primaryUOM": currentTrayData.productionProgress.primaryUOM ?? 0,
          "secondaryUOM": currentTrayData.productionProgress.secondaryUOM ?? 0,
          "code": currentTrayData.item.code ?? "",
          "productGrade": currentTrayData.productionProgress.productGrade ?? 0,
          "productNature": currentTrayData.productionProgress.productNature ?? 0,
          "progressId": currentTrayData.productionProgress.id,
          "operationId": currentTrayData.operation.id,
          "workOrderHeaderId": currentTrayData.workOrderHeader.id,
          "workOrderLineId": currentTrayData.workOrderLine.id,
          "itemId": currentTrayData.item.id,
          "shiftId": currentTrayData.shift.id,
          "primaryTrayId": currentTrayData.primaryTrayModel.id,
          "machineId": currentTrayData.machineModel.id,
          "planHeaderId": currentTrayData.planHeader?.id,
          "locatorId": 3,
          "processedItemId": currentTrayData.processedItem?.id ?? currentTrayData.item.id,
        };

        await _trayScanningRepo.postWipTransactions(wipPayload);
        Map<String, dynamic> updateProductionEntry = {
          "id": currentTrayData.productionProgress.id,
          "concurrencyStamp": currentTrayData.productionProgress.concurrencyStamp,
          "subOperation": "GBS Received",
          "date": DateTime.now().toIso8601String(),
          "transactionType": 6, // Formal Handover
          "operatorDescription": "system",
          "primaryQuantity": currentTrayData.productionProgress.primaryQuantity,
          "primaryUOM": currentTrayData.productionProgress.primaryUOM,
          "secondaryQuantity": currentTrayData.productionProgress.secondaryQuantity,
          "secondaryUOM": currentTrayData.productionProgress.secondaryUOM,
          "wipStatus": currentTrayData.productionProgress.wipStatus ?? 0,
          "gbsFlag": true, // Requirement: 1 (true)
          "pbsFlag": false, // Requirement: false
          "progressCode": currentTrayData.productionProgress.progressCode,
          "productGrade": currentTrayData.productionProgress.productGrade,
          "productNature": currentTrayData.productionProgress.productNature,
          "operationId": currentTrayData.productionProgress.operationId,
          "workOrderHeaderId": currentTrayData.productionProgress.workOrderHeaderId,
          "workOrderLineId": currentTrayData.productionProgress.workOrderLineId,
          "itemId": currentTrayData.productionProgress.itemId,
          "shiftId": currentTrayData.productionProgress.shiftId,
          "primaryTrayId": currentTrayData.productionProgress.primaryTrayId,
          "secondaryTrayId": currentTrayData.productionProgress.secondaryTrayId,
          "machineId": currentTrayData.productionProgress.machineId,
          "planHeaderId": currentTrayData.productionProgress.planHeaderId,
          "locatorId": 3, // Move to Batching Floor
          "batchHeaderId": currentTrayData.productionProgress.batchHeaderId,
          "batchLineId": currentTrayData.productionProgress.batchLinesId,
        };
        updateProductionEntry.remove("batchLinesId");

        if (currentTrayData.productionProgress.id != null) {
          await _trayScanningRepo.updateProductionProgress(
            currentTrayData.productionProgress.id!,
            updateProductionEntry,
          );
        }

        // Tray Detail Update
        if (_scannedTrays[i].trayUpdateId != null) {
          final getTrayRes = await _trayScanningRepo.fetchTrayDetailById(_scannedTrays[i].trayUpdateId!);
          if (getTrayRes.success && getTrayRes.data != null) {
            Map<String, dynamic> rawTrayPayload = Map<String, dynamic>.from(
                getTrayRes.data.containsKey('trayDetail') ? getTrayRes.data['trayDetail'] : getTrayRes.data
            );
            rawTrayPayload["locatorId"] = 3;
            rawTrayPayload.removeWhere((key, value) => ["creatorId", "creationTime", "lastModifierId", "lastModificationTime"].contains(key));
            await _trayScanningRepo.updateTrayDetails(rawTrayPayload, _scannedTrays[i].trayUpdateId!);
          }
        }
      }
    } catch (e) {
      isAllSuccess = false;
      debugPrint("❌ GBS Save Error: $e");
    } finally {
      AppLoader.hide(context);
      if (mounted) {
        if (isAllSuccess) {
          HapticFeedbackHelper.scanSuccess();
          AppSnackBar.showSuccess(context, message: 'Saved successfully');
          // Delay to allow SnackBar and Loader cleanup
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        } else {
          _showError("Failed to save some trays. Please check logs.");
        }
      }
    }
  }

  void _onRemoveTray(int index) {
    setState(() => _scannedTrays.removeAt(index));
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedbackHelper.scanError();
    AppSnackBar.showError(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Lightest Industrial Grey
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _buildPremiumHeader(context),
              _buildReceivingTypeRadioButtons(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: _receivingType == 'gbs'
                      ? _buildScannedTraysSection()
                      : _buildSampleCGradeTableSection(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const CustomBackButton(),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GBS Receiving',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'Receive Knitting Production in GBS',
                    style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: !_isSaveEnabled
                  ? null
                  : () {
                      HapticFeedbackHelper.buttonClick();
                      if (_receivingType == 'gbs') {
                        saveWipTransactionsAndUpdateTray();
                      } else {
                        saveSampleOrCGradeProgress();
                      }
                    },
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE CHANGES'),
              style: AppTheme.saveButtonStyle(isEnabled: _isSaveEnabled),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedTraysSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB0BEC5),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Toolbar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RECEIVED TRAYS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5),
                    ),
                    Text(
                      '${_scannedTrays.length} Tray(s) Received',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF78909C)),
                    ),
                  ],
                ),
                SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedbackHelper.buttonClick();
                      _onScanTray();
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('SCAN TRAY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // ── Fixed Header ─────────────────────────────────────────────
          const TrayTableHeader(actionColumnWidth: 44),

          // ── Scrollable Values ────────────────────────────────────────
          Expanded(
            child: _scannedTrays.isEmpty 
                ? const EmptyScanState(hasBorder: false)
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _scannedTrays.length,
                    itemBuilder: (context, index) {
                      final reversedIndex = _scannedTrays.length - 1 - index;
                      return GBSTrayRow(
                        index: reversedIndex,
                        tray: _scannedTrays[reversedIndex],
                        onRemove: () => _onRemoveTray(reversedIndex),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _handleReceivingTypeChange(String newType) {
    if (_receivingType == newType) return;

    if (_receivingType == 'gbs' && _scannedTrays.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Text(
                  'Confirm Switch',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Switching receiving nature will dismiss all scanned trays. Do you want to proceed?',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _receivingType = newType;
                    _scannedTrays.clear();
                    _selectedProgressIds.clear();
                  });
                },
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      setState(() {
        _receivingType = newType;
        _selectedProgressIds.clear();
      });
    }
  }

  Widget _buildReceivingTypeRadioButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECEIVING NATURE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF546E7A),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildRadioOption('GOOD PRODUCTION RECEIVING', 'gbs'),
              ),
              Expanded(
                child: _buildRadioOption('SAMPLE RECEIVING', 'sample'),
              ),
              Expanded(
                child: _buildRadioOption('C-GRADE RECEIVING', 'c_grade'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String label, String value) {
    final isSelected = _receivingType == value;
    Color optionColor;
    if (value == 'sample') {
      optionColor = const Color(0xFFF59E0B); // Amber/Yellow
    } else if (value == 'c_grade') {
      optionColor = const Color(0xFFEF4444); // Red
    } else {
      optionColor = const Color(0xFF0D47A1); // Primary Blue
    }

    return InkWell(
      onTap: () {
        HapticFeedbackHelper.buttonClick();
        _handleReceivingTypeChange(value);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: _receivingType,
            activeColor: optionColor,
            fillColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return optionColor;
              }
              return Colors.grey.shade400;
            }),
            onChanged: (val) {
              if (val != null) {
                HapticFeedbackHelper.buttonClick();
                _handleReceivingTypeChange(val);
              }
            },
          ),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? optionColor : const Color(0xFF37474F),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleCGradeTableSection() {
    final filtered = _filteredTrays;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB0BEC5),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _receivingType == 'sample' ? 'SAMPLE PENDING ENTRIES' : 'C GRADE PENDING ENTRIES',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5),
                    ),
                    Text(
                      '${filtered.length} Pending, ${_selectedProgressIds.length} Selected',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF78909C)),
                    ),
                  ],
                ),
                SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedbackHelper.buttonClick();
                      _fetchLatestTraysSilently();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('REFRESH', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          _buildSampleCGradeTableHeader(),

          Expanded(
            child: filtered.isEmpty
                ? const EmptyScanState(hasBorder: false)
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildSampleCGradeRow(filtered[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleCGradeTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: _isAllSelected,
              activeColor: const Color(0xFF0D47A1),
              onChanged: (val) {
                HapticFeedbackHelper.buttonClick();
                setState(() {
                  if (val == true) {
                    _selectedProgressIds.addAll(
                      _filteredTrays.map((t) => t.productionProgress.id).whereType<int>(),
                    );
                  } else {
                    _selectedProgressIds.clear();
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: Text('Work Order', style: _tableHeaderStyle)),
          Expanded(flex: 4, child: Text('Item / Date', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('Tubes', textAlign: TextAlign.center, style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('Pcs', textAlign: TextAlign.center, style: _tableHeaderStyle)),
          Expanded(flex: 3, child: Text('Remarks', style: _tableHeaderStyle)),
        ],
      ),
    );
  }

  Widget _buildSampleCGradeRow(ProductionProgressResponseModel item, int index) {
    final pp = item.productionProgress;
    final isSelected = _selectedProgressIds.contains(pp.id);
    
    String dateStr = '';
    if (pp.date != null) {
      dateStr = "${pp.date!.year}-${pp.date!.month.toString().padLeft(2, '0')}-${pp.date!.day.toString().padLeft(2, '0')} ${pp.date!.hour.toString().padLeft(2, '0')}:${pp.date!.minute.toString().padLeft(2, '0')}";
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: isSelected,
              activeColor: const Color(0xFF0D47A1),
              onChanged: (val) {
                HapticFeedbackHelper.buttonClick();
                setState(() {
                  if (val == true) {
                    if (pp.id != null) _selectedProgressIds.add(pp.id!);
                  } else {
                    _selectedProgressIds.remove(pp.id);
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              item.workOrderHeader.workOrderCode ?? '-',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238)),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.item.description ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1B64A3)),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              pp.primaryQuantity?.toStringAsFixed(0) ?? '0',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              pp.secondaryQuantity?.toStringAsFixed(0) ?? '0',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238)),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              pp.remarks ?? '-',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10, 
                fontStyle: pp.remarks != null ? FontStyle.normal : FontStyle.italic, 
                color: pp.remarks != null ? const Color(0xFF263238) : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}