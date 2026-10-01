import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/reports/controller/reports_controller.dart';
import 'package:active_wear_scanning/features/reports/model/report_models.dart';

class WorkOrderReportView extends StatelessWidget {
  final ReportsController controller;

  const WorkOrderReportView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final summary = controller.selectedWorkOrderSummary;
    final rows = controller.workOrderItemRows;

    return RefreshIndicator(
      onRefresh: () => controller.fetchCurrentReportData(),
      color: const Color(0xFF1B64A3),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // 1. Work Order Selector Dropdown Bar
          _buildWorkOrderSelector(context),

          const SizedBox(height: 12),

          // 2. Work Order Header Card (Matching Reference Layout)
          if (summary != null) _buildWorkOrderHeaderCard(summary),

          const SizedBox(height: 12),

          // 3. Legend / Abbreviations Strip
          _buildLegendStrip(),

          const SizedBox(height: 14),

          // 4. Matrix Breakdown Table / List
          if (rows.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.assignment_late_outlined, size: 44, color: Color(0xFF94A3B8)),
                  SizedBox(height: 10),
                  Text(
                    'No status data available for the selected Work Order',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            ..._buildGroupedItemMatrices(rows),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Work Order Dropdown Selector
  // ---------------------------------------------------------------------------
  Widget _buildWorkOrderSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.assignment_rounded, size: 18, color: Color(0xFF1B64A3)),
          ),
          const SizedBox(width: 10),
          const Text(
            'SELECT WORK ORDER:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<WorkOrderHeader>(
                  value: controller.selectedWorkOrder,
                  isExpanded: true,
                  hint: const Text('Choose Work Order', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1B64A3)),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  items: controller.workOrdersList.map((wo) {
                    final code = wo.workOrderCode.isNotEmpty ? wo.workOrderCode : 'WO #${wo.id}';
                    return DropdownMenuItem<WorkOrderHeader>(
                      value: wo,
                      child: Text(code),
                    );
                  }).toList(),
                  onChanged: (wo) => controller.selectWorkOrder(wo),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Work Order Header Card
  // ---------------------------------------------------------------------------
  Widget _buildWorkOrderHeaderCard(WorkOrderHeaderSummary summary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Blue Table Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F3D69), // Navy Header from Web Screenshot
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.layers_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'WORK ORDER: ${summary.workOrderCode}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: summary.isLocked ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    summary.status.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // Header Data Grid
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _buildHeaderItem('WORK ORDER DATE', summary.workOrderDate, width: isWide ? 120 : 100),
                    _buildHeaderItem('DESCRIPTION', summary.description, width: isWide ? 160 : 140),
                    _buildHeaderItem('CUSTOMER', summary.customer, width: isWide ? 140 : 120),
                    _buildHeaderItem('BRAND', summary.brand, width: isWide ? 130 : 110),
                    _buildHeaderItem('STYLE', summary.style, width: isWide ? 120 : 100),
                    _buildHeaderItem('CUSTOMER PO', summary.customerPo ?? '-', width: isWide ? 120 : 100),
                    _buildHeaderItem('TOTAL BATCHES', '${summary.totalBatches} Batches', width: isWide ? 120 : 100, isBoldValue: true),
                    _buildHeaderItem('TOTAL TUBES', '${summary.totalRequiredTubes.toStringAsFixed(0)} Tubes', width: isWide ? 120 : 100, isBoldValue: true, valueColor: const Color(0xFF1B64A3)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderItem(String label, String value, {double? width, bool isBoldValue = false, Color? valueColor}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Legend / Abbreviations Strip
  // ---------------------------------------------------------------------------
  Widget _buildLegendStrip() {
    final legends = [
      {'abbr': 'WO.TB', 'desc': 'Work Order Required Tubes'},
      {'abbr': 'P.TB', 'desc': 'Knit Plan Tubes'},
      {'abbr': 'A.TB', 'desc': 'Knit A-Grade Tubes'},
      {'abbr': 'C.TB', 'desc': 'Knit C-Grade Tubes'},
      {'abbr': 'S.TB', 'desc': 'Sample Tubes'},
      {'abbr': 'GBS.TR', 'desc': 'Trays Received at GBS'},
      {'abbr': 'GBS.TB', 'desc': 'Tubes Received at GBS'},
      {'abbr': 'GBS.STK.TB', 'desc': 'Tubes Stock at GBS'},
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: legends.map((l) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  l['abbr']!,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1B64A3)),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                l['desc']!,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Matrix Breakdown w.r.t Item & Color
  // ---------------------------------------------------------------------------
  List<Widget> _buildGroupedItemMatrices(List<WorkOrderItemColorStatusRow> rows) {
    return rows.map((row) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Item Header Bar with Quick Metric Badges
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(9),
                  topRight: Radius.circular(9),
                ),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.itemDescription,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMetricTag('WO.TB', row.woRequiredTubes.toStringAsFixed(0), const Color(0xFF1B64A3)),
                        _buildMetricTag('P.TB', row.knitPlanTubes.toStringAsFixed(0), const Color(0xFF475569)),
                        _buildMetricTag('A.TB', row.knitAGradeTubes.toStringAsFixed(0), const Color(0xFF16A34A)),
                        _buildMetricTag('C.TB', row.knitCGradeTubes.toStringAsFixed(0), const Color(0xFFDC2626)),
                        _buildMetricTag('S.TB', row.sampleTubes.toStringAsFixed(0), const Color(0xFFD97706)),
                        _buildMetricTag('GBS.TR', '${row.gbsReceivedTrays}', const Color(0xFF0284C7)),
                        _buildMetricTag('GBS.TB', row.gbsReceivedTubes.toStringAsFixed(0), const Color(0xFF0284C7)),
                        _buildMetricTag('GBS.STK.TB', row.gbsStockTubes.toStringAsFixed(0), const Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal Scrollable Breakdown Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 40,
                headingRowColor: WidgetStateProperty.all(const Color(0xFF0F3D69)),
                columnSpacing: 14,
                horizontalMargin: 12,
                columns: const [
                  DataColumn(label: Text('Color', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Processed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Fresh Lot (Tr/Tb)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Reassigned Lot (Tr/Tb)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Fresh WIP (Tr/Tb)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Reassigned WIP (Tr/Tb)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Ready R&I (Tr/Tb)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('R&I Received (Tr/Tb)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('R&I Stock (Tr/Tb)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Allocated', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                ],
                rows: [
                  DataRow(
                    cells: [
                      DataCell(Text(row.colorDescription, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                      DataCell(Text(row.processedItemDescription, style: const TextStyle(fontSize: 10, color: Color(0xFF475569)))),
                      DataCell(_buildStageCell(row.freshLotMakingTrays, row.freshLotMakingTubes)),
                      DataCell(_buildStageCell(row.reassignedLotMakingTrays, row.reassignedLotMakingTubes)),
                      DataCell(_buildStageCell(row.freshWipTrays, row.freshWipTubes)),
                      DataCell(_buildStageCell(row.reassignedWipTrays, row.reassignedWipTubes)),
                      DataCell(_buildStageCell(row.readyToReceiveTrays, row.readyToReceiveTubes)),
                      DataCell(_buildStageCell(row.riReceivedTrays, row.riReceivedTubes)),
                      DataCell(_buildStageCell(row.riStockTrays, row.riStockTubes)),
                      DataCell(Text(row.allocatedTubes.toStringAsFixed(0), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B64A3)))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildMetricTag(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildStageCell(int trays, double tubes) {
    return Text(
      '$trays / ${tubes.toStringAsFixed(0)}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: tubes > 0 ? FontWeight.bold : FontWeight.normal,
        color: tubes > 0 ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
      ),
    );
  }
}
