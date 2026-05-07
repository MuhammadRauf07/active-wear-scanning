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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        color: index.isEven ? Colors.white : Colors.blue.shade50.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          if (isKnitting) ...[
            Expanded(flex: 3, child: Text(group.title1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
            Expanded(flex: 3, child: Text(group.title2, style: const TextStyle(fontSize: 11))),
            Expanded(flex: 4, child: Text(group.subtitle ?? '-', style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ] else ...[
            Expanded(flex: 4, child: Text(group.title1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
            Expanded(flex: 4, child: Text(group.title2, style: const TextStyle(fontSize: 11))),
          ],
          Expanded(flex: 2, child: Text(group.trayCount.toString(), style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text(group.totalPcs.toInt().toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
          IconButton(
            icon: const Icon(Icons.list_alt_rounded, size: 20, color: Colors.blue),
            onPressed: onViewDetails,
            tooltip: 'View Tray Details',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}
