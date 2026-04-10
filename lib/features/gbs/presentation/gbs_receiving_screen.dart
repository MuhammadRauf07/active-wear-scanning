import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
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
  static const _borderColor = Colors.green;
  static const _inputAndButtonHeight = 42.0;
  final _trayScanningRepo = fromPlex<GBSReceivingRepo>();
  List<ProductionProgressResponseModel> availableTrayForGbs = [];
  ProductionProgressResponseModel? _currentTrayDetails;
  static final _labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87);
  static final _tableHeaderStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700);

  // ─── User Actions ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _onScanMachineBarcode();
  }

  /// Opens barcode scanner for tray receiving
  Future<void> _onScanTray() async {
    await ScannerAlwaysOpen.show(
      context,
      title: 'GBS Tray Receiving',
      onResult: (scannedCode) {
        final String? validationError = _validateTrayForReceiving(scannedCode);

        if (validationError == null) {
          return null;
        } else {
          return validationError;
        }
      },
    );
  }

  /// Validates scanned tray against availableTraysDetail. Returns null if valid, error message if invalid.
  String? _validateTrayForReceiving(String scannedCode) {
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid tray code';

    /// Check if already scanned (already assigned)
    final alreadyScanned = _scannedTrays.any((t) => t.trayCode.trim() == code);
    if (alreadyScanned) return 'Already assigned';

    /// Find matching tray in available list
    final available = availableTrayForGbs.where((t) => (t.primaryTrayModel.trayCode ?? '').trim() == code).toList();
    if (available.isEmpty) return 'Tray not available';

    _currentTrayDetails = available.first;
    final trayDetail = available.first.primaryTrayModel;
    if (trayDetail.active != true) return 'Tray is not active';

    setState(() {
      _scannedTrays.add(
        GBSScannedTray(
          itemDescription: _currentTrayDetails!.item.description,
          componentDescription: _currentTrayDetails!.item.componentDescription!,
          sizeDescription: _currentTrayDetails!.item.sizeDescription!,
          workOrderCode: _currentTrayDetails!.workOrderHeader.workOrderCode,
          primaryQuantity: _currentTrayDetails!.productionProgress.primaryQuantity?.toString() ?? '0',
          trayCode: scannedCode.trim(),
          trayUpdateId: trayDetail.id,
          trayConcurrencyStamp: trayDetail.concurrencyStamp,
        ),
      );
    });
    return null;
  }

  /// Builds a map of tray details for [DynamicInfoDisplay].
  /// Only includes non-empty values.
  Map<String, dynamic> _buildTrayDetailsMap(GBSScannedTray trayDetails) {
    final result = <String, dynamic>{};

    void addField(String key, IconData icon, String label, String? value) {
      if (value != null && value.trim().isNotEmpty && value.trim() != 'null') {
        result[key] = {'icon': icon, 'label': label, 'value': value};
      }
    }

    addField('Tray Code', Icons.qr_code, 'Tray Code', trayDetails.trayCode);
    addField('Work Order', Icons.assignment, 'Work Order', trayDetails.workOrderCode);
    addField('Item Description', Icons.description, 'Item Description', trayDetails.itemDescription);
    addField('Component Description', Icons.description, 'Component Description', trayDetails.componentDescription);
    addField('Size Description', Icons.description, 'Size Description', trayDetails.sizeDescription);

    return result;
  }

  void _onRemoveTray(int index) {
    setState(() {
      _scannedTrays.removeAt(index);
    });
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Success: $message')));
  }

  /// Save API ────────────────────────────────────────────────────────────────

  void saveWipTransactionsAndUpdateTray() async {
    AppLoader.show();
    for (int i = 0; i < _scannedTrays.length; i++) {
      final currentTrayData = availableTrayForGbs.firstWhere((t) => t.primaryTrayModel.id == _scannedTrays[i].trayUpdateId);

      Map<String, dynamic> wipProductionProgress = {
        "subOperation": "string",
        "transactionDate": DateTime.now().toIso8601String(),
        "transactionType": 1,
        "uom": currentTrayData.workOrderLine.uom,
        "operatorDescription": currentTrayData.productionProgress.operatorDescription,
        "primaryQuantity": currentTrayData.productionProgress.primaryQuantity,
        "secondaryQuantity": currentTrayData.productionProgress.secondaryQuantity,
        "primaryUOM": currentTrayData.productionProgress.primaryUOM,
        "secondaryUOM": currentTrayData.productionProgress.secondaryUOM,
        "code": currentTrayData.item.code,
        "productGrade": currentTrayData.productionProgress.productGrade,
        "productNature": currentTrayData.productionProgress.productNature,
        "progressId": currentTrayData.productionProgress.id, // ← Link to production progress!
        "operationId": currentTrayData.operation.id,
        "workOrderHeaderId": currentTrayData.workOrderHeader.id,
        "workOrderLineId": currentTrayData.workOrderLine.id,
        "itemId": currentTrayData.item.id,
        "shiftId": currentTrayData.shift.id,
        "primaryTrayId": currentTrayData.primaryTrayModel.id,
        "machineId": currentTrayData.machineModel.id,
        "planHeaderId": currentTrayData.planHeader.id,
        "locatorId": 3,
      };

      await _trayScanningRepo.postWipTransactions(wipProductionProgress);

      Map<String, dynamic> updateData = {
        "subOperation": "GBS Received",
        "date": DateTime.now().toIso8601String(),
        "transactionType": currentTrayData.productionProgress.transactionType,
        "operatorDescription": "system",
        "primaryQuantity": currentTrayData.productionProgress.primaryQuantity,
        "primaryUOM": currentTrayData.productionProgress.primaryUOM,
        "secondaryQuantity": currentTrayData.productionProgress.secondaryQuantity,
        "secondaryUOM": currentTrayData.productionProgress.secondaryUOM,
        "wipStatus": currentTrayData.productionProgress.wipStatus,
        "gbsFlag": true,
        "pbsFlag": currentTrayData.productionProgress.pbsFlag,
        "operationId": currentTrayData.operation.id,
        "workOrderHeaderId": currentTrayData.workOrderHeader.id,
        "workOrderLineId": currentTrayData.workOrderLine.id,
        "itemId": currentTrayData.item.id,
        "shiftId": currentTrayData.shift.id,
        "primaryTrayId": currentTrayData.primaryTrayModel.id,
        "machineId": currentTrayData.machineModel.id,
        "planHeaderId": currentTrayData.planHeader.id,
        "locatorId": 3,
        "concurrencyStamp": currentTrayData.productionProgress.concurrencyStamp,
      };

      if (currentTrayData.productionProgress.id != null) {
        await _trayScanningRepo.updateProductionProgress(currentTrayData.productionProgress.id!, updateData);
      }

      // Add Tray Update logic safely bouncing with a GET request
      if (_scannedTrays[i].trayUpdateId != null) {
        final getTrayRes = await _trayScanningRepo.fetchTrayDetailById(_scannedTrays[i].trayUpdateId!);
        if (getTrayRes.success && getTrayRes.data != null) {
          Map<String, dynamic> rawTrayPayload = getTrayRes.data.containsKey('trayDetail') 
              ? getTrayRes.data['trayDetail'] 
              : getTrayRes.data;
          
          rawTrayPayload["locatorId"] = 3; // Update to GBS explicitly!
          
          rawTrayPayload.remove("creatorId");
          rawTrayPayload.remove("creationTime");
          rawTrayPayload.remove("lastModifierId");
          rawTrayPayload.remove("lastModificationTime");
          
          final trayRes = await _trayScanningRepo.updateTrayDetails(rawTrayPayload, _scannedTrays[i].trayUpdateId!);
          if (!trayRes.success) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tray Fix Failed: ${trayRes.message}')));
          }
        }
      }
    }

    _showSuccessMessage("Saved");

    AppLoader.hide();
    Navigator.pop(context);
  }

  // ─── Build ────────────────────────────────────────────────────────────────
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildTrayScannerSection(), const SizedBox(height: 20), _buildReceivedTraysSection()]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGbsTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('TRAY CODE', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('WO', style: _tableHeaderStyle)),
          Expanded(flex: 5, child: Text('ITEM DESC', style: _tableHeaderStyle)),
          Expanded(flex: 3, child: Text('QUANTITY', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('WEIGHT', style: _tableHeaderStyle)),
          const SizedBox(width: 36), // Space for the delete icon
        ],
      ),
    );
  }

  Widget _buildGbsDataRow(int index, GBSScannedTray tray) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          /// Tray Code
          Expanded(
            flex: 2,
            child: Text(tray.trayCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
          ),

          /// Work Order
          Expanded(flex: 2, child: Text(tray.workOrderCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal))),

          /// Item Description
          Expanded(
            flex: 5,
            child: Text(
              tray.itemDescription,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          /// Quantity
          Expanded(
            flex: 3,
            child: Text(tray.primaryQuantity, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
          ),

          /// Weight
          Expanded(
            flex: 2,
            child: Builder(builder: (_) {
              final qty = double.tryParse(tray.primaryQuantity) ?? 0;
              final match = availableTrayForGbs.where((t) => t.primaryTrayModel.id == tray.trayUpdateId).firstOrNull;
              final pw = match?.item.pieceWeight;
              if (pw == null || pw == 0) {
                return Text('-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal));
              }
              final total = qty * pw;
              return Text('${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal));
            }),
          ),

          /// Remove Action
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

  /// Tray scanner section
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
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ready for scan...',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
                    onPressed: _onScanTray, // Your existing scan logic
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Received trays section
  Widget _buildReceivedTraysSection() {
    final hasTrays = _scannedTrays.isNotEmpty;
    final displayTrays = _scannedTrays.reversed.toList();

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
              if (!hasTrays)
                _buildEmptyState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _scannedTrays.length,
                  itemBuilder: (context, index) {
                    // Show most recent at the top
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No trays received yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text('Start by scanning a tray barcode', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  /// Opens barcode scanner for machine. On success, loads work order from API.
  Future<void> _onScanMachineBarcode() async {
    final apiResult = await _trayScanningRepo.getProductionProgress();

    if (!mounted) return;

    if (apiResult.success && apiResult.data != null) {
      setState(() {
        availableTrayForGbs = apiResult.data as List<ProductionProgressResponseModel>;
      });
    } else {
      _showError(apiResult.message);
    }

    AppLoader.hide();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $message'), backgroundColor: Colors.red));
  }
}
