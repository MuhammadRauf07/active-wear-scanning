import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/barcode_scanner_dialog.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/tray/model/plan_header_model.dart';
import 'package:active_wear_scanning/features/tray/model/scanned_tray.dart';
import 'package:active_wear_scanning/features/tray/model/tray_details_model.dart';
import 'package:active_wear_scanning/features/tray/repo/tray_scanning_repo.dart';
import 'package:flutter/material.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';

import '../../../core/widgets/custom_expanded_async_dropdown.dart';
import '../../../core/widgets/scanner_always_open.dart';

class TrayScanningScreen extends StatefulWidget {
  const TrayScanningScreen({super.key});

  @override
  State<TrayScanningScreen> createState() => _TrayScanningScreenState();
}

class _TrayScanningScreenState extends State<TrayScanningScreen> {
  // ─── Dependencies & State ────────────────────────────────────────────────

  final _trayScanningRepo = fromPlex<TrayScanningRepo>();
  String _machineBarcode = '';
  final List<ScannedTray> _scannedTrays = [];
  final List<TextEditingController> _quantityControllers = [];
  final _overrideQuantityController = TextEditingController();


  /// Work order details loaded after scanning machine barcode. Null until scan.
  List<PlanLineResponseModel>? _planLines;
  List<TrayDetailsModel> availableTraysDetail = [];
  PlanLineResponseModel? _selectedPlanLine;

  // ─── Styles ───────────────────────────────────────────────────────────────

  static const _inputAndButtonHeight = 42.0;
  static const _borderColor = Colors.blue;

  static final _labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87);

  static final _tableHeaderStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700);

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _overrideQuantityController.dispose();
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Returns the default quantity per tray from the loaded plan.
  /// Returns empty string if no plan is loaded.
  String _getPlanQuantityPerTray() {
    if (_planLines == null || _planLines!.isEmpty) return '';
    final quantity = _planLines!.first.planLine.quantityPerTray;
    return quantity == quantity.roundToDouble() ? quantity.round().toString() : quantity.toString();
  }

  /// Returns the quantity to pre-fill for new trays. User override takes priority over plan value.
  String _getDefaultQuantityForNewTray() {
    final override = _overrideQuantityController.text.trim();
    if (override.isNotEmpty) return override;
    return _getPlanQuantityPerTray();
  }

  /// Validates scanned tray against availableTraysDetail. Returns null if valid, error message if invalid.
  String? _validateTrayForScan(String scannedCode) {
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid tray code';

    // Check if already scanned (already assigned)
    final alreadyScanned = _scannedTrays.any((t) => t.trayCode.trim() == code);
    if (alreadyScanned) return 'Already assigned';

    // Find matching tray in available list
    final available = availableTraysDetail.where((t) => (t.trayDetails?.trayCode ?? '').trim() == code).toList();
    if (available.isEmpty) return 'Tray not available';

    final trayDetail = available.first.trayDetails;
    if (trayDetail?.active != true) return 'Tray is not active';

    _scannedTrays.add(ScannedTray(trayCode: scannedCode.trim(), trayUpdateId: trayDetail!.id, trayConcurrencyStamp: trayDetail.concurrencyStamp));

    return null;
  }

  /// Builds a map of plan line fields for [DynamicInfoDisplay].
  /// Only includes non-empty values.
  Map<String, dynamic> _buildPlanLineDetailsMap(PlanLineResponseModel planLine) {
    final result = <String, dynamic>{};

    void addField(String key, IconData icon, String label, String? value) {
      if (value != null && value.trim().isNotEmpty && value.trim() != 'null') {
        result[key] = {'icon': icon, 'label': label, 'value': value};
      }
    }

    final plan = planLine.planLine;
    final shift = planLine.shift;
    final workOrder = planLine.workOrderHeader;
    final item = planLine.item;

    addField('Plan Date', Icons.calendar_today, 'Plan Date', plan.planDate.toString());
    addField('Knitting Tube', Icons.precision_manufacturing, 'Knitting Tube', plan.primaryPlanQuantity.toString());
    addField('Pcs Per Tray', Icons.grid_view, 'Pcs Per Tray', plan.quantityPerTray.toString());
    addField('Garment Pcs', Icons.checkroom, 'Garment Pcs', plan.secondaryPlanQuantity.toString());
    addField('Shift Code', Icons.schedule, 'Shift Code', shift.code.toString());
    addField('Work Order Code', Icons.assignment, 'Work Order Code', workOrder.workOrderCode);
    addField('Work Order Date', Icons.event, 'Work Order Date', workOrder.workOrderDate);
    addField('Item Description', Icons.description, 'Item Description', item.description);

    return result;
  }

  // ─── User Actions ─────────────────────────────────────────────────────────

  /// Opens barcode scanner for tray. On success, validates and adds tray if eligible.
  Future<void> _onScanTray() async {
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trays',
      onResult: (scannedCode) {
        // 1. Run your validation logic (Returns String? message or null)
        final String? validationError = _validateTrayForScan(scannedCode);

        if (validationError == null) {
          // CASE: SUCCESS
          setState(() {
            // Add the controller to the background list
            _quantityControllers.add(
              TextEditingController(text: _getDefaultQuantityForNewTray()),
            );
          });

          // Return null to tell ScannerAlwaysOpen there is no error
          return null;
        } else {
          // CASE: ERROR (Duplicate, Invalid, Inactive, etc.)
          // Return the actual error string so the scanner can display it
          return validationError;
        }
      },
    );
  }
  /// Opens barcode scanner for machine. On success, loads work order from API.
  Future<void> _onScanMachineBarcode() async {
    AppLoader.show();

    final scannedCode = await BarcodeScannerDialog.show(context, title: 'Scan Machine Barcode');

    if (scannedCode == null || !mounted) {
      AppLoader.hide(); // Ensure loader hides if scan is cancelled
      return;
    }

    setState(() {
      _machineBarcode = scannedCode;
      _planLines = null;       // Reset previous data
      _selectedPlanLine = null; // Reset selection
    });

    final apiResult = await _trayScanningRepo.loadWorkOrderBySerialNumber(scannedCode);
    final trayDetailsModel = await _trayScanningRepo.fetchAvailableTrayDetails();

    if (!mounted) return;

    if (apiResult.success && apiResult.data != null) {
      setState(() {
        // Cast the data to our list
        _planLines = List<PlanLineResponseModel>.from(apiResult.data);
        availableTraysDetail = trayDetailsModel.data as List<TrayDetailsModel>;

        // Logic: Auto-select if only 1 item exists
        if (_planLines!.length == 1) {
          _selectedPlanLine = _planLines!.first;
          _overrideQuantityController.text = _getPlanQuantityPerTray();
        }
      });
    } else {
      _showError(apiResult.message ?? "No data found");
    }

    AppLoader.hide();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $message')));
  }

  /// Save API ────────────────────────────────────────────────────────────────

  void saveTrayAndProductionProgress() async {
    AppLoader.show();
    for (int i = 0; i < _scannedTrays.length; i++) {
      Map<String, dynamic> planData = {
        'description': _planLines!.first.item.description,
        'trayCode': _scannedTrays[i].trayCode,
        'shiftId': _planLines!.first.shift.id,
        'planLineId': _planLines!.first.planLine.id,
        'resourceId': _planLines!.first.resource.id,
        'workOrderHeaderId': _planLines!.first.workOrderHeader.id,
        'workOrderLineId': _planLines!.first.workOrderLine.id,
        'knitItemId': _planLines!.first.planLine.itemId,
        "locatorId": 2,
        "active": true,
        'concurrencyStamp': _scannedTrays[i].trayConcurrencyStamp,
      };

      Map<String, dynamic> productionProgressData = {
        "subOperation": "Knitting Tray Allocation",
        "date": DateTime.now().toString(),
        "transactionType": 0,
        "operatorDescription": "system",
        "primaryQuantity": _planLines!.first.planLine.primaryQuantity,
        "primaryUOM": _planLines!.first.planLine.primaryUOM,
        "secondaryQuantity": _planLines!.first.planLine.secondaryQuantity,
        "secondaryUOM": _planLines!.first.planLine.secondaryUOM,
        "wipStatus": 0,
        "gbsFlag": false,
        "pbsFlag": false,
        "operationId": _planLines!.first.operation.id,
        "workOrderHeaderId": _planLines!.first.workOrderHeader.id,
        "workOrderLineId": _planLines!.first.workOrderLine.id,
        "itemId": _planLines!.first.planLine.itemId,
        "shiftId": _planLines!.first.planLine.shiftId,
        "primaryTrayId": _scannedTrays[i].trayUpdateId,
        "machineId": _planLines!.first.planLine.resourceId,
        "planHeaderId": _planLines!.first.planLine.planHeaderId,
        "locatorId": 2,
      };

      await _trayScanningRepo.updateTrayDetails(planData, _scannedTrays[i].trayUpdateId!);
      await _trayScanningRepo.saveProductionProgress(productionProgressData);
    }

    AppLoader.hide();
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
                heading: 'Tray Scanning',
                subtitle: 'Scan tray barcode to record production',
                isShowBackIcon: true,
                topPadding: 0,
                horizontalPadding: 12,
                widget: CustomOutlinedButton(
                  label: 'Save Changes',
                  borderColor: Colors.blue,
                  textColor: Colors.blue,
                  buttonHeight: _inputAndButtonHeight,
                  onPressed: saveTrayAndProductionProgress,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_buildMachineScannerSection(), const SizedBox(height: 10), if (_planLines != null) _buildScannedTraysSection()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Section 1: Machine barcode input + work order details.
  Widget _buildMachineScannerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Machine Scanner', subtitle: 'Scan the machine barcode to load work order details'),
        const SizedBox(height: 12),
        ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scan Machine Barcode', style: _labelStyle),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildMachineBarcodeField()),
                  const SizedBox(width: 10),
                  CustomOutlinedButton(
                    label: 'Scan Machine',
                    borderColor: Colors.blue,
                    fillColor: Colors.blue,
                    textColor: Colors.white,
                    buttonHeight: _inputAndButtonHeight,
                    onPressed: _onScanMachineBarcode,
                  ),
                ],
              ),
              _buildWorkOrderDropdown(),
              const SizedBox(height: 10),
              if (_selectedPlanLine != null) ...[DynamicInfoDisplay(items: _buildPlanLineDetailsMap(_selectedPlanLine!))],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMachineBarcodeField() {
    return SizedBox(
      height: _inputAndButtonHeight,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(Icons.qr_code_scanner, size: 20, color: Colors.grey.shade400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _machineBarcode.isEmpty ? 'Place cursor here and scan barcode...' : _machineBarcode,
                style: TextStyle(fontSize: 14, color: _machineBarcode.isEmpty ? Colors.grey.shade400 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section 2: List of scanned trays with quantity inputs.
  Widget _buildScannedTraysSection() {
    final hasTrays = _scannedTrays.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Scanned Trays', subtitle: 'Scan a machine to start binding trays'),
        const SizedBox(height: 12),
        ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Scanned Trays (${_scannedTrays.length})', style: _labelStyle.copyWith(fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        height: _inputAndButtonHeight,
                        child: TextField(
                          controller: _overrideQuantityController,
                          decoration: _inputDecoration(
                            hintText: 'Pcs/tray',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
                            borderRadius: 4,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
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
              const SizedBox(height: 12),
              _buildTrayTableHeader(),
              if (!hasTrays) _buildEmptyState() else ...List.generate(_scannedTrays.length, (index) => _buildTrayRow(index, _scannedTrays[index])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrayTableHeader() {
    return Row(
      children: [
        Expanded(flex: 2, child: Text('TRAY CODE', style: _tableHeaderStyle)),
        Expanded(child: Text('QUANTITY', style: _tableHeaderStyle)),
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text('No scanned trays yet. Start by scanning a tray barcode.', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
      ),
    );
  }

  Widget _buildTrayRow(int index, ScannedTray tray) {
    final isEmpty = tray.trayCode.isEmpty;
    final displayCode = isEmpty ? '-' : tray.trayCode;
    final textColor = isEmpty ? Colors.grey.shade400 : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(displayCode, style: TextStyle(fontSize: 14, color: textColor)),
          ),
          Expanded(
            child: SizedBox(
              height: _inputAndButtonHeight,
              child: TextField(
                controller: _quantityControllers[index],
                decoration: _inputDecoration(hintText: '0', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), borderRadius: 4),
                keyboardType: TextInputType.number,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildDeleteTrayButton(index),
        ],
      ),
    );
  }

  Widget _buildDeleteTrayButton(int index) {
    return GestureDetector(
      onTap: () => _onDeleteTray(index),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
      ),
    );
  }

  void _onDeleteTray(int index) {
    setState(() {
      _quantityControllers[index].dispose();
      _quantityControllers.removeAt(index);
      _scannedTrays.removeAt(index);
    });
  }

  Widget _buildWorkOrderDropdown() {
    // Only show if we actually have data from the scan
    if (_planLines == null || _planLines!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Work Order & Item Description', style: _labelStyle),
          const SizedBox(height: 8),
          CustomExpandedAsyncDropdown<PlanLineResponseModel>(
            hint: "Select from list...",
            width: double.infinity, // Take full width
            height: 48,            // Match your app's input height
            borderColor: Colors.blue,
            items: _planLines,      // Use the list fetched from machine scan
            selectedValue: _selectedPlanLine,

            // This tells the dropdown what text to show in the list
            itemAsString: (plan) => "${plan.workOrderHeader.workOrderCode} - ${plan.item.description}",

            // Optional: Add a tag if an item is high priority or specific status
            itemTagBuilder: (plan) {
              // Example: if (plan.isUrgent) return "URGENT";
              return null;
            },
                onChanged: (PlanLineResponseModel? newValue) {
                  setState(() {
                    _selectedPlanLine = newValue;
                    // Automatically update the quantity field for the new selection
                    if (_selectedPlanLine != null) {
                      _overrideQuantityController.text = _getPlanQuantityPerTray();
                    }
                  });
                },
              ),
            ],
          ),


    );
  }

  /// Shared input decoration to reduce duplication.
  InputDecoration _inputDecoration({required String hintText, bool isDense = false, EdgeInsetsGeometry? contentPadding, double borderRadius = 6}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: _borderColor),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: isDense ? null : Icon(Icons.qr_code_scanner, size: 20, color: Colors.grey.shade400),
      border: border,
      focusedBorder: border,
      enabledBorder: border,
      isDense: isDense,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
