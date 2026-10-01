import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/reports/controller/reports_controller.dart';
import 'package:active_wear_scanning/features/reports/model/report_models.dart';
import 'package:active_wear_scanning/features/reports/presentation/widgets/report_filter_bar.dart';
import 'package:active_wear_scanning/features/reports/presentation/widgets/report_kpi_card.dart';

class KnittingReportView extends StatelessWidget {
  final ReportsController controller;

  const KnittingReportView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = controller.knittingItems;

    final double totalPlanTubes = items.fold(0.0, (sum, i) => sum + i.planTubes);
    final double totalActualTubes = items.fold(0.0, (sum, i) => sum + i.actualTubes);
    final double totalActualWeight = items.fold(0.0, (sum, i) => sum + i.actualWeight);
    final double totalCGradeQty = items.fold(0.0, (sum, i) => sum + i.cGradeQty);
    final double overallEfficiency = totalPlanTubes > 0 ? (totalActualTubes / totalPlanTubes) * 100 : 0.0;

    return RefreshIndicator(
      onRefresh: () => controller.fetchCurrentReportData(),
      color: const Color(0xFF1B64A3),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Filter Bar
          ReportFilterBar(
            controller: controller,
            searchHint: 'Search WO / Machine Serial / Plan Line...',
            showShiftFilter: true,
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
                      title: 'ACTUAL OUTPUT',
                      value: '${totalActualTubes.toStringAsFixed(0)} Tubes',
                      subtitle: 'Plan: ${totalPlanTubes.toStringAsFixed(0)}',
                      icon: Icons.precision_manufacturing_rounded,
                      color: const Color(0xFF1B64A3),
                    ),
                    ReportKpiCard(
                      title: 'TOTAL WEIGHT',
                      value: '${totalActualWeight.toStringAsFixed(1)} kg',
                      subtitle: 'Knitted Mass',
                      icon: Icons.scale_rounded,
                      color: const Color(0xFF2E7D32),
                    ),
                    ReportKpiCard(
                      title: 'EFFICIENCY',
                      value: '${overallEfficiency.toStringAsFixed(1)}%',
                      subtitle: 'Achievement Rate',
                      icon: Icons.speed_rounded,
                      color: overallEfficiency >= 90 ? const Color(0xFF2E7D32) : const Color(0xFFD97706),
                      badgeText: overallEfficiency >= 90 ? 'Target Met' : 'In Progress',
                      badgeColor: overallEfficiency >= 90 ? const Color(0xFF2E7D32) : const Color(0xFFD97706),
                    ),
                    ReportKpiCard(
                      title: 'C-GRADE / WASTE',
                      value: '${totalCGradeQty.toStringAsFixed(0)} Pcs',
                      subtitle: 'Defectives',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFDC2626),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Data Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PLAN LINES (${items.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Last Updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Cards List
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
                  Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text(
                    'No Knitting records match the active filters',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ],
              ),
            )
          else
            ...items.map((item) => _buildKnittingCard(item)),
        ],
      ),
    );
  }

  Widget _buildKnittingCard(KnittingReportItem knittingItem) {
    final line = knittingItem.planLine;
    final pct = knittingItem.completionPercentage;

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
          // Top Row: Code & Shift Badge
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
                    child: const Icon(Icons.precision_manufacturing_rounded, size: 16, color: Color(0xFF1B64A3)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    line.planLineCode ?? 'Plan Line #${line.id}',
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
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  knittingItem.shift?.description ?? knittingItem.shift?.code ?? 'Shift #${line.shiftId}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Info Grid
          Row(
            children: [
              Expanded(
                child: _buildMetaItem('Order / WO', line.orderNo ?? 'WO #${line.workOrderHeaderId}'),
              ),
              Expanded(
                child: _buildMetaItem('Machine', knittingItem.machine?.serialNumber ?? 'Resource #${line.resourceId}'),
              ),
              Expanded(
                child: _buildMetaItem('Plan Date', line.planDate.split('T').first),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Quantities & Progress
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
                    Row(
                      children: [
                        const Text(
                          'Target: ',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '${knittingItem.planTubes.toStringAsFixed(0)} Tubes (${knittingItem.planWeight.toStringAsFixed(1)} kg)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text(
                          'Actual: ',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '${knittingItem.actualTubes.toStringAsFixed(0)} Tubes',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B64A3)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pct >= 90 ? const Color(0xFF2E7D32) : const Color(0xFF1B64A3),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          if (knittingItem.sampleQty > 0 || knittingItem.cGradeQty > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (knittingItem.sampleQty > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Sample: ${knittingItem.sampleQty.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                    ),
                  ),
                if (knittingItem.cGradeQty > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'C-Grade: ${knittingItem.cGradeQty.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                    ),
                  ),
              ],
            ),
          ],
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
