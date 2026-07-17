import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/custom_expanded_async_dropdown.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/stitching_line_schedule/model/stitching_line_schedule_model.dart';
import 'package:active_wear_scanning/features/stitching_line_schedule/controller/stitching_line_schedule_controller.dart';
import 'package:active_wear_scanning/features/stitching_line_schedule/model/stitching_line_schedule_state.dart';

class StitchingLineScheduleScreen extends StatelessWidget {
  const StitchingLineScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StitchingLineScheduleController>(
      create: (_) => StitchingLineScheduleController(),
      child: const _StitchingLineScheduleScreenView(),
    );
  }
}

class _StitchingLineScheduleScreenView extends StatefulWidget {
  const _StitchingLineScheduleScreenView();

  @override
  State<_StitchingLineScheduleScreenView> createState() => _StitchingLineScheduleScreenViewState();
}

class _StitchingLineScheduleScreenViewState extends State<_StitchingLineScheduleScreenView> {
  Future<void> _saveChanges(StitchingLineScheduleController controller, StitchingLineScheduleState state) async {
    HapticFeedbackHelper.buttonClick();
    AppLoader.show(context, message: 'Updating ${state.selectedStitchingLineScheduleIds.length} Stitching Lines...');
    try {
      await controller.saveChanges();
      if (!mounted) return;
      AppLoader.hide(context);
      HapticFeedbackHelper.scanSuccess();
      AppSnackBar.showSuccess(context, message: 'Successfully updated ${state.selectedStitchingLineScheduleIds.length} Stitching Lines.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppLoader.hide(context);
      HapticFeedbackHelper.scanError();
      AppSnackBar.showError(context, message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StitchingLineScheduleController>();
    final state = controller.state;

    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPremiumHeader(controller, state),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: _buildPlaceholderContent(controller, state),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(StitchingLineScheduleController controller, StitchingLineScheduleState state) {
    final hasSelection = state.selectedCostCenterLine != null && state.selectedStitchingLineScheduleIds.isNotEmpty;
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
                  Text('Stitching Line Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238))),
                  Text('STITCHING LINE SCHEDULE CONSOLE', style: TextStyle(fontSize: 9, color: Color(0xFF546E7A), fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: hasSelection ? () => _saveChanges(controller, state) : null,
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE CHANGES'),
              style: AppTheme.saveButtonStyle(isEnabled: hasSelection),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard(StitchingLineScheduleController controller, StitchingLineScheduleState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SELECT CUSTOMER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF546E7A), letterSpacing: 0.5)),
          const SizedBox(height: 8),
          state.isLoadingStitchingLineSchedules
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: CircularProgressIndicator()))
              : CustomExpandedAsyncDropdown<String>(
                  selectedValue: state.selectedCustomer,
                  items: state.customers,
                  hint: "Select Customer...",
                  isShowSearch: true,
                  itemAsString: (c) => c,
                  borderColor: const Color(0xFFCFD8DC),
                  backgroundColor: Colors.white,
                  height: 48,
                  textSize: 13,
                  onChanged: (val) => controller.onCustomerChanged(val),
                ),
          if (state.selectedCustomer != null) ...[
            const SizedBox(height: 16),
            const Text('SELECT CUSTOMER PO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF546E7A), letterSpacing: 0.5)),
            const SizedBox(height: 8),
            CustomExpandedAsyncDropdown<String>(
              selectedValue: state.selectedCustomerPO,
              items: state.customerPOs,
              hint: "Select Customer PO...",
              isShowSearch: true,
              itemAsString: (po) => po,
              borderColor: const Color(0xFFCFD8DC),
              backgroundColor: Colors.white,
              height: 48,
              textSize: 13,
              onChanged: (val) => controller.onCustomerPOChanged(val),
            ),
          ],
          if (state.selectedCustomerPO != null) ...[
            const SizedBox(height: 16),
            const Text('SELECT ARTICLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF546E7A), letterSpacing: 0.5)),
            const SizedBox(height: 8),
            CustomExpandedAsyncDropdown<String>(
              selectedValue: state.selectedArticle,
              items: state.articles,
              hint: "Select Article...",
              isShowSearch: true,
              itemAsString: (art) => art,
              borderColor: const Color(0xFFCFD8DC),
              backgroundColor: Colors.white,
              height: 48,
              textSize: 13,
              onChanged: (val) => controller.onArticleChanged(val),
            ),
          ],
          if (state.selectedArticle != null) ...[
            const SizedBox(height: 16),
            const Text('SELECT COST CENTER LINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF546E7A), letterSpacing: 0.5)),
            const SizedBox(height: 8),
            state.isLoadingCostCenterLines
                ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: CircularProgressIndicator()))
                : CustomExpandedAsyncDropdown<CostCenterLine>(
                    selectedValue: state.selectedCostCenterLine,
                    items: state.costCenterLines,
                    hint: "Select Cost Center Line...",
                    isShowSearch: true,
                    itemAsString: (c) => c.name,
                    borderColor: const Color(0xFFCFD8DC),
                    backgroundColor: Colors.white,
                    height: 48,
                    textSize: 13,
                    onChanged: (val) => controller.selectCostCenterLine(val),
                  ),
          ],
          if (state.selectedCostCenterLine != null) ...[
            _buildAllocationModeButtons(controller, state),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholderContent(StitchingLineScheduleController controller, StitchingLineScheduleState state) {
    final filtered = controller.getFilteredStitchingLineSchedules();
    final showTable = state.selectedCostCenterLine != null && state.allocationMode != null && filtered.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSelectionCard(controller, state),
          const SizedBox(height: 16),
          if (showTable)
            Expanded(
              child: _buildPoStylesTable(controller, state, filtered),
            ),
        ],
      ),
    );
  }

  Widget _buildPoStylesTable(StitchingLineScheduleController controller, StitchingLineScheduleState state, List<StitchingLineScheduleItem> items) {
    final selectableItems = items.where(controller.isRowSelectable).toList();
    final allSelected = selectableItems.isNotEmpty && selectableItems.every((i) => state.selectedStitchingLineScheduleIds.contains(i.stitchingLineSchedule.id));
    const headerStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF37474F), letterSpacing: 0.3);
    const cellStyle = TextStyle(fontSize: 11, color: Color(0xFF263238), fontWeight: FontWeight.w500);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5))),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Checkbox(
                    value: allSelected,
                    activeColor: const Color(0xFF0D47A1),
                    onChanged: selectableItems.isEmpty ? null : (val) {
                      HapticFeedbackHelper.buttonClick();
                      controller.toggleAllSelectableSchedules(val == true);
                    },
                  ),
                ),
                const Expanded(flex: 3, child: Text('Bundle', style: headerStyle)),
                const Expanded(flex: 3, child: Text('Lot', style: headerStyle)),
                const Expanded(flex: 3, child: Text('Color', style: headerStyle)),
                const Expanded(flex: 2, child: Text('Size', style: headerStyle)),
                const Expanded(flex: 2, child: Text('Qty', style: headerStyle)),
                const Expanded(flex: 4, child: Text('Line', style: headerStyle)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0), thickness: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final isChecked = state.selectedStitchingLineScheduleIds.contains(item.stitchingLineSchedule.id);
                final isSelectable = controller.isRowSelectable(item);
                final currentCellStyle = isSelectable ? cellStyle : cellStyle.copyWith(color: const Color(0xFF94A3B8));
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  color: isChecked ? const Color(0xFFE3F2FD).withValues(alpha: 0.4) : null,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Checkbox(
                          value: isChecked,
                          activeColor: const Color(0xFF0D47A1),
                          onChanged: isSelectable
                              ? (val) {
                                  HapticFeedbackHelper.buttonClick();
                                  controller.toggleScheduleSelection(item.stitchingLineSchedule.id, val == true);
                                }
                              : null,
                        ),
                      ),
                      Expanded(flex: 3, child: Text(item.stitchingLineSchedule.bundleNo ?? '-', style: currentCellStyle, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 3, child: Text(item.stitchingLineSchedule.lot ?? '-', style: currentCellStyle, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 3, child: Text(item.stitchingLineSchedule.colorCode ?? '-', style: currentCellStyle, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 2, child: Text(item.stitchingLineSchedule.size ?? '-', style: currentCellStyle, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 2, child: Text(item.stitchingLineSchedule.quantity?.toString() ?? '-', style: currentCellStyle, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 4, child: _buildCurrentLineCellText(state, item, isChecked, isSelectable)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLineCellText(StitchingLineScheduleState state, StitchingLineScheduleItem item, bool isChecked, bool isSelectable) {
    final currentLine = item.stitchingLineSchedule.line ?? '-';
    if (isChecked && state.selectedCostCenterLine != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(currentLine, style: const TextStyle(fontSize: 11, color: Color(0xFF78909C), fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            state.selectedCostCenterLine!.description ?? '-',
            style: const TextStyle(fontSize: 11, color: Color(0xFF0D47A1), fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
    return Text(
      currentLine,
      style: TextStyle(fontSize: 11, color: isSelectable ? const Color(0xFF263238) : const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildAllocationModeButtons(StitchingLineScheduleController controller, StitchingLineScheduleState state) {
    if (state.selectedCostCenterLine == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('ALLOCATION OPTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF546E7A), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildModeButton(controller, state, label: 'Allocate', mode: 'allocate', icon: Icons.playlist_add_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _buildModeButton(controller, state, label: 'Re-Allocate', mode: 're-allocate', icon: Icons.playlist_play_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _buildModeButton(StitchingLineScheduleController controller, StitchingLineScheduleState state, {required String label, required String mode, required IconData icon}) {
    final isActive = state.allocationMode == mode;
    return OutlinedButton.icon(
      onPressed: () {
        HapticFeedbackHelper.buttonClick();
        controller.changeAllocationMode(mode);
      },
      icon: Icon(icon, size: 16, color: isActive ? Colors.white : const Color(0xFF0D47A1)),
      label: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isActive ? Colors.white : const Color(0xFF0D47A1), letterSpacing: 0.5),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: isActive ? const Color(0xFF0D47A1) : Colors.white,
        side: BorderSide(color: const Color(0xFF0D47A1), width: isActive ? 0 : 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
