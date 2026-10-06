import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/features/reports/controller/reports_controller.dart';
import 'package:active_wear_scanning/features/reports/model/report_models.dart';

class BatchReportView extends StatefulWidget {
  final ReportsController controller;

  const BatchReportView({super.key, required this.controller});

  @override
  State<BatchReportView> createState() => _BatchReportViewState();
}

class _BatchReportViewState extends State<BatchReportView> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Selector and Action Controls Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: _buildBatchSelectorBar(context),
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
  // 1. Batch Selector and Actions Bar
  // ---------------------------------------------------------------------------
  Widget _buildBatchSelectorBar(BuildContext context) {
    final controller = widget.controller;

    final uniqueBatches = <int, BatchReportItem>{};
    for (final b in controller.rawBatchItems) {
      if (b.batchHeader.id != null && b.batchHeader.id! > 0) {
        uniqueBatches.putIfAbsent(b.batchHeader.id!, () => b);
      }
    }
    final sortedBatches = uniqueBatches.values.toList()
      ..sort((a, b) => (b.batchHeader.id ?? 0).compareTo(a.batchHeader.id ?? 0));
    final int? currentId = controller.selectedBatch?.batchHeader.id;
    final int? dropdownValue = (currentId != null && uniqueBatches.containsKey(currentId)) ? currentId : null;

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
            'BATCH:',
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
                  hint: Text(
                    controller.isLoading ? 'Loading Batches...' : 'Select Batch',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1B64A3)),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  items: sortedBatches.map((batch) {
                    return DropdownMenuItem<int>(
                      value: batch.batchHeader.id!,
                      child: Text(batch.batchCode.isNotEmpty ? batch.batchCode : 'LOT-${batch.batchHeader.id}'),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      controller.selectBatchById(id);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Fetch Report Action Button
          if (controller.selectedBatch != null) ...[
            InkWell(
              onTap: controller.isBatchPdfLoading ? null : () => controller.fetchSelectedBatchPdf(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: controller.isBatchPdfLoading ? const Color(0xFF94A3B8) : const Color(0xFF1B64A3),
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
                    if (controller.isBatchPdfLoading)
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
          if (controller.batchPdfBytes != null) ...[
            Tooltip(
              message: 'Download / Save PDF',
              child: InkWell(
                onTap: () async {
                  final savedPath = await controller.saveCurrentBatchPdf();
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
                final batch = controller.selectedBatch;
                if (batch != null && batch.batchHeader.id != null) {
                  controller.fetchBatchPdfData(batch.batchHeader.id!);
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
    if (controller.isBatchPdfLoading) {
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
            const Text(
              'Generating & loading Batch PDF...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              controller.selectedBatch != null
                  ? 'Batch: ${controller.selectedBatch!.batchCode}'
                  : '',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    // Error State
    if (controller.batchPdfError != null) {
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
              controller.batchPdfError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                final batch = controller.selectedBatch;
                if (batch != null && batch.batchHeader.id != null) {
                  controller.fetchBatchPdfData(batch.batchHeader.id!);
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

    // No Batch Selected
    if (controller.selectedBatch == null) {
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
            Icon(Icons.layers_outlined, size: 54, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'Select Batch to Fetch Report',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            SizedBox(height: 4),
            Text(
              'Select a batch from the dropdown above to fetch batch report.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    // Batch Selected, but PDF not fetched yet
    if (controller.batchPdfBytes == null) {
      final batchCode = controller.selectedBatch!.batchCode;
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
              'Selected Batch: $batchCode',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click the button below to fetch and display the batch detail report.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => controller.fetchSelectedBatchPdf(),
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
    if (controller.batchPdfBytes != null) {
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
                      'BatchDetailReport_${controller.selectedBatch!.batchCode}.pdf',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(controller.batchPdfBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
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
                controller.batchPdfBytes!,
                controller: _pdfViewerController,
                enableDoubleTapZooming: true,
                canShowPaginationDialog: true,
                canShowScrollHead: true,
                canShowScrollStatus: true,
                onDocumentLoaded: (details) {
                  print("SfPdfViewer document successfully loaded: ${details.document.pages.count} pages");
                },
                onDocumentLoadFailed: (details) {
                  print("SfPdfViewer load failed: ${details.error} (${details.description})");
                },
              ),
            ),
          ],
        ),
      );
    }

    // Default Fallback
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            controller.selectedBatch != null
                ? 'Ready to load PDF for ${controller.selectedBatch!.batchCode}'
                : 'No Batch Selected',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),
          if (controller.selectedBatch != null && controller.selectedBatch!.batchHeader.id != null)
            ElevatedButton.icon(
              onPressed: () {
                controller.fetchBatchPdfData(controller.selectedBatch!.batchHeader.id!);
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Load PDF Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B64A3),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Full Screen PDF Modal
  // ---------------------------------------------------------------------------
  void _openFullScreenPdf(BuildContext context) {
    final controller = widget.controller;
    if (controller.batchPdfBytes == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F3D69),
            foregroundColor: Colors.white,
            title: Text(
              'Batch: ${controller.selectedBatch?.batchCode ?? ""}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: 'Download',
                onPressed: () async {
                  final savedPath = await controller.saveCurrentBatchPdf();
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
            controller.batchPdfBytes!,
            enableDoubleTapZooming: true,
            canShowPaginationDialog: true,
          ),
        ),
      ),
    );
  }
}
