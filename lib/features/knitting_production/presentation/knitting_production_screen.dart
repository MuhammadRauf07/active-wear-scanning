import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/utils/barcode_buffer_parser.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/empty_scan_state.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/tray_table_header.dart';
import 'package:active_wear_scanning/features/knitting_production/model/scanned_tray.dart';
import 'package:active_wear_scanning/features/knitting_production/presentation/widgets/scanned_tray_row.dart';
import 'package:active_wear_scanning/features/knitting_production/presentation/widgets/work_order_dropdown.dart';
import 'package:active_wear_scanning/features/knitting_production/model/plan_header_model.dart';
import 'package:active_wear_scanning/features/knitting_production/model/tray_details_model.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/features/knitting_production/controller/knitting_production_controller.dart';
import 'package:active_wear_scanning/features/knitting_production/model/knitting_production_state.dart';

class KnittingProductionScreen extends StatelessWidget {
  const KnittingProductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<KnittingProductionController>(
      create: (_) => KnittingProductionController(),
      child: const _KnittingProductionScreenView(),
    );
  }
}

class _KnittingProductionScreenView extends StatefulWidget {
  const _KnittingProductionScreenView();

  @override
  State<_KnittingProductionScreenView> createState() => _KnittingProductionScreenViewState();
}

class _KnittingProductionScreenViewState extends State<_KnittingProductionScreenView> {
  final _overrideQuantityController = TextEditingController();
  final _quantityInputFieldController = TextEditingController();
  final _remarksInputFieldController = TextEditingController();

  final Map<String, TextEditingController> _trayQuantityControllers = {};
  final _barcodeParser = BarcodeBufferParser();

  bool _isScannerOpen = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _quantityInputFieldController.addListener(_onQuantityChanged);
  }

  void _onQuantityChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _overrideQuantityController.dispose();
    _quantityInputFieldController.removeListener(_onQuantityChanged);
    _quantityInputFieldController.dispose();
    _remarksInputFieldController.dispose();
    for (final c in _trayQuantityControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (_isScannerOpen) return false;
    return _barcodeParser.handleKey(event, _processBluetoothScan);
  }

  Future<void> _processBluetoothScan(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return;

    final controller = context.read<KnittingProductionController>();
    final state = controller.state;

    if (state.machineBarcode.isEmpty) {
      _fetchMachineData(controller, code);
    } else {
      if (state.productionType != 'good') {
        _showError('Knitting Production is not for Sample and C Grade production.');
        return;
      }
      final error = await controller.validateAndAddTray(code, _overrideQuantityController.text);
      if (error != null && mounted) {
        _showError(error);
      } else {
        HapticFeedbackHelper.scanSuccess();
      }
    }
  }

  Future<void> _fetchMachineData(KnittingProductionController controller, String scannedCode) async {
    AppLoader.show(context, message: 'Loading Machine Data...');
    await controller.fetchMachineData(scannedCode);
    AppLoader.hide(context);

    if (!mounted) return;
    if (controller.state.errorMessage != null) {
      _showError(controller.state.errorMessage!);
      controller.resetMachine();
    } else {
      if (controller.state.selectedPlanLine != null) {
        _overrideQuantityController.text = controller.getPlanQuantityPerTray();
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedbackHelper.scanError();
    AppSnackBar.showError(context, message: message);
  }

  TextEditingController _getControllerForTray(String trayCode, String initialValue, KnittingProductionController controllerNotifier, int index) {
    if (!_trayQuantityControllers.containsKey(trayCode)) {
      final c = TextEditingController(text: initialValue);
      c.addListener(() {
        controllerNotifier.updateTrayQuantity(index, c.text);
      });
      _trayQuantityControllers[trayCode] = c;
    }
    return _trayQuantityControllers[trayCode]!;
  }

  bool _isSaveEnabled(KnittingProductionState state) {
    if (state.machineBarcode.isEmpty || state.selectedPlanLine == null) return false;
    if (state.productionType == 'good') {
      return state.scannedTrays.isNotEmpty;
    } else {
      final qtyText = _quantityInputFieldController.text.trim();
      final q = int.tryParse(qtyText) ?? 0;
      return q > 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KnittingProductionController>();
    final state = controller.state;

    // Synchronize tray controllers with current scanned trays
    final currentCodes = state.scannedTrays.map((t) => t.trayCode).toSet();
    _trayQuantityControllers.removeWhere((code, c) {
      if (!currentCodes.contains(code)) {
        c.dispose();
        return true;
      }
      return false;
    });

    final isSaveEnabled = _isSaveEnabled(state);

    return PopScope(
      canPop: !AppLoader.isVisible && !state.isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPremiumHeader(context, controller, state, isSaveEnabled),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KnittingProductionFadeSlideTransition(delay: 0, child: _buildMachineScannerSection(controller, state)),
                      if (state.selectedPlanLine != null) ...[
                        const SizedBox(height: 16),
                        const _KnittingProductionFadeSlideTransition(
                          delay: 100,
                          child: Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'PRODUCTION INTELLIGENCE',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                            ),
                          ),
                        ),
                        _KnittingProductionFadeSlideTransition(delay: 150, child: _buildProductionInfoGrid(controller, state)),
                        const SizedBox(height: 12),
                        _KnittingProductionFadeSlideTransition(delay: 180, child: _buildProductionTypeRadioButtons(controller, state)),
                      ],
                      if (state.selectedPlanLine != null && state.productionType == 'good') ...[
                        const SizedBox(height: 16),
                        _KnittingProductionFadeSlideTransition(delay: 200, child: _buildActionArea(controller)),
                      ],
                      if (state.selectedPlanLine != null) ...[
                        if (state.productionType == 'good') ...[
                          const SizedBox(height: 16),
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: _KnittingProductionFadeSlideTransition(
                              delay: 250,
                              child: Text(
                                'ACTIVE SCANNED TRAYS',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                              ),
                            ),
                          ),
                          _KnittingProductionFadeSlideTransition(
                            delay: 280,
                            child: SizedBox(
                              height: 320,
                              child: _buildScannedTraysTable(controller, state),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          _buildQuantityInputFieldSection(state),
                        ],
                      ],
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

  Widget _buildPremiumHeader(BuildContext context, KnittingProductionController controller, KnittingProductionState state, bool isSaveEnabled) {
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
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Knitting Production',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'Scan Trays in a Work Order',
                    style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: isSaveEnabled
                  ? () {
                      HapticFeedbackHelper.buttonClick();
                      _saveEntry(controller);
                    }
                  : null,
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE CHANGES'),
              style: AppTheme.saveButtonStyle(isEnabled: isSaveEnabled),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedTraysTable(KnittingProductionController controller, KnittingProductionState state) {
    return Container(
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
          const TrayTableHeader(),
          Expanded(
            child: state.scannedTrays.isEmpty
                ? const EmptyScanState()
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: state.scannedTrays.length,
                    itemBuilder: (context, index) {
                      final tray = state.scannedTrays[index];
                      final qtyCtrl = _getControllerForTray(tray.trayCode, tray.quantity ?? '', controller, index);
                      return ScannedTrayRow(
                        index: index,
                        tray: tray,
                        quantityController: qtyCtrl,
                        selectedPlanLine: state.selectedPlanLine,
                        onDelete: () async {
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineScannerSection(KnittingProductionController controller, KnittingProductionState state) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.machineBarcode.isEmpty
                                  ? 'Scan Machine'
                                  : 'ACTIVE MACHINE: ${state.machineBarcode.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF546E7A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (state.scannedTrays.isEmpty && _quantityInputFieldController.text.trim().isEmpty)
                              ? () {
                                  HapticFeedbackHelper.buttonClick();
                                  _onScanMachineBarcode(controller);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: state.machineBarcode.isEmpty
                                ? const Color(0xFF0D47A1)
                                : const Color(0xFF455A64),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade200,
                            disabledForegroundColor: Colors.grey.shade400,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'SCAN MACHINE',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: state.machineBarcode.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: (state.scannedTrays.isEmpty && _quantityInputFieldController.text.trim().isEmpty)
                                  ? () {
                                      HapticFeedbackHelper.buttonClick();
                                      controller.togglePreviousShift(!state.usePreviousShift);
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: state.usePreviousShift,
                                      activeColor: const Color(0xFF0D47A1),
                                      onChanged: (state.scannedTrays.isEmpty && _quantityInputFieldController.text.trim().isEmpty)
                                          ? (value) {
                                              if (value != null) {
                                                HapticFeedbackHelper.buttonClick();
                                                controller.togglePreviousShift(value);
                                              }
                                            }
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Add to Previous Shift',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF37474F),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'SELECT WORK ORDER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF546E7A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: (state.planLines == null || state.planLines!.isEmpty)
                                      ? Container(
                                          height: 48,
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFFCFD8DC),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Text(
                                            'No data found',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        )
                                      : WorkOrderDropdown(
                                          enabled: state.scannedTrays.isEmpty && _quantityInputFieldController.text.trim().isEmpty,
                                          planLines: state.planLines,
                                          selectedPlanLine: state.selectedPlanLine,
                                          onChanged: (newValue) {
                                            controller.changeSelectedPlanLine(newValue);
                                            if (newValue != null) {
                                              _overrideQuantityController.text = controller.getPlanQuantityPerTray();
                                            }
                                            _quantityInputFieldController.clear();
                                          },
                                        ),
                                ),
                                if (state.machineBarcode.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        AppLoader.show(context, message: 'Fetching available trays...');
                                        await controller.fetchAvailableTrays();
                                        if (context.mounted) {
                                          AppLoader.hide(context);
                                          _showAvailableTraysDialog(controller);
                                        }
                                      },
                                      icon: const Icon(Icons.layers_outlined, size: 16),
                                      label: const Text(
                                        'SHOW TRAYS',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE67E22),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: Colors.grey.shade300,
                                        disabledForegroundColor: Colors.grey.shade500,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductionInfoGrid(KnittingProductionController controller, KnittingProductionState state) {
    final info = _buildPlanLineDetailsMap(state);
    
    double totalUnits = 0;
    for (final tray in state.scannedTrays) {
      totalUnits += double.tryParse(tray.quantity ?? '') ?? 0;
    }

    final List<Map<String, dynamic>> allItems = [
      {'label': 'WORK ORDER', 'icon': Icons.qr_code_rounded, 'value': info['Work Order Code']?['value']},
      {'label': 'WORK ORDER DATE', 'icon': Icons.event_note_rounded, 'value': info['Work Order Date']?['value']},
      {'label': 'PLAN DATE', 'icon': Icons.calendar_today_rounded, 'value': info['Plan Date']?['value']},
      {'label': 'SHIFT', 'icon': Icons.timer_rounded, 'value': info['Shift Code']?['value']},
      {'label': 'TOTAL WO PLAN QTY', 'icon': Icons.analytics_rounded, 'value': info['Total WO Plan QTY']?['value']},
      {'label': 'TOLERANCE', 'icon': Icons.add_circle_outline_rounded, 'value': info['10% Allowed']?['value']},
      {'label': 'QTY WITH TOLERANCE', 'icon': Icons.verified_user_rounded, 'value': info['Extra Allowed Tubes']?['value']},
      {'label': 'REMAINING WO PLAN QTY', 'icon': Icons.hourglass_empty_rounded, 'value': info['Remaining WO Plan QTY']?['value']},
      {'label': 'TUBES PER TRAY', 'icon': Icons.flag_rounded, 'value': info['Tubes Per Tray']?['value']},
      {'label': 'SCANNED TRAYS', 'icon': Icons.layers_rounded, 'value': '${state.scannedTrays.length}'},
      {'label': 'SCANNED TUBES', 'icon': Icons.analytics_rounded, 'value': totalUnits.toStringAsFixed(0)},
      {'label': 'TRAY CAPACITY', 'icon': Icons.grid_view_rounded, 'isEditable': true},
      {'label': 'ITEM DESCRIPTION', 'icon': Icons.description_rounded, 'value': info['Item Description']?['value'], 'isFullWidth': true},
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final double cellWidth = (screenWidth - 32 - (3 * 6)) / 4;
    final double cellHeight = screenWidth >= 600 ? 74.0 : 68.0;
    final double childAspectRatio = cellWidth / cellHeight;

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: 12,
          itemBuilder: (context, index) => _buildMetricCard(allItems[index], controller),
        ),
        const SizedBox(height: 8),
        _buildMetricCard(allItems[12], controller),
      ],
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> item, KnittingProductionController controller) {
    final bool isFullWidth = item['isFullWidth'] ?? false;
    final bool isEditable = item['isEditable'] ?? false;
    final Color? valueColor = item['color'];
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth >= 600;

    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: isFullWidth
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : (isTablet
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
      decoration: BoxDecoration(
        color: isEditable ? const Color(0xFFFFFDE7) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditable ? const Color(0xFFFFD54F) : const Color(0xFFB0BEC5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                item['icon'],
                size: isTablet ? 12 : 11,
                color: isEditable ? const Color(0xFFF57F17) : const Color(0xFF1976D2),
              ),
              SizedBox(width: isTablet ? 6 : 4),
              Expanded(
                child: Text(
                  item['label'],
                  style: TextStyle(
                    fontSize: isTablet ? 10 : 8.5,
                    fontWeight: FontWeight.w700,
                    color: isEditable ? const Color(0xFFE65100) : const Color(0xFF546E7A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isEditable)
            Center(
              child: Container(
                width: isTablet ? 60 : 54,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFFE082), width: 1),
                ),
                child: TextField(
                  controller: _overrideQuantityController,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE65100),
                  ),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.only(top: 4),
                    isCollapsed: true,
                    border: InputBorder.none,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (val) {
                    if (val.startsWith('0')) {
                      _overrideQuantityController.text = val.replaceFirst(RegExp(r'^0+'), '');
                      _overrideQuantityController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _overrideQuantityController.text.length),
                      );
                    }
                  },
                  onEditingComplete: () {
                    final val = _overrideQuantityController.text.trim();
                    if (val.isEmpty || (int.tryParse(val) ?? 0) <= 0) {
                      _overrideQuantityController.text = controller.getPlanQuantityPerTray();
                    }
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
            )
          else
            Text(
              item['value'] ?? '---',
              style: TextStyle(
                fontSize: isFullWidth ? 14 : (isTablet ? 12 : 10.5),
                fontWeight: FontWeight.w800,
                color: valueColor ?? const Color(0xFF263238),
              ),
              maxLines: isFullWidth ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildPlanLineDetailsMap(KnittingProductionState state) {
    final result = <String, dynamic>{};
    void addField(String key, IconData icon, String label, String? value) {
      if (value != null && value.trim().isNotEmpty && value.trim() != 'null') {
        result[key] = {'icon': icon, 'label': label, 'value': value};
      }
    }

    final planLine = state.selectedPlanLine!;
    final plan = planLine.planLine;
    final workOrder = planLine.workOrderHeader;
    final item = planLine.item;

    String? formatDate(String? dateStr) {
      if (dateStr == null) return null;
      return dateStr.split('T')[0].split(' ')[0];
    }

    final totalWoPlanQty = planLine.workOrderLine.tubesAfterAdjustment;
    final int extraAllowed = (totalWoPlanQty * 0.1).ceil();
    final double maxAllowed = totalWoPlanQty + extraAllowed;
    
    double scannedTubesSum = 0;
    for (final tray in state.scannedTrays) {
      scannedTubesSum += double.tryParse(tray.quantity ?? '') ?? 0;
    }
    
    // Fetch sum of primary quantity for the work order using controller
    final controller = context.read<KnittingProductionController>();
    final sumPrimaryQty = controller.getSumPrimaryQuantityForWorkOrder(plan.workOrderLineId);
    final remainingWoPlanQty = maxAllowed - sumPrimaryQty - scannedTubesSum;

    addField('Work Order Code', Icons.qr_code_rounded, 'WORK ORDER', workOrder.workOrderCode);
    addField('Work Order Date', Icons.event_note_rounded, 'WORK ORDER DATE', formatDate(workOrder.workOrderDate));
    addField('Plan Date', Icons.calendar_today_rounded, 'PLAN DATE', formatDate(plan.planDate));
    addField('Shift Code', Icons.timer_rounded, 'SHIFT', planLine.shift.code);
    addField('Total WO Plan QTY', Icons.analytics_rounded, 'TOTAL WO PLAN QTY', totalWoPlanQty.toStringAsFixed(0));
    addField('10% Allowed', Icons.add_circle_outline_rounded, 'TOLERANCE', extraAllowed.toString());
    addField('Extra Allowed Tubes', Icons.verified_user_rounded, 'QTY WITH TOLERANCE', maxAllowed.toStringAsFixed(0));
    addField('Remaining WO Plan QTY', Icons.hourglass_empty_rounded, 'REMAINING WO PLAN QTY', remainingWoPlanQty.toStringAsFixed(0));
    addField('Tubes Per Tray', Icons.flag_rounded, 'TUBES PER TRAY', plan.quantityPerTray.toStringAsFixed(0));
    addField('Item Description', Icons.description_rounded, 'ITEM DESCRIPTION', item.description);

    return result;
  }

  Widget _buildActionArea(KnittingProductionController controller) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedbackHelper.buttonClick();
          _onScanTray(controller);
        },
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
        label: const Text(
          'SCAN TRAY',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildProductionTypeRadioButtons(KnittingProductionController controller, KnittingProductionState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRODUCTION NATURE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF546E7A),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildRadioOption('GOOD PRODUCTION', 'good', controller, state),
              ),
              Expanded(
                child: _buildRadioOption('SAMPLE', 'sample', controller, state),
              ),
              Expanded(
                child: _buildRadioOption('C-GRADE PRODUCTION', 'c_grade', controller, state),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String label, String value, KnittingProductionController controller, KnittingProductionState state) {
    final isSelected = state.productionType == value;
    Color optionColor;
    if (value == 'sample') {
      optionColor = const Color(0xFFF59E0B);
    } else if (value == 'c_grade') {
      optionColor = const Color(0xFFEF4444);
    } else {
      optionColor = const Color(0xFF0D47A1);
    }

    return InkWell(
      onTap: () {
        HapticFeedbackHelper.buttonClick();
        _handleProductionTypeChange(value, controller, state);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: state.productionType,
            activeColor: optionColor,
            fillColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return optionColor;
              }
              return Colors.grey.shade400;
            }),
            onChanged: (val) {
              if (val != null) {
                HapticFeedbackHelper.buttonClick();
                _handleProductionTypeChange(val, controller, state);
              }
            },
          ),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? optionColor : const Color(0xFF37474F),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _handleProductionTypeChange(String newType, KnittingProductionController controller, KnittingProductionState state) {
    if (state.productionType == newType) return;

    if (state.productionType == 'good' && state.scannedTrays.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Text(
                  'Confirm Switch',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Switching production nature will dismiss all scanned trays. Do you want to proceed?',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  controller.setProductionType(newType);
                  controller.resetMachine();
                  _quantityInputFieldController.clear();
                  _remarksInputFieldController.clear();
                },
                child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      );
    } else {
      controller.setProductionType(newType);
      _quantityInputFieldController.clear();
      _remarksInputFieldController.clear();
    }
  }

  Widget _buildQuantityInputFieldSection(KnittingProductionState state) {
    final title = state.productionType == 'sample' ? 'Sample Quantity' : 'C Grade Quantity';
    final isRemarksEnabled = _quantityInputFieldController.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB0BEC5),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF546E7A),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
            ),
            child: TextField(
              controller: _quantityInputFieldController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (val) {
                if (val.startsWith('0')) {
                  _quantityInputFieldController.text = val.replaceFirst(RegExp(r'^0+'), '');
                  _quantityInputFieldController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _quantityInputFieldController.text.length),
                  );
                }
                setState(() {});
              },
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              decoration: const InputDecoration(
                hintText: 'Enter Quantity',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.add_box_rounded, color: Color(0xFF0D47A1)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'REMARKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF546E7A),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isRemarksEnabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isRemarksEnabled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _remarksInputFieldController,
              enabled: isRemarksEnabled,
              keyboardType: TextInputType.text,
              onChanged: (val) => setState(() {}),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isRemarksEnabled ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
              ),
              decoration: InputDecoration(
                hintText: 'Enter Remarks',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.comment_rounded,
                  color: isRemarksEnabled ? const Color(0xFF0D47A1) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAvailableTraysDialog(KnittingProductionController controller) {
    final scrollController = ScrollController();

    scrollController.addListener(() {
      if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 50) {
        controller.fetchMoreAvailableTrays();
      }
    });

    showDialog(
      context: context,
      builder: (context) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final availableTrays = controller.getFilteredAvailableTrays();
            final isLoadingMore = controller.isLoadingMoreAvailableTrays;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AVAILABLE TRAYS (${availableTrays.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: availableTrays.isEmpty && !isLoadingMore
                          ? const Center(
                              child: Text(
                                'No available trays found',
                                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: availableTrays.length + (isLoadingMore ? 1 : 0),
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, idx) {
                                if (idx == availableTrays.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2.5),
                                    ),
                                  );
                                }
                                final code = availableTrays[idx].trayDetails?.trayCode ?? '';
                                return ListTile(
                                  leading: const Icon(Icons.layers_outlined, color: Color(0xFFE67E22)),
                                  title: Text(
                                    code,
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                  ),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    final err = await controller.validateAndAddTray(code, _overrideQuantityController.text);
                                    if (err != null && mounted) {
                                      _showError(err);
                                    } else {
                                      HapticFeedbackHelper.scanSuccess();
                                    }
                                  },
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
    ).then((_) {
      scrollController.dispose();
    });
  }

  Future<void> _onScanMachineBarcode(KnittingProductionController controller) async {
    setState(() => _isScannerOpen = true);
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Machine',
      onResult: (scannedCode) async {
        final code = scannedCode.trim();
        if (code.isEmpty) return 'Invalid machine code';
        
        AppLoader.show(context, message: 'Loading Machine Data...');
        await controller.fetchMachineData(code);
        AppLoader.hide(context);

        if (controller.state.errorMessage != null) {
          final err = controller.state.errorMessage!;
          controller.resetMachine();
          return err;
        }

        if (controller.state.selectedPlanLine != null) {
          _overrideQuantityController.text = controller.getPlanQuantityPerTray();
        }
        if (mounted) Navigator.of(context).pop();
        return null;
      },
    );
    if (mounted) {
      setState(() => _isScannerOpen = false);
    }
  }

  Future<void> _onScanTray(KnittingProductionController controller) async {
    setState(() => _isScannerOpen = true);
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Tray',
      onResult: (scannedCode) async {
        final code = scannedCode.trim();
        if (code.isEmpty) return 'Invalid tray code';
        final err = await controller.validateAndAddTray(code, _overrideQuantityController.text);
        if (err != null) return err;
        return null;
      },
      scannedItemsBuilder: (context) {
        return ChangeNotifierProvider<KnittingProductionController>.value(
          value: controller,
          child: Consumer<KnittingProductionController>(
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
                    const TrayTableHeader(),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: latestState.scannedTrays.length,
                        itemBuilder: (context, index) {
                          final tray = latestState.scannedTrays[index];
                          final qtyCtrl = _getControllerForTray(tray.trayCode, tray.quantity ?? '', latestController, index);
                          return ScannedTrayRow(
                            index: index,
                            tray: tray,
                            quantityController: qtyCtrl,
                            selectedPlanLine: latestState.selectedPlanLine,
                            onDelete: () async {
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
                                latestController.removeScannedTray(index);
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

  Future<void> _saveEntry(KnittingProductionController controller) async {
    try {
      await controller.saveTrayAndProductionProgress(
        remarksText: _remarksInputFieldController.text,
        singleQtyText: _quantityInputFieldController.text,
        onConfirmOverproduction: () async {
          final res = await showDialog<bool>(
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
                    Text(
                      'Overproduction Alert',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  controller.state.productionType == 'good'
                      ? 'Plan production has been scanned. More production will be taken as Excess. Do you want to proceed?'
                      : 'Plan production has been scanned. More production will be taken as shortfall. Do you want to proceed?',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
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
          );
          return res ?? false;
        },
        onSuccess: () {
          HapticFeedbackHelper.scanSuccess();
          AppSnackBar.showSuccess(context, message: 'Saved successfully!');
          _remarksInputFieldController.clear();
          _quantityInputFieldController.clear();
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      );
    } catch (e) {
      _showError(e.toString());
    }
  }
}

class _KnittingProductionFadeSlideTransition extends StatefulWidget {
  final Widget child;
  final int delay;

  const _KnittingProductionFadeSlideTransition({required this.child, required this.delay});

  @override
  State<_KnittingProductionFadeSlideTransition> createState() => _KnittingProductionFadeSlideTransitionState();
}

class _KnittingProductionFadeSlideTransitionState extends State<_KnittingProductionFadeSlideTransition> {
  late Future<void> _delayFuture;

  @override
  void initState() {
    super.initState();
    _delayFuture = Future.delayed(Duration(milliseconds: widget.delay));
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return FutureBuilder(
          future: _delayFuture,
          builder: (context, snapshot) {
            final isVisible = snapshot.connectionState == ConnectionState.done;
            return AnimatedOpacity(
              opacity: isVisible ? value : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Transform.translate(
                offset: Offset(0.0, (1.0 - (isVisible ? value : 0.0)) * 20),
                child: child,
              ),
            );
          },
        );
      },
      child: widget.child,
    );
  }
}
