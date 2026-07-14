import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/utils/barcode_buffer_parser.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/features/lot_making/repo/lot_repo.dart';
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
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';


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
  final _processingRepo = ProcessingRepo();
  final _lotRepo = LotRepo();
  final _lappingRepo = LappingRepo();
  bool _isLoading = false;
  List<LappingModel> _trays = [];
  List<LappingModel> _rawActiveTrays = [];
  final Map<String, WorkOrderSummary> _workOrders = {};
  String? _selectedWorkOrderId;
  final Map<String, List<LappingModel>> _scannedTraysByWO = {};
  final Set<int> _failedHandoverTrayIds = {};
  final Set<int> _failedCloseLappingIds = {};

  final _trayQtyController = TextEditingController();

  final Map<String, double> _trayOverrideQuantities = {};

  final FocusNode _focusNode = FocusNode();
  // Bluetooth Scanner Support
  final _barcodeParser = BarcodeBufferParser();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBatchData();
    });
  }

  bool _onHardwareKey(KeyEvent event) {
    return _barcodeParser.handleKey(event, _processBluetoothScan);
  }

  Future<void> _processBluetoothScan(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return;

    if (_selectedWorkOrderId == null) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: 'Please select a Work Order first');
      return;
    }
    
    AppLoader.show(context, message: 'Validating Tray...');
    final error = await _onTrayScanned(code);
    if (!mounted) return;
    AppLoader.hide(context);
    
    if (error != null) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: error);
    }
  }

  Future<void> _fetchBatchData() async {
    setState(() => _isLoading = true);

    final res = await _lappingRepo.fetchProductionProgress({
      'BatchHeaderId': widget.batchHeaderId.toString(),
      'TransactionType': '2',
    });

    if (res.success && res.data != null) {
      final List<LappingModel> rawTrays = res.data as List<LappingModel>;

      final Map<String, LappingModel> uniqueTrays = {};
      for (final tray in rawTrays) {
        if (tray.productionProgress.transactionType != 2) continue;
        if (tray.productionProgress.operationId != widget.currentOperationId) continue;
        
        final code = tray.primaryTrayModel.trayCode ?? 'UNKNOWN';
        if (!uniqueTrays.containsKey(code) || (tray.productionProgress.id ?? 0) > (uniqueTrays[code]!.productionProgress.id ?? 0)) {
          uniqueTrays[code] = tray;
        }
      }
      
      final fetchedTrays = uniqueTrays.values.toList();
      final Map<String, WorkOrderSummary> summaries = {};

      for (final tray in fetchedTrays) {
        final woId = tray.workOrderHeader.id;
        final itemDesc = tray.processedItem?.description ?? tray.item.description;

        if (itemDesc.isNotEmpty) {
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
            final woDesc = tray.workOrderHeader.description;
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
        _rawActiveTrays = rawTrays;
        _workOrders.clear();
        _workOrders.addAll(summaries);
        _isLoading = false;
        _selectedWorkOrderId = null;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        AppSnackBar.showError(context, message: res.message);
      }
    }
  }

  Future<void> _showAvailableTraysDialog() async {
    if (_selectedWorkOrderId == null) return;
    
    if (mounted) AppLoader.show(context, message: 'Loading available trays...');
    try {
      final trayRes = await _lotRepo.fetchTrayDetails();
      final headersRes = await _lotRepo.fetchLotHeaders();
      final linesRes = await _lotRepo.fetchLotLines();
      
      if (!mounted) return;
      AppLoader.hide(context);

      if (!trayRes.success || trayRes.data == null) {
        AppSnackBar.showError(context, message: 'Failed to fetch system trays');
        return;
      }
      
      final systemTrays = trayRes.data as List;
      final List<Map<String, dynamic>> lotHeaders = headersRes.success && headersRes.data != null
          ? List<Map<String, dynamic>>.from(headersRes.data as List)
          : [];
      final List<Map<String, dynamic>> lotLines = linesRes.success && linesRes.data != null
          ? List<Map<String, dynamic>>.from(linesRes.data as List)
          : [];

      // Filter empty reusable trays
      final emptySystemTrays = systemTrays.where((t) {
        final trayMap = t is Map ? t : (t as dynamic).toJson();
        final trayDetail = trayMap.containsKey('trayDetail') ? trayMap['trayDetail'] : trayMap;
        if (trayDetail['active'] != true) return false;
        if (trayDetail['trayType'] != 1) return false;
        
        final bool isEmptied = trayDetail['locatorId'] == null || trayDetail['trayQuantity'] == 0;
        if (!isEmptied) return false;
        
        // Check if reassigned in draft
        bool isReassigned = false;
        for (final line in lotLines) {
          final bl = line['batchLines'] as Map<String, dynamic>? ?? line;
          if (bl == null) continue;

          final blTrayId = bl['trayId'] as int?;
          final blIsReassigned = bl['isReAssigned'] as bool? ?? false;

          if (blTrayId == trayDetail['id'] && blIsReassigned) {
            final lineHeaderId = bl['batchHeaderId'];
            final isDraft = lotHeaders.any(
              (h) {
                final bh = h['batchHeader'] as Map<String, dynamic>? ?? h;
                final isLocked = bh['lockFlag'] as bool? ?? false;
                return bh['id']?.toString() == lineHeaderId?.toString() && !isLocked;
              },
            );
            if (isDraft) {
              isReassigned = true;
              break;
            }
          }
        }
        return !isReassigned;
      }).toList();

      final currentWOTrays = _scannedTraysByWO[_selectedWorkOrderId!] ?? [];
      final pendingWOTrays = _trays.where((t) {
        final woId = t.workOrderHeader.id;
        final itemDesc = t.processedItem?.description ?? t.item.description;
        final compositeId = '${woId}_$itemDesc';
        
        if (compositeId != _selectedWorkOrderId) return false;
        
        final alreadyScanned = currentWOTrays.any((st) => st.primaryTrayModel.trayCode == t.primaryTrayModel.trayCode);
        return !alreadyScanned;
      }).toList();

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 500, maxWidth: 450),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'AVAILABLE TRAYS FOR LAPPING',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: (pendingWOTrays.isEmpty && emptySystemTrays.isEmpty)
                        ? const Center(
                            child: Text(
                              'No available trays found',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          )
                        : ListView(
                            children: [
                              if (pendingWOTrays.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                  child: Text(
                                    'PENDING BATCH TRAYS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                ...List.generate(pendingWOTrays.length, (index) {
                                  final tray = pendingWOTrays[index];
                                  final qty = tray.productionProgress.primaryQuantity ?? 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.inventory_2_outlined, color: Color(0xFF0D47A1), size: 18),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Tray ${tray.primaryTrayModel.trayCode ?? 'N/A'}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Item: ${tray.processedItem?.description ?? tray.item.description}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${qty.toInt()} Tubes',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0D47A1),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Size: ${tray.item.sizeDescription ?? 'N/A'}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              if (emptySystemTrays.isNotEmpty) ...[
                                const Divider(height: 24),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                  child: Text(
                                    'EMPTY REUSABLE TRAYS (FOR REASSIGNMENT)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                ...List.generate(emptySystemTrays.length, (index) {
                                  final trayMap = emptySystemTrays[index] is Map ? emptySystemTrays[index] : (emptySystemTrays[index] as dynamic).toJson();
                                  final tray = trayMap.containsKey('trayDetail') ? trayMap['trayDetail'] : trayMap;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.inventory_2_outlined, color: Color(0xFF0D47A1), size: 18),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Tray ${tray['trayCode'] ?? 'N/A'}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F5E9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'REUSABLE',
                                            style: TextStyle(
                                              color: Color(0xFF2E7D32),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
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

  // --- Core Validation Logic (Updated for Tray-Detail Support) ---
  Future<String?> _onTrayScanned(String code) async {
    if (_trayQtyController.text.trim().isEmpty) return 'Please enter number of tubes before scanning!';
    final double inputPcs = double.tryParse(_trayQtyController.text) ?? 0;
    if (inputPcs <= 0) return 'Tubes amount must be greater than 0!';

    final trayCode = code.trim().toLowerCase();
    if (trayCode.isEmpty) return 'Invalid tray code';

    final activeSummary = _workOrders[_selectedWorkOrderId];
    if (activeSummary == null) return 'No Active Work Order selected!';

    for (final woTrays in _scannedTraysByWO.values) {
      if (woTrays.any((t) => t.primaryTrayModel.trayCode?.toLowerCase() == trayCode)) {
        return 'Tray already scanned in this session!';
      }
    }

    final currentWOTrays = _scannedTraysByWO[_selectedWorkOrderId] ?? [];

    double totalScanned = currentWOTrays.fold(0, (sum, t) =>
    sum + (_trayOverrideQuantities[t.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0));

    if ((totalScanned + inputPcs) > activeSummary.cumulativePieces) {
      return 'Limit exceeded! Max: ${activeSummary.cumulativePieces}';
    }

    LappingModel? matchedTray = _trays.where((t) => t.primaryTrayModel.trayCode?.toLowerCase() == trayCode).firstOrNull ??
        _rawActiveTrays.where((t) => t.primaryTrayModel.trayCode?.toLowerCase() == trayCode).firstOrNull;

    // trayType validation — only Type 1 trays allowed
    if (matchedTray != null && (matchedTray.primaryTrayModel.trayType ?? 0) != 1) {
      return 'Invalid tray type.';
    }

    if (matchedTray == null) {
      AppLoader.show(context, message: "Searching system trays...");
      final trayRes = await _lotRepo.fetchTrayDetailByCode(trayCode);
      if (!mounted) return 'Screen closed';
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
    final mainItemId = matchedTray.item.id;
    final processedItemId = matchedTray.productionProgress.processedItemId;
    String colorDesc = matchedTray.item.colorDescription ?? '';
    String sizeDesc = matchedTray.item.sizeDescription ?? '';
    double perGarmentTube = matchedTray.item.perGarmentTube;

    if (mainItemId > 0) {
      if (!mounted) return 'Screen closed';
      AppLoader.show(context, message: 'Fetching item details...');
      final itemRes = await _lappingRepo.fetchItemDef(mainItemId);
      if (!mounted) return 'Screen closed';
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
      if (!mounted) return 'Screen closed';
      AppLoader.show(context, message: 'Fetching color details...');
      final processedRes = await _lappingRepo.fetchItemDef(processedItemId);
      if (!mounted) return 'Screen closed';
      AppLoader.hide(context);
      if (processedRes.success && processedRes.data != null) {
        final pd = processedRes.data is Map ? processedRes.data as Map<String, dynamic> : {};
        if (pd['colorDescription'] != null) colorDesc = pd['colorDescription'];
        if (sizeDesc.isEmpty && pd['sizeDescription'] != null) sizeDesc = pd['sizeDescription'];
      }
    }

    // Rebuild matchedTray with enriched item
    final updatedItem = matchedTray.item.copyWith(
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

    setState(() {
      _trayOverrideQuantities[trayCode] = inputPcs;
      _scannedTraysByWO.putIfAbsent(_selectedWorkOrderId!, () => []);
      _scannedTraysByWO[_selectedWorkOrderId!]!.add(matchedTray!);
      FocusManager.instance.primaryFocus?.unfocus();
    });
    HapticFeedbackHelper.scanSuccess();
    return null;
  }

  void _openScanner() async {
    HapticFeedbackHelper.buttonClick();
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Tray',
      onResult: (scannedCode) async {
        return await _onTrayScanned(scannedCode);
      },
      scannedItemsBuilder: (context) {
        return StatefulBuilder(
          builder: (context, setSubState) {
            final currentWOTrays = _selectedWorkOrderId != null ? (_scannedTraysByWO[_selectedWorkOrderId!] ?? []) : [];
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
                selectedWorkOrderId: _selectedWorkOrderId,
                scannedTraysByWO: _scannedTraysByWO,
                trayOverrideQuantities: _trayOverrideQuantities,
                onRemove: (t, trayKey) {
                  setState(() {
                    _scannedTraysByWO[_selectedWorkOrderId]?.remove(t);
                    _trayOverrideQuantities.remove(trayKey);
                  });
                  setSubState(() {});
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPremiumHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Upper Controls (Scrollable when constrained/overflow-safe) ──
                          Flexible(
                            flex: 5,
                            fit: FlexFit.loose,
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ── 1. PROCESS FLOW RIBBON ──────────────────────────
                                    _buildProcessFlowRibbon(),
                                    const SizedBox(height: 16),

                                    // ── 2. HUD METRICS GRID ────────────────────────────
                                    _buildAeroIntelligenceGrid(),
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
                                        workOrders: _workOrders,
                                        selectedWorkOrderId: _selectedWorkOrderId,
                                        scannedTraysByWO: _scannedTraysByWO,
                                        trayOverrideQuantities: _trayOverrideQuantities,
                                        onSelected: (val) => setState(() => _selectedWorkOrderId = val),
                                      ),
                                    ),
                                    if (_selectedWorkOrderId != null) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 40,
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _showAvailableTraysDialog,
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

                          // ── Lower Scanned Table (Independently Scrollable) ──
                          if (_selectedWorkOrderId != null)
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
                                        selectedWorkOrderId: _selectedWorkOrderId,
                                        scannedTraysByWO: _scannedTraysByWO,
                                        trayQtyController: _trayQtyController,
                                        focusNode: _focusNode,
                                        onScanPressed: _openScanner,
                                      ),
                                      Expanded(
                                        child: Builder(
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

  Widget _buildPremiumHeader() {
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
                    'LOT: ${widget.batchCode}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      HapticFeedbackHelper.buttonClick();
                      _saveChanges();
                    },
              icon: Icon(
                _failedHandoverTrayIds.isNotEmpty || _failedCloseLappingIds.isNotEmpty
                    ? Icons.replay_rounded
                    : Icons.check_circle_rounded,
                size: 16,
              ),
              label: Text(
                _failedHandoverTrayIds.isNotEmpty || _failedCloseLappingIds.isNotEmpty
                    ? 'RETRY HANDOVER (${_failedHandoverTrayIds.length + _failedCloseLappingIds.length})'
                    : 'SUBMIT BATCH',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _failedHandoverTrayIds.isNotEmpty || _failedCloseLappingIds.isNotEmpty
                    ? const Color(0xFFE65100) // Deep Orange for retry
                    : const Color(0xFF2E7D32), // Standard Green
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

  Widget _buildProcessFlowRibbon() {
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
          _buildProcessNode('NEXT', widget.nextOperationName, Icons.arrow_forward_rounded, false),
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

  Widget _buildAeroIntelligenceGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 3.8,
      children: [
        _buildHUDCard('LOT #', widget.batchCode, Icons.tag_rounded),
        _buildHUDCard('MACHINE', widget.machine, Icons.precision_manufacturing_rounded),
        _buildHUDCard('COLOR', widget.color, Icons.palette_rounded),
        _buildHUDCard('OPERATION', 'LAPPING', Icons.account_tree_rounded),
        _buildHUDCard('TRAYS', '${widget.trayCount} UNITS', Icons.inventory_2_rounded),
        _buildHUDCard('WEIGHT', '${widget.totalWeight.toStringAsFixed(1)} g', Icons.scale_rounded),
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

  // Removed _buildScannerUI as it was extracted to LappingScannerUI.

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
    AppLoader.show(context, message: 'Submitting changes...');
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
      final baseProgress = allScannedTrays.first.productionProgress;
      int nextLocatorId = baseProgress.locatorId ?? 3; 
      final handoverOpId = widget.nextOperationId ?? baseProgress.operationId;

      if (handoverOpId != null) {
        final locRes = await _lotRepo.fetchLocators(operationId: handoverOpId);
        if (locRes.success && locRes.data != null) {
          final List locList = locRes.data is Map ? (locRes.data['items'] ?? []) : locRes.data;
          final matchingEntry = locList.cast<Map>().firstWhere(
                (entry) => (entry['operation']?['id'] ?? entry['locator']?['operationId'])?.toString() == handoverOpId.toString(),
            orElse: () => {},
          );
          if (matchingEntry.isNotEmpty) {
            nextLocatorId = matchingEntry['locator']?['id'] as int? ?? (baseProgress.locatorId ?? 3);
          }
        }
      }

      final Map<int, String> handoverErrors = {};

      // Local helper function to run isolated lifecycle steps for a single tray
      Future<bool> processSingleTrayHandover(LappingModel scannedTray) async {
        final pp = scannedTray.productionProgress;

        try {
          final double trayQty = _trayOverrideQuantities[scannedTray.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0;
          
          // --- 1. FETCH PREVIOUS WIP TRANSACTION (From the tray's state prior to Handover) ---
          int? wipId;
          if (pp.id != null) {
            final nativeWipRes = await _lotRepo.fetchWipTransactionsByProgressId(pp.id!);
            if (nativeWipRes.success && nativeWipRes.data != null) {
              final List rawItems = nativeWipRes.data is Map ? (nativeWipRes.data['items'] ?? []) : nativeWipRes.data;
              final items = rawItems.cast<Map<String, dynamic>>();
              final match = items.firstWhere(
                (e) => (e['wipTransaction']?['progressId'] ?? e['progressId'] ?? e['wipTransaction']?['productionProgressId'] ?? e['productionProgressId'])?.toString() == pp.id.toString(),
                orElse: () => {},
              );
              if (match.isNotEmpty) {
                wipId = match['wipTransaction']?['id'] as int?;
              }
            }
          }

          // --- 2. CREATE HANDOVER PRODUCTION PROGRESS (THE ANCHOR RECORD) ---
          Map<String, dynamic> nextJson = pp.toJson();
          nextJson.remove('id');
          nextJson.remove('progressCode');
          nextJson.remove('concurrencyStamp');
          nextJson.remove('batchLinesId');
          nextJson.remove('batchLineId');

          nextJson.addAll({
            "subOperation": "Handover",
            "transactionType": 2, // Handover
            "primaryTrayId": scannedTray.primaryTrayModel.id,
            "secondaryTrayId": scannedTray.primaryTrayModel.id, // Fill secondary fallback
            "primaryQuantity": trayQty,
            "secondaryQuantity": pp.secondaryQuantity ?? 0,
            "primaryUOM": pp.primaryUOM ?? 4,
            "secondaryUOM": pp.secondaryUOM ?? 1,
            "productGrade": pp.productGrade ?? 0,
            "productNature": pp.productNature ?? 0,
            "shiftId": pp.shiftId ?? 1,
            "machineId": pp.machineId ?? (_trays.isNotEmpty ? _trays.first.productionProgress.machineId : null),
            "isLastProcess": false,
            "isStarted": false,
            "reworkFlag": pp.reworkFlag ?? false,
            "lotMakingFlag": false, // Strict pass
            "locatorId": nextLocatorId,
            "operationId": handoverOpId ?? pp.operationId,
            "wipStatus": widget.nextOperationId != null ? 0 : 1,
            "gbsFlag": false,
            "pbsFlag": false,
            "date": DateTime.now().toIso8601String(),
            "operatorDescription": "system",
            "processedItemId": scannedTray.processedItem?.id ?? pp.processedItemId ?? scannedTray.item.id,
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
            final errMsg = 'Step 2 (createProductionProgress) failed: ${ppRes.message}';
            debugPrint('❌ $errMsg');
            handoverErrors[scannedTray.primaryTrayModel.id!] = errMsg;
            return false;
          }

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
              'OperationId': (handoverOpId ?? pp.operationId).toString(),
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
            const errMsg = 'Step 2.5: Failed to resolve targetProgressId';
            debugPrint('❌ $errMsg');
            handoverErrors[scannedTray.primaryTrayModel.id!] = errMsg;
            return false;
          }
          debugPrint('✅ Resolved targetProgressId: $targetProgressId');

          // --- 3. CREATE BATCH LINE (Cross-linked to established WIP logically) ---
          int? blId;
          final Map<String, dynamic> lotLinePayload = {
            "planDate": DateTime.now().toIso8601String(),
            "transactionDate": DateTime.now().toIso8601String(),
            "primaryQuantity": trayQty,
            "primaryUOM": pp.primaryUOM ?? 4,
            "secondaryQuantity": 0, 
            "secondaryUOM": pp.secondaryUOM ?? 1,
            "batchLineCode": "BL-${widget.batchHeaderId}-${scannedTray.primaryTrayModel.id}",
            "batchHeaderId": widget.batchHeaderId,
            "progressId": targetProgressId,
            "workOrderHeaderId": scannedTray.workOrderHeader.id,
            "workOrderLineId": scannedTray.workOrderLine.id,
            "itemId": scannedTray.item.id,
            "trayId": scannedTray.primaryTrayModel.id,
            "locatorId": nextLocatorId,
            "processItemId": scannedTray.processedItem?.id ?? pp.processedItemId ?? scannedTray.item.id,
            "active": true,
            "isReAssigned": true,
          };
          if (wipId != null) {
            lotLinePayload["wipTransactionId"] = wipId;
          }

          final blRes = await _lotRepo.createLotLine(lotLinePayload);
          if (!blRes.success || blRes.data == null) {
            final errMsg = 'Step 3 (createLotLine) failed: ${blRes.message}';
            debugPrint('❌ $errMsg');
            handoverErrors[scannedTray.primaryTrayModel.id!] = errMsg;
            return false;
          }
          final rawBlData = blRes.data;
          debugPrint('🆕 BatchLine Create Response: $rawBlData');
          blId = (rawBlData is Map)
              ? (rawBlData['batchLines']?['id'] ?? rawBlData['id'])
              : null;
          debugPrint('🆕 Resolved BatchLine ID: $blId');

          if (blId == null || blId == 0) {
            debugPrint('⚠️ id=0 returned for BatchLine — re-fetching by batchHeaderId+trayId...');
            final refetchBl = await _lotRepo.fetchLotLines(batchHeaderId: widget.batchHeaderId);
            if (refetchBl.success && refetchBl.data != null) {
              final List rawList = refetchBl.data is List ? refetchBl.data : [];
              final matches = rawList.where((item) {
                final Map blMap = item['batchLines'] ?? item;
                return blMap['trayId'] == scannedTray.primaryTrayModel.id;
              }).toList();
              if (matches.isNotEmpty) {
                final blMap = matches.last['batchLines'] ?? matches.last;
                blId = blMap['id'] as int?;
              }
            }
          }

          if (blId == null || blId == 0) {
            final errMsg = 'Step 3.5: Failed to resolve batchLineId';
            debugPrint('❌ $errMsg');
            handoverErrors[scannedTray.primaryTrayModel.id!] = errMsg;
            return false;
          }
          debugPrint('✅ Resolved BatchLine ID: $blId');

          // --- 3.7. UPDATE PRODUCTION PROGRESS TO SET batchLineId ---
          if (latestHandoverPP == null) {
            final refetchRes = await _processingRepo.fetchProductionProgress({
              'OperationId': (handoverOpId ?? pp.operationId).toString(),
              'TransactionType': '2',
            });
            if (refetchRes.success && refetchRes.data != null) {
              final list = refetchRes.data as List<ProductionProgressResponseModel>;
              final matches = list.where((r) => r.productionProgress.id == targetProgressId).toList();
              if (matches.isNotEmpty) {
                latestHandoverPP = matches.first;
              }
            }
          }

          if (latestHandoverPP != null) {
            final finalJson = latestHandoverPP.productionProgress.toJson();
            finalJson['batchHeaderId'] = widget.batchHeaderId;
            finalJson['batchLineId'] = blId;
            finalJson['batchLinesId'] = blId;
            finalJson.remove('id');
            finalJson.remove('progressCode');
            finalJson.remove('creationTime');
            finalJson.remove('creatorId');
            finalJson.remove('lastModificationTime');
            finalJson.remove('lastModifierId');
            final finalRes = await _processingRepo.updateProductionProgress(targetProgressId, finalJson);
            if (!finalRes.success) {
              final errMsg = 'Step 3.7 (updateProductionProgress link) failed: ${finalRes.message}';
              debugPrint('❌ $errMsg');
              handoverErrors[scannedTray.primaryTrayModel.id!] = errMsg;
              return false;
            }
            debugPrint('🔗 Linked ProductionProgress $targetProgressId to BatchLine $blId');

            // Also link the WIP Transaction created for this Handover PP step to the batchLine
            final newWipRes = await _lotRepo.fetchWipTransactionsByProgressId(targetProgressId);
            if (newWipRes.success && newWipRes.data != null) {
              final List rawItems = newWipRes.data is Map ? (newWipRes.data['items'] ?? []) : newWipRes.data;
              final items = rawItems.cast<Map<String, dynamic>>();
              final match = items.firstWhere(
                (e) => (e['wipTransaction']?['progressId'] ?? e['progressId'] ?? e['wipTransaction']?['productionProgressId'] ?? e['productionProgressId'])?.toString() == targetProgressId.toString(),
                orElse: () => {},
              );
              if (match.isNotEmpty) {
                final newWipId = match['wipTransaction']?['id'] as int?;
                if (newWipId != null) {
                  final wipPayload = Map<String, dynamic>.from(match['wipTransaction'] ?? match);
                  wipPayload['batchLinesId'] = blId;
                  wipPayload['batchLineId'] = blId;
                  wipPayload.remove('id');
                  wipPayload.remove('concurrencyStamp');
                  await _lotRepo.updateWipTransaction(newWipId, wipPayload);
                  debugPrint('🔗 Linked WIPTransaction $newWipId to BatchLine $blId');
                }
              }
            }
          }

          // --- 4. UPDATE TRAY DETAILS LOGIC (Visual State Link) ---
          final tRes = await _lotRepo.fetchTrayDetailById(scannedTray.primaryTrayModel.id!);
          if (tRes.success) {
            final tData = tRes.data['trayDetail'] ?? tRes.data;
            Map<String, dynamic> trayUpd = Map<String, dynamic>.from(tData);
            
            final fetchedStamp = trayUpd['concurrencyStamp'];
            final originalStamp = scannedTray.primaryTrayModel.concurrencyStamp;
            if (fetchedStamp == null && originalStamp != null) {
              trayUpd['concurrencyStamp'] = originalStamp;
            }

            // Remove audit, nested fields, and the invalid plural batchLinesId key to prevent server-side PUT mapping issues (500 errors)
            trayUpd.removeWhere((key, value) => 
              ["creatorId", "creationTime", "lastModifierId", "lastModificationTime", "batchLinesId"].contains(key) ||
              value is Map || 
              value is List
            );

            trayUpd["trayQuantity"] = trayQty.toInt();
            trayUpd["batchHeaderId"] = widget.batchHeaderId;
            trayUpd["isReAssigned"] = false;
            if (widget.machineId != null) {
              trayUpd["resourceId"] = widget.machineId;
            }
            // Do NOT overwrite workOrderHeaderId, workOrderLineId, knitItemId as they are read-only
            // database relations on the TrayDetail master record.
            trayUpd["locatorId"] = nextLocatorId;
            
            if (blId != null) {
              trayUpd["batchLineId"] = blId;
            }

            var updTrayRes = await _lotRepo.updateTrayDetails(scannedTray.primaryTrayModel.id!, trayUpd);
            if (!updTrayRes.success) {
              debugPrint('⚠️ Step 4 full update failed, retrying with minimal payload...');
              final Map<String, dynamic> minimalTrayUpd = {
                "id": scannedTray.primaryTrayModel.id,
                "trayCode": scannedTray.primaryTrayModel.trayCode,
                "trayQuantity": trayQty.toInt(),
                "batchHeaderId": widget.batchHeaderId,
                "locatorId": nextLocatorId,
                "isReAssigned": false,
                "workOrderHeaderId": trayUpd["workOrderHeaderId"],
                "workOrderLineId": trayUpd["workOrderLineId"],
                "knitItemId": trayUpd["knitItemId"],
                "concurrencyStamp": trayUpd['concurrencyStamp'] ?? originalStamp ?? fetchedStamp,
              };
              if (widget.machineId != null) {
                minimalTrayUpd["resourceId"] = widget.machineId;
              }
              if (blId != null) {
                minimalTrayUpd["batchLineId"] = blId;
              }
              
              updTrayRes = await _lotRepo.updateTrayDetails(scannedTray.primaryTrayModel.id!, minimalTrayUpd);
            }

            if (!updTrayRes.success) {
              final errMsg = 'Step 4 (updateTrayDetails) failed: ${updTrayRes.message}\n'
                  'Fetched Stamp: $fetchedStamp\n'
                  'Original Stamp: $originalStamp\n'
                  'Sent Stamp: ${trayUpd['concurrencyStamp']}';
              debugPrint('❌ $errMsg');
              handoverErrors[scannedTray.primaryTrayModel.id!] = errMsg;
              return false;
            }
            return true;
          } else {
            final errMsg = 'Step 4 (fetchTrayDetailById) failed: ${tRes.message}';
            debugPrint('❌ $errMsg');
            handoverErrors[scannedTray.primaryTrayModel.id!] = errMsg;
            return false;
          }
        } catch (e) {
          final errMsg = 'Exception: $e';
          debugPrint('❌ Handover error for tray ${scannedTray.primaryTrayModel.id}: $e');
          handoverErrors[scannedTray.primaryTrayModel.id!] = errMsg;
          return false;
        }
      }

      // --- CONCURRENT HANDOVER PROCESSING (STEPS 1-5) ---
      final handoversToProcess = _failedHandoverTrayIds.isEmpty
          ? allScannedTrays
          : allScannedTrays.where((t) => _failedHandoverTrayIds.contains(t.primaryTrayModel.id)).toList();

      final List<Future<bool>> handoverTasks = handoversToProcess.map((scannedTray) => processSingleTrayHandover(scannedTray)).toList();
      final List<bool> handoverResults = await Future.wait(handoverTasks);

      final newFailedHandoverTrayIds = <int>{};
      for (int i = 0; i < handoversToProcess.length; i++) {
        if (!handoverResults[i]) {
          newFailedHandoverTrayIds.add(handoversToProcess[i].primaryTrayModel.id!);
        }
      }

      setState(() {
        if (_failedHandoverTrayIds.isEmpty) {
          _failedHandoverTrayIds.addAll(newFailedHandoverTrayIds);
        } else {
          for (final t in handoversToProcess) {
            final id = t.primaryTrayModel.id!;
            if (newFailedHandoverTrayIds.contains(id)) {
              _failedHandoverTrayIds.add(id);
            } else {
              _failedHandoverTrayIds.remove(id);
            }
          }
        }
      });

      if (_failedHandoverTrayIds.isNotEmpty) {
        final errorDetails = _failedHandoverTrayIds
            .map((id) => 'Tray $id:\n${handoverErrors[id] ?? "Unknown error"}')
            .join('\n\n');
        throw Exception(errorDetails);
      }

      // --- Step 6: Concurrent Lapping Closure ---
      // We only execute closures once all handovers are 100% successful
      // Fetch all active production progress records for this batch across all operations to clean up any previous processes (e.g. Heat Set)
      final lappingPpRes = await _lappingRepo.fetchProductionProgress({
        'BatchHeaderId': widget.batchHeaderId.toString(),
        'TransactionType': '2',
      });
      List<LappingModel> traysToClose = [];
      if (lappingPpRes.success && lappingPpRes.data != null) {
        final list = lappingPpRes.data as List<LappingModel>;
        traysToClose = list.where((r) =>
          (widget.nextOperationId == null || r.productionProgress.operationId != widget.nextOperationId) &&
          (r.productionProgress.subOperation ?? '').toLowerCase() != 'handover'
        ).toList();
      }
      if (traysToClose.isEmpty) {
        traysToClose = _trays.where((t) => (t.productionProgress.subOperation ?? '').toLowerCase() != 'handover').toList();
      }

      final closuresToProcess = _failedCloseLappingIds.isEmpty
          ? traysToClose
          : traysToClose.where((t) => _failedCloseLappingIds.contains(t.productionProgress.id)).toList();

      final List<Future<bool>> closureTasks = closuresToProcess.map((realLappingPP) async {
        if (realLappingPP.productionProgress.id != null && realLappingPP.productionProgress.id! > 0) {
          try {
            final closeJson = realLappingPP.productionProgress.toJson();
            closeJson['transactionType'] = 3;
            closeJson['wipStatus'] = 1;
            closeJson.remove('id');
            closeJson.remove('progressCode');
            closeJson.remove('creationTime');
            closeJson.remove('creatorId');
            closeJson.remove('lastModificationTime');
            closeJson.remove('lastModifierId');
            final closeRes = await _processingRepo.updateProductionProgress(
              realLappingPP.productionProgress.id!, closeJson,
            );
            return closeRes.success;
          } catch (e) {
            return false;
          }
        }
        return true;
      }).toList();

      final List<bool> closureResults = await Future.wait(closureTasks);

      final newFailedCloseIds = <int>{};
      for (int i = 0; i < closuresToProcess.length; i++) {
        if (!closureResults[i]) {
          final id = closuresToProcess[i].productionProgress.id;
          if (id != null) newFailedCloseIds.add(id);
        }
      }

      setState(() {
        if (_failedCloseLappingIds.isEmpty) {
          _failedCloseLappingIds.addAll(newFailedCloseIds);
        } else {
          for (final t in closuresToProcess) {
            final id = t.productionProgress.id!;
            if (newFailedCloseIds.contains(id)) {
              _failedCloseLappingIds.add(id);
            } else {
              _failedCloseLappingIds.remove(id);
            }
          }
        }
      });

      if (_failedCloseLappingIds.isNotEmpty) {
        throw Exception('${_failedCloseLappingIds.length} lapping closure(s) failed. Please check network and retry.');
      }

      if (!mounted) return;
      AppLoader.hide(context);
      setState(() {
        _isLoading = false;
        _scannedTraysByWO.clear();
        _trayOverrideQuantities.clear();
        _failedHandoverTrayIds.clear();
        _failedCloseLappingIds.clear();
      });

      HapticFeedbackHelper.scanSuccess();
      _showDialog('Success', 'Trays successfully submitted to next operation.', isSuccess: true, onDismiss: () {
        if (mounted) Navigator.pop(context, true); 
      });
    } catch (e) {
      if (!mounted) return;
      AppLoader.hide(context);
      setState(() => _isLoading = false);
      HapticFeedbackHelper.scanError();
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