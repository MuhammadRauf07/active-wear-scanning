import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/features/reports/controller/reports_controller.dart';
import 'package:active_wear_scanning/features/reports/presentation/sub_reports/work_order_report_view.dart';
import 'package:active_wear_scanning/features/reports/presentation/sub_reports/batch_report_view.dart';
import 'package:active_wear_scanning/features/reports/presentation/sub_reports/induction_report_view.dart';
import 'package:active_wear_scanning/features/reports/presentation/sub_reports/tray_trolley_report_view.dart';

class ReportsMainScreen extends StatelessWidget {
  const ReportsMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReportsController>(
      create: (_) => ReportsController(),
      child: const _ReportsMainScreenView(),
    );
  }
}

class _ReportsMainScreenView extends StatelessWidget {
  const _ReportsMainScreenView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportsController>();

    if (controller.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppSnackBar.showError(context, message: controller.errorMessage!);
      });
    }

    final tabs = [
      {'label': 'Work Order Status', 'icon': Icons.assignment_rounded},
      {'label': 'Batch Report', 'icon': Icons.layers_rounded},
      {'label': 'Induction Store', 'icon': Icons.warehouse_rounded},
      {'label': 'Trays & Trolleys', 'icon': Icons.track_changes_rounded},
    ];

    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Standard Slate 100
        body: SafeArea(
          child: Column(
            children: [
              // Top Header
              CustomInspectionHeader(
                heading: 'REPORTS & ANALYTICS',
                subtitle: 'Manufacturing Status & Traceability',
                isShowBackIcon: true,
                topPadding: 12,
                horizontalPadding: 16,
                onBackPress: () => Navigator.of(context).pop(),
              ),

              // Navigation Tabs Ribbon
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    children: List.generate(tabs.length, (index) {
                      final tab = tabs[index];
                      final isSelected = controller.selectedTabIndex == index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => controller.setTabIndex(index),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF1B64A3) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  tab['icon'] as IconData,
                                  size: 16,
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tab['label'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // Body View
              Expanded(
                child: controller.isLoading && _isDatasetEmpty(controller)
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF1B64A3)),
                      )
                    : IndexedStack(
                        index: controller.selectedTabIndex,
                        children: [
                          WorkOrderReportView(controller: controller),
                          BatchReportView(controller: controller),
                          InductionReportView(controller: controller),
                          TrayTrolleyReportView(controller: controller),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isDatasetEmpty(ReportsController controller) {
    switch (controller.selectedTabIndex) {
      case 0:
        return controller.workOrdersList.isEmpty;
      case 1:
        return controller.rawBatchItems.isEmpty;
      case 2:
        return controller.inductionItems.isEmpty;
      case 3:
        return controller.trayTrolleyItems.isEmpty;
      default:
        return true;
    }
  }
}
