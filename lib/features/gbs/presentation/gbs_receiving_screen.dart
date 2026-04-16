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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onInitialDataFetch();
      }
    });
    _fetchLatestTraysSilently();
  }

  Future<void> _onInitialDataFetch() async {
    AppLoader.show();
    await _fetchLatestTraysSilently();
    AppLoader.hide();
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

  String? _validateTrayForReceiving(String scannedCode) {

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

    setState(() {
      _scannedTrays.add(
        GBSScannedTray(
          itemDescription: match.item.description,
          componentDescription: match.item.componentDescription ?? '',
          sizeDescription: match.item.sizeDescription ?? '',
          workOrderCode: match.workOrderHeader.workOrderCode,
          primaryQuantity: match.productionProgress.primaryQuantity?.toString() ?? '0',
          pieceWeight: match.item.pieceWeight ?? 0.0,
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

    AppLoader.show();
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
      AppLoader.hide();
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
      body: AppLoaderContextAttach(
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
                      _buildTrayScannerSection(),
                      const SizedBox(height: 20),
                      _buildReceivedTraysSection()
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

  Widget _buildReceivedTraysSection() {
    final hasTrays = _scannedTrays.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Received Trays', subtitle: 'Trays received in GBS (${_scannedTrays.length})'),
        const SizedBox(height: 12),
        ContentCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (hasTrays) _buildGbsTableHeader(),
              if (!hasTrays) _buildEmptyState()
              else ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _scannedTrays.length,
                itemBuilder: (context, index) {
                  final reversedIndex = _scannedTrays.length - 1 - index;
                  return _buildGbsDataRow(reversedIndex, _scannedTrays[reversedIndex]);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGbsTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('TRAY CODE', style: _tableHeaderStyle)),
          Expanded(flex: 4, child: Text('ITEM DESC', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('WEIGHT', textAlign: TextAlign.center, style: _tableHeaderStyle)),
          const SizedBox(width: 40), // Consistent trailing space
        ],
      ),
    );
  }

  Widget _buildGbsDataRow(int index, GBSScannedTray tray) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(tray.trayCode, style: const TextStyle(fontSize: 13))),
          Expanded(flex: 4, child: Text(tray.itemDescription, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(tray.primaryQuantity, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 2,
            child: Text(
              '${((double.tryParse(tray.primaryQuantity) ?? 0.0) * tray.pieceWeight).toStringAsFixed(2)} kg',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
            ),
          ),
          SizedBox(
            width: 40,
            child: GestureDetector(
              onTap: () => _onRemoveTray(index),
              child: Icon(Icons.cancel, size: 20, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No trays received yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}