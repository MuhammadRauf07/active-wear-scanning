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
    // Row tint: rework overrides status color
    final Color rowBg = summary.reworkFlag
        ? Colors.amber.shade50
        : summary.isStarted
            ? Colors.green.shade50
            : Colors.orange.shade50;
    final Color accentColor = summary.reworkFlag
        ? Colors.amber.shade400
        : summary.isStarted
            ? Colors.green.shade400
            : Colors.orange.shade400;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: accentColor, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              summary.batchCode,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              summary.machine,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              summary.color,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${summary.trayCount} trays',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${summary.totalWeight.toStringAsFixed(2)} g',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              summary.trolleyCode ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: summary.trolleyCode != null ? Colors.teal.shade700 : Colors.grey.shade400,
              ),
            ),
          ),
          // REWORK — plain text
          Expanded(
            flex: 2,
            child: Text(
              summary.reworkFlag ? 'Yes' : 'No',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: summary.reworkFlag ? Colors.amber.shade800 : Colors.grey.shade500,
              ),
            ),
          ),
          // STATUS — plain text
          Expanded(
            flex: 2,
            child: Text(
              summary.isStarted ? 'Started' : 'Issued',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: summary.isStarted ? Colors.green.shade700 : Colors.orange.shade700,
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
