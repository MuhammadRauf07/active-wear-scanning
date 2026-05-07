import 'package:flutter/material.dart';

class InductionTrayTableHeader extends StatelessWidget {
  const InductionTrayTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      color: Colors.grey.shade700,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('TRAY CODE', style: headerStyle)),
          Expanded(flex: 2, child: Text('WORK ORDER', style: headerStyle)),
          Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: headerStyle)),
          Expanded(flex: 2, child: Text('COLOR', style: headerStyle)),
          Expanded(flex: 2, child: Text('SIZE', style: headerStyle)),
          Expanded(flex: 2, child: Text('TUBES', style: headerStyle)),
          Expanded(flex: 2, child: Text('WEIGHT', style: headerStyle)),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}
