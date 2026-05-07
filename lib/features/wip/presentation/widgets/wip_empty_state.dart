import 'package:flutter/material.dart';

class WIPEmptyState extends StatelessWidget {
  const WIPEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No WIP entries found in this locator', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
