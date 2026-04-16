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
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
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
  List<ProductionProgressResponseModel> existingProductionProgresses = [];
  PlanLineResponseModel? _selectedPlanLine;

  // ─── Styles ───────────────────────────────────────────────────────────────

  static const _inputAndButtonHeight = 42.0;
  static const _borderColor = Colors.blue;

  static final _labelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  static final _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );

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
    final quantity = _selectedPlanLine!.planLine.quantityPerTray;
    return quantity == quantity.roundToDouble()
        ? quantity.round().toString()
        : quantity.toString();
  }

  /// Returns the quantity to pre-fill for new trays. User override takes priority over plan value.
  String _getDefaultQuantityForNewTray() {
    final override = _overrideQuantityController.text.trim();
    if (override.isNotEmpty) return override;
    return _getPlanQuantityPerTray();
  }

  /// Validates scanned tray against availableTraysDetail. Returns null if valid, error message if invalid.
  String? _validateTrayForScan(String scannedCode) {
    if (_selectedPlanLine == null) return 'Please select a work order first';
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid tray code';

    final alreadyScanned = _scannedTrays.any((t) => t.trayCode.trim() == code);
    if (alreadyScanned) return 'Already assigned';

    final available = availableTraysDetail.where((t) {
      final trayCodeFromApi = (t.trayDetails?.trayCode ?? '')
          .trim()
          .toLowerCase();
      final scannedCodeClean = code.toLowerCase();
      return trayCodeFromApi == scannedCodeClean;
    }).toList();

    if (available.isEmpty) return 'Tray not available';

    final trayDetail = available.first.trayDetails;
    if (trayDetail?.active != true) return 'Tray is not active';

    // Check if the tray has been logically emptied (ready for reuse)
    final bool isEmptied =
        trayDetail?.locatorId == null ||
        trayDetail?.trayQuantity == "0" ||
        trayDetail?.trayQuantity == 0;

    final alreadyInProduction = existingProductionProgresses.any(
      (t) =>
          (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase() ==
          code.toLowerCase(),
    );

    // Only block if it's in production AND hasn't been emptied out
    if (alreadyInProduction && !isEmptied)
      return 'Tray already scanned (Exists in Production Progress)';

    setState(() {
      _scannedTrays.add(
        ScannedTray(
          trayCode: code,
          trayUpdateId: trayDetail!.id,
          trayConcurrencyStamp: trayDetail.concurrencyStamp,
        ),
      );
      final controller = TextEditingController(
        text: _getDefaultQuantityForNewTray(),
      );
      controller.addListener(
        () => setState(() {}),
      ); // live weight recalculation
      _quantityControllers.add(controller);
    });

    return null;
  }

  /// Only includes non-empty values.
  Map<String, dynamic> _buildPlanLineDetailsMap(
    PlanLineResponseModel planLine,
  ) {
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

    addField(
      'Plan Date',
      Icons.calendar_today,
      'Plan Date',
      plan.planDate.toString(),
    );
    addField(
      'Knitting Tube',
      Icons.precision_manufacturing,
      'Knitting Tube',
      plan.primaryPlanQuantity.toString(),
    );
    addField(
      'Pcs Per Tray',
      Icons.grid_view,
      'Pcs Per Tray',
      plan.quantityPerTray.toString(),
    );
    addField(
      'Garment Pcs',
      Icons.checkroom,
      'Garment Pcs',
      plan.secondaryPlanQuantity.toString(),
    );
    addField('Shift Code', Icons.schedule, 'Shift Code', shift.code.toString());
    addField(
      'Work Order Code',
      Icons.assignment,
      'Work Order Code',
      workOrder.workOrderCode,
    );
    addField(
      'Work Order Date',
      Icons.event,
      'Work Order Date',
      workOrder.workOrderDate,
    );
    addField(
      'Item Description',
      Icons.description,
      'Item Description',
      item.description,
    );

    return result;
  }

  // ─── User Actions ─────────────────────────────────────────────────────────

  /// Opens barcode scanner for tray. On success, validates and adds tray if eligible.
  Future<void> _onScanTray() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trays',
      onResult: (scannedCode) {
        debugPrint("DEBUG: Scanned code received: $scannedCode");
        final String? validationError = _validateTrayForScan(scannedCode);

        return validationError;
      },
    );
  }

  /// Opens barcode scanner for machine. On success, loads work order from API.
  Future<void> _onScanMachineBarcode() async {
    AppLoader.show();

    final scannedCode = await BarcodeScannerDialog.show(
      context,
      title: 'Scan Barcode',
    );

    if (scannedCode == null || !mounted) {
      AppLoader.hide(); // Ensure loader hides if scan is cancelled
      return;
    }

    setState(() {
      _machineBarcode = scannedCode;
      _planLines = null; // Reset previous data
      _selectedPlanLine = null; // Reset selection
    });

    final apiResult = await _trayScanningRepo.loadWorkOrderBySerialNumber(
      scannedCode,
    );
    final trayDetailsModel = await _trayScanningRepo
        .fetchAvailableTrayDetails();
    final progressResult = await _trayScanningRepo.fetchProductionProgress();

    if (!mounted) return;

    if (apiResult.success && apiResult.data != null) {
      setState(() {
        // Cast the data to our list
        _planLines = List<PlanLineResponseModel>.from(apiResult.data);

        if (progressResult.success && progressResult.data != null) {
          existingProductionProgresses =
              progressResult.data as List<ProductionProgressResponseModel>;
        }

        if (trayDetailsModel.data != null) {
          availableTraysDetail = (trayDetailsModel.data as List)
              .map((item) => item as TrayDetailsModel)
              .toList();
          debugPrint(
            "API LOADED: ${availableTraysDetail.length} trays available for validation.",
          );
        }
        //availableTraysDetail = trayDetailsModel.data as List<TrayDetailsModel>;

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error: $message')));
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Success: $message')));
  }

  /// Save API ────────────────────────────────────────────────────────────────

  void saveTrayAndProductionProgress() async {
    AppLoader.show();
    for (int i = 0; i < _scannedTrays.length; i++) {
      // 1. Re-fetch the latest tray detail to get the current concurrencyStamp
      final trayResFetch = await _trayScanningRepo.fetchTrayById(
        _scannedTrays[i].trayUpdateId!,
      );

      if (!trayResFetch.success || trayResFetch.data == null) {
        if (mounted) {
          AppLoader.hide();
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Save Failed'),
              content: Text(
                'Could not refresh tray details for ${_scannedTrays[i].trayCode}: ${trayResFetch.message}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final latestTray = trayResFetch.data as TrayDetailsModel;
      final latestTrayDetail = latestTray.trayDetails;

      Map<String, dynamic> planData = {
        'description': _selectedPlanLine!.item.description,
        'trayCode': _scannedTrays[i].trayCode,
        'shiftId': _selectedPlanLine!.shift.id,
        'planLineId': _selectedPlanLine!.planLine.id,
        'resourceId': _selectedPlanLine!.resource.id,
        'workOrderHeaderId': _selectedPlanLine!.workOrderHeader.id,
        'workOrderLineId': _selectedPlanLine!.workOrderLine.id,
        'knitItemId': _selectedPlanLine!.planLine.itemId,
        "locatorId": 2,
        "active": true,
        "trayQuantity": (double.tryParse(_quantityControllers[i].text) ?? 5.0)
            .toInt(),
        'concurrencyStamp': latestTrayDetail?.concurrencyStamp,
      };

      Map<String, dynamic> productionProgressData = {
        "subOperation": "Knitting",
        "date": DateTime.now().toIso8601String(),
        "transactionType": 2,
        "operatorDescription": "system",
        "primaryQuantity":
            (double.tryParse(_quantityControllers[i].text) ?? 5.0),
        "primaryUOM": _selectedPlanLine!.planLine.primaryUOM ?? 0,
        "secondaryQuantity":
            (_selectedPlanLine!.item.perGarmentTube) *
            (double.tryParse(_quantityControllers[i].text) ?? 5.0),
        "secondaryUOM": _selectedPlanLine!.planLine.secondaryUOM ?? 0,
        "wipStatus": 0,
        "gbsFlag": false, // Waiting for GBS
        "pbsFlag": false, // false as per requirement
        "productGrade": 0,
        "productNature": 0,
        "isLastProcess": false,
        "lotMakingFlag": false,
        "reworkFlag": false,
        "operationId": _selectedPlanLine!.operation.id,
        "workOrderHeaderId": _selectedPlanLine!.workOrderHeader.id,
        "workOrderLineId": _selectedPlanLine!.workOrderLine.id,
        "itemId": _selectedPlanLine!.planLine.itemId,
        "shiftId": _selectedPlanLine!.planLine.shiftId,
        "primaryTrayId": latestTrayDetail?.id,
        "secondaryTrayId": latestTrayDetail?.id,
        "machineId": _selectedPlanLine!.planLine.resourceId,
        "locatorId": 2,
      };

      if (_selectedPlanLine!.planLine.planHeaderId != 0 &&
          _selectedPlanLine!.planLine.planHeaderId != null) {
        productionProgressData["planHeaderId"] =
            _selectedPlanLine!.planLine.planHeaderId;
      }

      final trayRes = await _trayScanningRepo.updateTrayDetails(
        planData,
        latestTrayDetail!.id!,
      );
      final progRes = await _trayScanningRepo.saveProductionProgress(
        productionProgressData,
      );

      if (!trayRes.success || !progRes.success) {
        if (mounted) {
          AppLoader.hide();
          String error = "";
          if (!trayRes.success)
            error = "Tray Update Failed: ${trayRes.message}";
          if (!progRes.success)
            error = "Production Progress Failed: ${progRes.message}";

          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Save Failed'),
              content: Text(error),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    AppLoader.hide();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved successfully!')));
      setState(() {
        _scannedTrays.clear();
        _quantityControllers.clear();
      });
      Navigator.pop(context);
    }
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
                    children: [
                      _buildMachineScannerSection(),
                      const SizedBox(height: 10),
                      if (_planLines != null) _buildScannedTraysSection(),
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

  /// Section 1: Machine barcode input + work order details.
  Widget _buildMachineScannerSection() {
    final locked = _scannedTrays.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Machine Scanner',
          subtitle: 'Scan the machine barcode to load work order details',
        ),
        const SizedBox(height: 12),
        ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scan Machine Barcode', style: _labelStyle),
              const SizedBox(height: 8),
              IgnorePointer(
                ignoring: locked,
                child: Opacity(
                  opacity: locked ? 0.45 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_selectedPlanLine != null) ...[
                DynamicInfoDisplay(
                  items: _buildPlanLineDetailsMap(_selectedPlanLine!),
                ),
              ],
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
                _machineBarcode.isEmpty
                    ? 'Place cursor here and scan barcode...'
                    : _machineBarcode,
                style: TextStyle(
                  fontSize: 14,
                  color: _machineBarcode.isEmpty
                      ? Colors.grey.shade400
                      : Colors.black87,
                ),
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
        const SectionHeader(
          title: 'Scanned Trays',
          subtitle: 'Scan a machine to start binding trays',
        ),
        const SizedBox(height: 12),
        ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scanned Trays (${_scannedTrays.length})',
                    style: _labelStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 13,
                            ),
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
              if (!hasTrays)
                _buildEmptyState()
              else
                ...List.generate(
                  _scannedTrays.length,
                  (index) => _buildTrayRow(index, _scannedTrays[index]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrayTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'TRAY CODE',
              style: _tableHeaderStyle.copyWith(letterSpacing: 1.1),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'WO',
              style: _tableHeaderStyle.copyWith(letterSpacing: 1.1),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'ITEM DESC',
              style: _tableHeaderStyle.copyWith(letterSpacing: 1.1),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'QUANTITY',
              style: _tableHeaderStyle.copyWith(letterSpacing: 1.1),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'WEIGHT',
              style: _tableHeaderStyle.copyWith(letterSpacing: 1.1),
            ),
          ),
          const SizedBox(width: 40), // Space for the delete icon
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'No scanned trays yet. Start by scanning a tray barcode.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Widget _buildTrayRow(int index, ScannedTray tray) {
    final isEmpty = tray.trayCode.isEmpty;
    final displayCode = isEmpty ? '-' : tray.trayCode;
    final textColor = isEmpty ? Colors.grey.shade400 : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
        // Alternate row colors for better readability
        color: index.isEven ? Colors.white : Colors.grey.shade50,
      ),
      child: Row(
        children: [
          // Tray Code Column
          Expanded(
            flex: 3,
            child: Text(
              displayCode,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
                color: isEmpty ? Colors.grey : Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _selectedPlanLine?.workOrderHeader.workOrderCode ?? "-",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: isEmpty ? Colors.grey : Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _selectedPlanLine?.item.description ?? "-",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: isEmpty ? Colors.grey : Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 55, // Slim text field
                height: 35,
                child: TextField(
                  controller: _quantityControllers[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Builder(
              builder: (_) {
                final qty =
                    double.tryParse(_quantityControllers[index].text) ?? 0;
                final pw = _selectedPlanLine?.item.pieceWeight;
                if (pw == null || pw == 0) {
                  return Text(
                    '-',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                      color: isEmpty ? Colors.grey : Colors.black87,
                    ),
                  );
                }
                final total = qty * pw;
                return Text(
                  '${total.toStringAsFixed(2)} kg',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: isEmpty ? Colors.grey : Colors.black87,
                  ),
                );
              },
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
        child: Icon(Icons.cancel, size: 18, color: Colors.red.shade400),
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
    /// Only show if we actually have data from the scan
    if (_planLines == null || _planLines!.isEmpty)
      return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Work Order & Item Description', style: _labelStyle),
          const SizedBox(height: 8),
          CustomExpandedAsyncDropdown<PlanLineResponseModel>(
            hint: "Select from list...",
            width: double.infinity,
            height: 48,
            borderColor: Colors.blue,
            items: _planLines,
            selectedValue: _selectedPlanLine,
            itemAsString: (plan) =>
                "${plan.workOrderHeader.workOrderCode} - ${plan.item.description}",
            onChanged: (PlanLineResponseModel? newValue) {
              setState(() {
                _selectedPlanLine = newValue;
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
  InputDecoration _inputDecoration({
    required String hintText,
    bool isDense = false,
    EdgeInsetsGeometry? contentPadding,
    double borderRadius = 6,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: _borderColor),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: isDense
          ? null
          : Icon(Icons.qr_code_scanner, size: 20, color: Colors.grey.shade400),
      border: border,
      focusedBorder: border,
      enabledBorder: border,
      isDense: isDense,
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
