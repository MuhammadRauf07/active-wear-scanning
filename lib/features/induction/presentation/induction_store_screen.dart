import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/utils/barcode_buffer_parser.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/empty_scan_state.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/features/gbs/model/gbs_scanned_tray.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/induction/model/induction_model.dart';
import 'package:active_wear_scanning/features/induction/repo/induction_repo.dart';
import 'package:active_wear_scanning/features/induction/presentation/widgets/induction_tray_row.dart';
import 'package:active_wear_scanning/features/induction/presentation/widgets/induction_tray_table_header.dart';
import 'package:flutter/material.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';

class InductionStoreScreen extends StatefulWidget {
  const InductionStoreScreen({super.key});

  @override
  State<InductionStoreScreen> createState() => _InductionStoreScreenState();
}

class _InductionStoreScreenState extends State<InductionStoreScreen> {
  final List<GBSScannedTray> _scannedTrays = [];
  final _inductionRepo = fromPlex<InductionRepo>();
  List<InductionModel> _availableTrays = [];

  static const _inputAndButtonHeight = 42.0;
  static final _labelStyle = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );
  static final _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );

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
    final code = scannedCode.trim();
    if (code.isEmpty) return;

    final error = await _validateTrayForInduction(code);
    if (error != null && mounted) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: error);
    } else {
      setState(() {});
    }
  }

  Future<void> _onInitialDataFetch() async {
    AppLoader.show(context);
    await _fetchAvailableTrays();
    AppLoader.hide(context);
  }

  Future<void> _fetchAvailableTrays() async {
    final res = await _inductionRepo.getProductionProgress();
    if (mounted && res.success && res.data != null) {
      setState(() {
        final allTrays = res.data as List<InductionModel>;
        _availableTrays = allTrays.where((t) => t.productionProgress.locatorId != 11).toList();
      });
      debugPrint(
        "🔍 Induction: Found ${_availableTrays.length} matching trays.",
      );
    }
  }

  Future<void> _onScanTray() async {
    await _fetchAvailableTrays();
    if (!mounted) return;

    await ScannerAlwaysOpen.show(
      context,
      title: 'Induction Store Scan',
      onResult: (scannedCode) {
        return _validateTrayForInduction(scannedCode);
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
                  const InductionTrayTableHeader(),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _scannedTrays.length,
                      itemBuilder: (context, index) {
                        return InductionTrayRow(
                          index: index,
                          tray: _scannedTrays[index],
                          displayIndex: index,
                          onRemove: () {
                            setState(() {
                              _scannedTrays.removeAt(index);
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

  Future<String?> _validateTrayForInduction(String scannedCode) async {
    final code = scannedCode.trim().toLowerCase();
    if (code.isEmpty) return 'Invalid tray code';

    final alreadyScanned = _scannedTrays.any(
      (t) => t.trayCode.trim().toLowerCase() == code,
    );
    if (alreadyScanned) return 'Already scanned';

    final matchIndex = _availableTrays.indexWhere((t) {
      final tCode = (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase();
      final pCode = (t.productionProgress.progressCode ?? '')
          .trim()
          .toLowerCase();
      return tCode == code || pCode == code;
    });

    if (matchIndex == -1) {
      return 'Tray not eligible for Induction';
    }

    final match = _availableTrays[matchIndex];

    if ((match.primaryTrayModel.trayType ?? 0) != 1) {
      return 'Invalid tray type.';
    }

    int targetItemId = match.productionProgress.processedItemId ?? match.item.id;
    String colorDesc = match.item.colorDescription ?? '';
    String sizeDesc = match.item.sizeDescription ?? '';

    if (targetItemId > 0) {
      AppLoader.show(context, message: "Fetching item details...");
      final itemRes = await _inductionRepo.fetchItemDef(targetItemId);
      AppLoader.hide(context);
      
      if (itemRes.success && itemRes.data != null) {
        final itemData = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
        if (itemData['colorDescription'] != null) colorDesc = itemData['colorDescription'];
        if (itemData['sizeDescription'] != null) sizeDesc = itemData['sizeDescription'];
      }
    }

    setState(() {
      _scannedTrays.add(
        GBSScannedTray(
          trayCode: match.primaryTrayModel.trayCode ?? '-',
          workOrderCode: match.workOrderHeader.workOrderCode ?? '-', // ✅ Added
          itemDescription: match.item.description ?? '-',
          sizeDescription: sizeDesc,
          colorDescription: colorDesc,
          primaryQuantity: (match.productionProgress.primaryQuantity ?? 0).toStringAsFixed(0),
          pieceWeight: match.item.pieceWeight ?? 0.0,
          trayUpdateId: match.primaryTrayModel.id,
          trayConcurrencyStamp: match.primaryTrayModel.concurrencyStamp,
        ),
      );
    });
    HapticFeedbackHelper.scanSuccess();
    return null;
  }

  void _onRemoveTray(int index) {
    setState(() => _scannedTrays.removeAt(index));
  }

  Future<void> _onSave() async {
    if (_scannedTrays.isEmpty) return;

    AppLoader.show(context, message: 'Saving Induction Data...');
    bool isAllSuccess = true;

    try {
      for (var scannedTray in _scannedTrays) {
        // Correct lookup pattern as per GBS module
        final currentTrayMatch = _availableTrays
            .where((t) => t.primaryTrayModel.id == scannedTray.trayUpdateId)
            .firstOrNull;

        if (currentTrayMatch == null) continue;

        final currentTrayData = currentTrayMatch;

        // 1. Post WIP Transaction as per requirement
        Map<String, dynamic> wipPayload = {
          "subOperation": "Induction Store",
          "transactionDate": DateTime.now().toIso8601String(),
          "transactionType": 1,
          "uom": currentTrayData.workOrderLine.uom ?? 0,
          "operatorDescription": "system",
          "primaryQuantity":
              currentTrayData.productionProgress.primaryQuantity ?? 0,
          "secondaryQuantity":
              currentTrayData.productionProgress.secondaryQuantity ?? 0,
          "primaryUOM": currentTrayData.productionProgress.primaryUOM ?? 0,
          "secondaryUOM": currentTrayData.productionProgress.secondaryUOM ?? 0,
          "code": currentTrayData.item.code ?? "",
          "productGrade": currentTrayData.productionProgress.productGrade ?? 0,
          "productNature":
              currentTrayData.productionProgress.productNature ?? 0,
          "progressId": currentTrayData.productionProgress.id,
          "operationId": currentTrayData.productionProgress.operationId,
          "workOrderHeaderId": currentTrayData.workOrderHeader.id,
          "workOrderLineId": currentTrayData.workOrderLine.id,
          "itemId": currentTrayData.item.id,
          "shiftId": currentTrayData.shift.id,
          "primaryTrayId": currentTrayData.primaryTrayModel.id,
          "machineId": currentTrayData.machineModel.id,
          "planHeaderId":
              currentTrayData.productionProgress.planHeaderId ??
              currentTrayData.planHeader?.id,
          "locatorId": 11,
          "batchHeaderId": currentTrayData
              .productionProgress
              .batchHeaderId, // Sourced from progress
          "batchLineId": currentTrayData
              .productionProgress
              .batchLinesId, // Sourced from progress
          "processitemd":
              currentTrayData.productionProgress.processedItemId ??
              currentTrayData.item.id, // Renamed to processitemd
        };

        await _inductionRepo.postWipTransactions(wipPayload);

        // 2. Update Production Progress
        Map<String, dynamic> updatePayload = currentTrayData.productionProgress
            .toJson();
        updatePayload['pbsFlag'] = true; // Mark as inducted
        updatePayload['pBSFlag'] = true; // Added to ensure ABP picks it up if case-sensitive
        updatePayload['locatorId'] = 11; // Sync locator
        updatePayload['date'] = DateTime.now().toIso8601String();

        final res = await _inductionRepo.updateProductionProgress(
          currentTrayData.productionProgress.id!,
          updatePayload,
        );

        if (!res.success)
          throw Exception('Failed to update tray ${scannedTray.trayCode}');

        // 3. Update Tray Details API
        final trayRes = await _inductionRepo.fetchTrayDetailById(currentTrayData.primaryTrayModel.id!);
        if (trayRes.success) {
          final tData = trayRes.data.containsKey('trayDetail') ? trayRes.data['trayDetail'] : trayRes.data;
          Map<String, dynamic> trayUpd = Map<String, dynamic>.from(tData);
          trayUpd["locatorId"] = 11; // Update locator for Induction Store
          // Remove audit fields if they cause PUT issues
          trayUpd.removeWhere((key, value) => ["creatorId", "creationTime", "lastModifierId", "lastModificationTime"].contains(key));
          
          await _inductionRepo.updateTrayDetails(currentTrayData.primaryTrayModel.id!, trayUpd);
        }
      }
    } catch (e) {
      isAllSuccess = false;
      debugPrint("❌ Induction Save Error: $e");
    } finally {
      AppLoader.hide(context);
      if (mounted) {
        if (isAllSuccess) {
          HapticFeedbackHelper.scanSuccess();
          AppSnackBar.showSuccess(context, message: 'Induction saved successfully');
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        } else {
          HapticFeedbackHelper.scanError();
          AppSnackBar.showError(context, message: 'Failed to save some trays');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Slate background
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPremiumHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildScannedQueue(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
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
                    'Induction Store',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'INVENTORY MANAGEMENT CONSOLE',
                    style: TextStyle(fontSize: 9, color: Color(0xFF546E7A), fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _scannedTrays.isEmpty
                  ? null
                  : () {
                      HapticFeedbackHelper.buttonClick();
                      _onSave();
                    },
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE CHANGES'),
              style: AppTheme.saveButtonStyle(isEnabled: _scannedTrays.isNotEmpty),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedQueue() {
    return Column(
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
                    'INDUCTION QUEUE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5),
                  ),
                  Text(
                    '${_scannedTrays.length} Trays Ready for Store',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF78909C)),
                  ),
                ],
              ),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _onScanTray,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('SCAN TRAY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // ── Fixed Header ─────────────────────────────────────────────
        const InductionTrayTableHeader(),
        Expanded(
          child: _scannedTrays.isEmpty
              ? const EmptyScanState(hasBorder: false)
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _scannedTrays.length,
                  itemBuilder: (context, index) {
                    final reversedIndex = _scannedTrays.length - 1 - index;
                    return InductionTrayRow(
                      index: reversedIndex,
                      tray: _scannedTrays[reversedIndex],
                      displayIndex: index,
                      onRemove: () => _onRemoveTray(reversedIndex),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Removed _buildTrayTableHeader and _buildTrayRow as they were extracted.
}
