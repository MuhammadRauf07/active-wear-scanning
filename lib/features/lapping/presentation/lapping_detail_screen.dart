import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/dynamic_info_display.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/processing/repo/processing_repo.dart';
import 'package:flutter/material.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';

class LappingDetailScreen extends StatefulWidget {
  final int batchHeaderId;
  final String batchCode;
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
  bool _isLoading = false;
  List<ProductionProgressResponseModel> _trays = [];
  final Map<String, _WorkOrderSummary> _workOrders = {};
  String? _selectedWorkOrderId;
  // Keyed by composite work order ID — each WO keeps its own independent tray bucket
  final Map<String, List<ProductionProgressResponseModel>> _scannedTraysByWO =
      {};

  final _trayBarcodeController = TextEditingController();
  final _trayQtyController = TextEditingController();
  final _trayFocusNode = FocusNode();

  final Map<String, double> _trayOverrideQuantities = {};

  @override
  void dispose() {
    _trayBarcodeController.dispose();
    _trayFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchBatchData();
  }

  Future<void> _fetchBatchData() async {
    setState(() => _isLoading = true);

    final res = await _processingRepo.fetchProductionProgress({
      'BatchHeaderId': widget.batchHeaderId.toString(),
      'TransactionType': '2', // Show active trays
    });

    if (res.success && res.data != null) {
      final List<ProductionProgressResponseModel> fetchedTrays =
          res.data as List<ProductionProgressResponseModel>;

      // Group by Work Order safely
      final Map<String, _WorkOrderSummary> summaries = {};

      for (final tray in fetchedTrays) {
        final woId = tray.workOrderHeader.id;
        final itemDesc =
            tray.processedItem?.description ?? tray.item.description ?? '';

        // Group strictly by both Work Order ID and Descriptive string to handle varied items mapped to a root order.
        if (woId != null && itemDesc.isNotEmpty) {
          final compositeId = '${woId}_$itemDesc';

          if (summaries.containsKey(compositeId)) {
            final existing = summaries[compositeId]!;
            summaries[compositeId] = _WorkOrderSummary(
              id: compositeId,
              description: existing.description,
              componentDescription: existing.componentDescription,
              trayCount: existing.trayCount + 1,
              cumulativePieces:
                  existing.cumulativePieces +
                  (tray.productionProgress.primaryQuantity ?? 0),
            );
          } else {
            // Access nested fields safely with fallback values to ensure they are non-nullable
            final woDesc = tray.workOrderHeader.description ?? '';

            summaries[compositeId] = _WorkOrderSummary(
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
        _selectedWorkOrderId =
            null; // Ensure no work order is selected by default
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching batch data: ${res.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                              'batch': {
                                'icon': Icons.qr_code,
                                'label': 'Batch ID',
                                'value': widget.batchCode,
                              },
                              'machine': {
                                'icon': Icons.precision_manufacturing,
                                'label': 'Machine',
                                'value': widget.machine,
                              },
                              'color': {
                                'icon': Icons.palette,
                                'label': 'Color',
                                'value': widget.color,
                              },
                              'weight': {
                                'icon': Icons.scale,
                                'label': 'Req Weight',
                                'value':
                                    '${widget.totalWeight.toStringAsFixed(2)} kg',
                              },
                              'trays': {
                                'icon': Icons.layers,
                                'label': 'Active Trays',
                                'value': '${widget.trayCount} trays',
                              },
                            },
                          ),
                          const SizedBox(height: 20),
                          if (_workOrders.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                'Select Work Order Line',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            ContentCard(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'WORK ORDER',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 6,
                                          child: Text(
                                            'ITEM DESC',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'TRAYS',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'TOTAL PCS',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'RE-ASSIGN PCS',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 32),
                                      ],
                                    ),
                                  ),
                                  ..._workOrders.values.map((wo) {
                                    final isSelected =
                                        _selectedWorkOrderId == wo.id;
                                    return InkWell(
                                      onTap: () {
                                        setState(
                                          () => _selectedWorkOrderId = wo.id,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.blue.withValues(
                                                  alpha: 0.05,
                                                )
                                              : Colors.transparent,
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                wo.description,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 6,
                                              child: Text(
                                                wo.componentDescription,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '${wo.trayCount}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '${wo.cumulativePieces.toInt()}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                            // RE-ASSIGN PCS: sum of override quantities for trays matching this work order
                                            Builder(
                                              builder: (context) {
                                                final woTrays =
                                                    _scannedTraysByWO[wo.id] ??
                                                    [];
                                                final reassigned = woTrays.fold<double>(
                                                  0,
                                                  (sum, t) =>
                                                      sum +
                                                      (_trayOverrideQuantities[t
                                                                  .primaryTrayModel
                                                                  .trayCode
                                                                  ?.toLowerCase() ??
                                                              ''] ??
                                                          0),
                                                );
                                                return Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    reassigned > 0
                                                        ? '${reassigned.toInt()}'
                                                        : '-',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: reassigned > 0
                                                          ? Colors.green
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            SizedBox(
                                              width: 32,
                                              child: Radio<String>(
                                                value: wo.id,
                                                groupValue:
                                                    _selectedWorkOrderId,
                                                activeColor: Colors.blue,
                                                onChanged: (val) {
                                                  setState(() {
                                                    _selectedWorkOrderId = val;
                                                    _trayQtyController.clear();
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                            if (_selectedWorkOrderId != null) ...[
                              const SizedBox(height: 24),
                              const SectionHeader(
                                title: 'Scan Trays',
                                subtitle:
                                    'Verify and assign trays to the selected work order',
                              ),
                              const SizedBox(height: 12),
                              ContentCard(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: _trayBarcodeController,
                                        focusNode: _trayFocusNode,
                                        decoration: InputDecoration(
                                          hintText: 'Enter/Scan Tray ID',
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 14,
                                          ),
                                          prefixIcon: IconButton(
                                            icon: Icon(
                                              Icons.qr_code_scanner,
                                              size: 20,
                                              color: Colors.blue,
                                            ),
                                            onPressed: _openScanner,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Colors.blue,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Colors.blue,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Colors.blue,
                                            ),
                                          ),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                        ),
                                        onSubmitted: (_) {
                                          final String? error = _onTrayScanned(
                                            _trayBarcodeController.text,
                                          );
                                          if (error != null) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(error),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 120,
                                      height: 44,
                                      child: TextField(
                                        controller: _trayQtyController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          hintText: 'Pcs/tray',
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 14,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Colors.blue,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Colors.blue,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Colors.blue,
                                            ),
                                          ),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 13,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    CustomOutlinedButton(
                                      label: 'Scan Tray',
                                      borderColor: Colors.blue,
                                      fillColor: Colors.blue,
                                      textColor: Colors.white,
                                      buttonHeight: 44,
                                      onPressed: () {
                                        if (_trayBarcodeController.text
                                            .trim()
                                            .isEmpty) {
                                          _openScanner();
                                        } else {
                                          final String? error = _onTrayScanned(
                                            _trayBarcodeController.text,
                                          );
                                          if (error != null) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(error),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if ((_scannedTraysByWO[_selectedWorkOrderId] ??
                                      [])
                                  .isNotEmpty)
                                _buildScannedTraysTable(),
                            ],
                          ] else if (!_isLoading && _trays.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No trays found in this batch.'),
                              ),
                            ),
                          const SizedBox(height: 20),
                          // const Center(
                          //   child: Text(
                          //     'Lapping Process Details\nComing Soon',
                          //     textAlign: TextAlign.center,
                          //     style: TextStyle(
                          //       fontSize: 16,
                          //       color: Colors.grey,
                          //       fontWeight: FontWeight.w500,
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openScanner() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Tray',
      onResult: (scannedCode) async {
        final code = scannedCode.trim();
        if (code.isEmpty) return 'Invalid tray code';
        _trayBarcodeController.text = code;
        return _onTrayScanned(code);
      },
    );
  }

  String? _onTrayScanned(String code) {
    if (_trayQtyController.text.trim().isEmpty) {
      return 'Please add No. of Pcs before scanning!';
    }

    final double inputPcs = double.tryParse(_trayQtyController.text) ?? 0;
    if (inputPcs <= 0) {
      return 'Pcs amount must be greater than 0!';
    }

    if (code.trim().isEmpty) return 'Invalid tray code';

    final trayCode = code.trim().toLowerCase();

    final activeSummary = _workOrders[_selectedWorkOrderId];
    if (activeSummary == null) return 'No Active Work Order selected!';

    final maxLimit = activeSummary.cumulativePieces;
    final currentWOTrays = _scannedTraysByWO[_selectedWorkOrderId] ?? [];

    // Validate commutative totals BEFORE adding (only for current WO)
    double totalPcsCurrentlyScanned = currentWOTrays.fold(
      0,
      (sum, t) =>
          sum +
          (_trayOverrideQuantities[t.primaryTrayModel.trayCode?.toLowerCase() ??
                  ''] ??
              0),
    );
    if ((totalPcsCurrentlyScanned + inputPcs) > maxLimit) {
      return 'Scanning denied: Pcs cannot exceed max cumulative limit ($maxLimit). Currently at $totalPcsCurrentlyScanned!';
    }

    // In actual production, hit the validate API.
    // For now we check if the scanned physical tray belongs to the API load and selected work order exactly matching the composite key.
    final matchedTray = _trays.where((t) {
      final tDesc = t.processedItem?.description ?? t.item.description ?? '';
      return (t.primaryTrayModel.trayCode?.toLowerCase() == trayCode) &&
          ('${t.workOrderHeader.id}_$tDesc' == _selectedWorkOrderId);
    }).firstOrNull;

    final currentWOTraysForDupe = _scannedTraysByWO[_selectedWorkOrderId] ?? [];
    if (matchedTray != null) {
      if (!currentWOTraysForDupe.any(
        (st) =>
            st.primaryTrayModel.trayCode ==
            matchedTray.primaryTrayModel.trayCode,
      )) {
        setState(() {
          _trayOverrideQuantities[matchedTray.primaryTrayModel.trayCode
                      ?.toLowerCase() ??
                  ''] =
              inputPcs;
          _scannedTraysByWO.putIfAbsent(_selectedWorkOrderId!, () => []);
          _scannedTraysByWO[_selectedWorkOrderId!]!.add(matchedTray);
          _trayBarcodeController.clear();
          _trayFocusNode.requestFocus();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tray scanned successfully'),
            backgroundColor: Colors.green,
          ),
        );
        return null;
      } else {
        return 'Tray already scanned in this session!';
      }
    } else {
      return 'Tray offline or does not belong to selected Work Order!';
    }
  }

  Widget _buildScannedTraysTable() {
    final traysToShow = _scannedTraysByWO[_selectedWorkOrderId] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SectionHeader(
          title: 'Scanned Trays',
          subtitle: 'Trays successfully scanned and validated',
        ),
        const SizedBox(height: 12),
        ContentCard(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'TRAY CODE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'ITEM DESC',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'QTY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'WEIGHT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 36),
                  ],
                ),
              ),
              ...traysToShow.map((t) {
                final trayKey =
                    t.primaryTrayModel.trayCode?.toLowerCase() ?? '';
                final qty = _trayOverrideQuantities[trayKey] ?? 0;
                final pw = t.item.pieceWeight ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          t.primaryTrayModel.trayCode ?? '-',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          t.processedItem?.description ??
                              t.item.description ??
                              '-',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          qty.toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${(qty * pw).toStringAsFixed(2)} kg',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: IconButton(
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: Colors.red,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              _scannedTraysByWO[_selectedWorkOrderId]?.remove(
                                t,
                              );
                              _trayOverrideQuantities.remove(trayKey);
                            });
                          },
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
    );
  }

  Future<void> _saveChanges() async {
    // Check if any tray was scanned at all across all work orders
    final allScannedTrays = _scannedTraysByWO.values
        .expand((list) => list)
        .toList();
    if (allScannedTrays.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Trays Scanned'),
          content: const Text(
            'Please scan at least one tray before submitting.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Completion validation: every work order must have at least one tray re-assigned
    for (final wo in _workOrders.values) {
      final woTrays = _scannedTraysByWO[wo.id] ?? [];
      final reassigned = woTrays.fold<double>(
        0,
        (sum, t) =>
            sum +
            (_trayOverrideQuantities[t.primaryTrayModel.trayCode
                        ?.toLowerCase() ??
                    ''] ??
                0),
      );
      if (reassigned == 0) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Incomplete Assignment'),
            content: Text(
              'You must Re-Assign trays for ALL Work Orders before submitting!\n\nMissing trays for:\n"${wo.componentDescription}"',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final batchRepo = BatchRepo();

      // Step 0: Deactivate all existing (old) batch lines for the current batch header
      final currentHeaderLinesRes = await batchRepo.fetchBatchLines(
        batchHeaderId: widget.batchHeaderId,
      );
      if (currentHeaderLinesRes.success && currentHeaderLinesRes.data != null) {
        final currentLines =
            currentHeaderLinesRes.data as List<Map<String, dynamic>>;
        for (final line in currentLines) {
          // The diagnostic showed the actual record is nested under 'batchLines'
          final batchLine = line['batchLines'] as Map<String, dynamic>? ?? line;

          final id = batchLine['id'] as int?;
          final activeRaw = batchLine['active'] ?? batchLine['isActive'];
          final bool isActive = activeRaw == true || activeRaw == 1;
          final reAssignedRaw =
              batchLine['isReAssigned'] ??
              batchLine['isreAssigned'] ??
              batchLine['isReassigned'];
          final bool isReassigned = reAssignedRaw == true || reAssignedRaw == 1;

          if (id != null && isActive && !isReassigned) {
            final updateRes = await batchRepo.updateBatchLine(id, {
              'id': id,
              'concurrencyStamp': batchLine['concurrencyStamp'],
              'active': false,
              'isActive': false,
              'isReAssigned': false,
              'planDate': batchLine['planDate'],
              'transactionDate': batchLine['transactionDate'],
              'primaryQuantity': batchLine['primaryQuantity'],
              'primaryUOM': batchLine['primaryUOM'],
              'secondaryQuantity': batchLine['secondaryQuantity'],
              'secondaryUOM': batchLine['secondaryUOM'],
              'batchLineCode': batchLine['batchLineCode'],
              'batchHeaderId': batchLine['batchHeaderId'],
              'progressId': batchLine['progressId'],
              'wipTransactionId': batchLine['wipTransactionId'],
              'workOrderHeaderId':
                  batchLine['workOrderHeaderId'] ??
                  line['workOrderHeader']?['id'],
              'workOrderLineId':
                  batchLine['workOrderLineId'] ?? line['workOrderLine']?['id'],
              'itemId': batchLine['itemId'] ?? line['item']?['id'],
              'trayId': batchLine['trayId'] ?? line['tray']?['id'],
              'locatorId': batchLine['locatorId'],
            });
            if (!updateRes.success) {
              throw Exception(
                'Failed to deactivate old batch line ($id): ${updateRes.message}',
              );
            }
          }
        }
      }

      for (final tray in allScannedTrays) {
        final progressId = tray.productionProgress.id!;
        int? wipTransactionId;

        // Step 1: Fetch WIP transaction for the new entry
        final wipRes = await batchRepo.fetchWipTransactionsByProgressId(
          progressId,
        );
        if (wipRes.success && wipRes.data != null) {
          final items = wipRes.data as List<Map<String, dynamic>>;
          if (items.isNotEmpty) {
            wipTransactionId = items.first['wipTransaction']?['id'] as int?;
          }
        }

        final double overrideQty =
            _trayOverrideQuantities[tray.primaryTrayModel.trayCode
                    ?.toLowerCase() ??
                ''] ??
            0;

        // Step 2: POST new batch line entry with isReAssigned: true
        final lineRes = await batchRepo.createBatchLine({
          "planDate": DateTime.now().toIso8601String(),
          "transactionDate": DateTime.now().toIso8601String(),
          "primaryQuantity": overrideQty,
          "primaryUOM": tray.productionProgress.primaryUOM ?? 0,
          "secondaryQuantity": tray.productionProgress.secondaryQuantity ?? 0,
          "secondaryUOM": tray.productionProgress.secondaryUOM ?? 0,
          "batchLineCode":
              "BL-${widget.batchHeaderId}-${tray.primaryTrayModel.id}",
          "batchHeaderId": widget.batchHeaderId,
          "progressId": progressId,
          "wipTransactionId": wipTransactionId,
          "workOrderHeaderId": tray.workOrderHeader.id,
          "workOrderLineId": tray.workOrderLine.id,
          "itemId": tray.item.id,
          "trayId": tray.primaryTrayModel.id,
          "locatorId": tray.productionProgress.locatorId,
          "isReAssigned": true,
          "active": true,
          if (tray.processedItem != null)
            "processedItemId": tray.processedItem!.id,
        });

        if (!lineRes.success) {
          throw Exception(
            lineRes.message ?? 'Unknown error creating batch line',
          );
        }

        // Extract the new batch line ID from the response
        int? newBatchLineId;
        if (lineRes.data != null) {
          final resData = lineRes.data as Map<String, dynamic>?;
          newBatchLineId = resData?['id'] as int?;
        }

        // Step 2b: Fetch the full existing tray-detail record, then update only the changed fields
        final trayId = tray.primaryTrayModel.id;
        if (trayId != null) {
          final fetchRes = await batchRepo.fetchTrayDetailById(trayId);
          if (!fetchRes.success || fetchRes.data == null) {
            throw Exception('Failed to fetch tray detail for ${tray.primaryTrayModel.trayCode}: ${fetchRes.message}');
          }

          final rawData = fetchRes.data as Map<String, dynamic>;
          // The actual flat record is usually nested under 'trayDetail' key
          final trayDetailMap = rawData['trayDetail'] as Map<String, dynamic>? ?? rawData;
          
          // Prepare a clean DTO containing ONLY mutable business fields.
          // IMPORTANT: Removed 'id' from body as it is already in the URL.
          final Map<String, dynamic> cleanDto = {
            'trayCode': trayDetailMap['trayCode'] ?? tray.primaryTrayModel.trayCode,
            'description': trayDetailMap['description'] ?? tray.primaryTrayModel.description,
            'trayQuantity': overrideQty.toInt(),
            'active': true,
            'isReAssigned': true,
            'trayType': trayDetailMap['trayType'] ?? 0,
            'productGrade': tray.productionProgress.productGrade ?? trayDetailMap['productGrade'] ?? 0,
            'productNature': tray.productionProgress.productNature ?? trayDetailMap['productNature'] ?? 0,
            'shiftId': tray.productionProgress.shiftId ?? trayDetailMap['shiftId'],
            'planLineId': trayDetailMap['planLineId'],
            'resourceId': trayDetailMap['resourceId'],
            'workOrderHeaderId': tray.workOrderHeader.id,
            'workOrderLineId': tray.workOrderLine.id,
            'knitItemId': tray.item.id,
            'locatorId': tray.productionProgress.locatorId ?? trayDetailMap['locatorId'],
            'batchHeaderId': widget.batchHeaderId,
            'batchLineId': newBatchLineId, // Using singular 'Id' as seen in other screens
            'concurrencyStamp': trayDetailMap['concurrencyStamp'],
          };

          debugPrint('🚀 Sending TrayDetail Update: $cleanDto');

          final trayDetailRes = await batchRepo.updateTrayDetails(trayId, cleanDto);
          if (!trayDetailRes.success) {
            throw Exception(
              'Failed to update tray detail for ${tray.primaryTrayModel.trayCode}: ${trayDetailRes.message}',
            );
          }
        }



        // Step 3: Fetch old batch line entries for this tray and deactivate them
        final oldLinesRes = await batchRepo.fetchBatchLinesByProgressId(
          progressId,
        );
        if (oldLinesRes.success && oldLinesRes.data != null) {
          final oldLines = oldLinesRes.data as List<Map<String, dynamic>>;
          for (final oldLineWrapper in oldLines) {
            final oldLine =
                oldLineWrapper['batchLines'] as Map<String, dynamic>? ??
                oldLineWrapper;

            final oldId = oldLine['id'] as int?;
            final activeRaw = oldLine['active'] ?? oldLine['isActive'];
            final bool isActive = activeRaw == true || activeRaw == 1;
            final reAssignedRaw =
                oldLine['isReAssigned'] ??
                oldLine['isreAssigned'] ??
                oldLine['isReassigned'];
            final bool isReassigned =
                reAssignedRaw == true || reAssignedRaw == 1;

            // Only deactivate old entries that are NOT the newly created re-assigned one
            if (oldId != null && !isReassigned && isActive) {
              // Clean Business DTO for deactivation: Preserve all fields while setting active = false
              final Map<String, dynamic> cleanOldLineDto = {
                'planDate': oldLine['planDate'],
                'transactionDate': oldLine['transactionDate'],
                'primaryQuantity': (oldLine['primaryQuantity'] as num?)?.toDouble() ?? 0,
                'primaryUOM': oldLine['primaryUOM'],
                'secondaryQuantity': (oldLine['secondaryQuantity'] as num?)?.toDouble() ?? 0,
                'secondaryUOM': oldLine['secondaryUOM'],
                'batchLineCode': oldLine['batchLineCode'],
                'active': false,
                'isActive': false, // Some APIs use both
                'isReAssigned': false,
                'batchHeaderId': oldLine['batchHeaderId'],
                'progressId': oldLine['progressId'],
                'wipTransactionId': oldLine['wipTransactionId'],
                'workOrderHeaderId': oldLine['workOrderHeaderId'] ?? oldLineWrapper['workOrderHeader']?['id'],
                'workOrderLineId': oldLine['workOrderLineId'] ?? oldLineWrapper['workOrderLine']?['id'],
                'itemId': oldLine['itemId'] ?? oldLineWrapper['item']?['id'],
                'trayId': oldLine['trayId'] ?? oldLineWrapper['tray']?['id'],
                'locatorId': oldLine['locatorId'],
                'processedItemId': oldLine['processedItemId'],
                'concurrencyStamp': oldLine['concurrencyStamp'],
              };

              final updateRes = await batchRepo.updateBatchLine(oldId, cleanOldLineDto);
              if (!updateRes.success) {
                throw Exception(
                  'Failed to deactivate history tray line ($oldId): ${updateRes.message}',
                );
              }
            }
          }
        }
      }

      // After batch line re-assignments: run the standard batch handover
      // PUT each tray transactionType→3, then POST new production progress for next operation
      final processingRepo = ProcessingRepo();
      final trayRes = await processingRepo.fetchProductionProgress({
        'BatchHeaderId': widget.batchHeaderId.toString(),
        'OperationId': widget.currentOperationId.toString(),
        'TransactionType': '2',
      });

      if (trayRes.success && trayRes.data != null) {
        final batchTrays =
            trayRes.data as List<ProductionProgressResponseModel>;
        for (final t in batchTrays) {
          final currentPp = t.productionProgress;
          final updatedJson = currentPp.toJson();
          updatedJson['transactionType'] = 3;
          final ures = await processingRepo.updateProductionProgress(
            currentPp.id!,
            updatedJson,
          );
          if (!ures.success) {
            throw Exception(
              'Failed to update progress to completed: ${ures.message}',
            );
          }

          final nextJson = currentPp.toJson();
          nextJson['transactionType'] = 2;
          nextJson.remove('id');
          nextJson.remove('progressCode');
          nextJson.remove('concurrencyStamp');
          if (widget.nextOperationId != null) {
            nextJson['operationId'] = widget.nextOperationId;
          } else {
            nextJson['wipStatus'] = 1;
          }
          final cres = await processingRepo.createProductionProgress(nextJson);
          if (!cres.success) {
            throw Exception(
              'Failed to create handover record: ${cres.message}',
            );
          }
        }
      }

      setState(() => _isLoading = false);
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Trays saved successfully to the batch!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}

class _WorkOrderSummary {
  final String id;
  final String description;
  final String componentDescription;
  final int trayCount;
  final double cumulativePieces;

  _WorkOrderSummary({
    required this.id,
    required this.description,
    required this.componentDescription,
    required this.trayCount,
    required this.cumulativePieces,
  });

  String get dropdownLabel =>
      '$description - $componentDescription - $trayCount Trays - ${cumulativePieces.toInt()} Pcs';
}
