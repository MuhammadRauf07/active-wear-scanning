import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/reports/controller/reports_controller.dart';
import 'package:active_wear_scanning/features/reports/model/report_models.dart';
import 'package:active_wear_scanning/features/reports/presentation/widgets/report_filter_bar.dart';
import 'package:active_wear_scanning/features/reports/presentation/widgets/report_kpi_card.dart';

class BatchReportView extends StatelessWidget {
  final ReportsController controller;

  const BatchReportView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = controller.batchItems;

    final int totalBatches = items.length;
    final int lockedBatches = items.where((b) => b.isLocked).length;
    final int reworkBatches = items.where((b) => b.reworkCount > 0).length;
    final int onHoldBatches = items.where((b) => b.holdCount > 0).length;
    final double totalTubes = items.fold(0.0, (sum, b) => sum + b.totalTubes);

    return RefreshIndicator(
      onRefresh: () => controller.fetchCurrentReportData(),
      color: const Color(0xFF1B64A3),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Filter Bar
          ReportFilterBar(
            controller: controller,
            searchHint: 'Search Batch Code / Color / Trolley...',
            statusOptions: const ['Normal', 'Locked', 'Rework', 'On Hold', 'Completed'],
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
                  childAspectRatio: isWide ? 2.8 : 2.1,
                  children: [
                    ReportKpiCard(
                      title: 'TOTAL BATCHES',
                      value: '$totalBatches',
                      subtitle: '${totalTubes.toStringAsFixed(0)} Tubes Total',
                      icon: Icons.layers_rounded,
                      color: const Color(0xFF1B64A3),
                    ),
                    ReportKpiCard(
                      title: 'LOCKED / SUBMITTED',
                      value: '$lockedBatches',
                      subtitle: 'Active Routing',
                      icon: Icons.lock_rounded,
                      color: const Color(0xFF2E7D32),
                    ),
                    ReportKpiCard(
                      title: 'IN REWORK',
                      value: '$reworkBatches',
                      subtitle: 'Needs Correction',
                      icon: Icons.replay_rounded,
                      color: const Color(0xFFD97706),
                      badgeText: reworkBatches > 0 ? 'Alert' : 'Clear',
                      badgeColor: reworkBatches > 0 ? const Color(0xFFD97706) : const Color(0xFF2E7D32),
                    ),
                    ReportKpiCard(
                      title: 'ON HOLD',
                      value: '$onHoldBatches',
                      subtitle: 'Blocked Flow',
                      icon: Icons.pause_circle_filled_rounded,
                      color: const Color(0xFFDC2626),
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
                  'BATCHES (${items.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Lifecycle & Trolley Tracking',
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
                  Icon(Icons.layers_clear_outlined, size: 48, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text(
                    'No Batches match the active filter criteria',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ],
              ),
            )
          else
            ...items.map((item) => _buildBatchCard(item)),
        ],
      ),
    );
  }

  Widget _buildBatchCard(BatchReportItem batchItem) {
    Color badgeBg = const Color(0xFFF1F5F9);
    Color badgeColor = const Color(0xFF475569);

    switch (batchItem.statusBadge) {
      case 'Locked':
        badgeBg = const Color(0xFFDCFCE7);
        badgeColor = const Color(0xFF166534);
        break;
      case 'Rework':
        badgeBg = const Color(0xFFFEF3C7);
        badgeColor = const Color(0xFFB45309);
        break;
      case 'On Hold':
        badgeBg = const Color(0xFFFEE2E2);
        badgeColor = const Color(0xFFDC2626);
        break;
      case 'Completed':
        badgeBg = const Color(0xFFEFF6FF);
        badgeColor = const Color(0xFF1B64A3);
        break;
    }

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
          // Row 1: Code & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.layers_rounded, size: 16, color: Color(0xFF1B64A3)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    batchItem.batchCode,
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
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  batchItem.statusBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
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
                child: _buildMetaItem('Plan Date', batchItem.planDate.split('T').first),
              ),
              Expanded(
                child: _buildMetaItem('Color', batchItem.colorDescription),
              ),
              Expanded(
                child: _buildMetaItem('Current Stage', batchItem.currentOperation),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Trolley & Trays info ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      batchItem.isTrolleyFreed ? Icons.check_circle_outline_rounded : Icons.local_shipping_outlined,
                      size: 16,
                      color: batchItem.isTrolleyFreed ? const Color(0xFF2E7D32) : const Color(0xFF1B64A3),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      batchItem.trolleyCode != null
                          ? 'Trolley: ${batchItem.trolleyCode}'
                          : (batchItem.isTrolleyFreed ? 'Trolley: Freed from Lapping' : 'No Trolley Attached'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: batchItem.isTrolleyFreed ? const Color(0xFF2E7D32) : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${batchItem.totalTrays} Trays (${batchItem.totalTubes.toStringAsFixed(0)} Tubes)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B64A3)),
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
