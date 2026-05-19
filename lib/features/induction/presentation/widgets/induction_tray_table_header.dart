import 'package:flutter/material.dart';

class InductionTrayTableHeader extends StatelessWidget {
  const InductionTrayTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: Color(0xFF455A64),
      letterSpacing: 0.2,
    );
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('TRAY CODE', textAlign: TextAlign.start, style: headerStyle)),
          Expanded(flex: 2, child: Text('WORK ORDER', textAlign: TextAlign.start, style: headerStyle)),
          Expanded(flex: 4, child: Text('ITEM DESCRIPTION', textAlign: TextAlign.start, style: headerStyle)),
          Expanded(flex: 2, child: Text('SIZE', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 2, child: Text('TUBES', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 2, child: Text('WEIGHT', textAlign: TextAlign.center, style: headerStyle)),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}
