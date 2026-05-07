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
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (summaries == null || summaries!.isEmpty) {
      return const ContentCard(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 32),
                SizedBox(height: 8),
                Text(
                  'No batches found for this operation.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tableHeaderStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade700,
    );

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 2, child: Text('BATCH ID', style: tableHeaderStyle)),
              Expanded(flex: 2, child: Text('MACHINE', style: tableHeaderStyle)),
              Expanded(flex: 2, child: Text('COLOR', style: tableHeaderStyle)),
              Expanded(flex: 2, child: Text('TRAYS', style: tableHeaderStyle)),
              Expanded(flex: 2, child: Text('WEIGHT', style: tableHeaderStyle)),
              Expanded(flex: 2, child: Text('TROLLY', style: tableHeaderStyle)),
              Expanded(flex: 2, child: Text('REWORK', style: tableHeaderStyle)),
              Expanded(flex: 2, child: Text('STATUS', style: tableHeaderStyle)),
              const Expanded(flex: 3, child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 8),
          ...summaries!.map((s) => BatchStatusRow(
            summary: s,
            onDetailsPressed: () => onDetailsPressed(s),
          )),
        ],
      ),
    );
  }
}
