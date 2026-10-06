import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/reports/controller/reports_controller.dart';

class WorkOrderReportView extends StatefulWidget {
  final ReportsController controller;

  const WorkOrderReportView({super.key, required this.controller});

  @override
  State<WorkOrderReportView> createState() => _WorkOrderReportViewState();
}

class _WorkOrderReportViewState extends State<WorkOrderReportView> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  Widget build(BuildContext context) {

    return Column(
      children: [
        // 1. Selector and Action Controls Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: _buildWorkOrderSelectorBar(context),
        ),

        // 2. Main PDF Viewer Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: _buildPdfViewerContainer(context),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Work Order Selector and Actions Bar
  // ---------------------------------------------------------------------------
  Widget _buildWorkOrderSelectorBar(BuildContext context) {
    final controller = widget.controller;

    final uniqueWOs = <int, WorkOrderHeader>{};
    for (final wo in controller.workOrdersList) {
      if (wo.id > 0) {
        uniqueWOs.putIfAbsent(wo.id, () => wo);
      }
    }
    final int? currentId = controller.selectedWorkOrder?.id;
    final int? dropdownValue = (currentId != null && uniqueWOs.containsKey(currentId)) ? currentId : null;

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
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF1B64A3)),
          ),
          const SizedBox(width: 10),
          const Text(
            'WORK ORDER:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
              letterSpacing: 0.3,
            ),
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
                child: DropdownButton<int>(
                  value: dropdownValue,
                  isExpanded: true,
                  hint: const Text(
                    'Select Work Order',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1B64A3)),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  items: uniqueWOs.values.map((wo) {
                    final code = wo.workOrderCode.isNotEmpty ? wo.workOrderCode : 'WO #${wo.id}';
                    return DropdownMenuItem<int>(
                      value: wo.id,
                      child: Text(code),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      controller.selectWorkOrderById(id);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Fetch Report Action Button
          if (controller.selectedWorkOrder != null) ...[
            InkWell(
              onTap: controller.isPdfLoading ? null : () => controller.fetchSelectedWorkOrderPdf(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: controller.isPdfLoading ? const Color(0xFF94A3B8) : const Color(0xFF1B64A3),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B64A3).withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.isPdfLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.cloud_download_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    const Text(
                      'Fetch Report',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Download / Save Action
          if (controller.workOrderPdfBytes != null) ...[
            Tooltip(
              message: 'Download / Save PDF',
              child: InkWell(
                onTap: () async {
                  final savedPath = await controller.saveCurrentWorkOrderPdf();
                  if (context.mounted) {
                    if (savedPath != null) {
                      AppSnackBar.showSuccess(
                        context,
                        message: 'Report saved successfully!',
                      );
                    } else {
                      AppSnackBar.showError(
                        context,
                        message: 'Failed to save PDF.',
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, size: 16, color: Color(0xFF16A34A)),
                      SizedBox(width: 4),
                      Text(
                        'Download',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Full Screen',
              child: InkWell(
                onTap: () => _openFullScreenPdf(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Icon(Icons.fullscreen_rounded, size: 20, color: Color(0xFF475569)),
                ),
              ),
            ),
          ],

          // Refresh Button
          const SizedBox(width: 6),
          Tooltip(
            message: 'Reload Report',
            child: InkWell(
              onTap: () {
                if (controller.selectedWorkOrder != null) {
                  controller.fetchWorkOrderPdfData(controller.selectedWorkOrder!.id);
                } else {
                  controller.fetchCurrentReportData();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF475569)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. PDF Viewer Box
  // ---------------------------------------------------------------------------
  Widget _buildPdfViewerContainer(BuildContext context) {
    final controller = widget.controller;

    // Loading State
    if (controller.isPdfLoading) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1B64A3), strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              'Generating & loading Work Order PDF...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              controller.selectedWorkOrder != null
                  ? 'Work Order: ${controller.selectedWorkOrder!.workOrderCode}'
                  : '',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    // Error State
    if (controller.pdfError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            const Text(
              'Failed to Load Report',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              controller.pdfError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                if (controller.selectedWorkOrder != null) {
                  controller.fetchWorkOrderPdfData(controller.selectedWorkOrder!.id);
                }
              },
              icon: const Icon(Icons.replay_rounded, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B64A3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    // No Work Order Selected
    if (controller.selectedWorkOrder == null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 54, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'Select Work Order to Fetch Report',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            SizedBox(height: 4),
            Text(
              'Select a work order from the dropdown above to fetch work order report.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    // Work Order Selected, but PDF not fetched yet
    if (controller.workOrderPdfBytes == null) {
      final woCode = controller.selectedWorkOrder!.workOrderCode.isNotEmpty
          ? controller.selectedWorkOrder!.workOrderCode
          : 'WO #${controller.selectedWorkOrder!.id}';
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_outlined, size: 48, color: Color(0xFF1B64A3)),
            ),
            const SizedBox(height: 16),
            Text(
              'Selected Work Order: $woCode',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click the button below to fetch and display the status report.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => controller.fetchSelectedWorkOrderPdf(),
              icon: const Icon(Icons.cloud_download_rounded, size: 18),
              label: const Text('Fetch Report', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B64A3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    // PDF Ready to Display
    if (controller.workOrderPdfBytes != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top PDF Info Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF0F3D69),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'WorkOrderStatusReport_${controller.selectedWorkOrder!.workOrderCode}.pdf',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(controller.workOrderPdfBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF93C5FD),
                    ),
                  ),
                ],
              ),
            ),

            // In-App SfPdfViewer
            Expanded(
              child: SfPdfViewer.memory(
                controller.workOrderPdfBytes!,
                controller: _pdfViewerController,
                enableDoubleTapZooming: true,
                canShowPaginationDialog: true,
                canShowScrollHead: true,
                canShowScrollStatus: true,
              ),
            ),
          ],
        ),
      );
    }

    // Default Fallback
    return const Center(child: CircularProgressIndicator(color: Color(0xFF1B64A3)));
  }

  // ---------------------------------------------------------------------------
  // 3. Full Screen PDF Modal
  // ---------------------------------------------------------------------------
  void _openFullScreenPdf(BuildContext context) {
    final controller = widget.controller;
    if (controller.workOrderPdfBytes == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F3D69),
            foregroundColor: Colors.white,
            title: Text(
              'Work Order: ${controller.selectedWorkOrder?.workOrderCode ?? ""}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: 'Download',
                onPressed: () async {
                  final savedPath = await controller.saveCurrentWorkOrderPdf();
                  if (ctx.mounted) {
                    if (savedPath != null) {
                      AppSnackBar.showSuccess(ctx, message: 'Report saved successfully!');
                    } else {
                      AppSnackBar.showError(ctx, message: 'Failed to save PDF.');
                    }
                  }
                },
              ),
            ],
          ),
          body: SfPdfViewer.memory(
            controller.workOrderPdfBytes!,
            enableDoubleTapZooming: true,
            canShowPaginationDialog: true,
          ),
        ),
      ),
    );
  }
}
