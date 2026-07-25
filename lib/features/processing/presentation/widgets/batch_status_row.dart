import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/processing/model/batch_summary_item.dart';

class BatchStatusRow extends StatelessWidget {
  final BatchSummaryItem summary;
  final VoidCallback onDetailsPressed;
  final bool isLast;

  const BatchStatusRow({
    super.key,
    required this.summary,
    required this.onDetailsPressed,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: isLast 
            ? null 
            : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // 1. Batch ID
          Expanded(
            flex: 2,
            child: Text(
              summary.batchCode,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1B64A3),
              ),
            ),
          ),
          
          // 2. Machine
          Expanded(
            flex: 2,
            child: Text(
              summary.machine.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
          
          // 3. Color
          Expanded(
            flex: 3,
            child: Text(
              summary.color,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ),
          
          // 4. Tubes
          Expanded(
            flex: 1,
            child: Text(
              summary.totalTubes.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          
          // 5. Re-assign
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                summary.isReassigned == true ? 'Yes' : 'No',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: summary.isReassigned == true ? const Color(0xFF1B64A3) : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          
          // 6. Rework
          Expanded(
            flex: 2,
            child: Center(
              child: _buildReworkIndicator(),
            ),
          ),
          
          // 7. State Badge
          Expanded(
            flex: 2,
            child: Center(
              child: _buildStateBadge(),
            ),
          ),
          
          // 8. Action
          GestureDetector(
            onTap: onDetailsPressed,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF1B64A3).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF1B64A3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReworkIndicator() {
    if (summary.reworkFlag == true) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yes',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFFEF4444),
            ),
          ),
          Transform.translate(
            offset: const Offset(1, -2),
            child: const Icon(
              Icons.error_rounded,
              size: 8,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      );
    } else {
      return const Text(
        'No',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
        ),
      );
    }
  }

  Widget _buildStateBadge() {
    final bool isStarted = summary.isStarted == true;
    final bool isDraft = summary.isDraft == true;

    final String label = isDraft
        ? 'SAVED AS DRAFT'
        : (isStarted ? 'STARTED' : 'OFFERED');
    final Color bgColor = isDraft
        ? const Color(0xFFEFF6FF)
        : (isStarted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7));
    final Color textColor = isDraft
        ? const Color(0xFF1E40AF)
        : (isStarted ? const Color(0xFF166534) : const Color(0xFF92400E));
    final IconData icon = isDraft
        ? Icons.drafts_outlined
        : (isStarted ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
