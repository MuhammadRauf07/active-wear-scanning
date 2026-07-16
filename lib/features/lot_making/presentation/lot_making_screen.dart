import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_expanded_async_dropdown.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/core/widgets/empty_scan_state.dart';
import 'package:active_wear_scanning/core/widgets/tray_table_header.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_color_model.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_machine_model.dart';
import 'package:active_wear_scanning/features/lot_making/repo/lot_repo.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/knitting_production/model/scanned_tray.dart';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';

import '../../common-models/common_models.dart';

class LotMakingScreen extends StatefulWidget {
  final LotHeaderResponseModel? existingBatch;
  final List<ProductionProgressResponseModel>? preloadedTrays;

  const LotMakingScreen({
    super.key,
    this.existingBatch,
    this.preloadedTrays,
  });

  @override
  State<LotMakingScreen> createState() => _LotMakingScreenState();
}

class _LotMakingScreenState extends State<LotMakingScreen> {
  final _lotRepo = LotRepo();

  List<LotMachineModel> _machines = [];
  LotMachineModel? _selectedMachine;
  bool _isLoading = true;

  List<LotColorModel> _colors = [];
  LotColorModel? _selectedColor;
  bool _isLoadingColors = false;

  WorkOrderHeader? _selectedWorkOrder;
  ProductionProgressResponseModel? _selectedTray;
  final Map<int, Set<String>> _workOrderValidColors = {};
  bool _isCachingColors = false;
  final Map<String, double> _colorPlanQuantities = {};

  final List<ProductionProgressResponseModel> _scannedTrays = [];
  final List<TextEditingController> _quantityControllers = [];
  final _overrideQuantityController = TextEditingController();

  List<ProductionProgressResponseModel> productionProgressTrays = [];

  final Set<int> _lotProgressIds = {};
  final Set<int> _currentBatchDatabaseProgressIds = {};
  final Map<int, int> _trayProcessedItemId = {};

  Set<String>? _referenceRoutingCodes;
  int? _referenceRoutingCount;
  int? _referenceMinOperationId;

  final FocusNode _focusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  late String _lotCode;
  StateSetter? _dialogSetState;

  @override
  void initState() {
    super.initState();
    _lotCode = widget.existingBatch?.batchHeader.batchHeaderCode ??
        "LOT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMachines();
      _fetchColors();
      _fetchProductionProgresses();
      _fetchLotProgressIds();
    });
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

  Future<void> _fetchProductionProgresses() async {
    final result = await _lotRepo.fetchProductionProgress();
    if (!mounted) return;
    if (result.success && result.data != null) {
      final progresses = result.data as List<ProductionProgressResponseModel>;
      setState(() {
        productionProgressTrays = progresses;
      });
      _cacheColorsForGbsWorkOrders();
      if (widget.existingBatch != null) {
        await _loadExistingLotTrays(progresses);
      }
    } else {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(
        context,
        title: 'Fetch Failed',
        message: result.message ?? 'Unknown error fetching production progresses',
      );
    }
  }

  List<WorkOrderHeader> getAvailableWorkOrders() {
    final Set<int> seenIds = {};
    final List<WorkOrderHeader> wos = [];
    
    final gbsTrays = productionProgressTrays.where((t) {
      final progressId = t.productionProgress.id;
      final isCurrentBatchDbTray = progressId != null && _currentBatchDatabaseProgressIds.contains(progressId);
      final hasBatchHeader = t.productionProgress.batchHeaderId != null && t.productionProgress.batchHeaderId != 0;
      final isCurrentBatchHeader = widget.existingBatch?.batchHeader.id != null && t.productionProgress.batchHeaderId == widget.existingBatch!.batchHeader.id;
      final isAssignedToOtherLot = hasBatchHeader && !isCurrentBatchHeader;

      return t.productionProgress.locatorId == 3 &&
             t.productionProgress.gbsFlag == true &&
             t.workOrderHeader != null &&
             !isAssignedToOtherLot &&
             (progressId == null || !_lotProgressIds.contains(progressId) || isCurrentBatchDbTray);
    }).toList();

    for (final tray in gbsTrays) {
      final id = tray.workOrderHeader.id;
      if (id != null && !seenIds.contains(id)) {
        seenIds.add(id);
        wos.add(tray.workOrderHeader);
      }
    }
    return wos;
  }

  List<WorkOrderHeader> getFilteredWorkOrders() {
    final wos = getAvailableWorkOrders();
    if (_selectedColor == null) return wos;
    final selectedColorDesc = _selectedColor!.segmentCode?.description?.toUpperCase();
    if (selectedColorDesc == null) return wos;
    
    return wos.where((wo) {
      final validColors = _workOrderValidColors[wo.id];
      return validColors != null && validColors.contains(selectedColorDesc);
    }).toList();
  }

  List<LotColorModel> getFilteredColors() {
    if (_selectedWorkOrder == null) return _colors;
    final validColors = _workOrderValidColors[_selectedWorkOrder!.id];
    if (validColors == null) return [];
    
    return _colors.where((color) {
      final desc = color.segmentCode?.description?.toUpperCase();
      return desc != null && validColors.contains(desc);
    }).toList();
  }

  List<ProductionProgressResponseModel> getTraysForSelectedWorkOrder() {
    if (_selectedWorkOrder == null) return [];
    return productionProgressTrays.where((t) {
      final progressId = t.productionProgress.id;
      final isCurrentBatchDbTray = progressId != null && _currentBatchDatabaseProgressIds.contains(progressId);
      final hasBatchHeader = t.productionProgress.batchHeaderId != null && t.productionProgress.batchHeaderId != 0;
      final isCurrentBatchHeader = widget.existingBatch?.batchHeader.id != null && t.productionProgress.batchHeaderId == widget.existingBatch!.batchHeader.id;
      final isAssignedToOtherLot = hasBatchHeader && !isCurrentBatchHeader;

      return t.productionProgress.locatorId == 3 &&
             t.productionProgress.gbsFlag == true &&
             t.workOrderHeader?.id == _selectedWorkOrder!.id &&
             !isAssignedToOtherLot &&
             (progressId == null || !_lotProgressIds.contains(progressId) || isCurrentBatchDbTray);
    }).toList();
  }

  List<ProductionProgressResponseModel> getTraysForSelectedWorkOrderAndColor() {
    final trays = getTraysForSelectedWorkOrder();
    if (_selectedColor == null) return [];
    final selectedColorDesc = _selectedColor!.segmentCode?.description?.toUpperCase();
    if (selectedColorDesc == null) return [];

    return trays.where((t) {
      final lineId = t.productionProgress.workOrderLineId ?? t.workOrderLine?.id;
      if (lineId == null) return false;
      final planQty = _colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
      return planQty > 0.0;
    }).toList();
  }

  double _getAlreadyAssignedTubesForWorkOrderLine(int workOrderLineId) {
    double sum = 0.0;
    final currentBatchId = widget.existingBatch?.batchHeader.id;
    for (final t in productionProgressTrays) {
      final lineId = t.productionProgress.workOrderLineId ?? t.workOrderLine?.id;
      if (lineId == workOrderLineId) {
        final bhId = t.productionProgress.batchHeaderId;
        if (bhId != null && bhId != 0 && bhId != currentBatchId) {
          sum += (t.productionProgress.primaryQuantity ?? 0.0);
        }
      }
    }
    return sum;
  }

  Map<String, double> _getTrayQuantities(ProductionProgressResponseModel tray) {
    final code = tray.primaryTrayModel.trayCode;
    final fallbackQty = tray.productionProgress.primaryQuantity ?? 0.0;
    if (code == null) {
      return {'actual': fallbackQty, 'alreadyScanned': 0.0, 'remaining': fallbackQty};
    }
    
    final trayProgresses = productionProgressTrays.where((t) => 
      (t.primaryTrayModel?.trayCode ?? '').trim().toLowerCase() == code.trim().toLowerCase() &&
      t.productionProgress.locatorId == 3 &&
      t.productionProgress.gbsFlag == true
    ).toList();
    
    final actual = trayProgresses.fold<double>(0.0, (sum, t) => sum + (t.productionProgress.primaryQuantity ?? 0.0));
    
    final alreadyScanned = trayProgresses.where((t) {
      final hasBatch = t.productionProgress.batchHeaderId != null && t.productionProgress.batchHeaderId != 0;
      final isCurrent = widget.existingBatch?.batchHeader.id != null && t.productionProgress.batchHeaderId == widget.existingBatch!.batchHeader.id;
      return hasBatch && !isCurrent;
    }).fold<double>(0.0, (sum, t) => sum + (t.productionProgress.primaryQuantity ?? 0.0));

    final remaining = actual - alreadyScanned;

    return {
      'actual': actual,
      'alreadyScanned': alreadyScanned,
      'remaining': remaining,
    };
  }

  Future<void> _cacheColorsForGbsWorkOrders() async {
    if (mounted) setState(() => _isCachingColors = true);
    
    try {
      final wos = getAvailableWorkOrders();
      for (final wo in wos) {
        final woId = wo.id;
        if (woId == null || _workOrderValidColors.containsKey(woId)) continue;
        
        final trays = productionProgressTrays.where((t) {
          final progressId = t.productionProgress.id;
          final isCurrentBatchDbTray = progressId != null && _currentBatchDatabaseProgressIds.contains(progressId);
          return t.productionProgress.locatorId == 3 &&
                 t.productionProgress.gbsFlag == true &&
                 t.workOrderHeader?.id == woId &&
                 (progressId == null || !_lotProgressIds.contains(progressId) || isCurrentBatchDbTray);
        }).toList();

        final lineIds = trays
            .map((t) => t.productionProgress.workOrderLineId ?? t.workOrderLine?.id)
            .whereType<int>()
            .toSet();

        final Set<String> validColors = {};
        for (final lineId in lineIds) {
          final res = await _lotRepo.fetchAllWorkOrderLineDetails(lineId);
          if (res.success && res.data != null) {
            _colorPlanQuantities.removeWhere((key, _) => key.startsWith("${lineId}_"));
            final items = res.data as List;
            for (final item in items) {
              final detail = (item as Map)['workOrderLineDetail'];
              if (detail != null) {
                final colorDesc = detail['colorDescription']?.toString().trim().toUpperCase();
                final planQty = (detail['planQuantity'] as num?)?.toDouble() ?? 0.0;
                if (colorDesc != null && colorDesc.isNotEmpty) {
                  validColors.add(colorDesc);
                  final key = "${lineId}_$colorDesc";
                  _colorPlanQuantities[key] = (_colorPlanQuantities[key] ?? 0.0) + planQty;
                }
              }
            }
          }
        }
        _workOrderValidColors[woId] = validColors;
      }
    } catch (e) {
      debugPrint('Error caching colors: $e');
    } finally {
      if (mounted) {
        setState(() => _isCachingColors = false);
      }
    }
  }

  Future<void> _loadExistingLotTrays(
    List<ProductionProgressResponseModel> allProgresses,
  ) async {
    if (widget.existingBatch == null) return;
    final batchHeaderId = widget.existingBatch!.batchHeader.id;
    if (batchHeaderId == null) return;

    final linesRes = await _lotRepo.fetchLotLines(
      batchHeaderId: batchHeaderId,
    );
    if (!linesRes.success || linesRes.data == null) return;

    final rawLines = linesRes.data as List<Map<String, dynamic>>;
    final linkedProgressIds = rawLines
        .map((line) => line['batchLines']?['progressId'] as int?)
        .whereType<int>()
        .toSet();

    final linkedTrays = allProgresses
        .where(
          (p) =>
              p.productionProgress.id != null &&
              linkedProgressIds.contains(p.productionProgress.id),
        )
        .toList();

    if (mounted && linkedTrays.isNotEmpty) {
      setState(() {
        _currentBatchDatabaseProgressIds.addAll(linkedProgressIds);
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

  Future<void> _fetchLotProgressIds() async {
    final result = await _lotRepo.fetchLotLines();
    if (result.success && result.data != null) {
      final lines = result.data as List<Map<String, dynamic>>;
      final ids = lines
          .map((l) => l['batchLines']?['progressId'] as int?)
          .whereType<int>()
          .toSet();
      if (mounted) setState(() => _lotProgressIds.addAll(ids));
    }
  }

  Future<void> _fetchMachines() async {
    setState(() => _isLoading = true);
    AppLoader.show(context, message: 'Loading Machines...');
    final result = await _lotRepo.fetchLotMachines();
    if (!mounted) return;

    if (result.success && result.data != null) {
      setState(() {
        _machines = result.data as List<LotMachineModel>;
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
      AppSnackBar.showError(context, message: result.message ?? '');
    }
  }

  Future<void> _fetchColors() async {
    setState(() => _isLoadingColors = true);
    AppLoader.show(context, message: 'Fetching Colors...');
    final result = await _lotRepo.fetchLotColors();
    if (!mounted) return;

    if (result.success && result.data != null) {
      setState(() {
        _colors = result.data as List<LotColorModel>;
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
      AppSnackBar.showError(context, message: result.message ?? '');
    }
  }

  void _onKey(RawKeyEvent event) {
    if (AppLoader.isVisible) {
      _barcodeBuffer = '';
      return;
    }
    if (event is RawKeyDownEvent) {
      final now = DateTime.now();
      if (_lastKeyPress != null &&
          now.difference(_lastKeyPress!).inMilliseconds > 200) {
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
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: 'Please select a machine first');
      return;
    }
    AppLoader.show(context, message: 'Validating Tray...');
    final error = await _validateTrayForScan(code);
    AppLoader.hide(context);
    if (error != null) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: error);
    }
  }

  Future<void> _onScanTray() async {
    if (_selectedMachine == null) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: 'Please select a machine first');
      return;
    }
    HapticFeedbackHelper.buttonClick();
    await Future.delayed(const Duration(milliseconds: 300));
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trays',
      onResult: (scannedCode) async {
        return await _validateTrayForScan(scannedCode);
      },
      scannedItemsBuilder: (context) {
        return StatefulBuilder(
          builder: (context, setSubState) {
            if (_scannedTrays.isEmpty) {
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
                  const TrayTableHeader(actionColumnWidth: 44, showBatchTubes: true, showDetailedTubes: true),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _scannedTrays.length,
                      itemBuilder: (context, index) {
                        final tray = _scannedTrays[index];
                        final qtys = _getTrayQuantities(tray);
                        final actualVal = qtys['actual']!;
                        final alreadyScannedVal = qtys['alreadyScanned']!;
                        final remainingVal = qtys['remaining']!;
                        final qty = double.tryParse(_quantityControllers[index].text) ?? 0;
                        final perTube = tray.item.perGarmentTube;
                        final pcs = qty * perTube;
                        final weight = qty * (tray.item.pieceWeight ?? 0);

                        const cellStyle = TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF263238),
                        );

                        const blueCellStyle = TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B64A3),
                        );

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: Text(
                                  tray.primaryTrayModel.trayCode ?? 'N/A',
                                  textAlign: TextAlign.center,
                                  style: blueCellStyle,
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  tray.workOrderHeader.workOrderCode ?? 'N/A',
                                  textAlign: TextAlign.center,
                                  style: cellStyle,
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  tray.item.sizeDescription ?? 'N/A',
                                  textAlign: TextAlign.center,
                                  style: cellStyle,
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  perTube.toStringAsFixed(0),
                                  textAlign: TextAlign.center,
                                  style: cellStyle,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  actualVal.toStringAsFixed(0),
                                  textAlign: TextAlign.center,
                                  style: cellStyle,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  alreadyScannedVal.toStringAsFixed(0),
                                  textAlign: TextAlign.center,
                                  style: cellStyle.copyWith(color: Colors.orange.shade800),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  remainingVal.toStringAsFixed(0),
                                  textAlign: TextAlign.center,
                                  style: cellStyle.copyWith(color: const Color(0xFF2E7D32)),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  pcs.toStringAsFixed(0),
                                  textAlign: TextAlign.center,
                                  style: cellStyle,
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  '${weight.toStringAsFixed(0)}g',
                                  textAlign: TextAlign.center,
                                  style: cellStyle,
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Container(
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFCFD8DC), width: 1.2),
                                  ),
                                  child: TextField(
                                    controller: _quantityControllers[index],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    style: cellStyle.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF1B64A3)),
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                                      isCollapsed: true,
                                      border: InputBorder.none,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      TubesInputFormatter(remainingVal.toInt()),
                                    ],
                                    onChanged: (val) {
                                      setState(() {});
                                      setSubState(() {});
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
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
                                      setState(() {
                                        _scannedTrays.removeAt(index);
                                        _quantityControllers.removeAt(index);
                                      });
                                      setSubState(() {});
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _validateTrayForScan(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid tray code';
    if (_selectedColor == null) return 'Please select a lot Color first';
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

    if (available.isEmpty) return 'Tray not found or not checked out via GBS';

    final tray = available.firstWhere(
      (t) => !_lotProgressIds.contains(t.productionProgress.id),
      orElse: () => available.first,
    );

    if (_selectedWorkOrder == null) return 'Please select a Work Order first';
    if (tray.workOrderHeader.id != _selectedWorkOrder?.id) {
      return 'Tray belongs to another Work Order (${tray.workOrderHeader.workOrderCode})';
    }

    if ((tray.primaryTrayModel?.trayType ?? 0) != 1)
      return 'Invalid tray type.';
    final progressId = tray.productionProgress.id;
    final isCurrentBatchDbTray = progressId != null && _currentBatchDatabaseProgressIds.contains(progressId);
    if (progressId != null && _lotProgressIds.contains(progressId) && !isCurrentBatchDbTray)
      return 'Tray already assigned to a lot';

    final workOrderLineId =
        tray.productionProgress.workOrderLineId ?? tray.workOrderLine?.id;
    final colorDescription = _selectedColor!.segmentCode?.description;
    if (colorDescription == null) return 'Selected Color has no description';

    final colorRes = await _lotRepo.fetchWorkOrderLineDetails(
      workOrderLineId!,
      colorDescription,
    );
    if (!colorRes.success || colorRes.data == null)
      return 'Validation error: ${colorRes.message}';

    final items = colorRes.data as List?;
    if (items == null || items.isEmpty)
      return 'Invalid tray: Tray does not belong to the selected color';

    final firstItem = items.first as Map;
    final detail = firstItem['workOrderLineDetail'];
    final dynamic processIdRaw = firstItem['processIItemd'];
    int processedItemId;
    if (processIdRaw is int) {
      processedItemId = processIdRaw;
    } else if (processIdRaw is Map) {
      processedItemId = processIdRaw['id'];
    } else {
      processedItemId = detail['knitItemId'] ?? tray.item?.id ?? 0;
    }

    final routingRes = await _lotRepo.fetchItemRoutings(processedItemId);
    if (!routingRes.success || routingRes.data == null)
      return 'Routing validation error: ${routingRes.message}';

    final routingItems = routingRes.data as List;
    final routingCodes = routingItems
        .map((r) => (r as Map)['itemRouting']?['operationId']?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .toSet();
    final routingCount = routingItems.length;

    if (routingCount == 0) return 'Tray item has no route configured';
    if (_referenceRoutingCodes == null) {
      _referenceRoutingCodes = routingCodes;
      _referenceRoutingCount = routingCount;
      int? minSeq;
      int? resolvedOpId;
      for (final r in routingItems) {
        final rMap = r as Map;
        final seq = rMap['itemRouting']?['seq'] as int?;
        final opId = rMap['itemRouting']?['operationId'] as int?;
        if (seq != null && opId != null) {
          if (minSeq == null || seq < minSeq) {
            minSeq = seq;
            resolvedOpId = opId;
          }
        }
      }
      _referenceMinOperationId = resolvedOpId;
    } else if (routingCount != _referenceRoutingCount ||
        !routingCodes.containsAll(_referenceRoutingCodes!) ||
        !_referenceRoutingCodes!.containsAll(routingCodes)) {
      return 'Tray has a different route';
    }

    final capacityRaw = _selectedMachine?.resource?.capacity;
    final capacity = capacityRaw != null
        ? double.tryParse(capacityRaw.toString())
        : null;
    if (capacity != null && capacity > 0) {
      final newQty =
          double.tryParse(_overrideQuantityController.text) ??
          tray.productionProgress.primaryQuantity ??
          0;
      final pw = tray.item?.pieceWeight ?? 0;
      double currentTotal = 0;
      for (int i = 0; i < _scannedTrays.length; i++) {
        final qty =
            double.tryParse(_quantityControllers[i].text) ??
            _scannedTrays[i].productionProgress.primaryQuantity ??
            0;
        final p = _scannedTrays[i].item?.pieceWeight ?? 0;
        currentTotal += qty * p;
      }
      if (currentTotal + (newQty * pw) > capacity) {
        return 'Exceeds machine capacity';
      }
    }

    double planQty = 0.0;
    for (final item in items) {
      if (item is Map) {
        final det = item['workOrderLineDetail'];
        if (det is Map) {
          planQty += (det['planQuantity'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }
    if (planQty > 0.0) {
      final newQty = double.tryParse(_overrideQuantityController.text) ??
          tray.productionProgress.primaryQuantity ??
          0.0;
      double currentCumulative = 0.0;
      for (int i = 0; i < _scannedTrays.length; i++) {
        final t = _scannedTrays[i];
        final lineId = t.productionProgress.workOrderLineId ?? t.workOrderLine?.id;
        if (lineId == workOrderLineId) {
          currentCumulative += double.tryParse(_quantityControllers[i].text) ?? 0.0;
        }
      }
      final alreadyAssigned = _getAlreadyAssignedTubesForWorkOrderLine(workOrderLineId);
      final totalScanned = currentCumulative + newQty + alreadyAssigned;

      final int extraAllowed = (planQty * 0.1).ceil();
      final double maxAllowed = planQty + extraAllowed;
      if (totalScanned > maxAllowed) {
        return 'Cannot scan tray. Scanned quantity (${totalScanned.toStringAsFixed(0)}) exceeds the maximum plan limit including 10% extra allowance (${maxAllowed.toStringAsFixed(0)}) for color "$colorDescription" (Already assigned in other batches: ${alreadyAssigned.toStringAsFixed(0)}).';
      }
    }

    setState(() {
      if (tray.primaryTrayModel?.id != null)
        _trayProcessedItemId[tray.primaryTrayModel!.id!] = processedItemId;
      _scannedTrays.add(tray);
      final defaultQty = _overrideQuantityController.text.isNotEmpty
          ? _overrideQuantityController.text
          : (tray.productionProgress.primaryQuantity?.toStringAsFixed(0) ??
                '0');
      _quantityControllers.add(TextEditingController(text: defaultQty));
    });
    _dialogSetState?.call(() {});
    HapticFeedbackHelper.scanSuccess();
    return null;
  }

  Future<void> _saveLotChanges() async {
    if (_scannedTrays.isEmpty) return;

    for (int i = 0; i < _quantityControllers.length; i++) {
      final text = _quantityControllers[i].text.trim();
      final val = int.tryParse(text);
      if (val == null || val <= 0) {
        HapticFeedbackHelper.scanError();
        AppSnackBar.showError(context, message: 'Please enter a valid tubes value for all trays.');
        return;
      }
      final maxVal = (_scannedTrays[i].productionProgress.primaryQuantity ?? 0.0).toInt();
      if (val > maxVal) {
        HapticFeedbackHelper.scanError();
        AppSnackBar.showError(context, message: 'Tubes count cannot exceed tray capacity ($maxVal).');
        return;
      }
    }

    // Check overproduction by color plan quantity
    final selectedColorDesc = _selectedColor?.segmentCode?.description?.trim().toUpperCase();
    if (selectedColorDesc != null) {
      final Map<int, double> lineCumulativeTubes = {};
      for (int i = 0; i < _scannedTrays.length; i++) {
        final tray = _scannedTrays[i];
        final lineId = tray.productionProgress.workOrderLineId ?? tray.workOrderLine?.id;
        if (lineId != null) {
          final qty = double.tryParse(_quantityControllers[i].text) ?? 0.0;
          lineCumulativeTubes[lineId] = (lineCumulativeTubes[lineId] ?? 0.0) + qty;
        }
      }

      double exceededMax = 0.0;
      double exceededMaxPlan = 0.0;
      bool exceedsMaxLimit = false;

      for (final lineId in lineCumulativeTubes.keys) {
        final planQty = _colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
        final sumTubes = lineCumulativeTubes[lineId] ?? 0.0;
        final alreadyAssigned = _getAlreadyAssignedTubesForWorkOrderLine(lineId);
        final totalScanned = sumTubes + alreadyAssigned;

        final int extraAllowed = (planQty * 0.1).ceil();
        final double maxAllowed = planQty + extraAllowed;

        if (planQty > 0.0 && totalScanned > maxAllowed) {
          exceedsMaxLimit = true;
          exceededMax = totalScanned;
          exceededMaxPlan = maxAllowed;
          break;
        }
      }

      if (exceedsMaxLimit) {
        HapticFeedbackHelper.scanError();
        AppSnackBar.showError(
          context,
          message: 'Cannot save. Cumulative tube count (${exceededMax.toStringAsFixed(0)}) exceeds the maximum allowed limit with 10% extra allowance (${exceededMaxPlan.toStringAsFixed(0)}) for color "$selectedColorDesc".',
        );
        return;
      }

      bool exceedsColorPlan = false;
      double exceededSum = 0.0;
      double exceededPlan = 0.0;
      for (final lineId in lineCumulativeTubes.keys) {
        final planQty = _colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
        final sumTubes = lineCumulativeTubes[lineId] ?? 0.0;
        final alreadyAssigned = _getAlreadyAssignedTubesForWorkOrderLine(lineId);
        final totalScanned = sumTubes + alreadyAssigned;

        if (planQty > 0.0 && totalScanned > planQty) {
          exceedsColorPlan = true;
          exceededSum = totalScanned;
          exceededPlan = planQty;
          break;
        }
      }

      if (exceedsColorPlan) {
        final proceed = await showDialog<bool>(
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
                    'Color Plan Exceeded',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              content: Text(
                'Cumulative tube count (${exceededSum.toStringAsFixed(0)}) exceeds the plan quantity (${exceededPlan.toStringAsFixed(0)}) for color "$selectedColorDesc". Do you want to proceed?',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ?? false;

        if (!proceed) return;
      }
    }

    AppLoader.show(context);

    int batchHeaderId;
    final batchCode = _lotCode;

    if (widget.existingBatch == null) {
      final res = await _lotRepo.createLotHeader({
        "planDate": DateTime.now().toIso8601String(),
        "colorDescription": _selectedColor?.segmentCode?.description ?? "N/A",
        "batchHeaderCode": batchCode,
        "machineId": _selectedMachine?.resource?.id ?? 0,
        "colorCode": _selectedColor?.segmentCode?.id ?? 0,
        "shiftId": _scannedTrays.first.shift?.id,
        "trayDetailId": null,
        "lockFlag": false,
      });

      if (!res.success) {
        AppLoader.hide(context);
        HapticFeedbackHelper.scanError();
        AppSnackBar.showError(context, title: 'Failed to create lot', message: res.message ?? '');
        return;
      }

      final data = res.data as Map;
      dev.log('🚀 LotHeader Create Full Response: $data');

      final rawId = data['id'] ??
          data['batchHeader']?['id'] ??
          data['result']?['id'] ??
          0;
      batchHeaderId = int.tryParse(rawId.toString()) ?? 0;

      // FALLBACK: If server returned 0, try to find the lot by its code
      if (batchHeaderId == 0) {
        dev.log('⚠️ Server returned ID 0. Attempting ID recovery by code: $batchCode');
        final allRes = await _lotRepo.fetchLotHeaders();
        if (allRes.success && allRes.data != null) {
          final List allBatches = allRes.data as List;
          for (var b in allBatches) {
            final bMap = b as Map;
            // Check both flat and nested structures
            final bHeader = bMap['batchHeader'] ?? bMap;
            if (bHeader['batchHeaderCode'] == batchCode) {
              batchHeaderId = bHeader['id'] ?? 0;
              dev.log('`✅ Recovered Lot ID: $batchHeaderId');
              break;
            }
          }
        }
      }
    } else {
      batchHeaderId = widget.existingBatch!.batchHeader.id!;
    }

    if (batchHeaderId == 0) {
      AppLoader.hide(context);
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: 'Invalid Lot ID generated.');
      return;
    }

    for (int i = 0; i < _scannedTrays.length; i++) {
      final tray = _scannedTrays[i];
      final qty = double.tryParse(_quantityControllers[i].text) ??
          tray.productionProgress.primaryQuantity ??
          0;

      final pp = tray.productionProgress;
      final originalQty = pp.primaryQuantity ?? 0.0;
      final isPartial = qty < originalQty;

      int resolvedProgressId = 0;

      if (isPartial) {
        // --- PARTIAL CONSUMPTION ---
        // 1. Create a NEW ProductionProgress for the consumed qty
        final newPPPayload = pp.toJson();
        newPPPayload['primaryQuantity'] = qty.toDouble();
        final perTube = tray.item.perGarmentTube;
        if (perTube > 0) {
          newPPPayload['secondaryQuantity'] = qty * perTube;
        }

        newPPPayload['batchHeaderId'] = batchHeaderId;
        newPPPayload['transactionType'] = 6; // Issued/WIP
        if (_referenceMinOperationId != null) {
          newPPPayload['operationId'] = _referenceMinOperationId;
        }

        newPPPayload.remove('id');
        newPPPayload.remove('progressCode');
        newPPPayload.remove('creationTime');
        newPPPayload.remove('creatorId');
        newPPPayload.remove('lastModificationTime');
        newPPPayload.remove('lastModifierId');

        dev.log('🚀 Creating new partial ProductionProgress for tray ${tray.primaryTrayModel?.trayCode} with qty: $qty');
        final resNewPP = await _lotRepo.postProductionProgress(newPPPayload);
        if (!resNewPP.success) {
          throw Exception('Failed to create partial production progress: ${resNewPP.message}');
        }

        // Recovery fallback for database ID
        if (resNewPP.data is Map) {
          resolvedProgressId = (resNewPP.data as Map)['id'] ?? 0;
        }
        if (resolvedProgressId == 0) {
          dev.log('⚠️ ProductionProgress ID is 0. Attempting ID recovery...');
          final allProgRes = await _lotRepo.fetchProductionProgress(query: {
            'LocatorId': '3',
            'maxResultCount': '1000',
          });
          if (allProgRes.success && allProgRes.data != null) {
            final List progresses = allProgRes.data as List;
            final matches = progresses.whereType<ProductionProgressResponseModel>().where((p) =>
              p.productionProgress.primaryQuantity == qty &&
              p.productionProgress.primaryTrayId == tray.primaryTrayModel?.id &&
              p.productionProgress.workOrderLineId == (tray.workOrderLine?.id ?? tray.productionProgress.workOrderLineId)
            ).toList();
            if (matches.isNotEmpty) {
              matches.sort((a, b) => (b.productionProgress.id ?? 0).compareTo(a.productionProgress.id ?? 0));
              resolvedProgressId = matches.first.productionProgress.id ?? 0;
            }
          }
        }

        if (resolvedProgressId == 0) {
          throw Exception('Failed to resolve database ID for the new production progress.');
        }
        dev.log('✅ Resolved partial ProductionProgress ID: $resolvedProgressId');

        // 2. Decrease the original ProductionProgress capacity in GBS
        final originalPPPayload = pp.toJson();
        originalPPPayload['primaryQuantity'] = (originalQty - qty).toDouble();
        if (perTube > 0) {
          originalPPPayload['secondaryQuantity'] = (originalQty - qty) * perTube;
        }

        originalPPPayload.remove('id');
        originalPPPayload.remove('progressCode');
        originalPPPayload.remove('creationTime');
        originalPPPayload.remove('creatorId');
        originalPPPayload.remove('lastModificationTime');
        originalPPPayload.remove('lastModifierId');

        dev.log('🚀 Updating original ProductionProgress ${pp.id} capacity to: ${originalQty - qty}');
        final resUpdateOriginalPP = await _lotRepo.updateProductionProgress(pp.id!, originalPPPayload);
        if (!resUpdateOriginalPP.success) {
          dev.log('❌ Failed to update original production progress: ${resUpdateOriginalPP.message}');
        }
      } else {
        // --- FULL CONSUMPTION ---
        final ppPayload = pp.toJson();
        ppPayload['batchHeaderId'] = batchHeaderId;
        ppPayload['transactionType'] = 6; // Issued/WIP
        if (_referenceMinOperationId != null) {
          ppPayload['operationId'] = _referenceMinOperationId;
        }

        ppPayload.remove('id');
        ppPayload.remove('progressCode');
        ppPayload.remove('creationTime');
        ppPayload.remove('creatorId');
        ppPayload.remove('lastModificationTime');
        ppPayload.remove('lastModifierId');

        dev.log('🚀 Updating ProductionProgress for tray ${tray.primaryTrayModel?.trayCode} to Op: $_referenceMinOperationId');
        final resPP = await _lotRepo.updateProductionProgress(pp.id!, ppPayload);
        if (!resPP.success) {
          throw Exception(resPP.message ?? 'Failed to update production progress.');
        }
        resolvedProgressId = pp.id!;
      }

      final perTube = tray.item.perGarmentTube;
      double finalSecondaryQty = 0.0;
      if (isPartial) {
        if (perTube > 0) {
          finalSecondaryQty = qty * perTube;
        } else {
          final originalPPQty = tray.productionProgress.primaryQuantity ?? 1.0;
          final originalSecQty = tray.productionProgress.secondaryQuantity ?? 0.0;
          finalSecondaryQty = originalPPQty > 0 ? (qty * originalSecQty / originalPPQty) : 0.0;
        }
      } else {
        finalSecondaryQty = (tray.productionProgress.secondaryQuantity ?? 0).toDouble();
      }

      // 3. Create the Lot Line
      final linePayload = {
        "planDate": DateTime.now().toIso8601String(),
        "transactionDate": DateTime.now().toIso8601String(),
        "primaryQuantity": qty.toDouble(),
        "primaryUOM": tray.productionProgress.primaryUOM ?? 0,
        "secondaryQuantity": finalSecondaryQty,
        "secondaryUOM": tray.productionProgress.secondaryUOM ?? 0,
        "batchLineCode": "BL-$batchHeaderId-${tray.primaryTrayModel?.id}",
        "active": true,
        "isReAssigned": false,
        "batchHeaderId": batchHeaderId,
        "progressId": resolvedProgressId,
        "workOrderHeaderId": tray.workOrderHeader.id,
        "workOrderLineId":
            tray.workOrderLine?.id ?? tray.productionProgress.workOrderLineId,
        "itemId": tray.item.id,
        "trayId": tray.primaryTrayModel?.id,
        "locatorId": tray.productionProgress.locatorId,
        "processItemId": _trayProcessedItemId[tray.primaryTrayModel?.id],
      };

      dev.log('🚀 POSTing LotLine: $linePayload');
      final resLine = await _lotRepo.createLotLine(linePayload);

      if (resLine.success && resLine.data != null) {
        final lineId = (resLine.data as Map)['id'];
        final int batchLineDbId = int.tryParse(lineId.toString()) ?? 0;

        if (batchLineDbId > 0 && resolvedProgressId > 0) {
          final ppFetchRes = await _lotRepo.fetchProductionProgressById(resolvedProgressId);
          if (ppFetchRes.success && ppFetchRes.data != null) {
            final responseModel = ProductionProgressResponseModel.fromJson(
              Map<String, dynamic>.from(ppFetchRes.data as Map),
            );
            final ppMap = responseModel.productionProgress.toJson();
            ppMap['batchLineId'] = batchLineDbId;
            ppMap.remove('batchLinesId');
            
            // Clean read-only/audit fields
            ppMap.remove('id');
            ppMap.remove('progressCode');
            ppMap.remove('concurrencyStamp');
            ppMap.remove('creationTime');
            ppMap.remove('creatorId');
            ppMap.remove('lastModificationTime');
            ppMap.remove('lastModifierId');

            final resPpLink = await _lotRepo.updateProductionProgress(resolvedProgressId, ppMap);
            if (resPpLink.success) {
              dev.log('🔗 Linked ProductionProgress $resolvedProgressId to BatchLine $batchLineDbId');
            } else {
              dev.log('❌ Failed linking ProductionProgress $resolvedProgressId to BatchLine: ${resPpLink.message}');
            }
          }
        }

        // Only update tray details if physically fully consumed (not partial of the physical tray capacity)
        final double trayCapacity = (tray.primaryTrayModel?.trayQuantity ?? 0).toDouble();
        final bool isPhysicallyFull = qty >= trayCapacity - 0.01;

        if (isPhysicallyFull) {
          final trayId = tray.primaryTrayModel?.id;
          if (trayId != null) {
            final trayData = await _lotRepo.fetchTrayDetailById(trayId);
            if (trayData.success && trayData.data != null) {
              final map = Map<String, dynamic>.from(trayData.data as Map);
              map['batchHeaderId'] = batchHeaderId;
              map['batchLineId'] = batchLineDbId;
              map['trayQuantity'] = qty.toInt();
              await _lotRepo.updateTrayDetails(trayId, map);
            }
          }
        }
      }
    }

    AppLoader.hide(context);
    HapticFeedbackHelper.scanSuccess();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: RawKeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKey: _onKey,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPremiumHeader(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildConfigurationPanel(),
                        const SizedBox(height: 10),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, animation) => FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.05),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            ),
                            child: _selectedColor != null
                                ? Column(
                                    key: const ValueKey('scanning_active'),
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildLiveDashboard(),
                                      const SizedBox(height: 10),
                                      _buildWOSummary(),
                                      const SizedBox(height: 10),
                                      Expanded(
                                        child: _buildScannedSection(),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(key: ValueKey('scanning_idle')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
          border: Border.all(
            color: const Color(0xFFB0BEC5),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
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
                    'Lot Making',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF263238),
                    ),
                  ),
                  const Text(
                    'SCAN TRAYS TO MAKE LOT',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF546E7A),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: (_selectedMachine != null && _scannedTrays.isNotEmpty)
                  ? () {
                      HapticFeedbackHelper.buttonClick();
                      _saveLotChanges();
                    }
                  : null,
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text(
                'SAVE LOT',
              ),
              style: AppTheme.saveButtonStyle(
                isEnabled: (_selectedMachine != null && _scannedTrays.isNotEmpty),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveDashboard() {
    double totalWeightGrams = 0;
    int totalTubes = 0;
    for (int i = 0; i < _scannedTrays.length; i++) {
      final qty = double.tryParse(_quantityControllers[i].text) ?? 0;
      totalTubes += qty.toInt();
      totalWeightGrams += qty * (_scannedTrays[i].item.pieceWeight ?? 0);
    }

    final capacityValue =
        double.tryParse(_selectedMachine?.resource?.capacity ?? '0') ?? 0;
    final allocatedWeightGrams = totalWeightGrams;
    final remainingWeightGrams = capacityValue - allocatedWeightGrams;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.analytics_rounded,
                      size: 16,
                      color: Color(0xFF1B64A3),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'LOT SCAN SUMMARY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B64A3),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildMetricCard(
                      'TRAYS',
                      '${_scannedTrays.length}',
                      Icons.layers_outlined,
                      const Color(0xFFE67E22),
                    ),
                    const SizedBox(width: 6),
                    _buildMetricCard(
                      'TUBES',
                      '$totalTubes',
                      Icons.grid_view_rounded,
                      const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 6),
                    _buildMetricCard(
                      'CAPACITY',
                      '${capacityValue.toStringAsFixed(0)}g',
                      Icons.speed_rounded,
                      const Color(0xFF1B64A3),
                    ),
                    const SizedBox(width: 6),
                    _buildMetricCard(
                      'ALLOC. WEIGHT',
                      '${allocatedWeightGrams.toStringAsFixed(0)}g',
                      Icons.monitor_weight_outlined,
                      const Color(0xFF8E44AD),
                    ),
                    const SizedBox(width: 6),
                    _buildMetricCard(
                      'REM. WEIGHT',
                      '${remainingWeightGrams.toStringAsFixed(0)}g',
                      Icons.hourglass_empty_rounded,
                      const Color(0xFF00796B),
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

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: Color(0xFF78909C),
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAvailableTraysDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogSetState = setDialogState;
            final availableTrays = getTraysForSelectedWorkOrder();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AVAILABLE GBS TRAYS (${availableTrays.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFE67E22),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const TrayTableHeader(actionColumnWidth: 0, showLotColumn: true, showDetailedTubes: true),
                    Expanded(
                      child: availableTrays.isEmpty
                          ? const Center(
                              child: Text(
                                'No available GBS trays for this work order',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: availableTrays.length,
                              itemBuilder: (ctx, index) {
                                final tray = availableTrays[index];
                                final qtys = _getTrayQuantities(tray);
                                final actualVal = qtys['actual']!;
                                final alreadyScannedVal = qtys['alreadyScanned']!;
                                final remainingVal = qtys['remaining']!;
                                final qty = remainingVal;
                                final perTube = tray.item.perGarmentTube;
                                final pcs = qty * perTube;
                                final weight = qty * (tray.item.pieceWeight ?? 0);

                                const cellStyle = TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF263238),
                                );

                                const blueCellStyle = TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B64A3),
                                );

                                final isScanned = _scannedTrays.any(
                                  (st) => st.productionProgress.id == tray.productionProgress.id,
                                );

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.withValues(alpha: 0.1),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: Text(
                                          tray.primaryTrayModel.trayCode ?? 'N/A',
                                          textAlign: TextAlign.center,
                                          style: blueCellStyle,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          tray.workOrderHeader.workOrderCode ?? 'N/A',
                                          textAlign: TextAlign.center,
                                          style: cellStyle,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          tray.item.sizeDescription ?? 'N/A',
                                          textAlign: TextAlign.center,
                                          style: cellStyle,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          perTube.toStringAsFixed(0),
                                          textAlign: TextAlign.center,
                                          style: cellStyle,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          actualVal.toStringAsFixed(0),
                                          textAlign: TextAlign.center,
                                          style: cellStyle,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          alreadyScannedVal.toStringAsFixed(0),
                                          textAlign: TextAlign.center,
                                          style: cellStyle.copyWith(color: Colors.orange.shade800),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          remainingVal.toStringAsFixed(0),
                                          textAlign: TextAlign.center,
                                          style: cellStyle.copyWith(color: const Color(0xFF2E7D32)),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          pcs.toStringAsFixed(0),
                                          textAlign: TextAlign.center,
                                          style: cellStyle,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          '${weight.toStringAsFixed(0)}g',
                                          textAlign: TextAlign.center,
                                          style: cellStyle,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 6,
                                        child: Text(
                                          isScanned ? _lotCode : '-',
                                          textAlign: TextAlign.center,
                                          style: cellStyle.copyWith(
                                            color: isScanned ? const Color(0xFF2E7D32) : Colors.grey,
                                            fontWeight: isScanned ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      /*
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 52,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1B64A3),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 30),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            elevation: 0,
                                          ),
                                          onPressed: () async {
                                            if (tray.primaryTrayModel.trayCode != null) {
                                              AppLoader.show(context, message: 'Validating Tray...');
                                              final error = await _validateTrayForScan(tray.primaryTrayModel.trayCode!);
                                              AppLoader.hide(context);
                                              if (error != null) {
                                                HapticFeedbackHelper.scanError();
                                                AppSnackBar.showError(context, message: error);
                                              } else {
                                                setDialogState(() {});
                                                setState(() {});
                                              }
                                            }
                                          },
                                          child: const Text(
                                            'ADD',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                      ),
                                      */
                                    ],
                                  ),
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
      _dialogSetState = null;
    });
  }

  Widget _buildConfigurationPanel() {
    final availableWOs = getFilteredWorkOrders();
    final availableColors = getFilteredColors();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: Color(0xFF1B64A3),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'LOT CONFIGURATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B64A3),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    if (_isCachingColors)
                      const SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B64A3)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Machine Dropdown
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MACHINE',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF78909C),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _LotOverlayDropdown<LotMachineModel>(
                                hint: "Select machine...",
                                items: _machines,
                                selectedValue: _selectedMachine,
                                itemLabel: (m) => m.resource?.brand ?? 'Unknown',
                                isReadOnly: _scannedTrays.isNotEmpty,
                                onChanged: (val) {
                                  HapticFeedbackHelper.buttonClick();
                                  setState(() {
                                    _selectedMachine = val;
                                    _selectedWorkOrder = null;
                                    _selectedColor = null;
                                    _selectedTray = null;
                                  });
                                  if (val != null) _fetchColors();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Work Order Dropdown
                        Expanded(
                          child: _selectedMachine == null
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'WORK ORDER',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF78909C),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _LotOverlayDropdown<WorkOrderHeader>(
                                      hint: "Select work order...",
                                      items: availableWOs,
                                      selectedValue: _selectedWorkOrder,
                                      itemLabel: (wo) => wo.workOrderCode ?? '-',
                                      isReadOnly: false, // NOT disabled when trays are scanned
                                      onChanged: (val) {
                                        HapticFeedbackHelper.buttonClick();
                                        setState(() {
                                          _selectedWorkOrder = val;
                                          _selectedTray = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                    if (_selectedWorkOrder != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Color Dropdown
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'COLOR',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF78909C),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _LotOverlayDropdown<LotColorModel>(
                                  hint: "Select color...",
                                  items: availableColors,
                                  selectedValue: _selectedColor,
                                  itemLabel: (c) => c.segmentCode?.description ?? '-',
                                  isReadOnly: _scannedTrays.isNotEmpty,
                                  onChanged: (val) {
                                    HapticFeedbackHelper.buttonClick();
                                    setState(() => _selectedColor = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Show Available Trays Button (Visible only after color is selected)
                          Expanded(
                            child: _selectedColor == null
                                ? const SizedBox.shrink()
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 14), // Align with dropdown label height
                                      SizedBox(
                                        width: double.infinity,
                                        height: 44, // Align with dropdown height
                                        child: ElevatedButton.icon(
                                          onPressed: _showAvailableTraysDialog,
                                          icon: const Icon(Icons.layers_outlined, size: 16),
                                          label: const Text(
                                            'SHOW AVAILABLE TRAYS',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
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
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildScannedSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFFE67E22),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'SCANNED TRAYS LIST',
                        style: TextStyle(
                          color: Color(0xFF263238),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      '${_scannedTrays.length} Trays',
                      style: const TextStyle(
                        color: Color(0xFF546E7A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedbackHelper.buttonClick();
                            _onScanTray();
                          },
                          icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 20,
                          ),
                          label: const Text(
                            'SCAN TRAY',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildCapacityProgress(),
                      const SizedBox(height: 10),
                      const TrayTableHeader(actionColumnWidth: 44, showBatchTubes: true, showDetailedTubes: true),
                      Expanded(
                        child: _scannedTrays.isEmpty
                            ? const EmptyScanState(hasBorder: false)
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: _scannedTrays.length,
                                itemBuilder: (ctx, idx) => _buildTrayRow(idx),
                              ),
                      ),
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

  Widget _buildCapacityProgress() {
    final capacityValue =
        double.tryParse(_selectedMachine?.resource?.capacity ?? '0') ?? 0;

    double allocatedWeightGrams = 0;
    for (int i = 0; i < _scannedTrays.length; i++) {
      final tray = _scannedTrays[i];
      final qty = double.tryParse(_quantityControllers[i].text) ?? 0;
      allocatedWeightGrams += qty * (tray.item.pieceWeight ?? 0);
    }

    final progress =
        capacityValue > 0 ? (allocatedWeightGrams / capacityValue) : 0.0;
    final percentage = (progress * 100).clamp(0, 100).toInt();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MACHINE LOAD / CAPACITY',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF546E7A),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: progress > 0.9 ? Colors.red : const Color(0xFF1B64A3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress > 0.9
                  ? Colors.red
                  : (progress > 0.7 ? Colors.orange : const Color(0xFF2E7D32)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrayRow(int index) {
    final tray = _scannedTrays[index];
    final qtys = _getTrayQuantities(tray);
    final actualVal = qtys['actual']!;
    final alreadyScannedVal = qtys['alreadyScanned']!;
    final remainingVal = qtys['remaining']!;
    final qty = double.tryParse(_quantityControllers[index].text) ?? 0;
    final perTube = tray.item.perGarmentTube;
    final pcs = qty * perTube;
    final weight = qty * (tray.item.pieceWeight ?? 0);

    const cellStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Color(0xFF263238),
    );

    const blueCellStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1B64A3),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Text(
              tray.primaryTrayModel.trayCode ?? 'N/A',
              textAlign: TextAlign.center,
              style: blueCellStyle,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              tray.workOrderHeader.workOrderCode ?? 'N/A',
              textAlign: TextAlign.center,
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              tray.item.sizeDescription ?? 'N/A',
              textAlign: TextAlign.center,
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              perTube.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              actualVal.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              alreadyScannedVal.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: cellStyle.copyWith(color: Colors.orange.shade800),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              remainingVal.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: cellStyle.copyWith(color: const Color(0xFF2E7D32)),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              pcs.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '${weight.toStringAsFixed(0)}g',
              textAlign: TextAlign.center,
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCFD8DC), width: 1.2),
              ),
              child: TextField(
                controller: _quantityControllers[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: cellStyle.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF1B64A3)),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                  isCollapsed: true,
                  border: InputBorder.none,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TubesInputFormatter(remainingVal.toInt()),
                ],
                onChanged: (val) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
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
                  setState(() {
                    _scannedTrays.removeAt(index);
                    _quantityControllers.removeAt(index);
                  });
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red.shade400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWOSummary() {
    if (_selectedColor == null || _selectedWorkOrder == null) {
      return const SizedBox.shrink();
    }

    final selectedColorDesc = _selectedColor?.segmentCode?.description?.trim().toUpperCase();
    if (selectedColorDesc == null) return const SizedBox.shrink();

    final allEligibleTrays = getTraysForSelectedWorkOrderAndColor();
    final Map<String, Map<String, dynamic>> woGroups = {};

    // 1. Initialize all groups from all eligible trays for this work order & color
    for (final tray in allEligibleTrays) {
      final code = tray.workOrderHeader.workOrderCode ?? 'Unknown WO';
      final itemDesc = tray.item.description ?? 'N/A';
      final sizeDesc = tray.item.sizeDescription ?? 'N/A';
      final lineId = tray.productionProgress.workOrderLineId ?? tray.workOrderLine?.id;
      final groupKey = "${code}_${itemDesc}_${sizeDesc}";

      if (!woGroups.containsKey(groupKey)) {
        double planQty = 0.0;
        if (lineId != null) {
          planQty = _colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
        }
        woGroups[groupKey] = {
          'code': code,
          'item': itemDesc,
          'size': sizeDesc,
          'trays': 0,
          'tubes': 0.0,
          'weight': 0.0,
          'planQty': planQty,
          'lineId': lineId,
        };
      }
    }

    // 2. Accumulate scanned counts
    for (int i = 0; i < _scannedTrays.length; i++) {
      final tray = _scannedTrays[i];
      final qty = double.tryParse(_quantityControllers[i].text) ?? 0;
      final code = tray.workOrderHeader.workOrderCode ?? 'Unknown WO';
      final itemDesc = tray.item.description ?? 'N/A';
      final sizeDesc = tray.item.sizeDescription ?? 'N/A';
      final lineId = tray.productionProgress.workOrderLineId ?? tray.workOrderLine?.id;
      final groupKey = "${code}_${itemDesc}_${sizeDesc}";

      final weight = qty * (tray.item.pieceWeight ?? 0);

      if (!woGroups.containsKey(groupKey)) {
        double planQty = 0.0;
        if (lineId != null) {
          planQty = _colorPlanQuantities["${lineId}_$selectedColorDesc"] ?? 0.0;
        }
        woGroups[groupKey] = {
          'code': code,
          'item': itemDesc,
          'size': sizeDesc,
          'trays': 0,
          'tubes': 0.0,
          'weight': 0.0,
          'planQty': planQty,
          'lineId': lineId,
        };
      }

      woGroups[groupKey]!['trays'] = (woGroups[groupKey]!['trays'] as int) + 1;
      woGroups[groupKey]!['tubes'] = (woGroups[groupKey]!['tubes'] as double) + qty;
      woGroups[groupKey]!['weight'] = (woGroups[groupKey]!['weight'] as double) + weight;
    }

    if (woGroups.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.summarize_rounded,
                        size: 16, color: Color(0xFF1B64A3)),
                    SizedBox(width: 8),
                    Text(
                      'WORK ORDER SUMMARY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B64A3),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(0),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.5), // WO
                    1: FlexColumnWidth(1.8), // Size
                    2: FlexColumnWidth(3.8), // Item
                    3: FlexColumnWidth(1.5), // Trays
                    4: FlexColumnWidth(2.6), // Tubes / Plan Limit (Max Allowed)
                    5: FlexColumnWidth(1.8), // Weight
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                      children: [
                        _buildTableHeaderCell('WO CODE'),
                        _buildTableHeaderCell('SIZE'),
                        _buildTableHeaderCell('ITEM'),
                        _buildTableHeaderCell('TRAYS'),
                        _buildTableHeaderCell('TUBES / PLAN'),
                        _buildTableHeaderCell('WEIGHT'),
                      ],
                    ),
                    ...woGroups.values.map((data) {
                      final planVal = data['planQty'] as double;
                      final planStr = planVal > 0.0 ? planVal.toStringAsFixed(0) : '-';
                      final int extraAllowed = (planVal * 0.1).ceil();
                      final double maxAllowed = planVal + extraAllowed;
                      final maxStr = planVal > 0.0 ? " (Max ${maxAllowed.toStringAsFixed(0)})" : "";

                      final lineId = data['lineId'] as int?;
                      final double assigned = lineId != null ? _getAlreadyAssignedTubesForWorkOrderLine(lineId) : 0.0;
                      final currentTubes = data['tubes'] as double;
                      final totalTubes = currentTubes + assigned;

                      final displayTubes = assigned > 0.0
                          ? "${currentTubes.toStringAsFixed(0)} (Total: ${totalTubes.toStringAsFixed(0)})"
                          : currentTubes.toStringAsFixed(0);

                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom:
                                BorderSide(color: Color(0xFFECEFF1), width: 1),
                          ),
                        ),
                        children: [
                          _buildTableCell(data['code'].toString(),
                              isBold: true),
                          _buildTableCell(data['size'].toString()),
                          _buildTableCell(data['item'].toString()),
                          _buildTableCell(data['trays'].toString()),
                          _buildTableCell(
                              "$displayTubes / $planStr$maxStr"),
                          _buildTableCell(
                              "${(data['weight'] as double).toStringAsFixed(0)}g"),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: Color(0xFF546E7A),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          color: const Color(0xFF263238),
        ),
      ),
    );
  }
}

class _LotOverlayDropdown<T> extends StatefulWidget {
  final String hint;
  final List<T> items;
  final T? selectedValue;
  final String Function(T) itemLabel;
  final String Function(T)? itemLabelInList;
  final ValueChanged<T?> onChanged;
  final bool isReadOnly;

  const _LotOverlayDropdown({
    required this.hint,
    required this.items,
    required this.selectedValue,
    required this.itemLabel,
    this.itemLabelInList,
    required this.onChanged,
    this.isReadOnly = false,
  });

  @override
  State<_LotOverlayDropdown<T>> createState() => _LotOverlayDropdownState<T>();
}

class _LotOverlayDropdownState<T> extends State<_LotOverlayDropdown<T>> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _rotateAnimation;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _overlayEntry?.remove();
    _controller.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (widget.isReadOnly) return;
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
      _controller.forward();
    });
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isOpen = false;
      _searchQuery = '';
      _searchController.clear();
      _controller.reverse();
    });
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeDropdown,
              child: Container(),
            ),
          ),
          Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: Material(
                elevation: 0,
                color: Colors.transparent,
                child: _buildDropdownMenu(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Opacity(
        opacity: widget.isReadOnly ? 0.6 : 1.0,
        child: GestureDetector(
          onTap: _toggleDropdown,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white, // Matching PO style drop down style
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isOpen ? const Color(0xFF1B64A3) : const Color(0xFFCFD8DC),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: widget.selectedValue == null
                      ? Text(widget.hint, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w400))
                      : Text(widget.itemLabel(widget.selectedValue as T), style: const TextStyle(color: Color(0xFF263238), fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                RotationTransition(
                  turns: _rotateAnimation,
                  child: Icon(Icons.arrow_drop_down_rounded, color: _isOpen ? const Color(0xFF1B64A3) : const Color(0xFF546E7A), size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownMenu() {
    final filteredItems = widget.items.where((item) {
      final label = (widget.itemLabelInList != null
              ? widget.itemLabelInList!(item)
              : widget.itemLabel(item))
          .toLowerCase();
      final query = _searchQuery.toLowerCase();
      return label.contains(query);
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: const Color(0xFFCFD8DC), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
                _overlayEntry?.markNeedsBuild();
              },
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              decoration: InputDecoration(
                hintText: "Search...",
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1B64A3)),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFCFD8DC)),
          Flexible(
            child: filteredItems.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No results found',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: filteredItems.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected = item == widget.selectedValue;

                      return InkWell(
                        onTap: () {
                          widget.onChanged(item);
                          _closeDropdown();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.itemLabelInList != null
                                      ? widget.itemLabelInList!(item)
                                      : widget.itemLabel(item),
                                  style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF1B64A3)
                                          : const Color(0xFF263238),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (isSelected) const Icon(Icons.check_rounded, color: Color(0xFF1B64A3), size: 16),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class TubesInputFormatter extends TextInputFormatter {
  final int maxTubes;

  TubesInputFormatter(this.maxTubes);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final parsed = int.tryParse(newValue.text);
    if (parsed == null) {
      return oldValue;
    }

    // Non-zero constraint: do not allow single 0 or starting with 0
    if (parsed == 0 || newValue.text.startsWith('0')) {
      return oldValue;
    }

    // Max constraint
    if (parsed > maxTubes) {
      return oldValue;
    }

    return newValue;
  }
}

