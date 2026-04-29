import 'package:flutter/services.dart';
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
    this.preloadedTrays,
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

  final Set<int> _batchedProgressIds = {};
  final Map<int, int> _trayProcessedItemId = {};

  // Item routing reference — captured from the first scanned tray
  Set<String>? _referenceRoutingCodes;
  int? _referenceRoutingCount;
  int? _referenceMinOperationId;

  static const _inputAndButtonHeight = 42.0;

  static final _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );

  final FocusNode _focusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  InputDecoration _inputDecoration({
    required String hintText,
    bool isDense = false,
    EdgeInsets? contentPadding,
    double borderRadius = 6.0,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      isDense: isDense,
      contentPadding: contentPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Colors.blue),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMachines();
      _fetchColors();
      _fetchProductionProgresses();
      _fetchBatchedProgressIds();
    });
  }

  Future<void> _loadExistingBatchTrays(
    List<ProductionProgressResponseModel> allProgresses,
  ) async {
    if (widget.existingBatch == null) return;
    final batchHeaderId = widget.existingBatch!.batchHeader.id;
    if (batchHeaderId == null) return;

    final linesRes = await _batchRepo.fetchBatchLines(
      batchHeaderId: batchHeaderId,
    );
    if (!linesRes.success || linesRes.data == null) return;

    final rawLines = linesRes.data as List<Map<String, dynamic>>;
    // Collect progressIds from linked batch-lines
    final linkedProgressIds = rawLines
        .map((line) => line['batchLines']?['progressId'] as int?)
        .whereType<int>()
        .toSet();

    debugPrint(
      '📋 Edit mode: batchHeaderId=$batchHeaderId, linked progressIds=$linkedProgressIds',
    );

    final linkedTrays = allProgresses
        .where(
          (p) =>
              p.productionProgress.id != null &&
              linkedProgressIds.contains(p.productionProgress.id),
        )
        .toList();

    if (mounted && linkedTrays.isNotEmpty) {
      setState(() {
        _scannedTrays.addAll(linkedTrays);
        for (var tray in linkedTrays) {
          _quantityControllers.add(
            TextEditingController(
              text:
                  tray.productionProgress.primaryQuantity?.toStringAsFixed(0) ??
                  '0',
            ),
          );
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
      await _loadExistingBatchTrays(progresses);
    }
  }

  /// Fetches ALL batch-lines to build a Set of progressIds already in any batch.
  /// This is the reliable source of truth because the production-progresses list
  /// API does NOT return batchHeaderId in its response.
  Future<void> _fetchBatchedProgressIds() async {
    final result = await _batchRepo.fetchBatchLines();
    if (result.success && result.data != null) {
      final lines = result.data as List<Map<String, dynamic>>;
      final ids = lines
          .map((l) => l['batchLines']?['progressId'] as int?)
          .whereType<int>()
          .toSet();
      debugPrint('🔒 Already batched progressIds: $ids');
      if (mounted) setState(() => _batchedProgressIds.addAll(ids));
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _overrideQuantityController.dispose();
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchMachines() async {
    setState(() => _isLoading = true);
    AppLoader.show(context, message: 'Loading Machines...');
    final result = await _batchRepo.fetchBatchMachines();

    if (!mounted) return;

    if (result.success && result.data != null) {
      setState(() {
        _machines = result.data as List<BatchMachineModel>;
        _isLoading = false;

        if (widget.existingBatch?.machine != null) {
          final editMachineId = widget.existingBatch!.machine!.id;
          final match = _machines
              .where((m) => m.resource?.id == editMachineId)
              .toList();
          if (match.isNotEmpty) _selectedMachine = match.first;
        }
      });
      AppLoader.hide(context);
    } else {
      setState(() => _isLoading = false);
      AppLoader.hide(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${result.message}')));
    }
  }

  Future<void> _fetchColors() async {
    setState(() => _isLoadingColors = true);
    AppLoader.show(context, message: 'Fetching Colors...');
    final result = await _batchRepo.fetchBatchColors();

    if (!mounted) return;

    if (result.success && result.data != null) {
      setState(() {
        _colors = result.data as List<BatchColorModel>;
        _isLoadingColors = false;

        if (widget.existingBatch?.colorCode != null) {
          final editColorId = widget.existingBatch!.colorCode!.id;
          final match = _colors
              .where((c) => c.segmentCode?.id == editColorId)
              .toList();
          if (match.isNotEmpty) _selectedColor = match.first;
        }
      });
      AppLoader.hide(context);
    } else {
      setState(() => _isLoadingColors = false);
      AppLoader.hide(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${result.message}')));
    }
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

    if (_selectedMachine == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Please select a machine first')));
      return;
    }
    
    AppLoader.show(context, message: 'Validating Tray...');
    final error = await _validateTrayForScan(code);
    AppLoader.hide(context);
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red));
    }
  }

  Future<void> _onScanTray() async {
    if (_selectedMachine == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Please select a machine first')));
      return;
    }
    await Future.delayed(const Duration(milliseconds: 300));
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trays',
      onResult: (scannedCode) async {
        return await _validateTrayForScan(scannedCode);
      },
    );
  }

  Future<String?> _validateTrayForScan(String scannedCode) async {
        final code = scannedCode.trim();
        if (code.isEmpty) return 'Invalid tray code';
        if (_selectedColor == null) return 'Please select a batch Color first';
        if (_scannedTrays.any(
          (t) =>
              (t.primaryTrayModel?.trayCode ?? '').trim().toLowerCase() ==
              code.toLowerCase(),
        ))
          return 'Already assigned';

        final available = productionProgressTrays
            .where(
              (t) =>
                  (t.primaryTrayModel?.trayCode ?? '').trim().toLowerCase() ==
                      code.toLowerCase() &&
                  t.productionProgress.locatorId == 3 &&
                  t.productionProgress.gbsFlag == true,
            )
            .toList();

        if (available.isEmpty)
          return 'Tray not found or not checked out via GBS';

        // Block if tray's progressId is already linked to any batch (via batch-liness)
        final tray = available.first;
        final progressId = tray.productionProgress.id;
        if (progressId != null && _batchedProgressIds.contains(progressId)) {
          return 'Tray already assigned to a batch';
        }

        final workOrderLineId =
            tray.productionProgress.workOrderLineId ?? tray.workOrderLine?.id;
        final colorDescription = _selectedColor!.segmentCode?.description;

        if (colorDescription == null) {
          return 'Selected Color has no description';
        }

        // Color validation via remote API
        final colorRes = await _batchRepo.fetchWorkOrderLineDetails(
          workOrderLineId!,
          colorDescription,
        );
        if (!colorRes.success || colorRes.data == null) {
          return 'Validation error: ${colorRes.message}';
        }

        final items = colorRes.data as List?;
        if (items == null || items.isEmpty) {
          return 'Invalid tray: Tray does not belong to the selected color';
        }

        final firstItem = items.first as Map;
        final detail = firstItem['workOrderLineDetail'];
        final dynamic processIdRaw = firstItem['processIItemd'];
        int processedItemId;
        if (processIdRaw is int) {
          processedItemId = processIdRaw;
        } else if (processIdRaw is Map) {
          processedItemId = processIdRaw['id'];
        } else {
          // Fallback: Agar null ho toh knitItemId use karein
          processedItemId = detail['knitItemId'] ?? tray.item?.id ?? 0;
        }

        // ── Item Routing Validation (after color validation) ─────────────────
        final itemDefId = tray.productionProgress.itemId;
        debugPrint(
          '🔑 itemDefId for routing: $itemDefId (from productionProgress.itemId)',
        );
        final routingRes = await _batchRepo.fetchItemRoutings(itemDefId!);
        if (!routingRes.success || routingRes.data == null) {
          return 'Routing validation error: ${routingRes.message}';
        }

        final routingItems = routingRes.data as List;
        final routingCodes = routingItems
            .map(
              (r) =>
                  (r as Map)['itemRouting']?['operationId']?.toString() ?? '',
            )
            .where((c) => c.isNotEmpty)
            .toSet();
        final routingCount = routingItems.length;

        if (routingCount == 0) {
          debugPrint(
            '❌ Item $itemDefId has no routings configured — scan blocked',
          );
          return 'Tray item has no route configured';
        } else if (_referenceRoutingCodes == null) {
          // First tray with routings: store as reference
          _referenceRoutingCodes = routingCodes;
          _referenceRoutingCount = routingCount;
          _referenceMinOperationId = routingCodes
              .map((s) => int.tryParse(s) ?? 0)
              .where((v) => v > 0)
              .fold<int?>(null, (min, v) => min == null || v < min ? v : min);
          debugPrint(
            '📋 Routing reference set: count=$routingCount codes=$routingCodes minOpId=$_referenceMinOperationId',
          );
        } else {
          // Subsequent trays: compare against reference
          debugPrint(
            '🔍 Routing compare: ref=$_referenceRoutingCodes(${_referenceRoutingCount}) vs current=$routingCodes($routingCount)',
          );
          if (routingCount != _referenceRoutingCount ||
              !routingCodes.containsAll(_referenceRoutingCodes!) ||
              !_referenceRoutingCodes!.containsAll(routingCodes)) {
            debugPrint('❌ Routing mismatch!');
            return 'Tray has a different route';
          }
          debugPrint('✅ Routing matched');
        }

        // Capacity check: cumulative weight must not exceed machine capacity
        final capacityRaw = _selectedMachine?.resource?.capacity;
        final capacity = capacityRaw != null
            ? double.tryParse(capacityRaw.toString())
            : null;
        if (capacity != null && capacity > 0) {
          final overrideText = _overrideQuantityController.text.trim();
          final newQty =
              double.tryParse(overrideText) ??
              tray.productionProgress.primaryQuantity ??
              0;
          final pw = tray.item?.pieceWeight;
          if (pw != null && pw > 0) {
            double currentTotal = 0;
            for (int i = 0; i < _scannedTrays.length; i++) {
              final qty =
                  double.tryParse(_quantityControllers[i].text) ??
                  _scannedTrays[i].productionProgress.primaryQuantity ??
                  0;
              final p = _scannedTrays[i].item?.pieceWeight;
              if (p != null && p > 0) currentTotal += qty * p;
            }
            final newTotal = currentTotal + (newQty * pw);
            if (newTotal > capacity) {
              return 'Exceeds machine capacity (${newTotal.toStringAsFixed(2)} kg > ${capacity.toStringAsFixed(2)} kg)';
            }
          }
        }

        setState(() {
          if (tray.primaryTrayModel?.id != null) {
            _trayProcessedItemId[tray.primaryTrayModel!.id!] = processedItemId;
          }
          _scannedTrays.add(tray);
          _quantityControllers.add(
            TextEditingController(text: _overrideQuantityController.text),
          );
        });

        return null; // OK
  }

  Future<void> _saveBatchChanges() async {
    if (_scannedTrays.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No trays to save.')));
      return;
    }

    AppLoader.show(context);

    // ── Determine batchHeaderId ──────────────────────────────────────────────
    int batchHeaderId;
    final bool isEditMode = widget.existingBatch != null;

    if (isEditMode) {
      batchHeaderId = widget.existingBatch!.batchHeader.id!;
    } else {
      final String timestampStr = DateTime.now().millisecondsSinceEpoch
          .toString();
      final String batchCode =
          "BCH-${timestampStr.substring(timestampStr.length - 5)}";

      final headerResponse = await _batchRepo.createBatchHeader({
        "planDate": DateTime.now().toIso8601String(),
        "colorDescription":
            _selectedColor?.segmentCode?.description ?? "Undefined",
        "batchHeaderCode": batchCode,
        "machineId": _selectedMachine?.resource?.id ?? 0,
        "colorCode": _selectedColor?.segmentCode?.id ?? 0,
        "shiftId": _scannedTrays.first.shift?.id,
        "lockFlag": false,
      });

      if (!headerResponse.success) {
        AppLoader.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Header Failed: ${headerResponse.message}')),
        );
        return;
      }

      // ABP integer PKs return id=0 on POST — resolve real ID via GET by batchCode
      final responseData = headerResponse.data as Map<String, dynamic>;
      int? extractedId =
          (responseData.containsKey('batchHeader')
                  ? responseData['batchHeader']['id']
                  : responseData['id'])
              as int?;

      if (extractedId == null || extractedId == 0) {
        final listRes = await _batchRepo.fetchBatchHeaders();
        if (listRes.success && listRes.data != null) {
          for (var item in (listRes.data as List<Map<String, dynamic>>)) {
            final h = item.containsKey('batchHeader')
                ? item['batchHeader']
                : item;
            if (h['batchHeaderCode'] == batchCode) {
              extractedId = h['id'] as int?;
              break;
            }
          }
        }
      }

      if (extractedId == null || extractedId == 0) {
        AppLoader.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not resolve batch ID. Try again.'),
            duration: Duration(seconds: 6),
          ),
        );
        return;
      }
      batchHeaderId = extractedId;
      debugPrint('✅ Batch header created: id=$batchHeaderId');
    }

    // ── In edit mode: which progresses already have a batch-line? ───────────
    final Set<int> alreadyLinkedProgressIds = {};
    if (isEditMode) {
      final linesRes = await _batchRepo.fetchBatchLines(
        batchHeaderId: batchHeaderId,
      );
      if (linesRes.success && linesRes.data != null) {
        for (var line in (linesRes.data as List<Map<String, dynamic>>)) {
          final pid = line['batchLines']?['progressId'] as int?;
          if (pid != null) alreadyLinkedProgressIds.add(pid);
        }
      }
    }

    // Derive the minimum operationId from the validated routing set (first step in the process)
    // Use the min operationId stored during scan validation (first step in the process)
    debugPrint('🔑 Save: using minOperationId=$_referenceMinOperationId');

    // ── Per-tray: sequential, blocking ──────────────────────────────────────
    for (int i = 0; i < _scannedTrays.length; i++) {
      final tray = _scannedTrays[i];
      final progressId = tray.productionProgress.id;
      final trayId = tray.primaryTrayModel.id;

      String? updatedConcurrencyStamp =
          tray.productionProgress.concurrencyStamp;

      // ① Resolve batchLineId (Create if not already linked, else use existing)
      int? batchLineId;

      if (progressId != null &&
          !alreadyLinkedProgressIds.contains(progressId)) {
        // Lookup wipTransactionId — backend DTO requires it as non-nullable FK
        int? wipTransactionId;
        final wipRes = await _batchRepo.fetchWipTransactionsByProgressId(
          progressId,
        );
        if (wipRes.success && wipRes.data != null) {
          final items = wipRes.data as List<Map<String, dynamic>>;
          if (items.isNotEmpty) {
            wipTransactionId = items.first['wipTransaction']?['id'] as int?;
          }
        }
        debugPrint(
          '🔍 WIP for progress $progressId → wipTransactionId=$wipTransactionId',
        );

        if (wipTransactionId != null) {
          final int pItemId =
              _trayProcessedItemId[trayId] ??
              tray.processedItem?.id ??
              tray.item?.id ??
              0;
          final lineRes = await _batchRepo.createBatchLine({
            "planDate": DateTime.now().toIso8601String(),
            "transactionDate": DateTime.now().toIso8601String(),
            "primaryQuantity": tray.productionProgress.primaryQuantity ?? 0,
            "primaryUOM": tray.productionProgress.primaryUOM ?? 0,
            "secondaryQuantity": tray.productionProgress.secondaryQuantity ?? 0,
            "secondaryUOM": tray.productionProgress.secondaryUOM ?? 0,
            "batchLineCode": "BL-$batchHeaderId-${trayId ?? i}",
            "batchHeaderId": batchHeaderId,
            "progressId": progressId,
            "wipTransactionId": wipTransactionId,
            "workOrderHeaderId": tray.workOrderHeader?.id,
            "workOrderLineId": tray.workOrderLine?.id,
            "itemId": tray.item?.id,
            "trayId": trayId,
            "locatorId": tray.productionProgress.locatorId,
            "processItemId": pItemId,
          });

          if (lineRes.success && lineRes.data != null) {
            debugPrint('✅ BatchLine API Response: ${lineRes.data}');
            final dynamic responseData = lineRes.data;
            if (responseData is Map<String, dynamic>) {
              // Now assigning to the OUTER scope batchLineId
              batchLineId =
                  (responseData['id'] as int?) ??
                  (responseData['batchLines']?['id'] as int?);
            }
            debugPrint('🎯 Resolved batchLineId: $batchLineId');

            // Update the tray-details record with both IDs
            if (trayId != null) {
              final trayRes = await _batchRepo.fetchTrayDetailById(trayId);
              if (trayRes.success && trayRes.data != null) {
                final trayMap = Map<String, dynamic>.from(
                  trayRes.data as Map<String, dynamic>,
                );
                trayMap['batchHeaderId'] = batchHeaderId;
                if (batchLineId != null)
                  trayMap['batchLinesId'] = batchLineId; // ✅ Fixed key (Plural)

                final updateRes = await _batchRepo.updateTrayDetails(
                  trayId,
                  trayMap,
                );
                if (updateRes.success) {
                  debugPrint(
                    '✅ TrayDetails updated: tray=$trayId batchLineId=$batchLineId',
                  );
                }
              }
            }
          } else {
            // Show full server error
            AppLoader.hide(context);
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('BatchLine Error (tray $trayId)'),
                content: SingleChildScrollView(
                  child: Text(
                    lineRes.message.isNotEmpty
                        ? lineRes.message
                        : 'Unknown server error',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            AppLoader.show(context);
          }
        }
      } else {
        // Use existing ID if already linked
        batchLineId = tray.productionProgress.batchLinesId;
      }

      // ③ Update productionProgress with both IDs (always ensure sync)
      if (progressId != null) {
        final prodPayload = <String, dynamic>{
          "subOperation": tray.productionProgress.subOperation,
          "date": DateTime.now().toIso8601String(),
          "transactionType": tray.productionProgress.transactionType,
          "operatorDescription": "system",
          "primaryQuantity": tray.productionProgress.primaryQuantity,
          "primaryUOM": tray.productionProgress.primaryUOM,
          "secondaryQuantity": tray.productionProgress.secondaryQuantity,
          "secondaryUOM": tray.productionProgress.secondaryUOM,
          "wipStatus": tray.productionProgress.wipStatus,
          "gbsFlag": true,
          "pbsFlag": true,
          "progressCode": tray.productionProgress.progressCode,
          "batchHeaderId": batchHeaderId,
          "batchLinesId": batchLineId, // ✅ Syncing batchLineId
          "operationId": tray.operation.id,
          "workOrderHeaderId": tray.workOrderHeader.id,
          "workOrderLineId": tray.workOrderLine.id,
          "itemId": tray.item.id,
          "shiftId": tray.shift.id,
          "primaryTrayId": trayId,
          "code": tray.item.code,
          "machineId": _selectedMachine?.resource?.id ?? tray.machineModel.id,
          "planHeaderId": tray.planHeader?.id,
          "locatorId": 3,
          "concurrencyStamp": updatedConcurrencyStamp,
        };

        final prodRes = await _batchRepo.updateProductionProgress(
          progressId,
          prodPayload,
        );
        if (prodRes.success && prodRes.data != null) {
          final resData = prodRes.data as Map<String, dynamic>;
          if (resData.containsKey('concurrencyStamp')) {
            updatedConcurrencyStamp = resData['concurrencyStamp'];
          }
        }
      }
    }

    // Update in-memory set so trays just saved can't be scanned into another batch
    for (final tray in _scannedTrays) {
      final pid = tray.productionProgress.id;
      if (pid != null) _batchedProgressIds.add(pid);
    }

    AppLoader.hide(context);
    Navigator.pop(context, true);
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
                      subtitle: 'Please select a machine from the list below',
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
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              if (_selectedMachine != null)
                                Text(
                                  'Capacity: ${_selectedMachine!.resource?.capacity ?? "N/A"}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (!_isLoading)
                            CustomExpandedAsyncDropdown<BatchMachineModel>(
                              hint: "Select from list...",
                              width: double.infinity,
                              height: 48,
                              borderColor: Colors.blue,
                              items: _machines,
                              selectedValue: _selectedMachine,
                              itemAsString: (machine) =>
                                  machine.resource?.brand ?? 'Unknown Brand',
                              onChanged: (BatchMachineModel? newValue) {
                                setState(() {
                                  _selectedMachine = newValue;
                                  _selectedColor = null; // Reset color
                                  _referenceRoutingCodes = null;
                                  _referenceRoutingCount = null;
                                  _referenceMinOperationId = null;
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
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (!_isLoadingColors)
                              CustomExpandedAsyncDropdown<BatchColorModel>(
                                hint: "Select color...",
                                width: double.infinity,
                                height: 48,
                                borderColor: Colors.blue,
                                items: _colors,
                                selectedValue: _selectedColor,
                                itemAsString: (color) =>
                                    color.segmentCode?.description ??
                                    'Unknown Color',
                                onChanged: (BatchColorModel? newValue) {
                                  setState(() {
                                    _selectedColor = newValue;
                                    _referenceRoutingCodes = null;
                                    _referenceRoutingCount = null;
                                    _referenceMinOperationId = null;
                                    _scannedTrays.clear(); // Reset trays
                                    _quantityControllers.clear();
                                  });
                                },
                              ),
                          ],
                        ],
                      ),
                    ),

                    // ── Real-time Scan Summary ──────────────────────────────
                    if (_selectedColor != null && _scannedTrays.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildScanSummary(),
                    ],

                    // Scan Trays Section
                    if (_selectedColor != null) ...[
                      const SizedBox(height: 16),
                      const SectionHeader(
                        title: 'Scanned Trays',
                        subtitle: 'Scan a tray to start binding',
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
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Row(
                                  children: [
                                    // SizedBox(
                                    //   width:
                                    //       100, // Reduced width for standard look
                                    //   height: _inputAndButtonHeight,
                                    //   child: TextField(
                                    //     controller: _overrideQuantityController,
                                    //     textAlign: TextAlign.center,
                                    //     decoration: _inputDecoration(
                                    //       hintText: 'Pcs/tray',
                                    //       isDense: true,
                                    //       contentPadding:
                                    //           const EdgeInsets.symmetric(
                                    //             horizontal: 8,
                                    //             vertical: 13,
                                    //           ),
                                    //       borderRadius: 4,
                                    //     ),
                                    //     keyboardType: TextInputType.number,
                                    //   ),
                                    // ),
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
                            if (_scannedTrays.isEmpty)
                              _buildEmptyState()
                            else
                              ...List.generate(_scannedTrays.length, (index) {
                                return _buildTrayRow(index);
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

  // ── Scan Summary ────────────────────────────────────────────────────────────
  Widget _buildScanSummary() {
    // ── Compute aggregates ──────────────────────────────────────────────────
    double totalPcs = 0;
    double totalWeight = 0;
    final Map<String, List<ProductionProgressResponseModel>> byWO = {};

    for (final t in _scannedTrays) {
      final qty = t.productionProgress.primaryQuantity ?? 0;
      final pw = t.item?.pieceWeight ?? 0;
      totalPcs += qty;
      totalWeight += qty * pw;
      final woCode = t.workOrderHeader?.workOrderCode ?? 'Unknown WO';
      byWO.putIfAbsent(woCode, () => []).add(t);
    }

    final capacityRaw = _selectedMachine?.resource?.capacity;
    final capacity = capacityRaw != null
        ? double.tryParse(capacityRaw.toString())
        : null;
    final remaining = capacity != null ? (capacity - totalWeight) : null;
    final isOverCapacity = remaining != null && remaining < 0;

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                'Scan Summary',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOverCapacity ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                // child: Text(
                //   isOverCapacity ? 'Over Capacity' : 'Live',
                //   style: TextStyle(
                //     fontSize: 10,
                //     fontWeight: FontWeight.bold,
                //     color: isOverCapacity ? Colors.red.shade700 : Colors.blue.shade700,
                //   ),
                // ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Stat row: Trays / Pcs / Weight / Capacity / Remaining ──────────
          IntrinsicHeight(
            child: Row(
              children: [
                _statTile('Trays', '${_scannedTrays.length}',Icons.layers_outlined),
                _verticalDivider(),
                _statTile('Total Pcs', totalPcs.toStringAsFixed(0), Icons.format_list_numbered),
                if (capacity != null && capacity > 0) ...[
                  _verticalDivider(),
                  _statTile('Capacity', '${capacity.toStringAsFixed(1)}', Icons.settings_input_component),
                  _verticalDivider(),
                  _statTile('Allocated Weight', '${totalWeight.toStringAsFixed(1)}', Icons.scale_outlined),
                  _verticalDivider(),
                  _statTile(
                    isOverCapacity ? 'Over By' : 'Remaining Weight',
                    '${remaining!.abs().toStringAsFixed(1)}',
                    isOverCapacity ? Icons.warning_amber_rounded : Icons.hourglass_empty,
                    valueColor: isOverCapacity ? Colors.red.shade700 : Colors.blue.shade900,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 4),

          // ── WO-grouped expandable list ─────────────────────────────────────
          ...byWO.entries.map((entry) {
            final woCode = entry.key;
            final woTrays = entry.value;
            
            // Group by Item within the WO
            final Map<String, List<ProductionProgressResponseModel>> byItem = {};
            double woPcs = 0;
            double woWeight = 0;
            for (final t in woTrays) {
              final qty = t.productionProgress.primaryQuantity ?? 0;
              final pw = t.item?.pieceWeight ?? 0;
              woPcs += qty;
              woWeight += qty * pw;
              final itemDesc = t.item?.description ?? 'Unknown Item';
              byItem.putIfAbsent(itemDesc, () => []).add(t);
            }

            return Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                childrenPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.assignment_outlined, size: 16, color: Colors.blue.shade700),
                ),
                title: Text(
                  woCode,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${woTrays.length} trays · ${woPcs.toStringAsFixed(0)} pcs · ${woWeight.toStringAsFixed(2)} kg',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                children: [
                  // Sub-header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: Colors.grey.shade100,
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: Text('ITEM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                        Expanded(flex: 2, child: Text('TRAYS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                        Expanded(flex: 2, child: Text('PCS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                        Expanded(flex: 3, child: Text('WEIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                      ],
                    ),
                  ),
                  ...byItem.entries.toList().asMap().entries.map((e) {
                    final i = e.key;
                    final itemEntry = e.value;
                    final itemDesc = itemEntry.key;
                    final itemTrays = itemEntry.value;
                    
                    double itemPcs = 0;
                    double itemWeight = 0;
                    for (final t in itemTrays) {
                      final qty = t.productionProgress.primaryQuantity ?? 0;
                      final pw = t.item?.pieceWeight ?? 0;
                      itemPcs += qty;
                      itemWeight += qty * pw;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: i.isEven ? Colors.white : Colors.grey.shade50,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              itemDesc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${itemTrays.length}',
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              itemPcs.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              '${itemWeight.toStringAsFixed(2)} kg',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  Widget _statTile(String label, String value, IconData icon, {Color? valueColor}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade600),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(vertical: 4),
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
              style: _tableHeaderStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'WO',
              style: _tableHeaderStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'ITEM DESC',
              style: _tableHeaderStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'QUANTITY',
              style: _tableHeaderStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'WEIGHT',
              style: _tableHeaderStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
      ),
      child: Center(
        child: Text(
          'No scanned trays yet. Start by scanning a tray barcode.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Widget _buildTrayRow(int index) {
    final tray = _scannedTrays[index];
    final trayId = tray.primaryTrayModel.id;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
        color: index.isEven ? Colors.white : Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              tray.primaryTrayModel?.trayCode ?? '',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              tray.workOrderHeader!.workOrderCode,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              tray.item!.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (tray.productionProgress.primaryQuantity ?? 0)
                      .toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Builder(
              builder: (_) {
                final qty = tray.productionProgress.primaryQuantity ?? 0;
                final pw = tray.item?.pieceWeight;
                if (pw == null || pw == 0)
                  return const Text('-', style: TextStyle(fontSize: 13));
                return Text(
                  '${(qty * pw).toStringAsFixed(2)} kg',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                final pid = tray.productionProgress.id;
                if (pid != null) _batchedProgressIds.remove(pid);
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
              child: Icon(Icons.cancel, size: 18, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
