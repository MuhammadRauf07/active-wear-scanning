import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_expanded_async_dropdown.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/batch/model/batch_machine_model.dart';
import 'package:active_wear_scanning/features/batch/model/batch_color_model.dart';
import 'package:active_wear_scanning/features/batch/model/batch_header_model.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:flutter/material.dart';

class BatchScanningScreen extends StatefulWidget {
  final BatchHeaderResponseModel? existingBatch;
  final List<ProductionProgressResponseModel>? preloadedTrays;

  const BatchScanningScreen({
    super.key, 
    this.existingBatch, 
    this.preloadedTrays
  });

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
    _fetchColors();
    _fetchProductionProgresses();
  }

  /// In edit mode, load the trays that are already linked to this batch
  /// via the batch-lines API. This is the reliable source of truth.
  Future<void> _loadExistingBatchTrays(List<ProductionProgressResponseModel> allProgresses) async {
    if (widget.existingBatch == null) return;
    final batchHeaderId = widget.existingBatch!.batchHeader.id;
    if (batchHeaderId == null) return;

    final linesRes = await _batchRepo.fetchBatchLines(batchHeaderId: batchHeaderId);
    if (!mounted || !linesRes.success || linesRes.data == null) return;

    final rawLines = linesRes.data as List<Map<String, dynamic>>;
    final linkedProgressIds = rawLines
        .map((l) => l['batchLines']?['progressId'] as int?)
        .whereType<int>()
        .toSet();

    final linkedTrays = allProgresses
        .where((p) => linkedProgressIds.contains(p.productionProgress.id))
        .toList();

    if (mounted && linkedTrays.isNotEmpty) {
      setState(() {
        _scannedTrays.addAll(linkedTrays);
        for (var tray in linkedTrays) {
          _quantityControllers.add(TextEditingController(
              text: tray.productionProgress.primaryQuantity?.toStringAsFixed(0) ?? '0'));
        }
      });
    }
  }



  Future<void> _fetchProductionProgresses() async {
    final result = await _batchRepo.fetchProductionProgress();
    if (mounted && result.success && result.data != null) {
      final progresses = result.data as List<ProductionProgressResponseModel>;
      setState(() {
        productionProgressTrays = progresses;
      });
      // In edit mode, once we have all progresses, load the ones linked to this batch
      await _loadExistingBatchTrays(progresses);
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

        if(widget.existingBatch?.machine != null) {
          final editMachineId = widget.existingBatch!.machine!.id;
          final match = _machines.where((m) => m.resource?.id == editMachineId).toList();
          if (match.isNotEmpty) _selectedMachine = match.first;
        }
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

        if(widget.existingBatch?.colorCode != null) {
           final editColorId = widget.existingBatch!.colorCode!.id;
           final match = _colors.where((c) => c.segmentCode?.id == editColorId).toList();
           if(match.isNotEmpty) _selectedColor = match.first;
         }
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

    AppLoader.show();

    // ── Determine batchHeaderId ──────────────────────────────────────────────
    // EDIT mode: batch already exists, reuse its ID
    // CREATE mode: POST new batch header first
    int batchHeaderId;
    final bool isEditMode = widget.existingBatch != null;

    if (isEditMode) {
      batchHeaderId = widget.existingBatch!.batchHeader.id!;
    } else {
      final String timestampStr = DateTime.now().millisecondsSinceEpoch.toString();
      final String batchCode = "BCH-${timestampStr.substring(timestampStr.length - 5)}";

      Map<String, dynamic> batchHeaderPayload = {
        "planDate": DateTime.now().toIso8601String(),
        "colorDescription": _selectedColor?.segmentCode?.description ?? "Undefined",
        "batchHeaderCode": batchCode,
        "machineId": _selectedMachine?.resource?.id ?? 0,
        "colorCode": _selectedColor?.segmentCode?.id ?? 0,
        "shiftId": _scannedTrays.first.shift.id,
        "lockFlag": false,
      };

      final headerResponse = await _batchRepo.createBatchHeader(batchHeaderPayload);
      if (!headerResponse.success) {
        AppLoader.hide();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Header Failed: ${headerResponse.message}')));
        return;
      }
      batchHeaderId = headerResponse.data['id'] as int;
    }

    // ── Fetch existing batch-lines to know which trays are already saved ─────
    // Key: trayId → already has a BatchLine, skip POST for these
    final Set<int> alreadyLinkedTrayIds = {};
    if (isEditMode) {
      final linesRes = await _batchRepo.fetchBatchLines(batchHeaderId: batchHeaderId);
      if (linesRes.success && linesRes.data != null) {
        final rawLines = linesRes.data as List<Map<String, dynamic>>;
        for (var line in rawLines) {
          final trayId = line['batchLines']?['trayId'];
          if (trayId != null) alreadyLinkedTrayIds.add(trayId as int);
        }
      }
    }

    // ── Per-tray updates ─────────────────────────────────────────────────────
    for (int i = 0; i < _scannedTrays.length; i++) {
      final currentTrayData = _scannedTrays[i];
      final trayId = currentTrayData.primaryTrayModel.id;

      // 1. Update ProductionProgress with batchHeaderId
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
        "progressCode": currentTrayData.productionProgress.progressCode,
        "batchHeaderId": batchHeaderId,
        "operationId": currentTrayData.operation.id,
        "workOrderHeaderId": currentTrayData.workOrderHeader.id,
        "workOrderLineId": currentTrayData.workOrderLine.id,
        "itemId": currentTrayData.item.id,
        "shiftId": currentTrayData.shift.id,
        "primaryTrayId": trayId,
        "machineId": _selectedMachine?.resource?.id ?? currentTrayData.machineModel.id,
        "planHeaderId": currentTrayData.planHeader.id,
        "locatorId": currentTrayData.productionProgress.locatorId,
        "concurrencyStamp": currentTrayData.productionProgress.concurrencyStamp,
      };

      if (currentTrayData.productionProgress.id != null) {
        final prodRes = await _batchRepo.updateProductionProgress(currentTrayData.productionProgress.id!, updateData);
        if (!prodRes.success) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Prod Progress Failed: ${prodRes.message}')));
        }
      }

      // 2. Update TrayDetails with batchHeaderId (GET then PUT bounce)
      if (trayId != null) {
        final getTrayRes = await _batchRepo.fetchTrayDetailById(trayId);
        if (getTrayRes.success && getTrayRes.data != null) {
          Map<String, dynamic> rawTrayPayload = getTrayRes.data.containsKey('trayDetail')
              ? getTrayRes.data['trayDetail']
              : getTrayRes.data;
          rawTrayPayload["batchHeaderId"] = batchHeaderId;
          rawTrayPayload.remove("creatorId");
          rawTrayPayload.remove("creationTime");
          rawTrayPayload.remove("lastModifierId");
          rawTrayPayload.remove("lastModificationTime");
          final trayRes = await _batchRepo.updateTrayDetails(trayId, rawTrayPayload);
          if (!trayRes.success) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tray Fix Failed: ${trayRes.message}')));
          }
        }
      }

      // 3. POST a new BatchLine ONLY if this tray is not already linked
      final bool isNewTray = trayId == null || !alreadyLinkedTrayIds.contains(trayId);
      if (isNewTray) {
        final String lineCode = "BL-$batchHeaderId-${trayId ?? i}";
        Map<String, dynamic> batchLinePayload = {
          "planDate": DateTime.now().toIso8601String(),
          "transactionDate": DateTime.now().toIso8601String(),
          "primaryQuantity": currentTrayData.productionProgress.primaryQuantity ?? 0,
          "primaryUOM": currentTrayData.productionProgress.primaryUOM ?? 0,
          "secondaryQuantity": currentTrayData.productionProgress.secondaryQuantity ?? 0,
          "secondaryUOM": currentTrayData.productionProgress.secondaryUOM ?? 0,
          "batchLineCode": lineCode,
          "batchHeaderId": batchHeaderId,
          "workOrderHeaderId": currentTrayData.workOrderHeader.id,
          "workOrderLineId": currentTrayData.workOrderLine.id,
          "itemId": currentTrayData.item.id,
          "trayId": trayId,
          "locatorId": currentTrayData.productionProgress.locatorId,
        };
        // Only include optional FK fields if they have valid values
        if (currentTrayData.productionProgress.id != null) {
          batchLinePayload["progressId"] = currentTrayData.productionProgress.id;
        }

        final lineRes = await _batchRepo.createBatchLine(batchLinePayload);
        if (!lineRes.success) {
          AppLoader.hide();
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('BatchLine Failed'),
              content: SingleChildScrollView(
                child: Text(
                  'Tray $trayId failed to link to batch.\n\nFull Server Error:\n${lineRes.message}',
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
            ),
          );
          AppLoader.show();
        }
      }
    }

    AppLoader.hide();
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
                                  Expanded(flex: 2, child: Text('WEIGHT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
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
