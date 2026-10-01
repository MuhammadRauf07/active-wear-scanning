import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/reports/controller/reports_controller.dart';
import 'package:active_wear_scanning/features/reports/model/report_models.dart';
import 'package:active_wear_scanning/features/reports/presentation/widgets/report_filter_bar.dart';
import 'package:active_wear_scanning/features/reports/presentation/widgets/report_kpi_card.dart';

class TrayTrolleyReportView extends StatelessWidget {
  final ReportsController controller;

  const TrayTrolleyReportView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = controller.trayTrolleyItems;

    final int totalAssets = items.length;
    final int freeAssets = items.where((i) => i.status == 'Available / Free').length;
    final int inUseAssets = items.where((i) => i.status == 'In Use').length;
    final int freeTrolleys = items.where((i) => i.assetType == 'Trolley' && i.status == 'Available / Free').length;
    final double utilizationRate = totalAssets > 0 ? (inUseAssets / totalAssets) * 100 : 0.0;

    return RefreshIndicator(
      onRefresh: () => controller.fetchCurrentReportData(),
      color: const Color(0xFF1B64A3),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Filter Bar
          ReportFilterBar(
            controller: controller,
            searchHint: 'Search Asset Code / Batch / Locator...',
            statusOptions: const ['Available / Free', 'In Use', 'Inactive'],
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
                      title: 'TOTAL ASSETS',
                      value: '$totalAssets',
                      subtitle: '${items.where((i) => i.assetType == "Trolley").length} Trolleys / ${items.where((i) => i.assetType == "Tray").length} Trays',
                      icon: Icons.track_changes_rounded,
                      color: const Color(0xFF1B64A3),
                    ),
                    ReportKpiCard(
                      title: 'AVAILABLE / FREE',
                      value: '$freeAssets',
                      subtitle: '$freeTrolleys Free Trolleys',
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF2E7D32),
                      badgeText: '$freeTrolleys Ready',
                      badgeColor: const Color(0xFF2E7D32),
                    ),
                    ReportKpiCard(
                      title: 'IN USE (LOADED)',
                      value: '$inUseAssets',
                      subtitle: 'Active On Floor',
                      icon: Icons.local_shipping_outlined,
                      color: const Color(0xFFD97706),
                    ),
                    ReportKpiCard(
                      title: 'UTILIZATION',
                      value: '${utilizationRate.toStringAsFixed(1)}%',
                      subtitle: 'Fleet Active Load',
                      icon: Icons.pie_chart_rounded,
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
                  'ASSETS (${items.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Physical Hardware State',
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
                  Icon(Icons.widgets_outlined, size: 48, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text(
                    'No Trays or Trolleys match the active filters',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ],
              ),
            )
          else
            ...items.map((item) => _buildTrayTrolleyCard(item)),
        ],
      ),
    );
  }

  Widget _buildTrayTrolleyCard(TrayTrolleyReportItem assetItem) {
    final bool isFree = assetItem.status == 'Available / Free';
    final bool isInactive = assetItem.status == 'Inactive';
    final bool isTrolley = assetItem.assetType == 'Trolley';

    Color badgeBg = const Color(0xFFDCFCE7);
    Color badgeColor = const Color(0xFF166534);

    if (isInactive) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeColor = const Color(0xFFDC2626);
    } else if (!isFree) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeColor = const Color(0xFFB45309);
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
                      color: isTrolley ? const Color(0xFFEFF6FF) : const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isTrolley ? Icons.local_shipping_outlined : Icons.inventory_2_outlined,
                      size: 16,
                      color: isTrolley ? const Color(0xFF1B64A3) : const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    assetItem.assetCode,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      assetItem.assetType,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
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
                  assetItem.status,
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
                child: _buildMetaItem('Current Location', assetItem.locatorName ?? 'Floor Area'),
              ),
              Expanded(
                child: _buildMetaItem('Assigned Batch', assetItem.currentBatchCode ?? (isFree ? 'None (Free)' : 'Unspecified')),
              ),
              Expanded(
                child: _buildMetaItem('Assigned WO', assetItem.currentWorkOrderCode ?? (isFree ? 'None' : 'N/A')),
              ),
            ],
          ),

          if (!isFree && assetItem.quantity > 0) ...[
            const SizedBox(height: 10),
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
                  const Text(
                    'Loaded Capacity / Quantity:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Text(
                    '${assetItem.quantity.toStringAsFixed(0)} Tubes / Units',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B64A3)),
                  ),
                ],
              ),
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
