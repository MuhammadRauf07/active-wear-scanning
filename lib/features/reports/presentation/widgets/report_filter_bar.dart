import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/reports/controller/reports_controller.dart';

class ReportFilterBar extends StatelessWidget {
  final ReportsController controller;
  final String searchHint;
  final List<String>? statusOptions;
  final bool showShiftFilter;
  final bool showOperationFilter;

  const ReportFilterBar({
    super.key,
    required this.controller,
    this.searchHint = 'Search records...',
    this.statusOptions,
    this.showShiftFilter = false,
    this.showOperationFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Search Bar & Refresh
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    onChanged: controller.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: searchHint,
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: controller.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                              onPressed: () => controller.setSearchQuery(''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: controller.isLoading ? null : () => controller.fetchCurrentReportData(),
                icon: controller.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B64A3)),
                      )
                    : const Icon(Icons.refresh_rounded, color: Color(0xFF1B64A3)),
                tooltip: 'Refresh Data',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Date Filters & Preset Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateChip(context, 'Today', DateFilterPreset.today),
                const SizedBox(width: 6),
                _buildDateChip(context, 'Yesterday', DateFilterPreset.yesterday),
                const SizedBox(width: 6),
                _buildDateChip(context, 'Last 7 Days', DateFilterPreset.last7Days),
                const SizedBox(width: 6),
                _buildDateChip(context, 'Last 30 Days', DateFilterPreset.last30Days),
                const SizedBox(width: 6),
                _buildDateChip(context, 'All', DateFilterPreset.all),
                const SizedBox(width: 6),
                _buildCustomDateButton(context),
              ],
            ),
          ),

          // Row 3: Optional Status / Shift / Operation Dropdowns
          if (statusOptions != null || showShiftFilter || showOperationFilter) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (showShiftFilter && controller.shifts.isNotEmpty) ...[
                    _buildShiftDropdown(),
                    const SizedBox(width: 8),
                  ],
                  if (showOperationFilter && controller.operations.isNotEmpty) ...[
                    _buildOperationDropdown(),
                    const SizedBox(width: 8),
                  ],
                  if (statusOptions != null) ...[
                    ...statusOptions!.map((status) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(status),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: controller.selectedStatusFilter == status
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                            selected: controller.selectedStatusFilter == status,
                            selectedColor: const Color(0xFF1B64A3),
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (selected) {
                              controller.setStatusFilter(selected ? status : null);
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: controller.selectedStatusFilter == status
                                    ? const Color(0xFF1B64A3)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateChip(BuildContext context, String label, DateFilterPreset preset) {
    final bool isSelected = controller.datePreset == preset;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF1B64A3),
      backgroundColor: const Color(0xFFF8FAFC),
      onSelected: (selected) {
        if (selected) controller.setDatePreset(preset);
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: isSelected ? const Color(0xFF1B64A3) : const Color(0xFFCBD5E1),
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCustomDateButton(BuildContext context) {
    final isSelected = controller.datePreset == DateFilterPreset.custom;
    return ActionChip(
      avatar: Icon(Icons.date_range_rounded, size: 14, color: isSelected ? Colors.white : const Color(0xFF475569)),
      label: Text(
        controller.customDateRange != null
            ? '${controller.customDateRange!.start.month}/${controller.customDateRange!.start.day} - ${controller.customDateRange!.end.month}/${controller.customDateRange!.end.day}'
            : 'Custom Range',
      ),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      backgroundColor: isSelected ? const Color(0xFF1B64A3) : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: isSelected ? const Color(0xFF1B64A3) : const Color(0xFFCBD5E1),
        ),
      ),
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: controller.customDateRange ??
              DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 7)),
                end: DateTime.now(),
              ),
        );
        if (picked != null) {
          controller.setDatePreset(DateFilterPreset.custom, customRange: picked);
        }
      },
    );
  }

  Widget _buildShiftDropdown() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: controller.selectedShiftId,
          hint: const Text('All Shifts', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
          style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All Shifts'),
            ),
            ...controller.shifts.map((s) => DropdownMenuItem<int?>(
                  value: s.id,
                  child: Text(s.description ?? s.code),
                )),
          ],
          onChanged: controller.setShiftFilter,
        ),
      ),
    );
  }

  Widget _buildOperationDropdown() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: controller.selectedOperationId,
          hint: const Text('All Operations', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
          style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All Operations'),
            ),
            ...controller.operations.map((op) => DropdownMenuItem<int?>(
                  value: op.id,
                  child: Text(op.name),
                )),
          ],
          onChanged: controller.setOperationFilter,
        ),
      ),
    );
  }
}
