import 'package:flutter/material.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
              _buildHeaderCell('BATCH #', 2),
              _buildHeaderCell('MACHINE', 2),
              _buildHeaderCell('COLOR', 3),
              _buildHeaderCell('TUBES', 1, align: TextAlign.center),
              _buildHeaderCell('RE-ASSIGN', 2, align: TextAlign.center),
              _buildHeaderCell('REWORK', 2, align: TextAlign.center),
              _buildHeaderCell('STATE', 2, align: TextAlign.center),
              const SizedBox(width: 32), // Action column spacer
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

  Widget _buildHeaderCell(String label, int flex, {TextAlign align = TextAlign.start}) {
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
