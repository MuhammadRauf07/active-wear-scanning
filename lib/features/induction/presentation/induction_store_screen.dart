import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/features/gbs/model/gbs_scanned_tray.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/induction/model/induction_model.dart';
import 'package:active_wear_scanning/features/induction/repo/induction_repo.dart';
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

  final FocusNode _focusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onInitialDataFetch();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final now = DateTime.now();
      if (_lastKeyPress != null && now.difference(_lastKeyPress!).inMilliseconds > 200) {
        _barcodeBuffer = '';
      }
      _lastKeyPress = now;

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.isNotEmpty) {
          final code = _barcodeBuffer;
          _barcodeBuffer = '';
          _processBluetoothScan(code);
        }
      } else if (event.character != null) {
        _barcodeBuffer += event.character!;
      }
    }
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
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: _onKey,
        child: SafeArea(
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildScannedTraysSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    final hasTrays = _scannedTrays.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Scanned Trays',
          subtitle: 'Scan a tray barcode to start induction',
        ),
        const SizedBox(height: 12),
        ContentCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scanned Trays (${_scannedTrays.length})', 
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)
                    ),
                    Row(
                      children: [
                        // SizedBox(
                        //   width: 100,
                        //   height: _inputAndButtonHeight,
                        //   child: TextField(
                        //     readOnly: true,
                        //     textAlign: TextAlign.center,
                        //     decoration: InputDecoration(
                        //       hintText: 'Pcs/tray',
                        //       hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        //       isDense: true,
                        //       contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
                        //       border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)),
                        //       enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)),
                        //     ),
                        //   ),
                        // ),
                        const SizedBox(width: 8),
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
              _buildTrayTableHeader(),
              if (!hasTrays)
                _buildEmptyState()
              else
                ...List.generate(_scannedTrays.length, (index) {
                   final reversedIndex = _scannedTrays.length - 1 - index;
                   return _buildTrayRow(reversedIndex, _scannedTrays[reversedIndex], index);
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrayTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('TRAY CODE', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('WORK ORDER', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('COLOR', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('SIZE', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('TUBES', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('WEIGHT', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildTrayRow(int index, GBSScannedTray tray, int displayIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
        color: displayIndex.isEven ? Colors.white : Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(tray.trayCode, style: const TextStyle(fontSize: 13, color: Colors.black87))),
          Expanded(flex: 2, child: Text(tray.workOrderCode, style: const TextStyle(fontSize: 12, color: Colors.black87))),
          Expanded(flex: 4, child: Text(tray.itemDescription, style: const TextStyle(fontSize: 11, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
          Expanded(
            flex: 2, 
            child: Text(tray.colorDescription.isNotEmpty ? tray.colorDescription : '-', style: const TextStyle(fontSize: 11, color: Colors.black87))
          ),
          Expanded(
            flex: 2, 
            child: Text(tray.sizeDescription.isNotEmpty ? tray.sizeDescription : '-', style: const TextStyle(fontSize: 11, color: Colors.black87))
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tray.primaryQuantity,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${((double.tryParse(tray.primaryQuantity) ?? 0.0) * tray.pieceWeight).toStringAsFixed(2)} g',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _onRemoveTray(index),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.cancel, size: 18, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
      ),
      child: Center(
        child: Text('No scanned trays yet. Start by scanning a tray barcode.', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
      ),
    );
  }
}
