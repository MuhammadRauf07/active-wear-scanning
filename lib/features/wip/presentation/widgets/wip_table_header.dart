import 'package:flutter/material.dart';

class WIPTableHeader extends StatelessWidget {
  final bool isKnitting;
  final bool isProcessing;

  const WIPTableHeader({
    super.key,
    required this.isKnitting,
    required this.isProcessing,
  });

  static final _tableHeaderStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: Colors.grey.shade700,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          if (isKnitting) ...[
            Expanded(flex: 3, child: Text('WORK ORDER', style: _tableHeaderStyle)),
            Expanded(flex: 3, child: Text('MACHINE', style: _tableHeaderStyle)),
            Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: _tableHeaderStyle)),
          ] else ...[
            Expanded(flex: 4, child: Text('BATCH NO', style: _tableHeaderStyle)),
            Expanded(flex: 4, child: Text('COLOR', style: _tableHeaderStyle)),
          ],
          Expanded(flex: 2, child: Text('TRAYS', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('TUBES', style: _tableHeaderStyle)),
          const SizedBox(width: 40), // Space for action button
        ],
      ),
    );
  }
}
