import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/features/reports/controller/reports_controller.dart';

class KnitPlanReportView extends StatefulWidget {
  final ReportsController controller;

  const KnitPlanReportView({super.key, required this.controller});

  @override
  State<KnitPlanReportView> createState() => _KnitPlanReportViewState();
}

class _KnitPlanReportViewState extends State<KnitPlanReportView> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Selector and Action Controls Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: _buildKnitPlanSelectorBar(context),
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
  // 1. Knit Plan Selector and Actions Bar
  // ---------------------------------------------------------------------------
  Widget _buildKnitPlanSelectorBar(BuildContext context) {
    final controller = widget.controller;
    final fromDateStr = DateFormat('yyyy-MM-dd').format(controller.knitPlanFromDate);
    final toDateStr = DateFormat('yyyy-MM-dd').format(controller.knitPlanToDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter controls row (wrapping on smaller screens)
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Title Pill
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF1B64A3)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'KNIT PLAN:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),

              // From Date Picker Button
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: controller.knitPlanFromDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    controller.setKnitPlanFromDate(picked);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF1B64A3)),
                      const SizedBox(width: 6),
                      Text(
                        'From: $fromDateStr',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // To Date Picker Button
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: controller.knitPlanToDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    controller.setKnitPlanToDate(picked);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_rounded, size: 14, color: Color(0xFF1B64A3)),
                      const SizedBox(width: 6),
                      Text(
                        'To: $toDateStr',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Shift Dropdown
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: controller.selectedKnitPlanShiftId,
                    hint: const Text(
                      'All Shifts',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1B64A3)),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All Shifts'),
                      ),
                      ...controller.shifts.map((shift) {
                        final label = shift.code.isNotEmpty
                            ? (shift.description != null && shift.description!.isNotEmpty
                                ? '${shift.code} (${shift.description})'
                                : shift.code)
                            : 'Shift #${shift.id}';
                        return DropdownMenuItem<int?>(
                          value: shift.id,
                          child: Text(label),
                        );
                      }),
                    ],
                    onChanged: (shiftId) {
                      controller.setKnitPlanShiftId(shiftId);
                    },
                  ),
                ),
              ),

              // Fetch Report Action Button
              InkWell(
                onTap: controller.isKnitPlanPdfLoading ? null : () => controller.fetchKnitPlanPdfData(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: controller.isKnitPlanPdfLoading ? const Color(0xFF94A3B8) : const Color(0xFF1B64A3),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B64A3).withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.isKnitPlanPdfLoading) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                      ],
                      const Text(
                        'Fetch Report',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Save/Download Button (shown if PDF loaded)
              if (controller.knitPlanPdfBytes != null) ...[
                InkWell(
                  onTap: () async {
                    final savedPath = await controller.saveCurrentKnitPlanPdf();
                    if (!context.mounted) return;
                    if (savedPath != null) {
                      AppSnackBar.showSuccess(context, message: 'Knit Plan Report saved successfully!');
                    } else {
                      AppSnackBar.showError(context, message: 'Could not save PDF file.');
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Save PDF',
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
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Main PDF Viewer Area
  // ---------------------------------------------------------------------------
  Widget _buildPdfViewerContainer(BuildContext context) {
    final controller = widget.controller;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _buildPdfViewerContent(context, controller),
    );
  }

  Widget _buildPdfViewerContent(BuildContext context, ReportsController controller) {
    // 1. Loading State
    if (controller.isKnitPlanPdfLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B64A3)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Generating Knit Plan Report PDF...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Contacting server and rendering document...',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    // 2. Error State
    if (controller.knitPlanPdfError != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 36, color: Color(0xFFDC2626)),
              const SizedBox(height: 10),
              const Text(
                'Report Fetch Failed',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF991B1B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                controller.knitPlanPdfError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => controller.fetchKnitPlanPdfData(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. PDF Bytes Available State
    if (controller.knitPlanPdfBytes != null) {
      return Stack(
        children: [
          SfPdfViewer.memory(
            controller.knitPlanPdfBytes!,
            controller: _pdfViewerController,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            enableDoubleTapZooming: true,
          ),

          // Floating Controls Bar
          Positioned(
            top: 10,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_in_rounded, size: 18, color: Color(0xFF1E293B)),
                    tooltip: 'Zoom In',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => _pdfViewerController.zoomLevel += 0.25,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.zoom_out_rounded, size: 18, color: Color(0xFF1E293B)),
                    tooltip: 'Zoom Out',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      if (_pdfViewerController.zoomLevel > 1.0) {
                        _pdfViewerController.zoomLevel -= 0.25;
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.first_page_rounded, size: 18, color: Color(0xFF1E293B)),
                    tooltip: 'First Page',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => _pdfViewerController.firstPage(),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 4. Initial Prompt State
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDBEAFE), width: 2),
              ),
              child: const Icon(
                Icons.calendar_view_week_rounded,
                size: 48,
                color: Color(0xFF1B64A3),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Select Date Range & Shift',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose From Date, To Date and Shift from the top bar,\nthen tap "Fetch Report" to generate the Knit Plan PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => controller.fetchKnitPlanPdfData(),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('Fetch Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B64A3),
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
