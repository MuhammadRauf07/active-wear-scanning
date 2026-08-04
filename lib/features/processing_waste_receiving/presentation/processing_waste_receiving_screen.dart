import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/utils/barcode_buffer_parser.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
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
          Expanded(flex: 4, child: Text('TRAY CODE', style: headerStyle)),
          Expanded(flex: 4, child: Text('WORK ORDER', textAlign: TextAlign.center, style: headerStyle)),
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
    final woCode = tray.workOrderHeader.workOrderCode ?? 'N/A';
    final size = tray.item.sizeDescription ?? 'N/A';
    final wasteQty = (tray.productionProgress.waste ?? 0.0).toStringAsFixed(0);
    final grade = tray.productionProgress.productGrade == 2 ? 'C' : 'B';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(code, style: blueCellStyle)),
          Expanded(flex: 4, child: Text(woCode, textAlign: TextAlign.center, style: cellStyle)),
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProcessingWasteController>();
    final state = controller.state;

    return PopScope(
      canPop: !state.isLoading && !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text(
            'Processing Waste Receiving',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B)),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
            onPressed: (state.isLoading || AppLoader.isVisible)
                ? null
                : () => Navigator.pop(context),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            if (state.scannedTrays.isNotEmpty)
              TextButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
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
                      },
                child: const Text(
                  'SAVE CHANGES',
                  style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
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
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0D47A1), size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'SCANNED WASTE TRAYS',
                                style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                              ),
                            ),
                            Text(
                              '${state.scannedTrays.length} Trays',
                              style: const TextStyle(color: Color(0xFF546E7A), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: state.isLoading
                                      ? null
                                      : () => _onScanTray(controller, state),
                                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                                  label: const Text('SCAN TRAY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D47A1),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: state.scannedTrays.isEmpty
                                    ? const EmptyScanState(hasBorder: false)
                                    : Column(
                                        children: [
                                          _buildTableHeader(),
                                          Expanded(
                                            child: ListView.builder(
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
                            ],
                          ),
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
    );
  }
}
