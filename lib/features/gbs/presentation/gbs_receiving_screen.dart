import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/utils/barcode_buffer_parser.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/tray_table_header.dart';
import 'package:active_wear_scanning/core/widgets/empty_scan_state.dart';
import 'package:active_wear_scanning/core/widgets/work_order_metrics_row.dart';
import 'package:active_wear_scanning/features/gbs/presentation/widgets/gbs_tray_row.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/features/gbs/controller/gbs_controller.dart';
import 'package:active_wear_scanning/features/gbs/model/gbs_state.dart';
import '../../../core/widgets/scanner_always_open.dart';
import '../../common-models/common_models.dart';

class GBSReceivingScreen extends StatelessWidget {
  const GBSReceivingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GbsController>(
      create: (_) => GbsController(),
      child: const _GBSReceivingScreenView(),
    );
  }
}

class _GBSReceivingScreenView extends StatefulWidget {
  const _GBSReceivingScreenView();

  @override
  State<_GBSReceivingScreenView> createState() => _GBSReceivingScreenViewState();
}

class _GBSReceivingScreenViewState extends State<_GBSReceivingScreenView> {
  final _barcodeParser = BarcodeBufferParser();

  bool _isScannerOpen = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (_isScannerOpen) return false;
    return _barcodeParser.handleKey(event, _processBluetoothScan);
  }

  Future<void> _processBluetoothScan(String scannedCode) async {
    final controller = context.read<GbsController>();
    final error = await controller.validateTrayForReceiving(scannedCode);
    if (error != null && mounted) {
      _showError(error);
    } else {
      HapticFeedbackHelper.scanSuccess();
    }
  }

  Future<void> _onScanTray(GbsController controller, GbsState state) async {
    controller.fetchLatestTraysSilently();
    setState(() => _isScannerOpen = true);
    await ScannerAlwaysOpen.show(
      context,
      title: 'GBS Tray Receiving',
      onResult: (scannedCode) {
        return controller.validateTrayForReceiving(scannedCode);
      },
      scannedItemsBuilder: (context) {
        return ChangeNotifierProvider<GbsController>.value(
          value: controller,
          child: Consumer<GbsController>(
            builder: (context, latestController, __) {
              final latestState = latestController.state;
              if (latestState.scannedTrays.isEmpty) {
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
                    const TrayTableHeader(actionColumnWidth: 44, showItemDescriptionColumn: true),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: latestState.scannedTrays.length,
                        itemBuilder: (context, index) {
                          final reversedIndex = latestState.scannedTrays.length - 1 - index;
                          return GBSTrayRow(
                            index: reversedIndex,
                            tray: latestState.scannedTrays[reversedIndex],
                            onRemove: () async {
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
                                latestController.removeScannedTray(reversedIndex);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    if (mounted) {
      setState(() => _isScannerOpen = false);
    }
  }

  bool _isSaveEnabled(GbsState state) {
    return state.scannedTrays.isNotEmpty;
  }

  Future<void> _onSave(GbsController controller, GbsState state) async {
    HapticFeedbackHelper.buttonClick();
    AppLoader.show(context, message: 'Saving GBS WIP Data...');
    try {
      await controller.saveWipTransactionsAndUpdateTray();
      if (!mounted) return;
      AppLoader.hide(context);
      HapticFeedbackHelper.scanSuccess();
      AppSnackBar.showSuccess(context, message: 'Saved successfully');
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      if (!mounted) return;
      AppLoader.hide(context);
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedbackHelper.scanError();
    AppSnackBar.showError(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GbsController>();
    final state = controller.state;

    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _buildPremiumHeader(controller, state),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: _buildScannedTraysSection(controller, state),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(GbsController controller, GbsState state) {
    final enabled = _isSaveEnabled(state);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const CustomBackButton(),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GBS Receiving', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238))),
                  Text('Receive Knitting Production in GBS', style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: !enabled ? null : () => _onSave(controller, state),
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE CHANGES'),
              style: AppTheme.saveButtonStyle(isEnabled: enabled),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationPanel(GbsController controller, GbsState state) {
    final unfiltered = controller.getUnfilteredTraysForReceiving();
    final Map<int, WorkOrderHeader> uniqueWOs = {};
    for (final tray in unfiltered) {
      uniqueWOs[tray.workOrderHeader.id] = tray.workOrderHeader;
    }
    final List<WorkOrderHeader> availableWOs = uniqueWOs.values.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFCFD8DC), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('WORK ORDER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF78909C), letterSpacing: 0.5)),
                const SizedBox(height: 6),
                _GbsOverlayDropdown<WorkOrderHeader>(
                  hint: "Select work order...",
                  items: availableWOs,
                  selectedValue: state.selectedWorkOrder,
                  itemLabel: (wo) => wo.description.isNotEmpty ? wo.description : (wo.workOrderCode.isNotEmpty ? wo.workOrderCode : 'WO #${wo.id}'),
                  onChanged: (val) {
                    controller.selectWorkOrder(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: state.selectedWorkOrder == null ? null : () => _showAvailableTraysDialog(controller, state),
              icon: const Icon(Icons.layers_outlined, size: 16),
              label: const Text('SHOW TRAYS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE67E22),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade500,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAvailableTraysDialog(GbsController controller, GbsState state) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final availableTrays = controller.getFilteredTrays()
                .where((t) => t.workOrderHeader.id == state.selectedWorkOrder?.id)
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFE67E22)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const TrayTableHeader(actionColumnWidth: 0, showItemDescriptionColumn: true, fontSize: 9.0),
                    Expanded(
                      child: availableTrays.isEmpty
                          ? const Center(
                              child: Text(
                                'No available trays for this work order',
                                style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                              ),
                            )
                          : ListView.builder(
                              itemCount: availableTrays.length,
                              itemBuilder: (ctx, index) {
                                final tray = availableTrays[index];
                                final qty = tray.productionProgress.primaryQuantity ?? 0.0;
                                final weight = qty * (tray.item.pieceWeight ?? 0);

                                const cellStyle = TextStyle(fontSize: 9.0, fontWeight: FontWeight.w600, color: Color(0xFF263238));
                                const blueCellStyle = TextStyle(fontSize: 9.0, fontWeight: FontWeight.w700, color: Color(0xFF1B64A3));

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
                                    border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 5, child: Text(tray.primaryTrayModel.trayCode ?? 'N/A', textAlign: TextAlign.center, style: blueCellStyle)),
                                      Expanded(flex: 16, child: Text(tray.item.description, maxLines: 1, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: cellStyle)),
                                      Expanded(flex: 3, child: Text(tray.item.sizeDescription ?? 'N/A', textAlign: TextAlign.center, style: cellStyle)),
                                      Expanded(flex: 4, child: Text(qty.toStringAsFixed(0), textAlign: TextAlign.center, style: cellStyle)),
                                      Expanded(flex: 4, child: Text('${weight.toStringAsFixed(0)}g', textAlign: TextAlign.center, style: cellStyle)),
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

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return '---';
    return rawDate.split('T')[0].split(' ')[0];
  }

  String _getFabricationType(GbsState state) {
    if (state.selectedWorkOrder == null) return '---';
    final matches = state.availableTrayForGbs
        .where((t) => t.workOrderHeader.id == state.selectedWorkOrder!.id);
    if (matches.isNotEmpty) {
      final fab = matches.first.item.garmentFabricationType;
      if (fab != null && fab.trim().isNotEmpty) return fab.trim();
    }
    return '---';
  }

  String _getScannedTubes(GbsState state) {
    double totalTubes = 0;
    for (final tray in state.scannedTrays) {
      totalTubes += double.tryParse(tray.primaryQuantity) ?? 0.0;
    }
    return totalTubes % 1 == 0
        ? totalTubes.toInt().toString()
        : totalTubes.toStringAsFixed(1);
  }

  Widget _buildScannedTraysSection(GbsController controller, GbsState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5, strokeAlign: BorderSide.strokeAlignOutside),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildConfigurationPanel(controller, state),
          if (state.selectedWorkOrder != null) ...[
            WorkOrderMetricsRow(
              workOrderDate: _formatDate(state.selectedWorkOrder?.workOrderDate),
              fabricationType: _getFabricationType(state),
              scannedTrays: '${state.scannedTrays.length}',
              scannedTubes: _getScannedTubes(state),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RECEIVED TRAYS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5)),
                      Text('${state.scannedTrays.length} Tray(s) Received', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF78909C))),
                    ],
                  ),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: () => _onScanTray(controller, state),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text('SCAN TRAY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const TrayTableHeader(actionColumnWidth: 44, showItemDescriptionColumn: true),
            Expanded(
              child: state.scannedTrays.isEmpty
                  ? const EmptyScanState(hasBorder: false)
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: state.scannedTrays.length,
                      itemBuilder: (context, index) {
                        final reversedIndex = state.scannedTrays.length - 1 - index;
                        return GBSTrayRow(
                          index: reversedIndex,
                          tray: state.scannedTrays[reversedIndex],
                          onRemove: () async {
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
                              controller.removeScannedTray(reversedIndex);
                            }
                          },
                        );
                      },
                    ),
            ),
          ] else
            const Expanded(
              child: Center(child: Text('Please select a work order to start scanning', style: TextStyle(color: Colors.grey, fontSize: 13))),
            ),
        ],
      ),
    );
  }
}

class _GbsOverlayDropdown<T> extends StatefulWidget {
  final String hint;
  final List<T> items;
  final T? selectedValue;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _GbsOverlayDropdown({
    required this.hint,
    required this.items,
    required this.selectedValue,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  State<_GbsOverlayDropdown<T>> createState() => _GbsOverlayDropdownState<T>();
}

class _GbsOverlayDropdownState<T> extends State<_GbsOverlayDropdown<T>> with SingleTickerProviderStateMixin {
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
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeDropdown, child: Container()),
          ),
          Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: Material(elevation: 0, color: Colors.transparent, child: _buildDropdownMenu()),
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
            border: Border.all(color: _isOpen ? const Color(0xFF1B64A3) : const Color(0xFFCFD8DC), width: 1.2),
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
      if (item is WorkOrderHeader) {
        return label.contains(query) || item.workOrderCode.toLowerCase().contains(query);
      }
      return label.contains(query);
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 8))],
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCFD8DC))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCFD8DC))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1B64A3))),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFCFD8DC)),
          Flexible(
            child: filteredItems.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No results found', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: filteredItems.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected = item == widget.selectedValue;
                      final isWO = item is WorkOrderHeader && item.description.isNotEmpty && item.workOrderCode.isNotEmpty;

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
                                child: isWO
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.itemLabel(item),
                                            style: TextStyle(
                                              color: isSelected ? const Color(0xFF1B64A3) : const Color(0xFF263238),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            item.workOrderCode,
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        widget.itemLabel(item),
                                        style: TextStyle(
                                          color: isSelected ? const Color(0xFF1B64A3) : const Color(0xFF263238),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
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