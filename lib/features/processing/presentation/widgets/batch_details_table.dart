import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/processing/model/batch_summary_item.dart';
import 'package:active_wear_scanning/features/processing/presentation/widgets/batch_status_row.dart';

class BatchDetailsTable extends StatelessWidget {
  final bool isLoading;
  final List<BatchSummaryItem>? summaries;
  final Function(BatchSummaryItem) onDetailsPressed;

  const BatchDetailsTable({
    super.key,
    required this.isLoading,
    required this.summaries,
    required this.onDetailsPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(10.5),
            bottomRight: Radius.circular(10.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  _buildHeaderCell('BATCH #', 2, align: TextAlign.center),
                  _buildHeaderCell('MACHINE', 2, align: TextAlign.center),
                  _buildHeaderCell('COLOR', 3, align: TextAlign.center),
                  _buildHeaderCell('TUBES', 1, align: TextAlign.center),
                  _buildHeaderCell('RE-ASSIGN', 2, align: TextAlign.center),
                  _buildHeaderCell('REWORK', 2, align: TextAlign.center),
                  _buildHeaderCell('STATE', 2, align: TextAlign.center),
                  const SizedBox(width: 24),
                ],
              ),
            ),
            ...List.generate(3, (i) => _buildSkeletonRow(isLast: i == 2)),
          ],
        ),
      );
    }

    if (summaries == null || summaries!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No batches currently issued to this operation.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(10.5), // Card radius (12) - Padding (1.5)
          bottomRight: Radius.circular(10.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Grid Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9), // Subtle Slate 100
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _buildHeaderCell('BATCH #', 2, align: TextAlign.center),
                _buildHeaderCell('MACHINE', 2, align: TextAlign.center),
                _buildHeaderCell('COLOR', 3, align: TextAlign.center),
                _buildHeaderCell('TUBES', 1, align: TextAlign.center),
                _buildHeaderCell('RE-ASSIGN', 2, align: TextAlign.center),
                _buildHeaderCell('REWORK', 2, align: TextAlign.center),
                _buildHeaderCell('STATE', 2, align: TextAlign.center),
                const SizedBox(width: 24), // Action column spacer
              ],
            ),
          ),

          // ── Data Rows ────────────────────────────────────────────────────────
          ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: summaries!.length,
            itemBuilder: (context, index) {
              return BatchStatusRow(
                summary: summaries![index],
                isLast: index == summaries!.length - 1,
                onDetailsPressed: () => onDetailsPressed(summaries![index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonRow({bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: _skeletonBox(width: 50, height: 10)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _skeletonBox(width: 45, height: 10)),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _skeletonBox(width: 70, height: 10)),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: _skeletonBox(width: 25, height: 10)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _skeletonBox(width: 30, height: 10)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _skeletonBox(width: 30, height: 10)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _skeletonBox(width: 55, height: 14, radius: 4)),
          const SizedBox(width: 8),
          _skeletonBox(width: 24, height: 24, radius: 6),
        ],
      ),
    );
  }

  Widget _skeletonBox({required double width, required double height, double radius = 3}) {
    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String label, int flex, {TextAlign align = TextAlign.center}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: Color(0xFF475569),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
