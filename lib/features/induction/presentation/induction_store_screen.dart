import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/utils/barcode_buffer_parser.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/empty_scan_state.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/features/gbs/model/gbs_scanned_tray.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/induction/model/induction_model.dart';
import 'package:active_wear_scanning/features/induction/repo/induction_repo.dart';
import 'package:active_wear_scanning/features/induction/presentation/widgets/induction_tray_row.dart';
import 'package:active_wear_scanning/features/induction/presentation/widgets/induction_tray_table_header.dart';
import 'package:flutter/material.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';

import '../../common-models/common_models.dart';

class InductionStoreScreen extends StatefulWidget {
  const InductionStoreScreen({super.key});

  @override
  State<InductionStoreScreen> createState() => _InductionStoreScreenState();
}

class _InductionStoreScreenState extends State<InductionStoreScreen> {
  final List<GBSScannedTray> _scannedTrays = [];
  final _inductionRepo = fromPlex<InductionRepo>();
  List<InductionModel> _availableTrays = [];
  WorkOrderHeader? _selectedWorkOrder;

  static const _inputAndButtonHeight = 42.0;
  static final _labelStyle = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );
  static final _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );

  // Centralized Bluetooth Scanner Support
  final _barcodeParser = BarcodeBufferParser();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onInitialDataFetch();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    return _barcodeParser.handleKey(event, _processBluetoothScan);
  }

  Future<void> _processBluetoothScan(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return;

    final error = await _validateTrayForInduction(code);
    if (error != null && mounted) {
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: error);
    } else {
      setState(() {});
    }
  }

  Future<void> _onInitialDataFetch() async {
    AppLoader.show(context);
    await _fetchAvailableTrays();
    AppLoader.hide(context);
  }

  Future<void> _fetchAvailableTrays() async {
    final res = await _inductionRepo.getProductionProgress();
    if (mounted && res.success && res.data != null) {
      setState(() {
        final allTrays = res.data as List<InductionModel>;
        _availableTrays = allTrays.where((t) => t.productionProgress.locatorId != 11).toList();
      });
      debugPrint(
        "🔍 Induction: Found ${_availableTrays.length} matching trays.",
      );
    }
  }

  Future<void> _onScanTray() async {
    await _fetchAvailableTrays();
    if (!mounted) return;

    await ScannerAlwaysOpen.show(
      context,
      title: 'Induction Store Scan',
      onResult: (scannedCode) {
        return _validateTrayForInduction(scannedCode);
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
                  const InductionTrayTableHeader(),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _scannedTrays.length,
                      itemBuilder: (context, index) {
                        return InductionTrayRow(
                          index: index,
                          tray: _scannedTrays[index],
                          displayIndex: index,
                          onRemove: () {
                            setState(() {
                              _scannedTrays.removeAt(index);
                            });
                            setSubState(() {});
                          },
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
    setState(() {});
  }

  Future<String?> _validateTrayForInduction(String scannedCode) async {
    final code = scannedCode.trim().toLowerCase();
    if (code.isEmpty) return 'Invalid tray code';

    final alreadyScanned = _scannedTrays.any(
      (t) => t.trayCode.trim().toLowerCase() == code,
    );
    if (alreadyScanned) return 'Already scanned';

    final matchIndex = _availableTrays.indexWhere((t) {
      final tCode = (t.primaryTrayModel.trayCode ?? '').trim().toLowerCase();
      final pCode = (t.productionProgress.progressCode ?? '')
          .trim()
          .toLowerCase();
      return tCode == code || pCode == code;
    });

    if (matchIndex == -1) {
      return 'Tray not eligible for Induction';
    }

    final match = _availableTrays[matchIndex];

    if ((match.primaryTrayModel.trayType ?? 0) != 1) {
      return 'Invalid tray type.';
    }

    int targetItemId = match.productionProgress.processedItemId ?? match.item.id;
    String colorDesc = match.item.colorDescription ?? '';
    String sizeDesc = match.item.sizeDescription ?? '';

    if (targetItemId > 0) {
      AppLoader.show(context, message: "Fetching item details...");
      final itemRes = await _inductionRepo.fetchItemDef(targetItemId);
      AppLoader.hide(context);
      
      if (itemRes.success && itemRes.data != null) {
        final itemData = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
        if (itemData['colorDescription'] != null) colorDesc = itemData['colorDescription'];
        if (itemData['sizeDescription'] != null) sizeDesc = itemData['sizeDescription'];
      }
    }

    setState(() {
      _scannedTrays.add(
        GBSScannedTray(
          trayCode: match.primaryTrayModel.trayCode ?? '-',
          workOrderCode: match.workOrderHeader.workOrderCode ?? '-', // ✅ Added
          itemDescription: match.item.description ?? '-',
          sizeDescription: sizeDesc,
          colorDescription: colorDesc,
          primaryQuantity: (match.productionProgress.primaryQuantity ?? 0).toStringAsFixed(0),
          pieceWeight: match.item.pieceWeight ?? 0.0,
          trayUpdateId: match.primaryTrayModel.id,
          trayConcurrencyStamp: match.primaryTrayModel.concurrencyStamp,
        ),
      );
    });
    HapticFeedbackHelper.scanSuccess();
    return null;
  }

  void _onRemoveTray(int index) {
    setState(() => _scannedTrays.removeAt(index));
  }

  Future<void> _onSave() async {
    if (_scannedTrays.isEmpty) return;

    AppLoader.show(context, message: 'Saving Induction Data...');
    bool isAllSuccess = true;

    try {
      for (var scannedTray in _scannedTrays) {
        // Correct lookup pattern as per GBS module
        final currentTrayMatch = _availableTrays
            .where((t) => t.primaryTrayModel.id == scannedTray.trayUpdateId)
            .firstOrNull;

        if (currentTrayMatch == null) continue;

        final currentTrayData = currentTrayMatch;

        // 1. Post WIP Transaction as per requirement
        Map<String, dynamic> wipPayload = {
          "subOperation": "Induction Store",
          "transactionDate": DateTime.now().toIso8601String(),
          "transactionType": 1,
          "uom": currentTrayData.workOrderLine.uom ?? 0,
          "operatorDescription": "system",
          "primaryQuantity":
              currentTrayData.productionProgress.primaryQuantity ?? 0,
          "secondaryQuantity":
              currentTrayData.productionProgress.secondaryQuantity ?? 0,
          "primaryUOM": currentTrayData.productionProgress.primaryUOM ?? 0,
          "secondaryUOM": currentTrayData.productionProgress.secondaryUOM ?? 0,
          "code": currentTrayData.item.code ?? "",
          "productGrade": currentTrayData.productionProgress.productGrade ?? 0,
          "productNature":
              currentTrayData.productionProgress.productNature ?? 0,
          "progressId": currentTrayData.productionProgress.id,
          "operationId": currentTrayData.productionProgress.operationId,
          "workOrderHeaderId": currentTrayData.workOrderHeader.id,
          "workOrderLineId": currentTrayData.workOrderLine.id,
          "itemId": currentTrayData.item.id,
          "shiftId": currentTrayData.shift.id,
          "primaryTrayId": currentTrayData.primaryTrayModel.id,
          "machineId": currentTrayData.machineModel.id,
          "planHeaderId":
              currentTrayData.productionProgress.planHeaderId ??
              currentTrayData.planHeader?.id,
          "locatorId": 11,
          "batchHeaderId": currentTrayData
              .productionProgress
              .batchHeaderId, // Sourced from progress
          "batchLineId": currentTrayData
              .productionProgress
              .batchLinesId, // Sourced from progress
          "processitemd":
              currentTrayData.productionProgress.processedItemId ??
              currentTrayData.item.id, // Renamed to processitemd
        };

        await _inductionRepo.postWipTransactions(wipPayload);

        // 2. Update Production Progress
        Map<String, dynamic> updatePayload = currentTrayData.productionProgress
            .toJson();
        updatePayload['pbsFlag'] = true; // Mark as inducted
        updatePayload['pBSFlag'] = true; // Added to ensure ABP picks it up if case-sensitive
        updatePayload['locatorId'] = 11; // Sync locator
        updatePayload['date'] = DateTime.now().toIso8601String();

        final res = await _inductionRepo.updateProductionProgress(
          currentTrayData.productionProgress.id!,
          updatePayload,
        );

        if (!res.success)
          throw Exception('Failed to update tray ${scannedTray.trayCode}');

        // 3. Update Tray Details API
        final trayRes = await _inductionRepo.fetchTrayDetailById(currentTrayData.primaryTrayModel.id!);
        if (trayRes.success) {
          final tData = trayRes.data.containsKey('trayDetail') ? trayRes.data['trayDetail'] : trayRes.data;
          Map<String, dynamic> trayUpd = Map<String, dynamic>.from(tData);
          trayUpd["locatorId"] = 11; // Update locator for Induction Store
          // Remove audit fields if they cause PUT issues
          trayUpd.removeWhere((key, value) => ["creatorId", "creationTime", "lastModifierId", "lastModificationTime"].contains(key));
          
          await _inductionRepo.updateTrayDetails(currentTrayData.primaryTrayModel.id!, trayUpd);
        }
      }
    } catch (e) {
      isAllSuccess = false;
      debugPrint("❌ Induction Save Error: $e");
    } finally {
      AppLoader.hide(context);
      if (mounted) {
        if (isAllSuccess) {
          HapticFeedbackHelper.scanSuccess();
          AppSnackBar.showSuccess(context, message: 'Induction saved successfully');
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        } else {
          HapticFeedbackHelper.scanError();
          AppSnackBar.showError(context, message: 'Failed to save some trays');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Slate background
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPremiumHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Container(
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
                    child: _buildScannedQueue(),
                  ),
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
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Induction Store',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'INVENTORY MANAGEMENT CONSOLE',
                    style: TextStyle(fontSize: 9, color: Color(0xFF546E7A), fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _scannedTrays.isEmpty
                  ? null
                  : () {
                      HapticFeedbackHelper.buttonClick();
                      _onSave();
                    },
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE CHANGES'),
              style: AppTheme.saveButtonStyle(isEnabled: _scannedTrays.isNotEmpty),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationPanel() {
    final Map<int, WorkOrderHeader> uniqueWOs = {};
    for (final tray in _availableTrays) {
      if (tray.workOrderHeader != null && tray.workOrderHeader.id != null) {
        uniqueWOs[tray.workOrderHeader.id!] = tray.workOrderHeader;
      }
    }
    final List<WorkOrderHeader> availableWOs = uniqueWOs.values.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFCFD8DC), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                _InductionOverlayDropdown<WorkOrderHeader>(
                  hint: "Select work order...",
                  items: availableWOs,
                  selectedValue: _selectedWorkOrder,
                  itemLabel: (wo) => wo.workOrderCode ?? '-',
                  onChanged: (val) {
                    setState(() {
                      _selectedWorkOrder = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _selectedWorkOrder == null
                    ? null
                    : _showAvailableTraysDialog,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAvailableTraysDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final availableTrays = _availableTrays
                .where((t) => t.workOrderHeader?.id == _selectedWorkOrder?.id)
                .toList();

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
                          'AVAILABLE TRAYS (${availableTrays.length})',
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
                    const InductionTrayTableHeader(),
                    Expanded(
                      child: availableTrays.isEmpty
                          ? const Center(
                              child: Text(
                                'No available trays for this work order',
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
                                final qty = tray.productionProgress.primaryQuantity ?? 0.0;
                                final weight = qty * (tray.item.pieceWeight ?? 0);

                                const cellStyle = TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                );

                                const blueCellStyle = TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D47A1),
                                );

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                        flex: 2,
                                        child: Text(
                                          tray.primaryTrayModel.trayCode ?? 'N/A',
                                          style: blueCellStyle,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          tray.workOrderHeader.workOrderCode ?? 'N/A',
                                          style: cellStyle,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          tray.item.description ?? 'N/A',
                                          style: cellStyle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          tray.item.sizeDescription ?? 'N/A',
                                          textAlign: TextAlign.center,
                                          style: cellStyle,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          qty.toStringAsFixed(0),
                                          textAlign: TextAlign.center,
                                          style: cellStyle,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${weight.toStringAsFixed(1)} g',
                                          textAlign: TextAlign.center,
                                          style: cellStyle,
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScannedQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildConfigurationPanel(),
        // ── Toolbar ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INDUCTION QUEUE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5),
                  ),
                  Text(
                    '${_scannedTrays.length} Trays Ready for Store',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF78909C)),
                  ),
                ],
              ),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _onScanTray,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('SCAN TRAY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // ── Fixed Header ─────────────────────────────────────────────
        const InductionTrayTableHeader(),
        Expanded(
          child: _scannedTrays.isEmpty
              ? const EmptyScanState(hasBorder: false)
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _scannedTrays.length,
                  itemBuilder: (context, index) {
                    final reversedIndex = _scannedTrays.length - 1 - index;
                    return InductionTrayRow(
                      index: reversedIndex,
                      tray: _scannedTrays[reversedIndex],
                      displayIndex: index,
                      onRemove: () => _onRemoveTray(reversedIndex),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Removed _buildTrayTableHeader and _buildTrayRow as they were extracted.
}

class _InductionOverlayDropdown<T> extends StatefulWidget {
  final String hint;
  final List<T> items;
  final T? selectedValue;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _InductionOverlayDropdown({
    required this.hint,
    required this.items,
    required this.selectedValue,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  State<_InductionOverlayDropdown<T>> createState() => _InductionOverlayDropdownState<T>();
}

class _InductionOverlayDropdownState<T> extends State<_InductionOverlayDropdown<T>> with SingleTickerProviderStateMixin {
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
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
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
    );
  }

  Widget _buildDropdownMenu() {
    final filteredItems = widget.items.where((item) {
      final label = widget.itemLabel(item).toLowerCase();
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
                                  widget.itemLabel(item),
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
