import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
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

  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

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
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final now = DateTime.now();
    if (_lastKeyPress != null && now.difference(_lastKeyPress!).inMilliseconds > 200) {
      _barcodeBuffer = '';
    }
    _lastKeyPress = now;

    final ch = event.character;
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        ch == '\n' || ch == '\r';

    if (isEnter) {
      if (_barcodeBuffer.isNotEmpty) {
        final code = _barcodeBuffer;
        _barcodeBuffer = '';
        debugPrint('📡 BT Scanner (Induction) → code: $code');
        _processBluetoothScan(code);
        return true;
      }
    } else if (ch != null && ch.isNotEmpty) {
      _barcodeBuffer += ch;
    }
    return false;
  }

  void _processBluetoothScan(String scannedCode) {
    final code = scannedCode.trim();
    if (code.isEmpty) return;

    final error = _validateTrayForInduction(code);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red));
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Induction Saved Successfully")),
          );
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to save some trays"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            CustomInspectionHeader(
              heading: 'Induction Store',
              subtitle: 'Scan Trays for Induction Store',
              isShowBackIcon: true,
              topPadding: 0,
              horizontalPadding: 12,
              widget: CustomOutlinedButton(
                label: 'Save Changes',
                borderColor: Colors.blue,
                textColor: Colors.blue,
                buttonHeight: 42,
                onPressed: _onSave,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildScannedTraysSection(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Tray Scanner',
          subtitle: 'Scan tray barcodes for induction',
        ),
        const SizedBox(height: 12),
        ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scan Tray Barcode', style: _labelStyle),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: _inputAndButtonHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ready for scan...',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CustomOutlinedButton(
                    label: 'Scan Tray',
                    borderColor: Colors.blue,
                    fillColor: Colors.blue,
                    textColor: Colors.white,
                    buttonHeight: _inputAndButtonHeight,
                    onPressed: _onScanTray,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScannedTraysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Scanned Trays',
          subtitle: 'Scan a tray barcode to start induction',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ContentCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Toolbar ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scanned Trays (${_scannedTrays.length})', 
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)
                      ),
                      CustomOutlinedButton(
                        label: 'Scan Tray',
                        borderColor: Colors.blue,
                        fillColor: Colors.blue,
                        textColor: Colors.white,
                        buttonHeight: _inputAndButtonHeight,
                        onPressed: _onScanTray,
                      ),
                    ],
                  ),
                ),
                
                // ── Fixed Header ─────────────────────────────────────────────
                const InductionTrayTableHeader(),

                // ── Scrollable Values ────────────────────────────────────────
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
            ),
          ),
        ),
      ],
    );
  }

  // Removed _buildTrayTableHeader and _buildTrayRow as they were extracted.
}
