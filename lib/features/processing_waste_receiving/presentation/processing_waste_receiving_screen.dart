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
                      final loc = pp.locatorId != null ? 'Loc #${pp.locatorId}' : 'Floor';

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
                      'SELECT OPERATION / STAGE',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF78909C), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCFD8DC)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: state.selectedOperationKey,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF0D47A1)),
                          items: state.operationOptions.map((opt) {
                            return DropdownMenuItem<String>(
                              value: opt.key,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      opt.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: opt.key == state.selectedOperationKey ? FontWeight.w800 : FontWeight.w600,
                                        color: opt.key.startsWith('lapping') ? const Color(0xFFE65100) : const Color(0xFF263238),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: opt.count > 0 ? const Color(0xFF1B64A3).withValues(alpha: 0.1) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${opt.count} batches (${opt.totalTubes} tubes)',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: opt.count > 0 ? const Color(0xFF1B64A3) : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              controller.selectOperationFilter(val);
                            }
                          },
                        ),
                      ),
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
          Expanded(flex: 3, child: Text('STAGE / OPERATION', textAlign: TextAlign.center, style: headerStyle)),
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
    if (batch.stageKey == 'lapping_adjustments') {
      stageColor = const Color(0xFFD97706); // Amber / Orange
    } else if (batch.stageKey == 'lapping_batch') {
      stageColor = const Color(0xFF0284C7); // Light Blue
    } else {
      stageColor = const Color(0xFF6D28D9); // Purple
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.1),
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
                                                : 'No pending waste batches for selected operation',
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
