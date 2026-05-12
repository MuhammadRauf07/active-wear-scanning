import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/processing/model/batch_summary_item.dart';

class BatchStatusRow extends StatelessWidget {
  final BatchSummaryItem summary;
  final VoidCallback onDetailsPressed;

  const BatchStatusRow({
    super.key,
    required this.summary,
    required this.onDetailsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = summary.reworkFlag
        ? Colors.amber.shade800
        : summary.isStarted
            ? Colors.green.shade700
            : Colors.orange.shade700;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              summary.batchCode,
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              summary.machine,
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              summary.color,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              summary.totalTubes.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
              ),
            ),
          ),
          // Weight and Trolley removed
          Expanded(
            flex: 2,
            child: Text(
              summary.reworkFlag ? 'Yes' : 'No',
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              summary.isStarted ? 'Started' : 'Offered',
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: onDetailsPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  child: const Text('Batch Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
