import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/utils/barcode_buffer_parser.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/features/lapping/presentation/widgets/lapping_scanner_ui.dart';
import 'package:active_wear_scanning/features/lapping/presentation/widgets/lapping_tray_table.dart';
import 'package:active_wear_scanning/features/lapping/presentation/widgets/work_order_selection_card.dart';
import 'package:active_wear_scanning/features/lapping/controller/lapping_controller.dart';
import 'package:active_wear_scanning/features/lapping/model/lapping_state.dart';
import 'package:active_wear_scanning/features/lapping/model/work_order_summary.dart';

class LappingDetailScreen extends StatelessWidget {
  final int batchHeaderId;
  final String batchCode;
  final int? machineId;
  final String machine;
  final String color;
  final int trayCount;
  final double totalWeight;
  final int currentOperationId;
  final int? nextOperationId;
  final String nextOperationName;

  const LappingDetailScreen({
    super.key,
    required this.batchHeaderId,
    required this.batchCode,
    required this.machineId,
    required this.machine,
    required this.color,
    required this.trayCount,
    required this.totalWeight,
    required this.currentOperationId,
    this.nextOperationId,
    required this.nextOperationName,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LappingController>(
      create: (_) => LappingController(
        batchHeaderId: batchHeaderId,
        batchCode: batchCode,
        machineId: machineId,
        machine: machine,
        color: color,
        trayCount: trayCount,
        totalWeight: totalWeight,
        currentOperationId: currentOperationId,
        nextOperationId: nextOperationId,
        nextOperationName: nextOperationName,
      ),
      child: const _LappingDetailScreenView(),
    );
  }
}

class _LappingDetailScreenView extends StatefulWidget {
  const _LappingDetailScreenView();

  @override
  State<_LappingDetailScreenView> createState() => _LappingDetailScreenViewState();
}

class _LappingDetailScreenViewState extends State<_LappingDetailScreenView> {
  final _trayQtyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _barcodeParser = BarcodeBufferParser();

  bool _isScannerOpen = false;

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _focusNode.dispose();
    _trayQtyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  bool _onHardwareKey(KeyEvent event) {
    if (_isScannerOpen) return false;
    return _barcodeParser.handleKey(event, _processBluetoothScan);
  }

  Future<void> _processBluetoothScan(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return;

    final controller = context.read<LappingController>();
    if (controller.state.selectedWorkOrderId == null) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: 'Please select a Work Order first');
      return;
    }

    if (_trayQtyController.text.trim().isEmpty) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: 'Please enter number of tubes before scanning!');
      return;
    }
    final double inputPcs = double.tryParse(_trayQtyController.text) ?? 0;
    if (inputPcs <= 0) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: 'Tubes amount must be greater than 0!');
      return;
    }

    AppLoader.show(context, message: 'Validating Tray...');
    final error = await controller.onTrayScanned(code, inputPcs);
    if (!mounted) return;
    AppLoader.hide(context);

    if (error != null) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: error);
    } else {
      HapticFeedbackHelper.scanSuccess();
    }
  }

  Future<void> _showAvailableTraysDialog(LappingController controller, LappingState state) async {
    if (state.selectedWorkOrderId == null) {
      AppSnackBar.showError(context, message: 'Please select a Work Order first');
      return;
    }

    if (mounted) AppLoader.show(context, message: 'Loading available trays...');
    try {
      await controller.fetchAvailableTrays(isRefresh: true);
      if (!mounted) return;
      AppLoader.hide(context);

      final scrollController = ScrollController();
      final searchController = TextEditingController();

      scrollController.addListener(() {
        if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 50) {
          controller.fetchMoreAvailableTrays();
        }
      });

      showDialog(
        context: context,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final availableTrays = controller.getFilteredAvailableTrays(searchController.text);
                  final isLoadingMore = controller.isLoadingMoreAvailableTrays;

                  // Collect all scanned tray codes across all work orders in current session
                  final scannedTrayCodes = <String>{};
                  for (final list in state.scannedTraysByWO.values) {
                    for (final t in list) {
                      final code = t.primaryTrayModel.trayCode?.trim().toUpperCase();
                      if (code != null && code.isNotEmpty) {
                        scannedTrayCodes.add(code);
                      }
                    }
                  }

                  return Dialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 520, maxWidth: 440),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Header ──────────────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE67E22).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.layers_rounded, color: Color(0xFFE67E22), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'AVAILABLE TRAYS (${availableTrays.length})',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(dialogCtx),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ── Search Input ────────────────────────────────────
                          TextField(
                            controller: searchController,
                            onChanged: (_) => setDialogState(() {}),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Search tray code...',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                              suffixIcon: searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                      onPressed: () {
                                        searchController.clear();
                                        setDialogState(() {});
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE67E22), width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),

                          // ── Trays List ──────────────────────────────────────
                          Expanded(
                            child: availableTrays.isEmpty && !isLoadingMore
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 24.0),
                                      child: Text(
                                        'No available reusable trays found',
                                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    controller: scrollController,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    itemCount: availableTrays.length + (isLoadingMore ? 1 : 0),
                                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (context, idx) {
                                      if (idx == availableTrays.length) {
                                        return const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: Center(
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        );
                                      }
                                      final rawCode = availableTrays[idx].trayDetails?.trayCode ?? '';
                                      final code = rawCode.trim().toUpperCase();
                                      final isAlreadyScanned = scannedTrayCodes.contains(code);

                                      return Container(
                                        color: isAlreadyScanned ? const Color(0xFFF8FAFC) : Colors.transparent,
                                        child: ListTile(
                                          dense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          enabled: !isAlreadyScanned,
                                          leading: Icon(
                                            Icons.inventory_2_outlined,
                                            color: isAlreadyScanned ? const Color(0xFF94A3B8) : const Color(0xFF1B64A3),
                                            size: 20,
                                          ),
                                          title: Text(
                                            'Tray $code',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: isAlreadyScanned ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                                              decoration: isAlreadyScanned ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          trailing: isAlreadyScanned
                                              ? Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE2E8F0),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'SCANNED',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF64748B),
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE8F5E9),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'REUSABLE',
                                                    style: TextStyle(
                                                      color: Color(0xFF2E7D32),
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                          onTap: isAlreadyScanned
                                              ? null
                                              : () async {
                                                  Navigator.pop(dialogCtx);
                                                  if (_trayQtyController.text.trim().isEmpty) {
                                                    _focusNode.requestFocus();
                                                    AppSnackBar.showError(
                                                      context,
                                                      message: 'Please enter tubes count to scan tray $code',
                                                    );
                                                  } else {
                                                    await _processBluetoothScan(rawCode);
                                                  }
                                                },
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
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        AppLoader.hide(context);
        AppSnackBar.showError(context, message: e.toString());
      }
    }
  }

  void _openScanner(LappingController controller, LappingState state) async {
    HapticFeedbackHelper.buttonClick();
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() => _isScannerOpen = true);
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Tray',
      onResult: (scannedCode) async {
        if (_trayQtyController.text.trim().isEmpty) return 'Please enter number of tubes before scanning!';
        final double inputPcs = double.tryParse(_trayQtyController.text) ?? 0;
        if (inputPcs <= 0) return 'Tubes amount must be greater than 0!';
        return await controller.onTrayScanned(scannedCode, inputPcs);
      },
      scannedItemsBuilder: (context) {
        return ChangeNotifierProvider<LappingController>.value(
          value: controller,
          child: Consumer<LappingController>(
            builder: (context, latestController, __) {
              final latestState = latestController.state;
              final currentWOTrays = latestState.selectedWorkOrderId != null ? (latestState.scannedTraysByWO[latestState.selectedWorkOrderId!] ?? []) : [];
              if (currentWOTrays.isEmpty) {
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
                child: LappingTrayTable(
                  selectedWorkOrderId: latestState.selectedWorkOrderId,
                  scannedTraysByWO: latestState.scannedTraysByWO,
                  trayOverrideQuantities: latestState.trayOverrideQuantities,
                  onRemove: (t, trayKey) {
                    latestController.removeScannedTray(t, trayKey);
                  },
                ),
              );
            },
          ),
        );
      },
    );
    if (mounted) {
      setState(() => _isScannerOpen = false);
      _focusNode.requestFocus();
    }
  }

  Future<void> _onSaveDraft(BuildContext context, LappingController controller) async {
    AppLoader.show(context, message: 'Saving draft to database...');
    try {
      await controller.saveChanges(isDraft: true);
      if (!context.mounted) return;
      AppLoader.hide(context);
      HapticFeedbackHelper.scanSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      AppLoader.hide(context);
      HapticFeedbackHelper.scanError();
      _showInfoDialog('Save Draft Error', e.toString());
    }
  }

  Future<void> _onSubmit(LappingController controller) async {
    AppLoader.show(context, message: 'Submitting changes...');
    try {
      await controller.saveChanges();
      if (!mounted) return;
      AppLoader.hide(context);
      HapticFeedbackHelper.scanSuccess();
      _showInfoDialog('Success', 'Trays successfully submitted to next operation.', isSuccess: true, onDismiss: () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      if (!mounted) return;
      AppLoader.hide(context);
      HapticFeedbackHelper.scanError();
      _showInfoDialog('Save Changes Error', e.toString());
    }
  }

  void _showInfoDialog(String title, String message, {bool isSuccess = false, VoidCallback? onDismiss}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: isSuccess ? Colors.green : Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (onDismiss != null) onDismiss();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showWasteDialog(BuildContext context, LappingController controller, WorkOrderSummary wo) {
    final compositeId = wo.id;
    final double originalQty = wo.originalPieces;
    final double reassignedQty = (controller.state.scannedTraysByWO[compositeId] ?? []).fold<double>(
      0.0,
      (sum, t) => sum + (controller.state.trayOverrideQuantities[t.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0.0),
    );
    final double currentWaste = controller.state.itemWasteQuantities[compositeId] ?? 0.0;

    // Suggest difference as default waste if current waste is 0
    final double suggestedWaste = currentWaste > 0 ? currentWaste : (originalQty - reassignedQty > 0 ? originalQty - reassignedQty : 0.0);

    final txtController = TextEditingController(text: suggestedWaste > 0 ? suggestedWaste.toInt().toString() : '0');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final double enteredWaste = double.tryParse(txtController.text) ?? 0.0;
            final double totalQty = reassignedQty + enteredWaste;
            final bool isMatch = totalQty == originalQty;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE67E22).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFE67E22), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Manage Line Waste',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    wo.componentDescription,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),

                      // Body
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Quantity Context Card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                              ),
                              child: Column(
                                children: [
                                  _buildWasteInfoRow('Incoming (Prev. Process):', '${originalQty.toInt()} tubes'),
                                  const SizedBox(height: 8),
                                  _buildWasteInfoRow('Reassigned (Scanned):', '${reassignedQty.toInt()} tubes'),
                                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                                  _buildWasteInfoRow(
                                    'Current Sum:',
                                    '${totalQty.toInt()} tubes',
                                    valueColor: isMatch ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    isBold: true,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            const Text(
                              'WASTAGE TUBES',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 8),

                            // Stepper input
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.remove_rounded, color: Color(0xFF1E293B)),
                                    onPressed: () {
                                      final cur = int.tryParse(txtController.text) ?? 0;
                                      if (cur > 0) {
                                        txtController.text = (cur - 1).toString();
                                        setStateDialog(() {});
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: txtController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                      isDense: true,
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      setStateDialog(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.add_rounded, color: Color(0xFF1E293B)),
                                    onPressed: () {
                                      final cur = int.tryParse(txtController.text) ?? 0;
                                      txtController.text = (cur + 1).toString();
                                      setStateDialog(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Validation Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isMatch ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isMatch ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isMatch ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                    size: 16,
                                    color: isMatch ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isMatch
                                          ? 'Total quantity matches incoming (${originalQty.toInt()} tubes).'
                                          : 'Total (${totalQty.toInt()}) must equal incoming (${originalQty.toInt()}). Diff: ${(originalQty - totalQty).toInt()}',
                                      style: TextStyle(
                                        color: isMatch ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Footer Actions
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                        ),
                        child: Row(
                          children: [
                            if (currentWaste > 0 || controller.state.itemWasteProgressIds[compositeId] != null) ...[
                              OutlinedButton.icon(
                                onPressed: () {
                                  controller.setWasteQuantity(compositeId, 0.0);
                                  Navigator.of(ctx).pop();
                                },
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 16),
                                label: const Text('Delete Waste', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              const Spacer(),
                            ] else ...[
                              const Spacer(),
                            ],
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                final double wasteVal = double.tryParse(txtController.text) ?? 0.0;
                                controller.setWasteQuantity(compositeId, wasteVal);
                                Navigator.of(ctx).pop();
                              },
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Save Waste', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D47A1),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWasteInfoRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ?? const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LappingController>();
    final state = controller.state;

    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPremiumHeader(controller, state),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            flex: 5,
                            fit: FlexFit.loose,
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (state.scannedTraysByWO.values.any((list) => list.any((t) => t.productionProgress.pbsFlag == true))) ...[
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.drafts_outlined, color: Color(0xFF1D4ED8), size: 18),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Editing Draft State: Work progress loaded from server.',
                                                style: TextStyle(
                                                  color: Color(0xFF1E40AF),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    _buildProcessFlowRibbon(controller),
                                    const SizedBox(height: 16),
                                    _buildAeroIntelligenceGrid(controller),
                                    const SizedBox(height: 16),
                                    Container(
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
                                      child: WorkOrderSelectionCard(
                                        workOrders: state.workOrders,
                                        selectedWorkOrderId: state.selectedWorkOrderId,
                                        scannedTraysByWO: state.scannedTraysByWO,
                                        trayOverrideQuantities: state.trayOverrideQuantities,
                                        itemWasteQuantities: state.itemWasteQuantities,
                                        onSelected: (val) => controller.setSelectedWorkOrderId(val),
                                        onAddWaste: (wo) => _showWasteDialog(context, controller, wo),
                                        onDeleteWaste: (compositeId) => controller.setWasteQuantity(compositeId, 0.0),
                                      ),
                                    ),
                                    if (state.selectedWorkOrderId != null) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 40,
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _showAvailableTraysDialog(controller, state),
                                          icon: const Icon(Icons.layers_outlined, size: 16),
                                          label: const Text(
                                            'SHOW AVAILABLE TRAYS',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFE67E22),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (state.selectedWorkOrderId != null)
                            Expanded(
                              flex: 4,
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      LappingScannerUI(
                                        selectedWorkOrderId: state.selectedWorkOrderId,
                                        scannedTraysByWO: state.scannedTraysByWO,
                                        trayQtyController: _trayQtyController,
                                        focusNode: _focusNode,
                                        onScanPressed: () => _openScanner(controller, state),
                                      ),
                                      Expanded(
                                        child: Builder(
                                          builder: (_) {
                                            final traysToShow = state.scannedTraysByWO[state.selectedWorkOrderId] ?? [];
                                            if (traysToShow.isNotEmpty) {
                                              return LappingTrayTable(
                                                selectedWorkOrderId: state.selectedWorkOrderId,
                                                scannedTraysByWO: state.scannedTraysByWO,
                                                trayOverrideQuantities: state.trayOverrideQuantities,
                                                onRemove: (t, trayKey) {
                                                  controller.removeScannedTray(t, trayKey);
                                                },
                                              );
                                            } else {
                                              return Container(
                                                width: double.infinity,
                                                alignment: Alignment.center,
                                                padding: const EdgeInsets.all(20),
                                                child: Text(
                                                  'No scanned trays yet. Start by scanning a tray barcode.',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade400,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              );
                                            }
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(LappingController controller, LappingState state) {
    final retryMode = state.failedHandoverTrayIds.isNotEmpty || state.failedCloseLappingIds.isNotEmpty;
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
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lapping Processing',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'LOT: ${controller.batchCode}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            if (!retryMode) ...[
              ElevatedButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () {
                        HapticFeedbackHelper.buttonClick();
                        _onSaveDraft(context, controller);
                      },
                icon: const Icon(Icons.drafts_rounded, size: 16),
                label: const Text('SAVE DRAFT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade200,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () {
                      HapticFeedbackHelper.buttonClick();
                      _onSubmit(controller);
                    },
              icon: Icon(
                retryMode ? Icons.replay_rounded : Icons.check_circle_rounded,
                size: 16,
              ),
              label: Text(
                retryMode
                    ? 'RETRY HANDOVER (${state.failedHandoverTrayIds.length + state.failedCloseLappingIds.length})'
                    : 'SUBMIT BATCH',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: retryMode
                    ? const Color(0xFFE65100)
                    : const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: Colors.grey.shade200,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessFlowRibbon(LappingController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B64A3), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B64A3).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildProcessNode('CURRENT', 'LAPPING', Icons.settings_suggest_rounded, true),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Divider(color: Colors.white38, thickness: 1.5),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
          _buildProcessNode('NEXT', controller.nextOperationName, Icons.arrow_forward_rounded, false),
        ],
      ),
    );
  }

  Widget _buildProcessNode(String label, String value, IconData icon, bool isActive) {
    return Column(
      crossAxisAlignment: isActive ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) Icon(icon, color: Colors.white, size: 16),
            if (isActive) const SizedBox(width: 8),
            Text(value.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
            if (!isActive) const SizedBox(width: 8),
            if (!isActive) Icon(icon, color: Colors.white60, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildAeroIntelligenceGrid(LappingController controller) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 3.8,
      children: [
        _buildHUDCard('LOT #', controller.batchCode, Icons.tag_rounded),
        _buildHUDCard('MACHINE', controller.machine, Icons.precision_manufacturing_rounded),
        _buildHUDCard('COLOR', controller.color, Icons.palette_rounded),
        _buildHUDCard('OPERATION', 'LAPPING', Icons.account_tree_rounded),
        _buildHUDCard('TRAYS', '${controller.trayCount} UNITS', Icons.inventory_2_rounded),
        _buildHUDCard('WEIGHT', '${controller.totalWeight.toStringAsFixed(1)} g', Icons.scale_rounded),
      ],
    );
  }

  Widget _buildHUDCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}