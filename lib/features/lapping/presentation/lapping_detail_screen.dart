import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/lapping/model/lapping_model.dart';
import 'package:active_wear_scanning/features/lapping/model/work_order_summary.dart';
import 'package:active_wear_scanning/features/lapping/presentation/widgets/lapping_scanner_ui.dart';
import 'package:active_wear_scanning/features/lapping/presentation/widgets/lapping_tray_table.dart';
import 'package:active_wear_scanning/features/lapping/presentation/widgets/work_order_selection_card.dart';
import 'package:active_wear_scanning/features/lapping/repo/lapping_repo.dart';
import 'package:active_wear_scanning/features/processing/repo/processing_repo.dart';
import 'package:flutter/material.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';

class LappingDetailScreen extends StatefulWidget {
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
  State<LappingDetailScreen> createState() => _LappingDetailScreenState();
}

class _LappingDetailScreenState extends State<LappingDetailScreen> {
  static const _inputAndButtonHeight = 44.0;
  static final _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );
  
  final _processingRepo = ProcessingRepo();
  final _batchRepo = BatchRepo();
  final _lappingRepo = LappingRepo();
  bool _isLoading = false;
  List<LappingModel> _trays = [];
  final Map<String, WorkOrderSummary> _workOrders = {};
  String? _selectedWorkOrderId;
  final Map<String, List<LappingModel>> _scannedTraysByWO = {};

  final _trayBarcodeController = TextEditingController();
  final _trayQtyController = TextEditingController();
  final _trayFocusNode = FocusNode();

  final Map<String, double> _trayOverrideQuantities = {};

  final FocusNode _focusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  @override
  void dispose() {
    _focusNode.dispose();
    _trayQtyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBatchData();
    });
  }

  void _onKey(RawKeyEvent event) {
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
    final code = scannedCode.trim();
    if (code.isEmpty) return;

    if (_selectedWorkOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Work Order first')));
      return;
    }
    
    AppLoader.show(context, message: 'Validating Tray...');
    final error = await _onTrayScanned(code);
    AppLoader.hide(context);
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red));
    }
  }

  Future<void> _fetchBatchData() async {
    setState(() => _isLoading = true);

    final res = await _lappingRepo.fetchProductionProgress({
      'BatchHeaderId': widget.batchHeaderId.toString(),
      'TransactionType': '2',
    });

    if (res.success && res.data != null) {
      final List<LappingModel> fetchedTrays =
      res.data as List<LappingModel>;

      final Map<String, WorkOrderSummary> summaries = {};

      for (final tray in fetchedTrays) {
        final woId = tray.workOrderHeader?.id;
        final itemDesc = tray.processedItem?.description ?? tray.item?.description ?? '';

        if (woId != null && itemDesc.isNotEmpty) {
          final compositeId = '${woId}_$itemDesc';

          if (summaries.containsKey(compositeId)) {
            final existing = summaries[compositeId]!;
            summaries[compositeId] = WorkOrderSummary(
              id: compositeId,
              description: existing.description,
              componentDescription: existing.componentDescription,
              trayCount: existing.trayCount + 1,
              cumulativePieces: existing.cumulativePieces + (tray.productionProgress.primaryQuantity ?? 0),
            );
          } else {
            final woDesc = tray.workOrderHeader?.description ?? '';
            summaries[compositeId] = WorkOrderSummary(
              id: compositeId,
              description: woDesc,
              componentDescription: itemDesc,
              trayCount: 1,
              cumulativePieces: tray.productionProgress.primaryQuantity ?? 0,
            );
          }
        }
      }

      setState(() {
        _trays = fetchedTrays;
        _workOrders.clear();
        _workOrders.addAll(summaries);
        _isLoading = false;
        _selectedWorkOrderId = null;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${res.message}')),
        );
      }
    }
  }

  // --- Core Validation Logic (Updated for Tray-Detail Support) ---
  Future<String?> _onTrayScanned(String code) async {
    if (_trayQtyController.text.trim().isEmpty) return 'Please add No. of Pcs before scanning!';
    final double inputPcs = double.tryParse(_trayQtyController.text) ?? 0;
    if (inputPcs <= 0) return 'Pcs amount must be greater than 0!';

    final trayCode = code.trim().toLowerCase();
    if (trayCode.isEmpty) return 'Invalid tray code';

    final activeSummary = _workOrders[_selectedWorkOrderId];
    if (activeSummary == null) return 'No Active Work Order selected!';

    final currentWOTrays = _scannedTraysByWO[_selectedWorkOrderId] ?? [];
    if (currentWOTrays.any((t) => t.primaryTrayModel.trayCode?.toLowerCase() == trayCode)) {
      return 'Tray already scanned in this session!';
    }

    double totalScanned = currentWOTrays.fold(0, (sum, t) =>
    sum + (_trayOverrideQuantities[t.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0));

    if ((totalScanned + inputPcs) > activeSummary.cumulativePieces) {
      return 'Limit exceeded! Max: ${activeSummary.cumulativePieces}';
    }

    LappingModel? matchedTray;
    matchedTray = _trays.where((t) => t.primaryTrayModel.trayCode?.toLowerCase() == trayCode).firstOrNull;

    // trayType validation — only Type 1 trays allowed
    if (matchedTray != null && (matchedTray.primaryTrayModel.trayType ?? 0) != 1) {
      return 'Invalid tray type.';
    }

    if (matchedTray == null) {
      AppLoader.show(context, message: "Searching system trays...");
      final trayRes = await _batchRepo.fetchTrayDetailByCode(trayCode);
      AppLoader.hide(context);

      if (trayRes.success && trayRes.data != null) {
        final trayMap = trayRes.data.containsKey('trayDetail') ? trayRes.data['trayDetail'] : trayRes.data;
        final int? existingBatch = trayMap['batchHeaderId'];
        if (existingBatch != null && existingBatch != 0 && existingBatch != widget.batchHeaderId) {
          return 'Tray belongs to another batch ($existingBatch)';
        }

        final refTray = _trays.firstWhere((t) => '${t.workOrderHeader.id}_${t.processedItem?.description ?? t.item.description}' == _selectedWorkOrderId);

        matchedTray = LappingModel(
          productionProgress: ProductionProgress(
            id: null,
            primaryTrayId: trayMap['id'],
            locatorId: trayMap['locatorId'] ?? 2,
            primaryQuantity: inputPcs,
            transactionType: 2,
            processedItemId: refTray.productionProgress.processedItemId, // ✅ FIXED: Preserve inner ID
          ),
          operation: refTray.operation,
          shift: refTray.shift,
          machineModel: refTray.machineModel,
          workOrderHeader: refTray.workOrderHeader,
          workOrderLine: refTray.workOrderLine,
          item: refTray.item,
          processedItem: refTray.processedItem, // ✅ FIXED: Preserve processedItem
          primaryTrayModel: PrimaryTrayModel(
            id: trayMap['id'],
            trayCode: trayMap['trayCode'],
            concurrencyStamp: trayMap['concurrencyStamp'],
          ),
        );
      } else {
        return 'Tray not available in system!';
      }
    }

    // Fetch metadata from item-defs using main item ID
    final mainItemId = matchedTray.item?.id ?? 0;
    final processedItemId = matchedTray.productionProgress.processedItemId;
    String colorDesc = matchedTray.item?.colorDescription ?? '';
    String sizeDesc = matchedTray.item?.sizeDescription ?? '';
    double perGarmentTube = matchedTray.item?.perGarmentTube ?? 0;

    if (mainItemId > 0) {
      AppLoader.show(context, message: 'Fetching item details...');
      final itemRes = await _lappingRepo.fetchItemDef(mainItemId);
      AppLoader.hide(context);
      if (itemRes.success && itemRes.data != null) {
        final itemData = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
        if (itemData['perGarmentTube'] != null) perGarmentTube = (itemData['perGarmentTube'] as num).toDouble();
        if (itemData['colorDescription'] != null) colorDesc = itemData['colorDescription'];
        if (itemData['sizeDescription'] != null) sizeDesc = itemData['sizeDescription'];
      }
    }

    // If color still empty, try processedItemId as fallback
    if (colorDesc.isEmpty && processedItemId != null && processedItemId > 0) {
      AppLoader.show(context, message: 'Fetching color details...');
      final processedRes = await _lappingRepo.fetchItemDef(processedItemId);
      AppLoader.hide(context);
      if (processedRes.success && processedRes.data != null) {
        final pd = processedRes.data is Map ? processedRes.data as Map<String, dynamic> : {};
        if (pd['colorDescription'] != null) colorDesc = pd['colorDescription'];
        if (sizeDesc.isEmpty && pd['sizeDescription'] != null) sizeDesc = pd['sizeDescription'];
      }
    }

    // Rebuild matchedTray with enriched item
    if (matchedTray.item != null) {
      final updatedItem = matchedTray.item!.copyWith(
        colorDescription: colorDesc,
        sizeDescription: sizeDesc,
        perGarmentTube: perGarmentTube,
      );
      matchedTray = LappingModel(
        productionProgress: matchedTray.productionProgress,
        operation: matchedTray.operation,
        shift: matchedTray.shift,
        machineModel: matchedTray.machineModel,
        workOrderHeader: matchedTray.workOrderHeader,
        workOrderLine: matchedTray.workOrderLine,
        primaryTrayModel: matchedTray.primaryTrayModel,
        item: updatedItem,
        processedItem: matchedTray.processedItem,
        planHeader: matchedTray.planHeader,
        batchHeader: matchedTray.batchHeader,
      );
    }

    setState(() {
      _trayOverrideQuantities[trayCode] = inputPcs;
      _scannedTraysByWO.putIfAbsent(_selectedWorkOrderId!, () => []);
      _scannedTraysByWO[_selectedWorkOrderId!]!.add(matchedTray!);
      _focusNode.requestFocus();
    });
    return null;
  }

  void _openScanner() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Tray',
      onResult: (scannedCode) async {
        return await _onTrayScanned(scannedCode);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: _onKey,
        child: SafeArea(
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).requestFocus(_focusNode);
            },
            behavior: HitTestBehavior.opaque,
            child: ExcludeSemantics(
              excluding: _isLoading,
              child: Column(
            children: [
              CustomInspectionHeader(
                heading: 'Lapping Details',
                subtitle: widget.batchCode,
                isShowBackIcon: true,
                topPadding: 10,
                horizontalPadding: 12,
                buttonLabel: 'Submit',
                callBack: _saveChanges,
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DynamicInfoDisplay(
                              items: {
                                'batch': {'icon': Icons.qr_code, 'label': 'Batch ID', 'value': widget.batchCode},
                                'machine': {'icon': Icons.precision_manufacturing, 'label': 'Machine', 'value': widget.machine},
                                'color': {'icon': Icons.palette, 'label': 'Color', 'value': widget.color},
                                'weight': {'icon': Icons.scale, 'label': 'Req Weight', 'value': '${widget.totalWeight.toStringAsFixed(2)} g'},
                                'trays': {'icon': Icons.layers, 'label': 'Active Trays', 'value': '${widget.trayCount} trays'},
                              },
                            ),
                            const SizedBox(height: 20),
                            WorkOrderSelectionCard(
                              workOrders: _workOrders,
                              selectedWorkOrderId: _selectedWorkOrderId,
                              scannedTraysByWO: _scannedTraysByWO,
                              trayOverrideQuantities: _trayOverrideQuantities,
                              onSelected: (val) => setState(() => _selectedWorkOrderId = val),
                            ),
                            if (_selectedWorkOrderId != null) ...[
                              // const SizedBox(height: 24),
                              // const SectionHeader(title: 'Scan Trays', subtitle: 'Verify and assign trays to the selected work order'),
                              const SizedBox(height: 12),
                              LappingScannerUI(
                                selectedWorkOrderId: _selectedWorkOrderId,
                                scannedTraysByWO: _scannedTraysByWO,
                                trayQtyController: _trayQtyController,
                                focusNode: _focusNode,
                                onScanPressed: _openScanner,
                                childTable: Builder(
                                  builder: (_) {
                                    final traysToShow = _scannedTraysByWO[_selectedWorkOrderId] ?? [];
                                    if (traysToShow.isNotEmpty) {
                                      return LappingTrayTable(
                                        selectedWorkOrderId: _selectedWorkOrderId,
                                        scannedTraysByWO: _scannedTraysByWO,
                                        trayOverrideQuantities: _trayOverrideQuantities,
                                        onRemove: (t, trayKey) {
                                          setState(() {
                                            _scannedTraysByWO[_selectedWorkOrderId]?.remove(t);
                                            _trayOverrideQuantities.remove(trayKey);
                                          });
                                        },
                                      );
                                    } else {
                                      return Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 40),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'No scanned trays yet. Start by scanning a tray barcode.',
                                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                        ),
                                      );
                                    }
                                  },
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
      ),
      ),
    );
  }

  // Removed _buildScannerUI as it was extracted to LappingScannerUI.

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // --- Submission Logic ---
  Future<void> _saveChanges() async {
    final allScannedTrays = _scannedTraysByWO.values.expand((list) => list).toList();

    if (allScannedTrays.isEmpty) {
      _showDialog('No Trays Scanned', 'Please scan at least one tray.');
      return;
    }

    // Completion validation
    for (final wo in _workOrders.values) {
      if ((_scannedTraysByWO[wo.id] ?? []).isEmpty) {
        _showDialog('Incomplete', 'Missing trays for "${wo.componentDescription}"');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      // Only process newly reassigned trays
      final assignedTrays = _scannedTraysByWO.values.expand((list) => list).toList();
      final allScannedTrays = assignedTrays;

      if (allScannedTrays.isEmpty) {
        AppLoader.hide(context);
        setState(() => _isLoading = false);
        _showDialog('No Changes', 'No new trays were reassigned.');
        return;
      }

      // --- Step 2 & 3: Sequential Processing (Audit -> BatchLine -> Progress) ---
      // Determine Handover Location
      int nextLocatorId = 3; 
      final baseProgress = allScannedTrays.first.productionProgress;
      final handoverOpId = widget.nextOperationId ?? baseProgress?.operationId;

      if (handoverOpId != null) {
        final locRes = await _batchRepo.fetchLocators(operationId: handoverOpId);
        if (locRes.success && locRes.data != null) {
          final locList = locRes.data as List;
          final matchingEntry = locList.cast<Map>().firstWhere(
                (entry) => (entry['operation']?['id'] ?? entry['locator']?['operationId'])?.toString() == handoverOpId.toString(),
            orElse: () => {},
          );
          if (matchingEntry.isNotEmpty) {
            nextLocatorId = matchingEntry['locator']?['id'] as int? ?? 3;
          }
        }
      }
           for (final scannedTray in allScannedTrays) {
        final double trayQty = _trayOverrideQuantities[scannedTray.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0;
        
        // --- 1. SET UP AND CREATE HANDOVER PRODUCTION PROGRESS (THE ANCHOR RECORD) ---
        Map<String, dynamic> nextJson = scannedTray.productionProgress.toJson();
        nextJson.remove('id');
        nextJson.remove('progressCode');
        nextJson.remove('concurrencyStamp');
        nextJson.remove('batchLinesId');

        nextJson.addAll({
          "subOperation": "Handover",
          "transactionType": 2, // Handover
          "primaryTrayId": scannedTray.primaryTrayModel.id,
          "secondaryTrayId": scannedTray.primaryTrayModel.id, // Fill secondary fallback
          "primaryQuantity": trayQty,
          "secondaryQuantity": scannedTray.productionProgress.secondaryQuantity ?? 0,
          "primaryUOM": scannedTray.productionProgress.primaryUOM ?? 4,
          "secondaryUOM": scannedTray.productionProgress.secondaryUOM ?? 1,
          "productGrade": scannedTray.productionProgress.productGrade ?? 0,
          "productNature": scannedTray.productionProgress.productNature ?? 0,
          "shiftId": scannedTray.productionProgress.shiftId ?? 1,
          "machineId": scannedTray.productionProgress.machineId ?? (_trays.isNotEmpty ? _trays.first.productionProgress.machineId : null),
          "isLastProcess": false,
          "reworkFlag": false,
          "lotMakingFlag": false, // Strict pass
          "locatorId": nextLocatorId,
          "operationId": handoverOpId ?? scannedTray.productionProgress.operationId,
          "wipStatus": widget.nextOperationId != null ? 0 : 1,
          "gbsFlag": false,
          "pbsFlag": false,
          "date": DateTime.now().toIso8601String(),
          "operatorDescription": "system",
          "processedItemId": scannedTray.processedItem?.id ?? scannedTray.productionProgress.processedItemId ?? scannedTray.item.id,
          "itemId": scannedTray.item.id,
          "workOrderHeaderId": scannedTray.workOrderHeader.id,
          "workOrderLineId": scannedTray.workOrderLine.id,
        });

        // Include batchHeaderId in the initial creation so the Handover PP is always
        // grouped correctly in ProcessingScreen._fetchOpDetails (which groups by batchHeaderId).
        nextJson['batchHeaderId'] = widget.batchHeaderId;
        nextJson.remove("planHeaderId"); // Only planHeaderId needs purging

        final ppRes = await _processingRepo.createProductionProgress(nextJson);
        if (!ppRes.success) {
          throw Exception("Failed to generate Handover Progress track sequence for tray. Server Message: ${ppRes.message}");
        }
        // Parse targetProgressId safely — ABP POST returns id=0 in the body (backend quirk)
        // The record IS persisted — we must re-fetch by operationId+trayId to get the real ID.
        final dynamic ppData = ppRes.data;
        debugPrint('🆕 PP Create Response: $ppData');
        int? targetProgressId;
        if (ppData is Map) {
          final rawId = int.tryParse(ppData['id']?.toString() ?? '');
          if (rawId != null && rawId > 0) targetProgressId = rawId;
        } else if (ppData is int && ppData > 0) {
          targetProgressId = ppData;
        }

        // ABP returns id=0 → re-fetch to resolve the real DB id
        ProductionProgressResponseModel? latestHandoverPP;
        if (targetProgressId == null || targetProgressId == 0) {
          debugPrint('⚠️ id=0 returned — re-fetching PP by operationId+trayId...');
          final refetchRes = await _processingRepo.fetchProductionProgress({
            'OperationId': (handoverOpId ?? scannedTray.productionProgress.operationId).toString(),
            'TransactionType': '2',
          });
          if (refetchRes.success && refetchRes.data != null) {
            final list = refetchRes.data as List<ProductionProgressResponseModel>;
            final matches = list.where((r) =>
              r.primaryTrayModel.id == scannedTray.primaryTrayModel.id &&
              (r.productionProgress.subOperation ?? '').toLowerCase() == 'handover'
            ).toList();
            if (matches.isNotEmpty) {
              matches.sort((a, b) => (a.productionProgress.id ?? 0).compareTo(b.productionProgress.id ?? 0));
              latestHandoverPP = matches.last;
              targetProgressId = latestHandoverPP.productionProgress.id;
            }
          }
        }

        if (targetProgressId == null || targetProgressId == 0) {
          throw Exception("Could not resolve Handover Progress ID after creation. Raw: $ppData");
        }
        debugPrint('✅ Resolved targetProgressId: $targetProgressId');


        // --- 2. FETCH PREVIOUS WIP TRANSACTION (From the tray's state prior to Handover) ---
        int? wipId;
        if (scannedTray.productionProgress.id != null) {
          final nativeWipRes = await _batchRepo.fetchWipTransactionsByProgressId(scannedTray.productionProgress.id!);
          if (nativeWipRes.success && nativeWipRes.data != null) {
            final items = nativeWipRes.data as List<Map<String, dynamic>>;
            if (items.isNotEmpty) {
              wipId = items.first['wipTransaction']?['id'] as int?;
            }
          }
        }

        // --- 3. CREATE BATCH LINE (Cross-linked to established WIP logically) ---
        int? blId;
        if (wipId != null) {
            final blRes = await _batchRepo.createBatchLine({
            "planDate": DateTime.now().toIso8601String(),
            "transactionDate": DateTime.now().toIso8601String(),
            "primaryQuantity": trayQty,
            "primaryUOM": scannedTray.productionProgress.primaryUOM ?? 4,
            "secondaryQuantity": 0, 
            "secondaryUOM": scannedTray.productionProgress.secondaryUOM ?? 1,
            "batchLineCode": "BL-${widget.batchHeaderId}-${scannedTray.primaryTrayModel.id}",
            "batchHeaderId": widget.batchHeaderId,
            "progressId": targetProgressId,
            "wipTransactionId": wipId, 
            "workOrderHeaderId": scannedTray.workOrderHeader.id,
            "workOrderLineId": scannedTray.workOrderLine.id,
            "itemId": scannedTray.item.id,
            "trayId": scannedTray.primaryTrayModel.id,
            "locatorId": nextLocatorId,
            "processItemId": scannedTray.processedItem?.id ?? scannedTray.productionProgress.processedItemId ?? scannedTray.item.id ?? 0,
            "active": true,
        });

        if (!blRes.success || blRes.data == null) {
            throw Exception("Batch Line Error: ${blRes.message}");
        }

        blId = blRes.data['id'] ?? blRes.data['batchLine']?['id'] ?? blRes.data;
        }

        // --- 4. UPDATE TRAY DETAILS LOGIC (Visual State Link) ---
        final tRes = await _batchRepo.fetchTrayDetailById(scannedTray.primaryTrayModel.id!);
        if (tRes.success) {
          final tData = tRes.data['trayDetail'] ?? tRes.data;
          Map<String, dynamic> trayUpd = Map<String, dynamic>.from(tData);
          trayUpd["trayQuantity"] = trayQty.toInt();
          trayUpd["batchHeaderId"] = widget.batchHeaderId;
          trayUpd["isReAssigned"] = true;
          if (widget.machineId != null) {
            trayUpd["resourceId"] = widget.machineId;
          }
          trayUpd["workOrderHeaderId"] = scannedTray.workOrderHeader.id;
          trayUpd["workOrderLineId"] = scannedTray.workOrderLine.id;
          trayUpd["knitItemId"] = scannedTray.processedItem?.id ?? scannedTray.productionProgress.processedItemId ?? scannedTray.item.id;
          trayUpd["locatorId"] = nextLocatorId;
          
          if (blId != null) {
             trayUpd["batchLinesId"] = blId; 
          }
          await _batchRepo.updateTrayDetails(scannedTray.primaryTrayModel.id!, trayUpd);
        }

        // --- 5. FINALIZE PRODUCTION PROGRESS ---
        // Use the re-fetched PP's own data as base (has valid concurrencyStamp for ABP PUT).
        if (latestHandoverPP != null) {
          final finalJson = latestHandoverPP!.productionProgress.toJson();
          finalJson['batchHeaderId'] = widget.batchHeaderId;
          // Keep concurrencyStamp — ABP REQUIRES it on PUT (do NOT remove)
          if (blId != null) finalJson['batchLinesId'] = blId;
          final finalRes = await _processingRepo.updateProductionProgress(targetProgressId!, finalJson);
          if (!finalRes.success) {
            debugPrint('⚠️ Step 5 PP finalize failed (non-critical): ${finalRes.message}');
          } else {
            debugPrint('✅ Step 5 PP finalized with batchHeaderId=${widget.batchHeaderId}');
          }
        }
      }

      // --- 6. MARK ALL ORIGINAL LAPPING PROGRESS RECORDS AS COMPLETED (transactionType=3) ---
      // We do this for ALL initial input trays (_trays) since the batch processing is now complete.
      final lappingPpRes = await _lappingRepo.fetchProductionProgress({
        'OperationId': widget.currentOperationId.toString(),
        'BatchHeaderId': widget.batchHeaderId.toString(),
        'TransactionType': '2',
      });
      List<LappingModel> traysToClose = [];
      if (lappingPpRes.success && lappingPpRes.data != null) {
        final list = lappingPpRes.data as List<LappingModel>;
        traysToClose = list.where((r) => (r.productionProgress.subOperation ?? '').toLowerCase() != 'handover').toList();
      }
      if (traysToClose.isEmpty) {
        traysToClose = _trays.where((t) => (t.productionProgress.subOperation ?? '').toLowerCase() != 'handover').toList();
      }

      for (final realLappingPP in traysToClose) {
        if (realLappingPP.productionProgress.id != null && realLappingPP.productionProgress.id! > 0) {
          final closeJson = realLappingPP.productionProgress.toJson();
          closeJson['transactionType'] = 3;
          final closeRes = await _processingRepo.updateProductionProgress(
            realLappingPP.productionProgress.id!, closeJson,
          );
          if (!closeRes.success) {
            debugPrint('⚠️ close-lapping failed: ${closeRes.message}');
          } else {
            debugPrint('✅ Closed Lapping PP id=${realLappingPP.productionProgress.id}');
          }
        }
      }

      AppLoader.hide(context);
      setState(() {
        _isLoading = false;
        _scannedTraysByWO.clear();
        _trayOverrideQuantities.clear();
      });

      _showDialog('Success', 'Trays successfully assigned to new machine.', isSuccess: true, onDismiss: () {
        Navigator.pop(context, true); 
      });
    } catch (e) {
      AppLoader.hide(context);
      setState(() => _isLoading = false);
      _showDialog('Save Changes Error', e.toString());
    }
  }

  void _showDialog(String title, String message, {bool isSuccess = false, VoidCallback? onDismiss}) {
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
}
  // Removed _WorkOrderSummary as it was extracted to model.