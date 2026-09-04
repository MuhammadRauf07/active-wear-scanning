import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/utils/barcode_buffer_parser.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/empty_scan_state.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/controller/processing_waste_controller.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/model/processing_waste_state.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class ProcessingWasteReceivingScreen extends StatelessWidget {
  const ProcessingWasteReceivingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProcessingWasteController>(
      create: (_) => ProcessingWasteController(),
      child: const _ProcessingWasteReceivingView(),
    );
  }
}

class _ProcessingWasteReceivingView extends StatefulWidget {
  const _ProcessingWasteReceivingView();

  @override
  State<_ProcessingWasteReceivingView> createState() => _ProcessingWasteReceivingViewState();
}

class _ProcessingWasteReceivingViewState extends State<_ProcessingWasteReceivingView> {
  final _barcodeParser = BarcodeBufferParser();
  bool _isScannerOpen = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (_isScannerOpen) return false;
    return _barcodeParser.handleKey(event, _processBluetoothScan);
  }

  Future<void> _processBluetoothScan(String scannedCode) async {
    final controller = context.read<ProcessingWasteController>();
    final error = await controller.validateScanCode(scannedCode);
    if (error != null && mounted) {
      AppSnackBar.showError(context, message: error);
    }
  }

  Future<void> _onScanTray(ProcessingWasteController controller, ProcessingWasteState state) async {
    setState(() => _isScannerOpen = true);
    await ScannerAlwaysOpen.show(
      context,
      title: 'Waste Tray Scan',
      onResult: (scannedCode) {
        return controller.validateScanCode(scannedCode);
      },
      scannedItemsBuilder: (context) {
        return ChangeNotifierProvider<ProcessingWasteController>.value(
          value: controller,
          child: Consumer<ProcessingWasteController>(
            builder: (context, latestController, __) {
              final latestState = latestController.state;
              if (latestState.scannedTrays.isEmpty) {
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
                    _buildTableHeader(),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: latestState.scannedTrays.length,
                        itemBuilder: (context, index) {
                          final reversedIndex = latestState.scannedTrays.length - 1 - index;
                          final model = latestState.scannedTrays[reversedIndex];
                          return _buildScannedRow(latestController, model, reversedIndex);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    setState(() => _isScannerOpen = false);
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF455A64), letterSpacing: 0.2);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(color: Color(0xFFF1F5F9), border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5))),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('TRAY CODE', style: headerStyle)),
          Expanded(flex: 3, child: Text('OPERATION', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 3, child: Text('WORK ORDER', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 2, child: Text('SIZE', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 2, child: Text('GRADE', textAlign: TextAlign.center, style: headerStyle)),
          SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildScannedRow(ProcessingWasteController controller, ProductionProgressResponseModel tray, int index) {
    const cellStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238));
    const blueCellStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1B64A3));

    final code = tray.primaryTrayModel.trayCode ?? 'N/A';
    final opName = tray.operation.name.isNotEmpty ? tray.operation.name : (tray.productionProgress.operationId != null ? 'Op #${tray.productionProgress.operationId}' : 'N/A');
    final woCode = tray.workOrderHeader.workOrderCode ?? 'N/A';
    final size = tray.item.sizeDescription ?? 'N/A';
    final wasteQty = ((tray.productionProgress.waste ?? 0.0) > 0 
        ? tray.productionProgress.waste! 
        : (tray.productionProgress.secondaryQuantity ?? tray.productionProgress.primaryQuantity ?? 0.0)).toStringAsFixed(0);
    final grade = tray.productionProgress.productGrade == 2 ? 'C' : 'B';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(code, style: blueCellStyle)),
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B64A3).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  opName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF1B64A3)),
                ),
              ),
            ),
          ),
          Expanded(flex: 3, child: Text(woCode, textAlign: TextAlign.center, style: cellStyle)),
          Expanded(flex: 2, child: Text(size, textAlign: TextAlign.center, style: cellStyle)),
          Expanded(flex: 2, child: Text(wasteQty, textAlign: TextAlign.center, style: cellStyle)),
          Expanded(flex: 2, child: Text(grade, textAlign: TextAlign.center, style: cellStyle)),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => controller.removeScannedTray(index),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red.shade400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAvailableWasteDialog(BuildContext context, ProcessingWasteController controller, ProcessingWasteState state) {
    showDialog(
      context: context,
      builder: (ctx) {
        final available = state.selectedOperationId == null
            ? state.availableWasteTrays
            : state.availableWasteTrays.where((t) => t.productionProgress.operationId == state.selectedOperationId).toList();

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.88,
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PENDING PROCESSING WASTE (${available.length})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFE67E22)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('TRAY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF546E7A)))),
                      Expanded(flex: 3, child: Text('OPERATION', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF546E7A)))),
                      Expanded(flex: 3, child: Text('WORK ORDER', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF546E7A)))),
                      Expanded(flex: 2, child: Text('SIZE', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF546E7A)))),
                      Expanded(flex: 2, child: Text('TUBES', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF546E7A)))),
                      Expanded(flex: 2, child: Text('GRADE', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF546E7A)))),
                    ],
                  ),
                ),
                Expanded(
                  child: available.isEmpty
                      ? const Center(
                          child: Text('No pending waste trays found in Locator 18', style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
                        )
                      : ListView.builder(
                          itemCount: available.length,
                          itemBuilder: (c, i) {
                            final item = available[i];
                            final code = item.primaryTrayModel.trayCode ?? 'N/A';
                            final op = item.operation.name.isNotEmpty ? item.operation.name : (item.productionProgress.operationId != null ? 'Op #${item.productionProgress.operationId}' : 'N/A');
                            final wo = item.workOrderHeader.workOrderCode ?? 'N/A';
                            final size = item.item.sizeDescription ?? 'N/A';
                            final qty = ((item.productionProgress.waste ?? 0) > 0 ? item.productionProgress.waste! : (item.productionProgress.secondaryQuantity ?? item.productionProgress.primaryQuantity ?? 0)).toStringAsFixed(0);
                            final grade = item.productionProgress.productGrade == 2 ? 'C' : 'B';

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: i.isEven ? Colors.white : const Color(0xFFF8FAFC),
                                border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1)))),
                                  Expanded(
                                    flex: 3,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.orange.shade200, width: 0.5),
                                        ),
                                        child: Text(
                                          op,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.orange.shade900),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(flex: 3, child: Text(wo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF263238)))),
                                  Expanded(flex: 2, child: Text(size, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF263238)))),
                                  Expanded(flex: 2, child: Text(qty, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF263238)))),
                                  Expanded(flex: 2, child: Text(grade, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1B64A3)))),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterBar(ProcessingWasteController controller, ProcessingWasteState state) {
    final availableCount = state.selectedOperationId == null
        ? state.availableWasteTrays.length
        : state.availableWasteTrays.where((t) => t.productionProgress.operationId == state.selectedOperationId).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFCFD8DC), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FILTER BY OPERATION',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF78909C), letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCFD8DC)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: state.selectedOperationId,
                      isExpanded: true,
                      hint: const Text('All Operations', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238))),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Operations', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
                        ),
                        ...state.operations.map(
                          (op) => DropdownMenuItem<int?>(
                            value: op.id,
                            child: Text(op.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238))),
                          ),
                        ),
                      ],
                      onChanged: (val) => controller.setSelectedOperation(val),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => _showAvailableWasteDialog(context, controller, state),
                icon: const Icon(Icons.layers_outlined, size: 16),
                label: Text(
                  'SHOW WASTE ($availableCount)',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE67E22),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProcessingWasteController>();
    final state = controller.state;

    return PopScope(
      canPop: !state.isLoading && !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _buildPremiumHeader(controller, state),
              if (state.errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFB0BEC5),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFilterBar(controller, state),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SCANNED WASTE TRAYS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF263238),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    '${state.scannedTrays.length} Tray(s) Scanned',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF78909C),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 38,
                                child: ElevatedButton.icon(
                                  onPressed: state.isLoading
                                      ? null
                                      : () => _onScanTray(controller, state),
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
                        _buildTableHeader(),
                        Expanded(
                          child: state.scannedTrays.isEmpty
                              ? const EmptyScanState(hasBorder: false)
                              : ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: state.scannedTrays.length,
                                  itemBuilder: (context, index) {
                                    final reversedIndex = state.scannedTrays.length - 1 - index;
                                    final model = state.scannedTrays[reversedIndex];
                                    return _buildScannedRow(controller, model, reversedIndex);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(ProcessingWasteController controller, ProcessingWasteState state) {
    final enabled = state.scannedTrays.isNotEmpty && !state.isLoading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFB0BEC5),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
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
            CustomBackButton(
              onBackPress: (state.isLoading || AppLoader.isVisible)
                  ? () {}
                  : () => Navigator.pop(context),
            ),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Processing Waste Receiving',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'Receive and log waste trays from processing',
                    style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: enabled
                  ? () async {
                      try {
                        await AppLoader.runWithLoader(
                          context,
                          message: 'Saving Waste logs & WIP transactions...',
                          action: () => controller.saveWasteReceivingData(),
                        );
                        if (context.mounted) {
                          AppSnackBar.showSuccess(context, message: 'Processing waste received successfully!');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackBar.showError(context, message: e.toString());
                        }
                      }
                    }
                  : null,
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE CHANGES'),
              style: AppTheme.saveButtonStyle(isEnabled: enabled),
            ),
          ],
        ),
      ),
    );
  }
}
