import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
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

  static const _inputAndButtonHeight = 42.0;
  static final _labelStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87);
  static final _tableHeaderStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700);

  // Bluetooth Scanner Support
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
    _fetchLatestTraysSilently();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final now = DateTime.now();
      // If it's been more than 200ms since the last keypress, reset buffer.
      // Scanners type very fast (usually <50ms between keys).
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
    final error = _validateTrayForReceiving(scannedCode);
    if (error != null) {
      _showError(error as String);
    } else {
      // Optionally show a success snackbar or play a sound
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tray $scannedCode scanned successfully')));
    }
  }

  Future<void> _onInitialDataFetch() async {
    AppLoader.show(context);
    await _fetchLatestTraysSilently();
    AppLoader.hide(context);
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
    );
    setState(() {});
  }

  Future<String?> _validateTrayForReceiving(String scannedCode) async {

    final code = scannedCode.trim().toLowerCase();
    if (code.isEmpty) return 'Invalid tray code';

    final alreadyScanned = _scannedTrays.any((t) => t.trayCode.trim().toLowerCase() == code);
    if (alreadyScanned) return 'Already assigned';

    // 2. Flexible Matching Logic
    final match = availableTrayForGbs.where((t) {
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

    int targetItemId = match.productionProgress.processedItemId ?? match.item.id;
    String colorDesc = match.item.colorDescription ?? '';
    String sizeDesc = match.item.sizeDescription ?? '';
    double perGarmentTube = match.item.perGarmentTube;

    if (targetItemId > 0) {
      AppLoader.show(context, message: "Fetching item details...");
      final itemRes = await _trayScanningRepo.fetchItemDef(targetItemId);
      AppLoader.hide(context);
      
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
    return null;
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
          "transactionType": 1,
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
          "transactionType": 1, // Formal Handover
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
        };

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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Successfully")));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $message'), backgroundColor: Colors.red));
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomInspectionHeader(
                heading: 'GBS Receiving',
                subtitle: 'Scan trays to receive them in GBS',
                isShowBackIcon: true,
                topPadding: 0,
                horizontalPadding: 12,
                widget: CustomOutlinedButton(
                  label: 'Save Changes',
                  borderColor: Colors.blue,
                  textColor: Colors.blue,
                  buttonHeight: 42,
                  onPressed: saveWipTransactionsAndUpdateTray,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildScannedTraysSection()
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

  Widget _buildTrayScannerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Tray Scanner', subtitle: 'Scan tray barcodes to receive them in GBS'),
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
                      decoration: BoxDecoration(border: Border.all(color: Colors.blue), borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Text('Ready for scan...', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
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
        const SectionHeader(title: 'Received Trays', subtitle: 'Scan tray barcodes to receive them in GBS'),
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
                      'Received Trays (${_scannedTrays.length})', 
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
              if (!hasTrays) _buildEmptyState()
              else ...List.generate(_scannedTrays.length, (index) {
                final reversedIndex = _scannedTrays.length - 1 - index;
                return _buildTrayRow(reversedIndex, _scannedTrays[reversedIndex]);
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
          Expanded(flex: 3, child: Text('ITEM DESCRIPTION', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('COLOR', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('SIZE', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('PCS/TUBE', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('TUBES', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('PCS', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('WEIGHT', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildTrayRow(int index, GBSScannedTray tray) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
        color: index.isEven ? Colors.white : Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(tray.trayCode, style: const TextStyle(fontSize: 13, color: Colors.black87))),
          Expanded(flex: 2, child: Text(tray.workOrderCode, style: const TextStyle(fontSize: 12, color: Colors.black87))),
          Expanded(flex: 3, child: Text(tray.itemDescription, style: const TextStyle(fontSize: 11, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
          Expanded(
            flex: 2, 
            child: Text(tray.colorDescription.isNotEmpty ? tray.colorDescription : '-', style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600))
          ),
          Expanded(
            flex: 2, 
            child: Text(tray.sizeDescription.isNotEmpty ? tray.sizeDescription : '-', style: const TextStyle(fontSize: 11, color: Colors.black87))
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.perGarmentTube > 0 ? tray.perGarmentTube.toStringAsFixed(0) : '-',
              style: TextStyle(fontSize: 12, color: Colors.indigo.shade700, fontWeight: FontWeight.w600),
            ),
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
                  style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Builder(
              builder: (_) {
                final tubes = double.tryParse(tray.primaryQuantity) ?? 0;
                final garmentPcs = (tray.perGarmentTube > 0) ? (tubes * tray.perGarmentTube) : 0;
                return Text(
                  garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade700),
                );
              },
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