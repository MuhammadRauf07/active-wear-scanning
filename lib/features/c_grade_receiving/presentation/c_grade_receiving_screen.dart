import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/empty_scan_state.dart';
import 'package:active_wear_scanning/core/widgets/work_order_metrics_row.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/c_grade_receiving/controller/c_grade_receiving_controller.dart';

class CGradeReceivingScreen extends StatelessWidget {
  const CGradeReceivingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CGradeReceivingController>(
      create: (_) => CGradeReceivingController(),
      child: const _CGradeReceivingScreenView(),
    );
  }
}

class _CGradeReceivingScreenView extends StatefulWidget {
  const _CGradeReceivingScreenView();

  @override
  State<_CGradeReceivingScreenView> createState() => _CGradeReceivingScreenViewState();
}

class _CGradeReceivingScreenViewState extends State<_CGradeReceivingScreenView> {
  static final _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedbackHelper.scanError();
    AppSnackBar.showError(context, message: message);
  }

  Future<void> _onSave(CGradeReceivingController controller, CGradeReceivingState state) async {
    HapticFeedbackHelper.buttonClick();
    AppLoader.show(context, message: 'Saving C-Grade WIP Data...');
    try {
      await controller.saveCGradeReceiving();
      if (!mounted) return;
      AppLoader.hide(context);
      HapticFeedbackHelper.scanSuccess();
      AppSnackBar.showSuccess(context, message: 'C-Grade receiving saved successfully');
    } catch (e) {
      if (!mounted) return;
      AppLoader.hide(context);
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CGradeReceivingController>();
    final state = controller.state;
    final isSaveEnabled = state.selectedProgressIds.isNotEmpty && !state.isLoading;

    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(controller, state, isSaveEnabled),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: _buildTableSection(controller, state),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(CGradeReceivingController controller, CGradeReceivingState state, bool enabled) {
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
                    'C-Grade Receiving',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF263238),
                    ),
                  ),
                  Text(
                    'Receive C-Grade Production',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF546E7A),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
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

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return '---';
    return rawDate.split('T')[0].split(' ')[0];
  }

  String _getFabricationType(CGradeReceivingState state) {
    if (state.selectedWorkOrder == null) return '---';
    final matches = state.availableProgresses
        .where((t) => t.workOrderHeader.id == state.selectedWorkOrder!.id);
    if (matches.isNotEmpty) {
      final fab = matches.first.item.garmentFabricationType;
      if (fab != null && fab.trim().isNotEmpty) return fab.trim();
    }
    return '---';
  }

  String _getScannedTrays(CGradeReceivingController controller, CGradeReceivingState state) {
    final selectedRecords = controller
        .getFilteredEntries()
        .where((t) => state.selectedProgressIds.contains(t.productionProgress.id));
    final distinctTrays = selectedRecords
        .map((t) => t.primaryTrayModel.trayCode)
        .where((c) => c != null && c.trim().isNotEmpty)
        .toSet();
    if (distinctTrays.isNotEmpty) {
      return distinctTrays.length.toString();
    }
    return state.selectedProgressIds.length.toString();
  }

  String _getScannedTubes(CGradeReceivingController controller, CGradeReceivingState state) {
    final selectedRecords = controller
        .getFilteredEntries()
        .where((t) => state.selectedProgressIds.contains(t.productionProgress.id));
    double totalWeight = 0;
    for (final r in selectedRecords) {
      final pp = r.productionProgress;
      final primaryQty = (pp.primaryQuantity ?? 0) > 0
          ? (pp.primaryQuantity ?? 0)
          : (pp.waste ?? 0);
      totalWeight += primaryQty.toDouble();
    }
    return totalWeight % 1 == 0 ? totalWeight.toInt().toString() : totalWeight.toStringAsFixed(1);
  }

  Widget _buildTableSection(CGradeReceivingController controller, CGradeReceivingState state) {
    final grouped = controller.getGroupedCGradeEntries();
    final allIds = controller
        .getFilteredEntries()
        .map((t) => t.productionProgress.id)
        .whereType<int>()
        .toList();
    final isAllSelected = allIds.isNotEmpty &&
        allIds.every((id) => state.selectedProgressIds.contains(id));

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildConfigurationPanel(controller, state),
          if (state.selectedWorkOrder != null) ...[
            WorkOrderMetricsRow(
              workOrderDate: _formatDate(state.selectedWorkOrder?.workOrderDate),
              fabricationType: _getFabricationType(state),
              scannedTrays: _getScannedTrays(controller, state),
              scannedTubes: _getScannedTubes(controller, state),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'C-GRADE PENDING ENTRIES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF263238),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${grouped.length} Pending Groups, ${state.selectedProgressIds.length} Selected Records',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF78909C),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedbackHelper.buttonClick();
                        controller.fetchLatestEntriesSilently();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'REFRESH',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
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
                ],
              ),
            ),
            _buildTableHeader(controller, isAllSelected),
            Expanded(
              child: grouped.isEmpty
                  ? const EmptyScanState(hasBorder: false)
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        return _buildTableRow(
                          controller,
                          state,
                          grouped[index],
                          index,
                        );
                      },
                    ),
            ),
          ] else
            const Expanded(
              child: Center(
                child: Text(
                  'Please select a work order to view pending C-Grade entries',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfigurationPanel(CGradeReceivingController controller, CGradeReceivingState state) {
    final Map<int, WorkOrderHeader> uniqueWOs = {};
    for (final progress in state.availableProgresses) {
      uniqueWOs[progress.workOrderHeader.id] = progress.workOrderHeader;
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
                _CGradeOverlayDropdown<WorkOrderHeader>(
                  hint: "Select work order...",
                  items: availableWOs,
                  selectedValue: state.selectedWorkOrder,
                  itemLabel: (wo) => wo.description.isNotEmpty
                      ? wo.description
                      : (wo.workOrderCode.isNotEmpty ? wo.workOrderCode : 'WO #${wo.id}'),
                  onChanged: (val) {
                    controller.selectWorkOrder(val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(CGradeReceivingController controller, bool isAllSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: isAllSelected,
              activeColor: const Color(0xFF0D47A1),
              onChanged: (val) {
                HapticFeedbackHelper.buttonClick();
                controller.toggleAllProgressIds(val == true);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 9, child: Text('ITEM DESCRIPTION', style: _tableHeaderStyle)),
          Expanded(flex: 3, child: Text('WEIGHT (KG)', textAlign: TextAlign.center, style: _tableHeaderStyle)),
          Expanded(flex: 4, child: Text('REMARKS', textAlign: TextAlign.center, style: _tableHeaderStyle)),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    CGradeReceivingController controller,
    CGradeReceivingState state,
    CGradeGroup group,
    int index,
  ) {
    final isGroupSelected = group.allProgressIds.isNotEmpty &&
        group.allProgressIds.every((id) => state.selectedProgressIds.contains(id));

    final String weightStr = '${group.totalWeightKg.toStringAsFixed(2)} kg';
    final remarksText = group.remarks.trim().isNotEmpty ? group.remarks.trim() : '-';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: isGroupSelected,
              activeColor: const Color(0xFF0D47A1),
              onChanged: (val) {
                HapticFeedbackHelper.buttonClick();
                controller.toggleGroupProgressIds(group.allProgressIds, val == true);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 9,
            child: Text(
              group.itemDescription,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B64A3),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              weightStr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF263238),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: remarksText == '-'
                  ? null
                  : () => _showRemarksDialog(context, group.itemDescription, remarksText),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: remarksText == '-' ? Colors.transparent : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: remarksText == '-' ? null : Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        remarksText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: remarksText == '-' ? FontWeight.normal : FontWeight.w600,
                          color: remarksText == '-' ? Colors.grey.shade500 : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                    if (remarksText != '-') ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFF1D4ED8)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemarksDialog(BuildContext context, String itemDesc, String remarks) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.comment_rounded, color: Color(0xFF0D47A1), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Entry Remarks',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              itemDesc,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B64A3),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                remarks,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF334155),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _CGradeOverlayDropdown<T> extends StatefulWidget {
  final String hint;
  final List<T> items;
  final T? selectedValue;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _CGradeOverlayDropdown({
    required this.hint,
    required this.items,
    required this.selectedValue,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  State<_CGradeOverlayDropdown<T>> createState() => _CGradeOverlayDropdownState<T>();
}

class _CGradeOverlayDropdownState<T> extends State<_CGradeOverlayDropdown<T>>
    with SingleTickerProviderStateMixin {
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
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
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
                    ? Text(
                        widget.hint,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      )
                    : Text(
                        widget.itemLabel(widget.selectedValue as T),
                        style: const TextStyle(
                          color: Color(0xFF263238),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              RotationTransition(
                turns: _rotateAnimation,
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: _isOpen ? const Color(0xFF1B64A3) : const Color(0xFF546E7A),
                  size: 24,
                ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
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
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected = item == widget.selectedValue;
                      final isWO = item is WorkOrderHeader &&
                          item.description.isNotEmpty &&
                          item.workOrderCode.isNotEmpty;

                      return InkWell(
                        onTap: () {
                          widget.onChanged(item);
                          _closeDropdown();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
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
                                              color: isSelected
                                                  ? const Color(0xFF1B64A3)
                                                  : const Color(0xFF263238),
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
                                          color: isSelected
                                              ? const Color(0xFF1B64A3)
                                              : const Color(0xFF263238),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  color: Color(0xFF1B64A3),
                                  size: 16,
                                ),
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

