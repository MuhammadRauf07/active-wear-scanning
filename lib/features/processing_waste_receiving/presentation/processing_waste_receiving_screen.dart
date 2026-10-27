import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/controller/processing_waste_controller.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/model/processing_waste_state.dart';

class ProcessingWasteReceivingScreen extends StatelessWidget {
  const ProcessingWasteReceivingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProcessingWasteController>(
      create: (_) => ProcessingWasteController(),
      child: const _ProcessingWasteReceivingView(),
    );
  }
}

class _ProcessingWasteReceivingView extends StatefulWidget {
  const _ProcessingWasteReceivingView();

  @override
  State<_ProcessingWasteReceivingView> createState() => _ProcessingWasteReceivingViewState();
}

class _ProcessingWasteReceivingViewState extends State<_ProcessingWasteReceivingView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showBatchDetailsDialog(BuildContext context, BatchWasteGroupItem batch) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BATCH DETAILS: ${batch.batchCode}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${batch.stageName} • WO: ${batch.workOrderCode} • Total: ${batch.totalTubes} Tubes',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF546E7A)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('TRAY CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF546E7A)))),
                      Expanded(flex: 2, child: Text('TUBES', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF546E7A)))),
                      Expanded(flex: 2, child: Text('GRADE', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF546E7A)))),
                      Expanded(flex: 3, child: Text('REMARKS', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF546E7A)))),
                      Expanded(flex: 2, child: Text('LOCATOR', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF546E7A)))),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: batch.progressItems.length,
                    itemBuilder: (context, index) {
                      final item = batch.progressItems[index];
                      final pp = item.productionProgress;
                      final trayCode = item.primaryTrayModel.trayCode ?? (pp.primaryTrayId != null ? '#${pp.primaryTrayId}' : 'N/A');
                      final qty = (pp.waste != null && pp.waste! > 0)
                          ? pp.waste!.toInt().toString()
                          : (pp.secondaryQuantity ?? pp.primaryQuantity ?? 0).toInt().toString();
                      final grade = pp.productGrade == 2 ? 'Grade C' : (pp.productGrade == 1 ? 'Grade B' : 'Grade A');
                      final remarks = pp.remarks ?? pp.subOperation ?? '-';
                      final loc = pp.locatorId != null
                          ? (pp.locatorId == 23
                              ? 'Lapping (Reassign) [Loc #23]'
                              : (pp.locatorId == 8 ? 'Lapping [Loc #8]' : 'Loc #${pp.locatorId}'))
                          : 'Floor';

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
                          border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                trayCode,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                qty,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: pp.productGrade == 2 ? Colors.red.shade50 : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: pp.productGrade == 2 ? Colors.red.shade200 : Colors.amber.shade200,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    grade,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: pp.productGrade == 2 ? Colors.red.shade900 : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                remarks,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF546E7A)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                loc,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF546E7A)),
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
  }

  Widget _buildTopHeader(BuildContext context, ProcessingWasteController controller, ProcessingWasteState state) {
    final hasSelection = state.selectedBatchGroupIds.isNotEmpty && !state.isLoading;
    final selectedCount = state.selectedBatchesCount;
    final selectedTubes = state.selectedTubesCount;

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
            CustomBackButton(
              onBackPress: (state.isLoading || AppLoader.isVisible)
                  ? () {}
                  : () => Navigator.pop(context),
            ),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Processing Waste Receiving',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'Receive floor waste into Locator 18 (Waste Store)',
                    style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: hasSelection
                  ? () async {
                      try {
                        await AppLoader.runWithLoader(
                          context,
                          message: 'Receiving $selectedCount batch(es) ($selectedTubes tubes) into Locator 18...',
                          action: () => controller.receiveWaste(),
                        );
                        if (context.mounted) {
                          AppSnackBar.showSuccess(
                            context,
                            message: 'Processing waste received and logged in Locator 18 successfully!',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackBar.showError(context, message: e.toString());
                        }
                      }
                    }
                  : null,
              icon: const Icon(Icons.move_to_inbox_rounded, size: 16),
              label: Text(
                selectedCount > 0 ? 'RECEIVE WASTE ($selectedCount)' : 'RECEIVE WASTE',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
              style: AppTheme.saveButtonStyle(isEnabled: hasSelection),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndSearchBar(ProcessingWasteController controller, ProcessingWasteState state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFCFD8DC), width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Operation / Stage Dropdown
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SELECT LOCATOR',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF78909C), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    _WasteOperationOverlayDropdown(
                      options: state.operationOptions,
                      selectedKey: state.selectedOperationKey,
                      onSelected: (val) => controller.selectOperationFilter(val),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Search Input
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SEARCH BATCH / WO',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF78909C), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => controller.setSearchQuery(val),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238)),
                        decoration: InputDecoration(
                          hintText: 'Filter by batch, WO, item...',
                          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF90A4AE)),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF78909C)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    controller.setSearchQuery('');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
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
                            borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Refresh Button
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: SizedBox(
                  height: 42,
                  child: IconButton(
                    onPressed: state.isLoading ? null : () => controller.fetchInitialData(),
                    tooltip: 'Refresh data',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFCFD8DC)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: state.isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded, color: Color(0xFF0D47A1), size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Selection and summary bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: state.isAllSelected,
                    tristate: state.selectedBatchGroupIds.isNotEmpty && !state.isAllSelected,
                    onChanged: (val) => controller.toggleSelectAll(val ?? false),
                    activeColor: const Color(0xFF0D47A1),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    state.selectedBatchGroupIds.isEmpty
                        ? 'Select All (${state.filteredBatchGroups.length} batches available)'
                        : '${state.selectedBatchesCount} of ${state.filteredBatchGroups.length} batches selected (${state.selectedTubesCount} total tubes)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: state.selectedBatchGroupIds.isNotEmpty ? FontWeight.w800 : FontWeight.w600,
                      color: state.selectedBatchGroupIds.isNotEmpty ? const Color(0xFF0D47A1) : const Color(0xFF546E7A),
                    ),
                  ),
                ],
              ),
              if (state.selectedBatchGroupIds.isNotEmpty)
                TextButton(
                  onPressed: () => controller.toggleSelectAll(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Clear Selection',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: Color(0xFF455A64),
      letterSpacing: 0.3,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 32), // Checkbox spacing
          Expanded(flex: 3, child: Text('WORK ORDER', style: headerStyle)),
          Expanded(flex: 3, child: Text('BATCH NO', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 3, child: Text('LOCATOR / OPERATION', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 6, child: Text('ITEM DESCRIPTION', style: headerStyle)),
          Expanded(flex: 2, child: Text('SIZE', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 2, child: Text('TUBES', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 2, child: Text('GRADE', textAlign: TextAlign.center, style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildBatchRow(
    BuildContext context,
    ProcessingWasteController controller,
    ProcessingWasteState state,
    BatchWasteGroupItem batch,
    int index,
  ) {
    final isSelected = state.selectedBatchGroupIds.contains(batch.id);

    const cellStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238));
    const blueCellStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1));

    Color stageColor;
    Color stageBg;
    if (batch.stageKey == 'lapping_reassign') {
      stageColor = const Color(0xFF0D9488); // Teal
      stageBg = const Color(0xFF0D9488).withValues(alpha: 0.12);
    } else if (batch.stageKey == 'lapping_adjustments') {
      stageColor = const Color(0xFFD97706); // Amber / Orange
      stageBg = const Color(0xFFD97706).withValues(alpha: 0.12);
    } else if (batch.stageKey == 'lapping_batch') {
      stageColor = const Color(0xFF0284C7); // Light Blue
      stageBg = const Color(0xFF0284C7).withValues(alpha: 0.12);
    } else {
      stageColor = const Color(0xFF6D28D9); // Purple
      stageBg = const Color(0xFF6D28D9).withValues(alpha: 0.12);
    }

    final sizeText = (batch.sizeDescription.isNotEmpty && batch.sizeDescription != 'N/A')
        ? batch.sizeDescription
        : '-';

    return InkWell(
      onTap: () => controller.toggleBatchSelection(batch.id),
      onLongPress: () => _showBatchDetailsDialog(context, batch),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0D47A1).withValues(alpha: 0.06)
              : (index.isEven ? Colors.white : const Color(0xFFF8FAFC)),
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF0D47A1).withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => controller.toggleBatchSelection(batch.id),
                activeColor: const Color(0xFF0D47A1),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            // Work Order
            Expanded(
              flex: 3,
              child: Text(
                batch.workOrderCode,
                style: cellStyle,
              ),
            ),
            // Batch Code
            Expanded(
              flex: 3,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.2), width: 0.5),
                  ),
                  child: Text(
                    batch.batchCode,
                    style: blueCellStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            // Stage / Operation
            Expanded(
              flex: 3,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: stageBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: stageColor.withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: Text(
                        batch.stageName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: stageColor),
                      ),
                    ),
                    if (batch.sourceLocatorId == 23 || batch.stageKey == 'lapping_reassign')
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Locator 23',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.teal.shade800),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Item Description
            Expanded(
              flex: 6,
              child: Text(
                batch.itemDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: cellStyle,
              ),
            ),
            // Size (Separate column)
            Expanded(
              flex: 2,
              child: Text(
                sizeText,
                textAlign: TextAlign.center,
                style: cellStyle,
              ),
            ),
            // Tubes (Quantity)
            Expanded(
              flex: 2,
              child: Text(
                '${batch.totalTubes}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1)),
              ),
            ),
            // Grade
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: batch.productGrade.contains('C') ? Colors.red.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: batch.productGrade.contains('C') ? Colors.red.shade200 : Colors.amber.shade200,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    batch.productGrade,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: batch.productGrade.contains('C') ? Colors.red.shade900 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProcessingWasteController>();
    final state = controller.state;
    final batches = state.filteredBatchGroups;

    return PopScope(
      canPop: !state.isLoading && !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopHeader(context, controller, state),
              if (state.errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Container(
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
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFilterAndSearchBar(controller, state),
                        _buildTableHeader(),
                        Expanded(
                          child: batches.isEmpty
                              ? (state.isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                                          const SizedBox(height: 12),
                                          Text(
                                            state.selectedOperationKey == 'all'
                                                ? 'No pending waste batches found'
                                                : 'No pending waste batches for selected locator',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF546E7A),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Waste logged from Processing & Lapping will appear here for receipt.',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF90A4AE)),
                                          ),
                                        ],
                                      ),
                                    ))
                              : ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: batches.length,
                                  itemBuilder: (context, index) {
                                    final batch = batches[index];
                                    return _buildBatchRow(context, controller, state, batch, index);
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
      ),
    );
  }
}

class _WasteOperationOverlayDropdown extends StatefulWidget {
  final List<WasteOperationOption> options;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  const _WasteOperationOverlayDropdown({
    required this.options,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  State<_WasteOperationOverlayDropdown> createState() => _WasteOperationOverlayDropdownState();
}

class _WasteOperationOverlayDropdownState extends State<_WasteOperationOverlayDropdown>
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
    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _overlayEntry?.remove();
    _overlayEntry = null;
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
    if (mounted) {
      setState(() {
        _isOpen = false;
        _searchQuery = '';
        _searchController.clear();
        _controller.reverse();
      });
    }
  }

  Color _getStageColor(WasteOperationOption opt) {
    if (opt.key == 'all') return const Color(0xFF0D47A1); // Deep Navy
    final locId = opt.locatorId;
    final opId = opt.operationId;
    final text = '${opt.label} ${opt.stageType ?? ''} ${opt.key}'.toLowerCase();

    // Heat Set (Loc 6, Op 5)
    if (locId == 6 || opId == 5 || text.contains('heat')) return const Color(0xFFEA580C);
    // Dye (Loc 22, Op 12)
    if (locId == 22 || opId == 12 || text.contains('dye')) return const Color(0xFF6366F1);
    // Tumble (Loc 20, Op 14)
    if (locId == 20 || opId == 14 || text.contains('tumble')) return const Color(0xFF0891B2);
    // Lapping Reassign (Loc 23)
    if (locId == 23 || text.contains('reassign')) return const Color(0xFF0D9488);
    // Lapping Floor (Loc 8, Op 7)
    if (locId == 8 || opId == 7 || text.contains('lapping')) return const Color(0xFF0284C7);
    // QA (Loc 9, Op 8)
    if (locId == 9 || opId == 8 || text.contains('qa')) return const Color(0xFF7C3AED);
    // PBS (Loc 19, Op 16)
    if (locId == 19 || opId == 16 || text.contains('pbs')) return const Color(0xFFE11D48);

    return const Color(0xFF475569);
  }

  IconData _getStageIcon(WasteOperationOption opt) {
    if (opt.key == 'all') return Icons.layers_rounded;
    final locId = opt.locatorId;
    final opId = opt.operationId;
    final text = '${opt.label} ${opt.stageType ?? ''} ${opt.key}'.toLowerCase();

    if (locId == 6 || opId == 5 || text.contains('heat')) return Icons.local_fire_department_rounded;
    if (locId == 22 || opId == 12 || text.contains('dye')) return Icons.color_lens_rounded;
    if (locId == 20 || opId == 14 || text.contains('tumble')) return Icons.autorenew_rounded;
    if (locId == 23 || text.contains('reassign')) return Icons.sync_alt_rounded;
    if (locId == 8 || opId == 7 || text.contains('lapping')) return Icons.bubble_chart_rounded;
    if (locId == 9 || opId == 8 || text.contains('qa')) return Icons.verified_rounded;
    if (locId == 19 || opId == 16 || text.contains('pbs')) return Icons.inventory_2_rounded;

    return Icons.warehouse_rounded;
  }

  String? _getStageSubtitle(WasteOperationOption opt) {
    if (opt.locatorId != null) {
      final opPart = (opt.stageType != null && opt.stageType!.isNotEmpty) ? ' • ${opt.stageType}' : '';
      return 'Locator #${opt.locatorId}$opPart';
    }
    return null;
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeDropdown,
              child: Container(color: Colors.transparent),
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
                child: _buildDropdownMenu(size),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownMenu(Size size) {
    final filtered = widget.options.where((opt) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return opt.label.toLowerCase().contains(q) ||
          (opt.stageType?.toLowerCase().contains(q) ?? false) ||
          (_getStageSubtitle(opt)?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF263238)),
              decoration: InputDecoration(
                hintText: "Search locator or operation...",
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF90A4AE)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF78909C)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _overlayEntry?.markNeedsBuild();
                        },
                      )
                    : null,
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
                  borderSide: const BorderSide(color: Color(0xFF1B64A3), width: 1.5),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Flexible(
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No locators found', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isSelected = item.key == widget.selectedKey;
                      final itemColor = _getStageColor(item);
                      final iconData = _getStageIcon(item);
                      final subtitle = _getStageSubtitle(item);

                      return InkWell(
                        onTap: () {
                          widget.onSelected(item.key);
                          _closeDropdown();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: itemColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(iconData, size: 16, color: itemColor),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                        color: isSelected ? const Color(0xFF0D47A1) : const Color(0xFF263238),
                                      ),
                                    ),
                                    if (subtitle != null)
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: itemColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.count > 0 ? const Color(0xFF1B64A3).withValues(alpha: 0.1) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${item.count} batches (${item.totalTubes} tubes)',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: item.count > 0 ? const Color(0xFF1B64A3) : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF0D47A1), size: 16)
                              else
                                const SizedBox(width: 16),
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

  @override
  Widget build(BuildContext context) {
    final selectedOption = widget.options.firstWhere(
      (o) => o.key == widget.selectedKey,
      orElse: () => widget.options.isNotEmpty
          ? widget.options.first
          : const WasteOperationOption(key: 'all', label: 'All Locators'),
    );

    final itemColor = _getStageColor(selectedOption);
    final iconData = _getStageIcon(selectedOption);

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isOpen ? const Color(0xFF0D47A1) : const Color(0xFFCFD8DC),
              width: _isOpen ? 1.5 : 1.0,
            ),
            boxShadow: _isOpen
                ? [
                    BoxShadow(
                      color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              Icon(iconData, size: 16, color: itemColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedOption.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: itemColor == const Color(0xFF0D47A1) ? const Color(0xFF263238) : itemColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selectedOption.count > 0 ? const Color(0xFF1B64A3).withValues(alpha: 0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${selectedOption.count} batches (${selectedOption.totalTubes} tubes)',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: selectedOption.count > 0 ? const Color(0xFF1B64A3) : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              RotationTransition(
                turns: _rotateAnimation,
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: _isOpen ? const Color(0xFF0D47A1) : const Color(0xFF546E7A),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
