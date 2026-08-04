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
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/features/carton_packing/model/carton_packing_scanned_item.dart';
import 'package:active_wear_scanning/features/carton_packing/presentation/widgets/carton_packing_row.dart';
import 'package:active_wear_scanning/features/carton_packing/controller/carton_packing_controller.dart';
import 'package:active_wear_scanning/features/carton_packing/model/carton_packing_state.dart';

class CartonPackingScreen extends StatelessWidget {
  const CartonPackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CartonPackingController>(
      create: (_) => CartonPackingController(),
      child: const _CartonPackingScreenView(),
    );
  }
}

class _CartonPackingScreenView extends StatefulWidget {
  const _CartonPackingScreenView();

  @override
  State<_CartonPackingScreenView> createState() => _CartonPackingScreenViewState();
}

class _CartonPackingScreenViewState extends State<_CartonPackingScreenView> {
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
    final controller = context.read<CartonPackingController>();
    AppLoader.show(context, message: 'Validating Carton unique ID...');
    final error = await controller.validateCartonForScan(scannedCode);
    if (!mounted) return;
    AppLoader.hide(context);

    if (error != null) {
      _showError(error);
    } else {
      HapticFeedbackHelper.scanSuccess();
    }
  }

  Future<void> _onScanCarton(CartonPackingController controller, CartonPackingState state) async {
    setState(() => _isScannerOpen = true);
    await ScannerAlwaysOpen.show(
      context,
      title: 'Carton Packing Scan',
      onResult: (scannedCode) async {
        return controller.validateCartonForScan(scannedCode);
      },
      scannedItemsBuilder: (context) {
        return ChangeNotifierProvider<CartonPackingController>.value(
          value: controller,
          child: Consumer<CartonPackingController>(
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
                    _buildCartonTableHeader(),
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
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Delete'),
                                  content: const Text('Are you sure you want to delete this carton?'),
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
                                latestController.removeScannedCarton(reversedIndex);
                              }
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

  Future<void> _onSave(CartonPackingController controller, CartonPackingState state) async {
    HapticFeedbackHelper.buttonClick();
    AppLoader.show(context, message: 'Saving carton packing logs & WIP transactions...');
    try {
      await controller.saveCartonPackingData();
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

  String _getUomString(int uomValue) {
    switch (uomValue) {
      case 0:
        return 'Pack';
      case 1:
        return 'Pc';
      case 2:
        return 'Kg';
      case 3:
        return 'No';
      case 4:
        return 'Tube';
      case 5:
        return 'CM';
      case 6:
        return 'M';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CartonPackingController>();
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

  Widget _buildPremiumHeader(CartonPackingController controller, CartonPackingState state) {
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
                  Text('Carton Packing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238))),
                  Text('Modular Carton Packing HUD', style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.3)),
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

  Widget _buildMainContentSection(CartonPackingController controller, CartonPackingState state) {
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
                    const Text('SCANNED CARTONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5)),
                    Text('${state.scannedCartons.length} Total Cartons', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF78909C))),
                  ],
                ),
                SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () => _onScanCarton(controller, state),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('SCAN CARTON', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
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
            _buildSaleOrderMasterCard(state),
            const Divider(height: 1, color: Color(0xFFCFD8DC), thickness: 1.5),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('CARTON GROUP SPECIFICATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5)),
            ),
            Expanded(
              flex: 4,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: state.activeCartonGroups.length,
                itemBuilder: (context, index) {
                  final group = state.activeCartonGroups[index];
                  final isExpanded = state.expandedGroupId == group.id;
                  final lines = state.groupLinesCache[group.id] ?? [];

                  return _buildCartonGroupSpecsPanel(controller, state, group, lines, isExpanded);
                },
              ),
            ),
            const Divider(height: 1, color: Color(0xFFCFD8DC), thickness: 1.5),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('CARTON SCAN CHECKLIST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5)),
            ),
            _buildCartonTableHeader(),
            Expanded(
              flex: 3,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: state.scannedCartons.length,
                itemBuilder: (context, index) {
                  final reversedIndex = state.scannedCartons.length - 1 - index;
                  final model = state.scannedCartons[reversedIndex];

                  return CartonPackingRow(
                    index: reversedIndex,
                    item: model,
                    onRemove: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm Delete'),
                          content: const Text('Are you sure you want to delete this carton?'),
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
                        controller.removeScannedCarton(reversedIndex);
                      }
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

  Widget _buildSaleOrderMasterCard(CartonPackingState state) {
    if (state.activeSaleOrder == null) return const SizedBox();

    String formatDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return '-';
      return dateStr.split('T')[0].split(' ')[0];
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_rounded, color: Color(0xFF0D47A1), size: 16),
              SizedBox(width: 8),
              Text('SALE ORDER MASTER DATA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1), letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSpecsCard('ORDER NO', state.activeSaleOrder!.orderNo, Icons.qr_code_rounded),
              const SizedBox(width: 8),
              _buildSpecsCard('CUSTOMER PO', state.activeSaleOrder!.customerPO, Icons.receipt_long_rounded),
              const SizedBox(width: 8),
              _buildSpecsCard('CUSTOMER NAME', state.activeCustomerName ?? '-', Icons.person_rounded),
              const SizedBox(width: 8),
              _buildSpecsCard('SHIPMENT DATE', formatDate(state.activeSaleOrder!.shipmentDate), Icons.local_shipping_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartonGroupSpecsPanel(CartonPackingController controller, CartonPackingState state, PackingInstructionHeader header, List<PackingInstructionLineResponse> lines, bool isExpanded) {
    final headerId = header.id;
    final detailIds = state.groupDetailIdsCache[headerId] ?? [];
    final dbPackedCount = detailIds.where((id) => state.packedCartonDetailIds.contains(id)).length;
    final sessionScannedCount = state.scannedCartons.where((c) => c.packingInstructionHeader.id == headerId).length;
    final totalScannedCount = dbPackedCount + sessionScannedCount;
    
    final weightUom = _getUomString(header.weight.toInt());
    final dimsUom = _getUomString(header.measurementUom);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFD8DC), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => controller.toggleExpandedGroupId(headerId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: Color(0xFF1B64A3), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          header.cartonGroup,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalScannedCount / ${header.noCartons} Cartons Scanned',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF78909C)),
                        ),
                      ],
                    ),
                  ),
                  if (lines.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF90CAF9), width: 1),
                      ),
                      child: Text(
                        '${lines.length} ${lines.length == 1 ? 'Item' : 'Items'}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF1B64A3),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFCFD8DC)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _buildSpecsCard('NET WEIGHT', '${header.netWeight.toStringAsFixed(1)} $weightUom', Icons.scale_rounded),
                      const SizedBox(width: 8),
                      _buildSpecsCard('GROSS WEIGHT', '${header.grossWeight.toStringAsFixed(1)} $weightUom', Icons.scale_rounded),
                      const SizedBox(width: 8),
                      _buildSpecsCard('DIMENSIONS', '${header.length.toStringAsFixed(0)}x${header.width.toStringAsFixed(0)}x${header.height.toStringAsFixed(0)} $dimsUom', Icons.aspect_ratio_rounded),
                      const SizedBox(width: 8),
                      _buildSpecsCard('TOTAL ITEMS', '${lines.length}', Icons.layers_rounded),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'PACK RATIO & ITEMS BREAKDOWN',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF546E7A), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          color: const Color(0xFFF1F5F9),
                          child: const Row(
                            children: [
                              Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                              Expanded(flex: 2, child: Text('COLOR', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                              Expanded(flex: 2, child: Text('SIZE', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                              Expanded(flex: 2, child: Text('PACK RATIO', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                            ],
                          ),
                        ),
                        if (lines.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.white,
                            alignment: Alignment.center,
                            child: const Text('No items defined.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          )
                        else
                          ...lines.map((line) {
                            final idx = lines.indexOf(line);
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                                border: Border(top: BorderSide(color: const Color(0xFFE2E8F0), width: idx == 0 ? 0 : 1)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      line.itemDef.description,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFECEFF1), borderRadius: BorderRadius.circular(4)),
                                        child: Text(line.itemDef.colorDescription, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF455A64))),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFF0F4C3), borderRadius: BorderRadius.circular(4)),
                                        child: Text(line.itemDef.sizeDescription, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF827717))),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '1 : ${line.packingInstructionLine.packRatio}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartonTableHeader() {
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

  Widget _buildSpecsCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: const Color(0xFF1B64A3)),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
