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
    const headerStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w900,
      color: Color(0xFF64748B),
      letterSpacing: 0.5,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      ),
      child: Row(
        children: [
          if (isKnitting) ...[
            Expanded(flex: 3, child: Text('WORK ORDER', style: headerStyle)),
            Expanded(flex: 3, child: Text('MACHINE', style: headerStyle)),
            Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: headerStyle)),
          ] else if (isProcessing) ...[
            Expanded(flex: 3, child: Text('BATCH NO', style: headerStyle)),
            Expanded(flex: 3, child: Text('MACHINE', style: headerStyle)),
            Expanded(flex: 4, child: Text('COLOR', style: headerStyle)),
          ] else ...[
            Expanded(flex: 4, child: Text('BATCH NO', style: headerStyle)),
            Expanded(flex: 4, child: Text('COLOR', style: headerStyle)),
          ],
          Expanded(flex: 2, child: Text('TRAYS', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 2, child: Text('TUBES', textAlign: TextAlign.center, style: headerStyle)),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}
