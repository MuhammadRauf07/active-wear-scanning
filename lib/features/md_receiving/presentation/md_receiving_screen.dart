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
import 'package:active_wear_scanning/features/carton_packing/presentation/widgets/carton_packing_row.dart';
import 'package:active_wear_scanning/features/md_receiving/controller/md_receiving_controller.dart';
import 'package:active_wear_scanning/features/md_receiving/model/md_receiving_state.dart';

class MdReceivingScreen extends StatelessWidget {
  const MdReceivingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MdReceivingController>(
      create: (_) => MdReceivingController(),
      child: const _MdReceivingScreenView(),
    );
  }
}

class _MdReceivingScreenView extends StatefulWidget {
  const _MdReceivingScreenView();

  @override
  State<_MdReceivingScreenView> createState() => _MdReceivingScreenViewState();
}

class _MdReceivingScreenViewState extends State<_MdReceivingScreenView> {
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
    final controller = context.read<MdReceivingController>();
    final error = await controller.validateScanCode(scannedCode);
    if (error != null && mounted) {
      _showError(error);
    }
  }

  Future<void> _onScanItem(MdReceivingController controller, MdReceivingState state) async {
    setState(() => _isScannerOpen = true);
    await ScannerAlwaysOpen.show(
      context,
      title: 'MD Receiving Scan',
      onResult: (scannedCode) {
        return controller.validateScanCode(scannedCode);
      },
      scannedItemsBuilder: (context) {
        return ChangeNotifierProvider<MdReceivingController>.value(
          value: controller,
          child: Consumer<MdReceivingController>(
            builder: (context, latestController, __) {
              final latestState = latestController.state;
              if (latestState.scannedCartons.isEmpty) {
                return const Center(
                  child: Text(
                    'No cartons scanned yet',
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
                        itemCount: latestState.scannedCartons.length,
                        itemBuilder: (context, index) {
                          final reversedIndex = latestState.scannedCartons.length - 1 - index;
                          final model = latestState.scannedCartons[reversedIndex];
                          return CartonPackingRow(
                            index: reversedIndex,
                            item: model,
                            onRemove: () async {
                              latestController.removeScannedCarton(reversedIndex);
                            },
                          );
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
    if (mounted) {
      setState(() => _isScannerOpen = false);
    }
  }

  Future<void> _onSave(MdReceivingController controller, MdReceivingState state) async {
    HapticFeedbackHelper.buttonClick();
    AppLoader.show(context, message: 'Saving MD receiving logs & WIP transactions...');
    try {
      await controller.saveMdReceivingData();
      if (!mounted) return;
      AppLoader.hide(context);
      HapticFeedbackHelper.scanSuccess();
      AppSnackBar.showSuccess(context, message: 'Saved successfully (${state.scannedCartons.length} carton(s))');
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      if (!mounted) return;
      AppLoader.hide(context);
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedbackHelper.scanError();
    AppSnackBar.showError(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MdReceivingController>();
    final state = controller.state;

    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _buildPremiumHeader(controller, state),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: _buildMainContentSection(controller, state),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(MdReceivingController controller, MdReceivingState state) {
    final hasScanned = state.scannedCartons.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const CustomBackButton(),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MD Receiving', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238))),
                  Text('Log incoming MD material items', style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: !hasScanned ? null : () => _onSave(controller, state),
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE CHANGES'),
              style: AppTheme.saveButtonStyle(isEnabled: hasScanned),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContentSection(MdReceivingController controller, MdReceivingState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5, strokeAlign: BorderSide.strokeAlignOutside),
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
                    const Text('SCANNED MD ITEMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5)),
                    Text('${state.scannedCartons.length} Total Items', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF78909C))),
                  ],
                ),
                SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () => _onScanItem(controller, state),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('SCAN ITEM', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
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
          const Divider(height: 1, color: Color(0xFFCFD8DC), thickness: 1),

          if (state.scannedCartons.isEmpty)
            const Expanded(child: EmptyScanState(hasBorder: false))
          else ...[
            _buildTableHeader(),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: state.scannedCartons.length,
                itemBuilder: (context, index) {
                  final reversedIndex = state.scannedCartons.length - 1 - index;
                  final model = state.scannedCartons[reversedIndex];
                  return CartonPackingRow(
                    index: reversedIndex,
                    item: model,
                    onRemove: () {
                      controller.removeScannedCarton(reversedIndex);
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF455A64), letterSpacing: 0.2);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(color: Color(0xFFF1F5F9), border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5))),
      child: const Row(
        children: [
          Expanded(flex: 4, child: Text('Carton ID', style: headerStyle)),
          Expanded(flex: 4, child: Text('Carton Group', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 2, child: Text('Packs/Carton', textAlign: TextAlign.center, style: headerStyle)),
          SizedBox(width: 44),
        ],
      ),
    );
  }
}
