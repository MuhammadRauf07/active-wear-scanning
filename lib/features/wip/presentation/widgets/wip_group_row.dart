import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/wip/model/wip_group.dart';

class WIPGroupRow extends StatelessWidget {
  final int index;
  final WIPGroup group;
  final bool isKnitting;
  final bool isProcessing;
  final VoidCallback onViewDetails;

  const WIPGroupRow({
    super.key,
    required this.index,
    required this.group,
    required this.isKnitting,
    required this.isProcessing,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: index.isOdd ? const Color(0xFFF8FAFC) : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          if (isKnitting) ...[
            Expanded(flex: 3, child: Text(group.title1, style: _cellStyle(isBold: true, color: const Color(0xFF0D47A1)))),
            Expanded(flex: 3, child: Text(group.title2, style: _cellStyle())),
            Expanded(flex: 4, child: Text(group.subtitle ?? '-', style: _cellStyle(isSmall: true), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ] else if (isProcessing) ...[
            Expanded(flex: 3, child: Text(group.title1, style: _cellStyle(isBold: true, color: const Color(0xFF0D47A1)))),
            Expanded(flex: 3, child: Text(group.title2, style: _cellStyle())),
            Expanded(flex: 4, child: Text(group.title3 ?? '-', style: _cellStyle())),
          ] else ...[
            Expanded(flex: 4, child: Text(group.title1, style: _cellStyle(isBold: true, color: const Color(0xFF0D47A1)))),
            Expanded(flex: 4, child: Text(group.title2, style: _cellStyle())),
          ],
          Expanded(flex: 2, child: Text(group.trayCount.toString(), textAlign: TextAlign.center, style: _cellStyle())),
          Expanded(flex: 2, child: Text(group.totalPcs.toInt().toString(), textAlign: TextAlign.center, style: _cellStyle(isBold: true, color: const Color(0xFF059669)))),
          IconButton(
            onPressed: onViewDetails,
            icon: const Icon(Icons.analytics_rounded, color: Color(0xFF0D47A1), size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: 'View Details',
          ),
        ],
      ),
    );
  }

  TextStyle _cellStyle({bool isBold = false, bool isSmall = false, Color? color}) {
    return TextStyle(
      fontSize: isSmall ? 10 : 11,
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
      color: color ?? const Color(0xFF1E293B),
    );
  }
}
