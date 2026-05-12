import 'package:flutter/material.dart';

class TrayStatusBadge extends StatelessWidget {
  final bool isReassigned;

  const TrayStatusBadge({
    super.key,
    required this.isReassigned,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isReassigned ? Colors.greenAccent.shade400 : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isReassigned ? Icons.check_circle : Icons.pending,
            size: 12,
            color: isReassigned ? Colors.white : Colors.white70,
          ),
          const SizedBox(width: 4),
          Text(
            isReassigned ? 'REASSIGNED' : 'PENDING',
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
