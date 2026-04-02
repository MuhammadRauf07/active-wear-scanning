import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_expanded_async_dropdown.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/batch/model/batch_machine_model.dart';
import 'package:active_wear_scanning/features/batch/model/batch_color_model.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:flutter/material.dart';

class BatchScanningScreen extends StatefulWidget {
  const BatchScanningScreen({super.key});

  @override
  State<BatchScanningScreen> createState() => _BatchScanningScreenState();
}

class _BatchScanningScreenState extends State<BatchScanningScreen> {
  final _batchRepo = BatchRepo(); 

  List<BatchMachineModel> _machines = [];
  BatchMachineModel? _selectedMachine;
  bool _isLoading = true;

  List<BatchColorModel> _colors = [];
  BatchColorModel? _selectedColor;
  bool _isLoadingColors = false;

  final List<ProductionProgressResponseModel> _scannedTrays = [];
  final List<TextEditingController> _quantityControllers = [];
  final _overrideQuantityController = TextEditingController();

  List<ProductionProgressResponseModel> productionProgressTrays = [];

  static const _inputAndButtonHeight = 42.0;

  @override
  void initState() {
    super.initState();
    _fetchMachines();
    _fetchProductionProgresses();
  }

  Future<void> _fetchProductionProgresses() async {
    final result = await _batchRepo.fetchProductionProgress();
    if (mounted && result.success && result.data != null) {
      setState(() {
        productionProgressTrays = result.data as List<ProductionProgressResponseModel>;
      });
    }
  }

  @override
  void dispose() {
    _overrideQuantityController.dispose();
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchMachines() async {
    setState(() => _isLoading = true);
    final result = await _batchRepo.fetchBatchMachines();
    
    if (!mounted) return;

    if (result.success && result.data != null) {
      setState(() {
        _machines = result.data as List<BatchMachineModel>;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${result.message}')),
      );
    }
  }

  Future<void> _fetchColors() async {
    setState(() => _isLoadingColors = true);
    final result = await _batchRepo.fetchBatchColors();
    
    if (!mounted) return;

    if (result.success && result.data != null) {
      setState(() {
        _colors = result.data as List<BatchColorModel>;
        _isLoadingColors = false;
      });
    } else {
      setState(() => _isLoadingColors = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${result.message}')),
      );
    }
  }

  Future<void> _onScanTray() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trays',
      onResult: (scannedCode) {
        final code = scannedCode.trim();
        if (code.isEmpty) return 'Invalid tray code';
        if (_scannedTrays.any((t) => (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase() == code.toLowerCase())) return 'Already assigned';
        
        final available = productionProgressTrays.where((t) => 
           (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase() == code.toLowerCase() &&
           t.productionProgress.locatorId == 3 &&
           t.productionProgress.gbsFlag == true
        ).toList();

        if (available.isEmpty) return 'Tray not found or not checked out via GBS';
        
        setState(() {
          _scannedTrays.add(available.first);
          _quantityControllers.add(TextEditingController(text: _overrideQuantityController.text));
        });
        
        return null; // OK
      },
    );
  }

  Future<void> _saveBatchChanges() async {
    if (_scannedTrays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No trays to save.')));
      return;
    }
    
    final String batchId = "BCH-${DateTime.now().millisecondsSinceEpoch}";

    AppLoader.show();
    
    for (int i = 0; i < _scannedTrays.length; i++) {
      final currentTrayData = _scannedTrays[i];
      
      Map<String, dynamic> updateData = {
        "subOperation": "Batch Received",
        "date": DateTime.now().toIso8601String(),
        "transactionType": currentTrayData.productionProgress.transactionType,
        "operatorDescription": "system",
        "primaryQuantity": currentTrayData.productionProgress.primaryQuantity,
        "primaryUOM": currentTrayData.productionProgress.primaryUOM,
        "secondaryQuantity": currentTrayData.productionProgress.secondaryQuantity,
        "secondaryUOM": currentTrayData.productionProgress.secondaryUOM,
        "wipStatus": currentTrayData.productionProgress.wipStatus,
        "gbsFlag": true,
        "pbsFlag": true, 
        "progressCode": batchId, // Unified ID for Clubbing!
        "operationId": currentTrayData.operation.id,
        "workOrderHeaderId": currentTrayData.workOrderHeader.id,
        "workOrderLineId": currentTrayData.workOrderLine.id,
        "itemId": currentTrayData.item.id,
        "shiftId": currentTrayData.shift.id,
        "primaryTrayId": currentTrayData.primaryTrayModel.id,
        "machineId": _selectedMachine!.resource?.id ?? currentTrayData.machineModel.id, // Override with Batch Machine
        "planHeaderId": currentTrayData.planHeader.id,
        "locatorId": currentTrayData.productionProgress.locatorId,
        "concurrencyStamp": currentTrayData.productionProgress.concurrencyStamp,
      };

      if (currentTrayData.productionProgress.id != null) {
        await _batchRepo.updateProductionProgress(currentTrayData.productionProgress.id!, updateData);
      }
    }
    
    AppLoader.hide();
    
    // Return back to tracking screen to auto-refresh!
    Navigator.pop(context, true);
  }

  InputDecoration _inputDecoration({required String hintText, bool isDense = false, EdgeInsetsGeometry? contentPadding, double borderRadius = 6}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: Colors.blue),
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
                heading: 'Batch Scanning',
                subtitle: 'Select machine to begin batch processing',
                isShowBackIcon: true,
                topPadding: 0,
                horizontalPadding: 12,
                widget: CustomOutlinedButton(
                  label: 'Save Changes',
                  borderColor: Colors.blue,
                  textColor: Colors.blue,
                  buttonHeight: _inputAndButtonHeight,
                  onPressed: _saveBatchChanges,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Machine Selection', 
                        subtitle: 'Please select a machine from the list below'
                      ),
                      const SizedBox(height: 12),
                      ContentCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Select Machine', 
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                                ),
                                if (_selectedMachine != null)
                                  Text(
                                    'Capacity: ${_selectedMachine!.resource?.capacity ?? "N/A"}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else
                              CustomExpandedAsyncDropdown<BatchMachineModel>(
                                hint: "Select from list...",
                                width: double.infinity,
                                height: 48,
                                borderColor: Colors.blue,
                                items: _machines,
                                selectedValue: _selectedMachine,
                                itemAsString: (machine) => machine.resource?.brand ?? 'Unknown Brand',
                                onChanged: (BatchMachineModel? newValue) {
                                  setState(() {
                                    _selectedMachine = newValue;
                                    _selectedColor = null; // Reset color
                                    _scannedTrays.clear(); // Reset trays
                                    _quantityControllers.clear();
                                  });
                                  if (newValue != null) {
                                    _fetchColors();
                                  }
                                },
                              ),
                            
                            // Color Dropdown
                            if (_selectedMachine != null) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Select Color', 
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              if (_isLoadingColors)
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              else
                                CustomExpandedAsyncDropdown<BatchColorModel>(
                                  hint: "Select color...",
                                  width: double.infinity,
                                  height: 48,
                                  borderColor: Colors.blue,
                                  items: _colors,
                                  selectedValue: _selectedColor,
                                  itemAsString: (color) => color.segmentCode?.description ?? 'Unknown Color',
                                  onChanged: (BatchColorModel? newValue) {
                                    setState(() {
                                      _selectedColor = newValue;
                                      _scannedTrays.clear(); // Reset trays
                                      _quantityControllers.clear();
                                    });
                                  },
                                ),
                            ]
                          ],
                        ),
                      ),
                      
                      // Scan Trays Section
                      if (_selectedColor != null) ...[
                        const SizedBox(height: 16),
                        const SectionHeader(title: 'Scanned Trays', subtitle: 'Scan a tray to start binding'),
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
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)
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
                              Row(
                                children: [
                                  Expanded(flex: 2, child: Text('TRAY CODE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                                  Expanded(flex: 2, child: Text('WORK ORDER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                                  Expanded(flex: 3, child: Text('ITEM DESC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                                  Expanded(flex: 2, child: Text('CAPACITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                                  const SizedBox(width: 44),
                                ],
                              ),
                              if (_scannedTrays.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text('No scanned trays yet. Start by scanning a tray barcode.', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                                  ),
                                )
                              else
                                ...List.generate(_scannedTrays.length, (index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            _scannedTrays[index].primaryTrayModel.trayCode ?? '', 
                                            style: const TextStyle(fontSize: 14, color: Colors.black87)
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            _scannedTrays[index].workOrderHeader.workOrderCode, 
                                            style: const TextStyle(fontSize: 13, color: Colors.black87)
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            _scannedTrays[index].item.description, 
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13, color: Colors.black87)
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: const Text(
                                            '-', 
                                            style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _quantityControllers[index].dispose();
                                              _quantityControllers.removeAt(index);
                                              _scannedTrays.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
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
}
