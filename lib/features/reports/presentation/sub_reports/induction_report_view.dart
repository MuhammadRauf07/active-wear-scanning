import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/reports/controller/reports_controller.dart';
import 'package:active_wear_scanning/features/reports/model/report_models.dart';
import 'package:active_wear_scanning/features/reports/presentation/widgets/report_filter_bar.dart';
import 'package:active_wear_scanning/features/reports/presentation/widgets/report_kpi_card.dart';

class InductionReportView extends StatelessWidget {
  final ReportsController controller;

  const InductionReportView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = controller.inductionItems;

    final int totalTrays = items.length;
    final int batchedCount = items.where((i) => i.isBatched).length;
    final int unbatchedCount = items.where((i) => !i.isBatched).length;
    final double totalWeight = items.fold(0.0, (sum, i) => sum + i.weight);
    final double totalTubes = items.fold(0.0, (sum, i) => sum + i.tubes);

    return RefreshIndicator(
      onRefresh: () => controller.fetchCurrentReportData(),
      color: const Color(0xFF1B64A3),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Filter Bar
          ReportFilterBar(
            controller: controller,
            searchHint: 'Search Tray / Work Order / Item Description...',
            statusOptions: const ['Batched', 'Unbatched'],
            showOperationFilter: true,
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
                      title: 'TOTAL INDUCTED',
                      value: '$totalTrays Trays',
                      subtitle: '${totalTubes.toStringAsFixed(0)} Tubes (${totalWeight.toStringAsFixed(1)} kg)',
                      icon: Icons.warehouse_rounded,
                      color: const Color(0xFF1B64A3),
                    ),
                    ReportKpiCard(
                      title: 'UNBATCHED STOCK',
                      value: '$unbatchedCount Trays',
                      subtitle: 'Waiting for Batching',
                      icon: Icons.pending_actions_rounded,
                      color: const Color(0xFFD97706),
                      badgeText: unbatchedCount > 0 ? 'Pending' : 'Empty',
                      badgeColor: unbatchedCount > 0 ? const Color(0xFFD97706) : const Color(0xFF2E7D32),
                    ),
                    ReportKpiCard(
                      title: 'ALLOCATED TO LOT',
                      value: '$batchedCount Trays',
                      subtitle: 'In Active Batches',
                      icon: Icons.done_all_rounded,
                      color: const Color(0xFF2E7D32),
                    ),
                    ReportKpiCard(
                      title: 'TOTAL TUBES',
                      value: totalTubes.toStringAsFixed(0),
                      subtitle: 'In Induction Area',
                      icon: Icons.view_week_rounded,
                      color: const Color(0xFF0284C7),
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
                  'INDUCTION TRAYS (${items.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Staging & Inventory Ledger',
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
                  Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text(
                    'No Induction records match the active filters',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ],
              ),
            )
          else
            ...items.map((item) => _buildInductionCard(item)),
        ],
      ),
    );
  }

  Widget _buildInductionCard(InductionReportItem inductionItem) {
    final bool isBatched = inductionItem.isBatched;

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
                    child: const Icon(Icons.warehouse_rounded, size: 16, color: Color(0xFF1B64A3)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    inductionItem.trayCode,
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
                  color: isBatched ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isBatched ? 'Batched (#${inductionItem.batchHeaderId})' : 'Unbatched Stock',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isBatched ? const Color(0xFF166534) : const Color(0xFFB45309),
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
                child: _buildMetaItem('Work Order', inductionItem.workOrderCode),
              ),
              Expanded(
                child: _buildMetaItem('Locator', inductionItem.locatorName),
              ),
              Expanded(
                child: _buildMetaItem('Grade', 'Grade ${inductionItem.productGrade == 1 ? 'A' : 'B'}'),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Item description & weight
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
                Expanded(
                  child: Text(
                    '${inductionItem.itemDescription} (${inductionItem.colorDescription} / ${inductionItem.sizeDescription})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${inductionItem.tubes.toStringAsFixed(0)} Tubes (${inductionItem.weight.toStringAsFixed(1)} kg)',
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
