import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/tray_table_header.dart';
import 'package:active_wear_scanning/core/widgets/empty_scan_state.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_color_model.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_machine_model.dart';
import 'package:active_wear_scanning/features/lot_making/controller/lot_making_controller.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_making_state.dart';

class LotMakingScreen extends StatelessWidget {
  final LotHeaderResponseModel? existingBatch;
  final List<ProductionProgressResponseModel>? preloadedTrays;
  final LotMakingController? controller;

  const LotMakingScreen({
    super.key,
    this.existingBatch,
    this.preloadedTrays,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return ChangeNotifierProvider<LotMakingController>.value(
        value: controller!,
        child: const _LotMakingScreenView(),
      );
    }
    return ChangeNotifierProvider<LotMakingController>(
      create: (_) => LotMakingController(
        existingBatch: existingBatch,
        preloadedTrays: preloadedTrays,
      ),
      child: const _LotMakingScreenView(),
    );
  }
}

class _LotMakingScreenView extends StatefulWidget {
  const _LotMakingScreenView();

  @override
  State<_LotMakingScreenView> createState() => _LotMakingScreenViewState();
}

class _LotMakingScreenViewState extends State<_LotMakingScreenView> {
  final List<TextEditingController> _quantityControllers = [];
  final _overrideQuantityController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<LotMakingController>();
      if ((controller.state.isLoading || controller.state.isCachingColors) && !AppLoader.isVisible) {
        AppLoader.show(context, message: 'Loading lot data...');
        while (controller.state.isLoading || controller.state.isCachingColors) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (mounted) AppLoader.hide(context);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _overrideQuantityController.dispose();
    for (final c in _quantityControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers(List<ProductionProgressResponseModel> scannedTrays) {
    if (_quantityControllers.length < scannedTrays.length) {
      final startIndex = _quantityControllers.length;
      for (int i = startIndex; i < scannedTrays.length; i++) {
        _quantityControllers.add(
          TextEditingController(
            text: scannedTrays[i].productionProgress.primaryQuantity?.toStringAsFixed(0) ?? '0',
          ),
        );
      }
    } else if (_quantityControllers.length > scannedTrays.length) {
      for (final c in _quantityControllers) {
        c.dispose();
      }
      _quantityControllers.clear();
      for (final t in scannedTrays) {
        _quantityControllers.add(
          TextEditingController(
            text: t.productionProgress.primaryQuantity?.toStringAsFixed(0) ?? '0',
          ),
        );
      }
    }
  }

  void _onKey(RawKeyEvent event) {
    if (AppLoader.isVisible) {
      _barcodeBuffer = '';
      return;
    }
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

  Future<void> _processBluetoothScan(String scannedCode) async {
    final controller = context.read<LotMakingController>();
    if (controller.state.selectedMachine == null) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: 'Please select a machine first');
      return;
    }
    AppLoader.show(context, message: 'Validating Tray...');
    final double overrideQty = double.tryParse(_overrideQuantityController.text) ?? 0.0;
    final error = await controller.validateTrayForScan(scannedCode, overrideQty);
    AppLoader.hide(context);
    if (error != null) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: error);
    } else {
      HapticFeedbackHelper.scanSuccess();
    }
  }

  Future<void> _onScanTray(LotMakingController controller, LotMakingState state) async {
    if (state.selectedMachine == null) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: 'Please select a machine first');
      return;
    }
    HapticFeedbackHelper.buttonClick();
    await Future.delayed(const Duration(milliseconds: 300));
    // Release the parent's keyboard listener so the dialog's TextField
    // can capture hardware (Bluetooth) scanner key events.
    _focusNode.unfocus();
    final screenContext = context;
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trays',
      onResult: (scannedCode) async {
        final double overrideQty = double.tryParse(_overrideQuantityController.text) ?? 0.0;
        return await controller.validateTrayForScan(scannedCode, overrideQty);
      },
      scannedItemsBuilder: (context) {
        // The dialog runs in a new route — inject the controller so Consumer can find it.
        return ChangeNotifierProvider<LotMakingController>.value(
          value: controller,
          child: Consumer<LotMakingController>(
            builder: (_, latestController, __) {
              final latestState = latestController.state;
              _syncControllers(latestState.scannedTrays);
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
                    const TrayTableHeader(actionColumnWidth: 44, showBatchTubes: true, showDetailedTubes: true, hidePcsColumns: true),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: latestState.scannedTrays.length,
                        itemBuilder: (context, index) {
                          final tray = latestState.scannedTrays[index];
                          final qtys = latestController.getTrayQuantities(tray);
                          final actualVal = qtys['actual']!;
                          final alreadyScannedVal = qtys['alreadyScanned']!;
                          final remainingVal = qtys['remaining']!;
                          final qty = double.tryParse(_quantityControllers[index].text) ?? 0;
                          final weight = qty * (tray.item.pieceWeight ?? 0);

                          const cellStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238));
                          const blueCellStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1B64A3));

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
                              border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 8, child: Text(tray.primaryTrayModel.trayCode ?? 'N/A', textAlign: TextAlign.center, style: blueCellStyle)),
                                Expanded(flex: 4, child: Text(tray.workOrderHeader.workOrderCode ?? 'N/A', textAlign: TextAlign.center, style: cellStyle)),
                                Expanded(flex: 3, child: Text(tray.item.sizeDescription ?? 'N/A', textAlign: TextAlign.center, style: cellStyle)),
                                Expanded(flex: 3, child: Text(actualVal.toStringAsFixed(0), textAlign: TextAlign.center, style: cellStyle)),
                                Expanded(flex: 3, child: Text(alreadyScannedVal.toStringAsFixed(0), textAlign: TextAlign.center, style: cellStyle.copyWith(color: Colors.orange.shade800))),
                                Expanded(flex: 3, child: Text(remainingVal.toStringAsFixed(0), textAlign: TextAlign.center, style: cellStyle.copyWith(color: const Color(0xFF2E7D32)))),
                                Expanded(flex: 4, child: Text('${weight.toStringAsFixed(0)}g', textAlign: TextAlign.center, style: cellStyle)),
                                Expanded(
                                  flex: 4,
                                  child: Container(
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCFD8DC), width: 1.2),
                                    ),
                                    child: TextField(
                                      controller: _quantityControllers[index],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      style: cellStyle.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF1B64A3)),
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                                        isCollapsed: true,
                                        border: InputBorder.none,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        TubesInputFormatter(remainingVal.toInt()),
                                      ],
                                      onChanged: (val) {
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  child: Center(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () async {
                                          final confirm = await showDialog<bool>(
                                            context: screenContext,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Confirm Delete'),
                                              content: const Text('Are you sure you want to delete this tray?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFEF4444),
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            latestController.removeScannedTray(index);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                        ),
                                      ),
                                    ),
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
              );
            },
          ),
        );
      },
    );
    // Re-capture keyboard focus so Bluetooth scanner works on the main screen again.
    if (mounted) _focusNode.requestFocus();
  }

  void _showAvailableTraysDialog(LotMakingController controller, LotMakingState state) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final availableTrays = controller.getTraysForSelectedWorkOrder();
            final woCode = state.selectedWorkOrder?.workOrderCode ?? '';

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AVAILABLE TRAYS COUNT - ${availableTrays.length}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFE67E22)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'WORK ORDER - ${woCode.isNotEmpty ? woCode : 'N/A'}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1B64A3)),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const TrayTableHeader(actionColumnWidth: 0, showLotColumn: true, showDetailedTubes: true, hidePcsColumns: true),
                    Expanded(
                      child: availableTrays.isEmpty
                          ? const Center(
                        child: Text(
                          'No available GBS trays for this work order',
                          style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      )
                          : ListView.builder(
                        itemCount: availableTrays.length,
                        itemBuilder: (ctx, index) {
                          final tray = availableTrays[index];
                          final qtys = controller.getTrayQuantities(tray);
                          final actualVal = qtys['actual']!;
                          final alreadyScannedVal = qtys['alreadyScanned']!;
                          final remainingVal = qtys['remaining']!;
                          final qty = remainingVal;
                          final weight = qty * (tray.item.pieceWeight ?? 0);

                          const cellStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238));
                          const blueCellStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1B64A3));

                          final isScanned = state.scannedTrays.any(
                                (st) => st.productionProgress.id == tray.productionProgress.id,
                          );

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
                              border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 8, child: Text(tray.primaryTrayModel.trayCode ?? 'N/A', textAlign: TextAlign.center, style: blueCellStyle)),
                                Expanded(flex: 4, child: Text(tray.workOrderHeader.workOrderCode ?? 'N/A', textAlign: TextAlign.center, style: cellStyle)),
                                Expanded(flex: 3, child: Text(tray.item.sizeDescription ?? 'N/A', textAlign: TextAlign.center, style: cellStyle)),
                                Expanded(flex: 3, child: Text(actualVal.toStringAsFixed(0), textAlign: TextAlign.center, style: cellStyle)),
                                Expanded(flex: 3, child: Text(alreadyScannedVal.toStringAsFixed(0), textAlign: TextAlign.center, style: cellStyle.copyWith(color: Colors.orange.shade800))),
                                Expanded(flex: 3, child: Text(remainingVal.toStringAsFixed(0), textAlign: TextAlign.center, style: cellStyle.copyWith(color: const Color(0xFF2E7D32)))),
                                Expanded(flex: 4, child: Text('${weight.toStringAsFixed(0)}g', textAlign: TextAlign.center, style: cellStyle)),
                                Expanded(
                                  flex: 6,
                                  child: Text(
                                    isScanned ? state.lotCode : '-',
                                    textAlign: TextAlign.center,
                                    style: cellStyle.copyWith(
                                      color: isScanned ? const Color(0xFF2E7D32) : Colors.grey,
                                      fontWeight: isScanned ? FontWeight.bold : FontWeight.normal,
                                    ),
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
            );
          },
        );
      },
    );
  }

  Future<void> _saveLotChanges(LotMakingController controller, LotMakingState state) async {
    if (state.scannedTrays.isEmpty) return;

    for (int i = 0; i < _quantityControllers.length; i++) {
      final text = _quantityControllers[i].text.trim();
      final val = int.tryParse(text);
      if (val == null || val <= 0) {
        HapticFeedbackHelper.scanError();
        AppSnackBar.showError(context, message: 'Please enter a valid tubes value for all trays.');
        return;
      }
      final maxVal = (state.scannedTrays[i].productionProgress.primaryQuantity ?? 0.0).toInt();
      if (val > maxVal) {
        HapticFeedbackHelper.scanError();
        AppSnackBar.showError(context, message: 'Tubes count cannot exceed tray capacity ($maxVal).');
        return;
      }
    }

    final selectedColorDesc = state.selectedColor?.segmentCode?.description?.trim().toUpperCase();
    if (selectedColorDesc != null) {
      final Map<int, double> lineCumulativeTubes = {};
      for (int i = 0; i < state.scannedTrays.length; i++) {
        final tray = state.scannedTrays[i];
        final lineId = tray.productionProgress.workOrderLineId ?? tray.workOrderLine?.id;
        if (lineId != null) {
          final qty = double.tryParse(_quantityControllers[i].text) ?? 0.0;
          lineCumulativeTubes[lineId] = (lineCumulativeTubes[lineId] ?? 0.0) + qty;
        }
      }

      double exceededMax = 0.0;
      double exceededMaxPlan = 0.0;
      bool exceedsMaxLimit = false;

      for (final lineId in lineCumulativeTubes.keys) {
        final planQty = state.colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
        final sumTubes = lineCumulativeTubes[lineId] ?? 0.0;
        final alreadyAssigned = controller.getAlreadyAssignedTubesForWorkOrderLine(lineId);
        final totalScanned = sumTubes + alreadyAssigned;

        final int extraAllowed = (planQty * 0.1).ceil();
        final double maxAllowed = planQty + extraAllowed;

        if (planQty > 0.0 && totalScanned > maxAllowed) {
          exceedsMaxLimit = true;
          exceededMax = totalScanned;
          exceededMaxPlan = maxAllowed;
          break;
        }
      }

      if (exceedsMaxLimit) {
        HapticFeedbackHelper.scanError();
        AppSnackBar.showError(
          context,
          message: 'Cannot save. Cumulative tube count (${exceededMax.toStringAsFixed(0)}) exceeds the maximum allowed limit with 10% extra allowance (${exceededMaxPlan.toStringAsFixed(0)}) for color "$selectedColorDesc".',
        );
        return;
      }

      bool exceedsColorPlan = false;
      double exceededSum = 0.0;
      double exceededPlan = 0.0;
      for (final lineId in lineCumulativeTubes.keys) {
        final planQty = state.colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
        final sumTubes = lineCumulativeTubes[lineId] ?? 0.0;
        final alreadyAssigned = controller.getAlreadyAssignedTubesForWorkOrderLine(lineId);
        final totalScanned = sumTubes + alreadyAssigned;

        if (planQty > 0.0 && totalScanned > planQty) {
          exceedsColorPlan = true;
          exceededSum = totalScanned;
          exceededPlan = planQty;
          break;
        }
      }

      if (exceedsColorPlan) {
        final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Text('Color Plan Exceeded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                ],
              ),
              content: Text(
                'Cumulative tube count (${exceededSum.toStringAsFixed(0)}) exceeds the plan quantity (${exceededPlan.toStringAsFixed(0)}) for color "$selectedColorDesc". Do you want to proceed?',
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        ) ?? false;

        if (!proceed) return;
      }
    }

    AppLoader.show(context);
    try {
      final List<double> finalQuantities = _quantityControllers.map((c) => double.tryParse(c.text) ?? 0.0).toList();
      await controller.saveLotChanges(finalQuantities);
      if (!mounted) return;
      AppLoader.hide(context);
      HapticFeedbackHelper.scanSuccess();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppLoader.hide(context);
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: e.toString());
    }
  }

  void _updateLoaderState(LotMakingState state) {
    final bool shouldLoad = state.isLoading || state.isCachingColors || state.isLoadingColors;
    if (shouldLoad && !AppLoader.isVisible) {
      AppLoader.show(context, message: 'Loading lot data...');
    } else if (!shouldLoad && AppLoader.isVisible) {
      AppLoader.hide(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LotMakingController>();
    final state = controller.state;
    _syncControllers(state.scannedTrays);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateLoaderState(state);
    });

    final bool isInitialLoading = state.isLoading && state.machines.isEmpty && state.productionProgressTrays.isEmpty;

    return PopScope(
      canPop: !AppLoader.isVisible && !isInitialLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: isInitialLoading
            ? Container(
                color: const Color(0xFFF1F5F9),
                child: const Center(
                  child: SizedBox.shrink(),
                ),
              )
            : RawKeyboardListener(
                focusNode: _focusNode,
                autofocus: true,
                onKey: _onKey,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPremiumHeader(controller, state),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildConfigurationPanel(controller, state),
                                    if (state.selectedColor != null) ...[
                                      const SizedBox(height: 10),
                                      _buildLiveDashboard(controller, state),
                                      const SizedBox(height: 10),
                                      _buildWOSummary(controller, state),
                                      const SizedBox(height: 10),
                                    ],
                                  ],
                                ),
                              ),
                              if (state.selectedColor != null)
                                SliverFillRemaining(
                                  hasScrollBody: true,
                                  child: _buildScannedSection(controller, state),
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
    );
  }

  Widget _buildPremiumHeader(LotMakingController controller, LotMakingState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5, strokeAlign: BorderSide.strokeAlignOutside),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const CustomBackButton(),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Lot Making', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238))),
                  const Text(
                    'SCAN TRAYS TO MAKE LOT',
                    style: TextStyle(fontSize: 9, color: Color(0xFF546E7A), fontWeight: FontWeight.w700, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: (state.selectedMachine != null && state.scannedTrays.isNotEmpty)
                  ? () {
                HapticFeedbackHelper.buttonClick();
                _saveLotChanges(controller, state);
              }
                  : null,
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE LOT'),
              style: AppTheme.saveButtonStyle(
                isEnabled: (state.selectedMachine != null && state.scannedTrays.isNotEmpty),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveDashboard(LotMakingController controller, LotMakingState state) {
    double totalWeightGrams = 0;
    int totalTubes = 0;
    for (int i = 0; i < state.scannedTrays.length; i++) {
      final qty = double.tryParse(_quantityControllers[i].text) ?? 0;
      totalTubes += qty.toInt();
      totalWeightGrams += qty * (state.scannedTrays[i].item.pieceWeight ?? 0);
    }

    final capacityKg = double.tryParse(state.selectedMachine?.resource?.capacity ?? '0') ?? 0;
    final capacityGrams = capacityKg * 1000;
    final allocatedWeightGrams = totalWeightGrams;
    final remainingWeightGrams = capacityGrams - allocatedWeightGrams;

    final String capacityLabel = '${capacityKg.toStringAsFixed(0)} kg';
    final String allocLabel = '${(allocatedWeightGrams / 1000).toStringAsFixed(2)} kg';
    final String remLabel = '${(remainingWeightGrams / 1000).toStringAsFixed(2)} kg';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 16, color: Color(0xFF1B64A3)),
                    SizedBox(width: 8),
                    Text(
                      'LOT SCAN SUMMARY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1B64A3), letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildMetricCard('TRAYS', '${state.scannedTrays.length}', Icons.layers_outlined, const Color(0xFFE67E22)),
                    const SizedBox(width: 6),
                    _buildMetricCard('TUBES', '$totalTubes', Icons.grid_view_rounded, const Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    _buildMetricCard('CAPACITY', capacityLabel, Icons.speed_rounded, const Color(0xFF1B64A3)),
                    const SizedBox(width: 6),
                    _buildMetricCard('ALLOC. WEIGHT', allocLabel, Icons.monitor_weight_outlined, const Color(0xFF8E44AD)),
                    const SizedBox(width: 6),
                    _buildMetricCard('REM. WEIGHT', remLabel, Icons.hourglass_empty_rounded, const Color(0xFF00796B)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF78909C), letterSpacing: 0.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationPanel(LotMakingController controller, LotMakingState state) {
    final availableWOs = controller.getFilteredWorkOrders();
    final availableColors = controller.getFilteredColors();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF1B64A3)),
                    const SizedBox(width: 8),
                    const Text(
                      'LOT CONFIGURATION',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1B64A3), letterSpacing: 0.5),
                    ),
                    const Spacer(),
                    if (state.isCachingColors)
                      const SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B64A3)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MACHINE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF78909C), letterSpacing: 0.5)),
                              const SizedBox(height: 6),
                              _LotOverlayDropdown<LotMachineModel>(
                                hint: "Select machine...",
                                items: state.machines,
                                selectedValue: state.selectedMachine,
                                itemLabel: (m) => m.resource?.brand ?? 'Unknown',
                                isReadOnly: state.scannedTrays.isNotEmpty,
                                onChanged: (val) {
                                  HapticFeedbackHelper.buttonClick();
                                  controller.selectMachine(val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: state.selectedMachine == null
                              ? const SizedBox.shrink()
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('WORK ORDER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF78909C), letterSpacing: 0.5)),
                              const SizedBox(height: 6),
                              _LotOverlayDropdown<WorkOrderHeader>(
                                hint: "Select work order...",
                                items: availableWOs,
                                selectedValue: state.selectedWorkOrder,
                                itemLabel: (wo) => wo.workOrderCode ?? '-',
                                isReadOnly: false,
                                onChanged: (val) async {
                                  HapticFeedbackHelper.buttonClick();
                                  AppLoader.show(context, message: 'Loading color details...');
                                  await controller.selectWorkOrder(val);
                                  if (context.mounted) AppLoader.hide(context);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (state.selectedWorkOrder != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('COLOR', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF78909C), letterSpacing: 0.5)),
                                const SizedBox(height: 6),
                                _LotOverlayDropdown<LotColorModel>(
                                  hint: "Select color...",
                                  items: availableColors,
                                  selectedValue: state.selectedColor,
                                  itemLabel: (c) => c.segmentCode?.description ?? '-',
                                  isReadOnly: state.scannedTrays.isNotEmpty,
                                  onChanged: (val) {
                                    HapticFeedbackHelper.buttonClick();
                                    controller.selectColor(val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: state.selectedColor == null
                                ? const SizedBox.shrink()
                                : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showAvailableTraysDialog(controller, state),
                                    icon: const Icon(Icons.layers_outlined, size: 16),
                                    label: const Text(
                                      'SHOW AVAILABLE TRAYS',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE67E22),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannedSection(LotMakingController controller, LotMakingState state) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Container(
          color: Colors.white,
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
                    const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFE67E22), size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'SCANNED TRAYS LIST',
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
                          onPressed: () {
                            HapticFeedbackHelper.buttonClick();
                            _onScanTray(controller, state);
                          },
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                          label: const Text('SCAN TRAY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildCapacityProgress(state),
                      const SizedBox(height: 10),
                      const TrayTableHeader(actionColumnWidth: 44, showBatchTubes: true, showDetailedTubes: true, hidePcsColumns: true),
                      Expanded(
                        child: state.scannedTrays.isEmpty
                            ? const EmptyScanState(hasBorder: false)
                            : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: state.scannedTrays.length,
                          itemBuilder: (ctx, idx) => _buildTrayRow(controller, state, idx),
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
    );
  }

  Widget _buildCapacityProgress(LotMakingState state) {
    final capacityKg = double.tryParse(state.selectedMachine?.resource?.capacity ?? '0') ?? 0;
    final capacityGrams = capacityKg * 1000;

    double allocatedWeightGrams = 0;
    for (int i = 0; i < state.scannedTrays.length; i++) {
      final tray = state.scannedTrays[i];
      final qty = double.tryParse(_quantityControllers[i].text) ?? 0;
      allocatedWeightGrams += qty * (tray.item.pieceWeight ?? 0);
    }

    final progress = capacityGrams > 0 ? (allocatedWeightGrams / capacityGrams) : 0.0;
    final percentage = (progress * 100).clamp(0, 100).toInt();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MACHINE LOAD / CAPACITY',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF546E7A), letterSpacing: 0.5),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: progress > 0.9 ? Colors.red : const Color(0xFF1B64A3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress > 0.9 ? Colors.red : (progress > 0.7 ? Colors.orange : const Color(0xFF2E7D32)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrayRow(LotMakingController controller, LotMakingState state, int index) {
    final tray = state.scannedTrays[index];
    final qtys = controller.getTrayQuantities(tray);
    final actualVal = qtys['actual']!;
    final alreadyScannedVal = qtys['alreadyScanned']!;
    final remainingVal = qtys['remaining']!;
    final qty = double.tryParse(_quantityControllers[index].text) ?? 0;
    final weight = qty * (tray.item.pieceWeight ?? 0);

    const cellStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238));
    const blueCellStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1B64A3));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(flex: 8, child: Text(tray.primaryTrayModel.trayCode ?? 'N/A', textAlign: TextAlign.center, style: blueCellStyle)),
          Expanded(flex: 4, child: Text(tray.workOrderHeader.workOrderCode ?? 'N/A', textAlign: TextAlign.center, style: cellStyle)),
          Expanded(flex: 3, child: Text(tray.item.sizeDescription ?? 'N/A', textAlign: TextAlign.center, style: cellStyle)),
          Expanded(flex: 3, child: Text(actualVal.toStringAsFixed(0), textAlign: TextAlign.center, style: cellStyle)),
          Expanded(flex: 3, child: Text(alreadyScannedVal.toStringAsFixed(0), textAlign: TextAlign.center, style: cellStyle.copyWith(color: Colors.orange.shade800))),
          Expanded(flex: 3, child: Text(remainingVal.toStringAsFixed(0), textAlign: TextAlign.center, style: cellStyle.copyWith(color: const Color(0xFF2E7D32)))),
          Expanded(flex: 4, child: Text('${weight.toStringAsFixed(0)}g', textAlign: TextAlign.center, style: cellStyle)),
          Expanded(
            flex: 4,
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCFD8DC), width: 1.2),
              ),
              child: TextField(
                controller: _quantityControllers[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: cellStyle.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF1B64A3)),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                  isCollapsed: true,
                  border: InputBorder.none,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TubesInputFormatter(remainingVal.toInt()),
                ],
                onChanged: (val) => setState(() {}),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Delete'),
                        content: const Text('Are you sure you want to delete this tray?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      controller.removeScannedTray(index);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade400),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWOSummary(LotMakingController controller, LotMakingState state) {
    if (state.selectedColor == null || state.selectedWorkOrder == null) {
      return const SizedBox.shrink();
    }

    final selectedColorDesc = state.selectedColor?.segmentCode?.description?.trim().toUpperCase();
    if (selectedColorDesc == null) return const SizedBox.shrink();

    final allEligibleTrays = controller.getTraysForSelectedWorkOrderAndColor();
    final Map<String, Map<String, dynamic>> woGroups = {};

    for (final tray in allEligibleTrays) {
      final code = tray.workOrderHeader.workOrderCode ?? 'Unknown WO';
      final itemDesc = tray.item.description ?? 'N/A';
      final sizeDesc = tray.item.sizeDescription ?? 'N/A';
      final lineId = tray.productionProgress.workOrderLineId ?? tray.workOrderLine?.id;
      final groupKey = "${code}_${itemDesc}_${sizeDesc}";

      if (!woGroups.containsKey(groupKey)) {
        double planQty = 0.0;
        if (lineId != null) {
          planQty = state.colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
        }
        woGroups[groupKey] = {
          'code': code,
          'item': itemDesc,
          'size': sizeDesc,
          'trays': 0,
          'tubes': 0.0,
          'weight': 0.0,
          'planQty': planQty,
          'lineId': lineId,
        };
      }
    }

    for (int i = 0; i < state.scannedTrays.length; i++) {
      final tray = state.scannedTrays[i];
      final qty = double.tryParse(_quantityControllers[i].text) ?? 0;
      final code = tray.workOrderHeader.workOrderCode ?? 'Unknown WO';
      final itemDesc = tray.item.description ?? 'N/A';
      final sizeDesc = tray.item.sizeDescription ?? 'N/A';
      final lineId = tray.productionProgress.workOrderLineId ?? tray.workOrderLine?.id;
      final groupKey = "${code}_${itemDesc}_${sizeDesc}";

      final weight = qty * (tray.item.pieceWeight ?? 0);

      if (!woGroups.containsKey(groupKey)) {
        double planQty = 0.0;
        if (lineId != null) {
          planQty = state.colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
        }
        woGroups[groupKey] = {
          'code': code,
          'item': itemDesc,
          'size': sizeDesc,
          'trays': 0,
          'tubes': 0.0,
          'weight': 0.0,
          'planQty': planQty,
          'lineId': lineId,
        };
      }

      woGroups[groupKey]!['trays'] = (woGroups[groupKey]!['trays'] as int) + 1;
      woGroups[groupKey]!['tubes'] = (woGroups[groupKey]!['tubes'] as double) + qty;
      woGroups[groupKey]!['weight'] = (woGroups[groupKey]!['weight'] as double) + weight;
    }

    if (woGroups.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.summarize_rounded, size: 16, color: Color(0xFF1B64A3)),
                    SizedBox(width: 8),
                    Text(
                      'WORK ORDER SUMMARY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1B64A3), letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(0),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.5),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(6.0),
                    3: FlexColumnWidth(1.8),
                    4: FlexColumnWidth(2.0),
                    5: FlexColumnWidth(1.8),
                    6: FlexColumnWidth(1.8),
                    7: FlexColumnWidth(2.0),
                    8: FlexColumnWidth(2.2),
                    9: FlexColumnWidth(1.8),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                      children: [
                        _buildTableHeaderCell('WORK ORDER'),
                        _buildTableHeaderCell('SIZE'),
                        _buildTableHeaderCell('ITEM DESCRIPTION'),
                        _buildTableHeaderCell('SCANNED TRAYS'),
                        _buildTableHeaderCell('SCANNED TUBES'),
                        _buildTableHeaderCell('PLAN TUBES'),
                        _buildTableHeaderCell('MAX TUBES'),
                        _buildTableHeaderCell('ASSIGNED TUBES'),
                        _buildTableHeaderCell('REMAINING TUBES'),
                        _buildTableHeaderCell('WEIGHT'),
                      ],
                    ),
                    ...woGroups.values.map((data) {
                      final planVal = data['planQty'] as double;
                      final planStr = planVal > 0.0 ? planVal.toStringAsFixed(0) : '-';
                      final int extraAllowed = (planVal * 0.1).ceil();
                      final double maxAllowed = planVal + extraAllowed;
                      final maxStr = planVal > 0.0 ? maxAllowed.toStringAsFixed(0) : '-';

                      final lineId = data['lineId'] as int?;
                      final double assigned = lineId != null ? controller.getAlreadyAssignedTubesForWorkOrderLine(lineId) : 0.0;
                      final currentTubes = data['tubes'] as double;
                      final double totalScanned = currentTubes + assigned;
                      final double remTubes = planVal > 0.0 ? (planVal - totalScanned) : 0.0;
                      final remStr = planVal > 0.0 ? remTubes.toStringAsFixed(0) : '-';
                      final weightVal = (data['weight'] as double);

                      return TableRow(
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFECEFF1), width: 1))),
                        children: [
                          _buildTableCell(data['code'].toString(), isBold: true),
                          _buildTableCell(data['size'].toString()),
                          _buildTableCell(data['item'].toString()),
                          _buildTableCell(data['trays'].toString()),
                          _buildTableCell(currentTubes.toStringAsFixed(0)),
                          _buildTableCell(planStr),
                          _buildTableCell(maxStr),
                          _buildTableCell(assigned > 0.0 ? assigned.toStringAsFixed(0) : '0'),
                          _buildTableCell(remStr),
                          _buildTableCell("${weightVal.toStringAsFixed(0)}g"),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF546E7A)),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: const Color(0xFF263238)),
      ),
    );
  }
}

class _LotOverlayDropdown<T> extends StatefulWidget {
  final String hint;
  final List<T> items;
  final T? selectedValue;
  final String Function(T) itemLabel;
  final String Function(T)? itemLabelInList;
  final ValueChanged<T?> onChanged;
  final bool isReadOnly;

  const _LotOverlayDropdown({
    required this.hint,
    required this.items,
    required this.selectedValue,
    required this.itemLabel,
    this.itemLabelInList,
    required this.onChanged,
    this.isReadOnly = false,
  });

  @override
  State<_LotOverlayDropdown<T>> createState() => _LotOverlayDropdownState<T>();
}

class _LotOverlayDropdownState<T> extends State<_LotOverlayDropdown<T>> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _rotateAnimation;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _overlayEntry?.remove();
    _controller.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (widget.isReadOnly) return;
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
      _controller.forward();
    });
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isOpen = false;
      _searchQuery = '';
      _searchController.clear();
      _controller.reverse();
    });
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeDropdown, child: Container()),
          ),
          Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: Material(elevation: 0, color: Colors.transparent, child: _buildDropdownMenu()),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Opacity(
        opacity: widget.isReadOnly ? 0.6 : 1.0,
        child: GestureDetector(
          onTap: _toggleDropdown,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _isOpen ? const Color(0xFF1B64A3) : const Color(0xFFCFD8DC), width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: widget.selectedValue == null
                      ? Text(widget.hint, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w400))
                      : Text(widget.itemLabel(widget.selectedValue as T), style: const TextStyle(color: Color(0xFF263238), fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                RotationTransition(
                  turns: _rotateAnimation,
                  child: Icon(Icons.arrow_drop_down_rounded, color: _isOpen ? const Color(0xFF1B64A3) : const Color(0xFF546E7A), size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownMenu() {
    final filteredItems = widget.items.where((item) {
      final label = (widget.itemLabelInList != null ? widget.itemLabelInList!(item) : widget.itemLabel(item)).toLowerCase();
      final query = _searchQuery.toLowerCase();
      return label.contains(query);
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 8))],
        border: Border.all(color: const Color(0xFFCFD8DC), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
                _overlayEntry?.markNeedsBuild();
              },
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              decoration: InputDecoration(
                hintText: "Search...",
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCFD8DC))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCFD8DC))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1B64A3))),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFCFD8DC)),
          Flexible(
            child: filteredItems.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No results found', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
                : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: filteredItems.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                final isSelected = item == widget.selectedValue;

                return InkWell(
                  onTap: () {
                    widget.onChanged(item);
                    _closeDropdown();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.itemLabelInList != null ? widget.itemLabelInList!(item) : widget.itemLabel(item),
                            style: TextStyle(color: isSelected ? const Color(0xFF1B64A3) : const Color(0xFF263238), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isSelected) const Icon(Icons.check_rounded, color: Color(0xFF1B64A3), size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TubesInputFormatter extends TextInputFormatter {
  final int maxTubes;

  TubesInputFormatter(this.maxTubes);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final parsed = int.tryParse(newValue.text);
    if (parsed == null) return oldValue;
    if (parsed == 0 || newValue.text.startsWith('0')) return oldValue;
    if (parsed > maxTubes) return oldValue;

    return newValue;
  }
}
