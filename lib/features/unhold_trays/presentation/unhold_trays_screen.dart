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
import 'package:active_wear_scanning/core/widgets/tray_table_header.dart';
import 'package:active_wear_scanning/features/unhold_trays/controller/unhold_trays_controller.dart';
import 'package:active_wear_scanning/features/unhold_trays/model/unhold_trays_state.dart';

class UnholdTraysScreen extends StatelessWidget {
  const UnholdTraysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UnholdTraysController>(
      create: (_) => UnholdTraysController(),
      child: const _UnholdTraysScreenView(),
    );
  }
}

class _UnholdTraysScreenView extends StatefulWidget {
  const _UnholdTraysScreenView();

  @override
  State<_UnholdTraysScreenView> createState() => _UnholdTraysScreenViewState();
}

class _UnholdTraysScreenViewState extends State<_UnholdTraysScreenView> {
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
    final controller = context.read<UnholdTraysController>();
    final error = await controller.validateAndAddBarcodeScan(scannedCode);
    if (error != null && mounted) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: error);
    } else if (mounted) {
      HapticFeedbackHelper.scanSuccess();
      AppSnackBar.showSuccess(context, message: 'Tray added for unhold');
    }
  }

  Future<void> _onScanTray(UnholdTraysController controller) async {
    setState(() => _isScannerOpen = true);
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan to Release Tray',
      onResult: (scannedCode) async {
        final err = await controller.validateAndAddBarcodeScan(scannedCode);
        if (err != null) return err;
        if (mounted) HapticFeedbackHelper.scanSuccess();
        return null;
      },
    );
    if (mounted) setState(() => _isScannerOpen = false);
  }

  Future<void> _onSave(UnholdTraysController controller) async {
    AppLoader.show(context, message: 'Releasing held trays...');
    final success = await controller.saveChanges();
    if (!mounted) return;
    AppLoader.hide(context);

    if (success) {
      HapticFeedbackHelper.scanSuccess();
      AppSnackBar.showSuccess(context, message: 'Trays successfully unheld and released!');
    } else if (controller.state.errorMessage != null) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: controller.state.errorMessage!);
    }
  }

  void _showReferenceHeldTraysDialog(UnholdTraysController controller, UnholdTraysState state) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HELD TRAYS (${state.selectedOrigin == "knitting" ? "KNITTING PRODUCTION" : "PBS"})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFC62828)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: state.heldTrays.isEmpty
                    ? Center(
                        child: Text(
                          'No held trays found in ${state.selectedOrigin == "knitting" ? "Knitting Production" : "PBS"}.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF78909C)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.heldTrays.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (c, idx) {
                          final item = state.heldTrays[idx];
                          final trayCode = item.primaryTrayModel.trayCode ?? '-';
                          final itemDesc = item.item.description;
                          final woCode = item.workOrderHeader.workOrderCode;
                          final qty = item.productionProgress.primaryQuantity?.toStringAsFixed(0) ?? '0';

                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.front_hand_outlined, color: Colors.red, size: 20),
                            title: Text(trayCode, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            subtitle: Text('$itemDesc | WO: $woCode', style: const TextStyle(fontSize: 11)),
                            trailing: Text('$qty tubes', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UnholdTraysController>();
    final state = controller.state;
    final bool canSave = state.scannedTrays.isNotEmpty && !state.isLoading;

    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(controller, state, canSave),
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
                        _buildOriginSelectorPanel(controller, state),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SCANNED TRAYS TO RELEASE',
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
                                  onPressed: state.isLoading ? null : () => _onScanTray(controller),
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
                        const TrayTableHeader(showHoldColumn: false),
                        Expanded(
                          child: state.scannedTrays.isEmpty
                              ? const EmptyScanState(hasBorder: false)
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: state.scannedTrays.length,
                                  separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFECEFF1)),
                                  itemBuilder: (ctx, idx) {
                                    final item = state.scannedTrays[idx];
                                    final trayCode = item.primaryTrayModel.trayCode ?? '-';
                                    final itemDesc = item.item.description;
                                    final qty = item.productionProgress.primaryQuantity?.toStringAsFixed(0) ?? '0';

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 32,
                                            child: Text(
                                              '${idx + 1}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF78909C)),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              trayCode,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 5,
                                            child: Text(
                                              itemDesc,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE8F5E9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '$qty tubes',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40,
                                            child: IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                              onPressed: () => controller.removeScannedTray(idx),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
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

  Widget _buildHeader(UnholdTraysController controller, UnholdTraysState state, bool canSave) {
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
                  Text('Unhold Trays', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238))),
                  Text('Release held trays back to process', style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: !canSave ? null : () => _onSave(controller),
              icon: const Icon(Icons.save_rounded, size: 16),
              label: Text('SAVE CHANGES (${state.scannedTrays.length})'),
              style: AppTheme.saveButtonStyle(isEnabled: canSave),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOriginSelectorPanel(UnholdTraysController controller, UnholdTraysState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  'HOLD ORIGIN',
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
                    child: DropdownButton<String>(
                      value: state.selectedOrigin,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'knitting',
                          child: Text('Knitting Production', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238))),
                        ),
                        DropdownMenuItem(
                          value: 'pbs',
                          child: Text('PBS (Processing)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238))),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) controller.changeOrigin(val);
                      },
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
                onPressed: () => _showReferenceHeldTraysDialog(controller, state),
                icon: const Icon(Icons.layers_outlined, size: 16),
                label: Text(
                  'SHOW HOLD (${state.heldTrays.length})',
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
}
