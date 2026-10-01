import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/reports/controller/reports_controller.dart';
import 'package:active_wear_scanning/features/reports/model/report_models.dart';
import 'package:active_wear_scanning/features/reports/presentation/widgets/report_filter_bar.dart';
import 'package:active_wear_scanning/features/reports/presentation/widgets/report_kpi_card.dart';

class WorkOrderReportView extends StatelessWidget {
  final ReportsController controller;

  const WorkOrderReportView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = controller.workOrderItems;

    final double totalRequiredTubes = items.fold(0.0, (sum, i) => sum + i.requiredTubes);
    final double totalKnittedTubes = items.fold(0.0, (sum, i) => sum + i.knittedTubes);
    final double totalPackedTubes = items.fold(0.0, (sum, i) => sum + i.packedTubes);
    final int totalBatchesCount = items.fold(0, (sum, i) => sum + i.totalBatches);
    final double fulfillmentRate = totalRequiredTubes > 0 ? (totalKnittedTubes / totalRequiredTubes) * 100 : 0.0;

    return RefreshIndicator(
      onRefresh: () => controller.fetchCurrentReportData(),
      color: const Color(0xFF1B64A3),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Filter Bar
          ReportFilterBar(
            controller: controller,
            searchHint: 'Search Work Order / Customer PO...',
            statusOptions: const ['In Progress', 'Completed'],
          ),

          // KPI Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return GridView.count(
                  crossAxisCount: isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: isWide ? 2.4 : 1.75,
                  children: [
                    ReportKpiCard(
                      title: 'TOTAL REQUIRED',
                      value: '${totalRequiredTubes.toStringAsFixed(0)} Tubes',
                      subtitle: 'Work Orders: ${items.length}',
                      icon: Icons.assignment_rounded,
                      color: const Color(0xFF1B64A3),
                    ),
                    ReportKpiCard(
                      title: 'KNITTED YIELD',
                      value: '${totalKnittedTubes.toStringAsFixed(0)} Tubes',
                      subtitle: 'Produced Stock',
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF2E7D32),
                    ),
                    ReportKpiCard(
                      title: 'PACKED OUTPUT',
                      value: '${totalPackedTubes.toStringAsFixed(0)} Tubes',
                      subtitle: 'Ready for Dispatch',
                      icon: Icons.all_inbox_rounded,
                      color: const Color(0xFFD97706),
                    ),
                    ReportKpiCard(
                      title: 'FULFILLMENT',
                      value: '${fulfillmentRate.toStringAsFixed(1)}%',
                      subtitle: '$totalBatchesCount Batches Total',
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF7C3AED),
                      badgeText: fulfillmentRate >= 100 ? 'Fulfilled' : 'Active',
                      badgeColor: fulfillmentRate >= 100 ? const Color(0xFF2E7D32) : const Color(0xFF7C3AED),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'WORK ORDERS (${items.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Auto-aggregated from Batch Lines',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          if (items.isEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.assignment_late_outlined, size: 48, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text(
                    'No Work Orders match the active criteria',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ],
              ),
            )
          else
            ...items.map((item) => _buildWorkOrderCard(item)),
        ],
      ),
    );
  }

  Widget _buildWorkOrderCard(WorkOrderReportItem woItem) {
    final bool isCompleted = woItem.status == 'Completed';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Code & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.assignment_rounded, size: 16, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WO #${woItem.workOrderCode}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  woItem.status ?? 'In Progress',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? const Color(0xFF166534) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Meta Info
          Row(
            children: [
              Expanded(
                child: _buildMetaItem('Customer PO', woItem.customerPo ?? 'Standard PO'),
              ),
              Expanded(
                child: _buildMetaItem('Batches Created', '${woItem.totalBatches} (${woItem.completedBatches} Done)'),
              ),
              Expanded(
                child: _buildMetaItem('Margins (K/D/S)', '${woItem.knittingMargin.toStringAsFixed(0)}% / ${woItem.dyeingMargin.toStringAsFixed(0)}% / ${woItem.stitchingMargin.toStringAsFixed(0)}%'),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Required: ${woItem.requiredTubes.toStringAsFixed(0)} Tubes',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      'Knitted: ${woItem.knittedTubes.toStringAsFixed(0)} | Packed: ${woItem.packedTubes.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (woItem.progressPercent / 100).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? const Color(0xFF2E7D32) : const Color(0xFF7C3AED),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
