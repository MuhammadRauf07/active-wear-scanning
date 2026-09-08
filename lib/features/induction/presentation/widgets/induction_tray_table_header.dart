import 'package:flutter/material.dart';

class InductionTrayTableHeader extends StatelessWidget {
  final bool showActionColumn;
  final bool centerAlignAll;

  const InductionTrayTableHeader({
    super.key,
    this.showActionColumn = true,
    this.centerAlignAll = false,
  });

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF455A64),
      letterSpacing: centerAlignAll ? 0.4 : 0.2,
    );
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('TRAY CODE', textAlign: centerAlignAll ? TextAlign.center : TextAlign.start, style: headerStyle)),
          Expanded(flex: 2, child: Text('WORK ORDER', textAlign: centerAlignAll ? TextAlign.center : TextAlign.start, style: headerStyle)),
          Expanded(flex: 4, child: Text('ITEM DESCRIPTION', textAlign: centerAlignAll ? TextAlign.center : TextAlign.start, style: headerStyle)),
          Expanded(flex: 2, child: Text('SIZE', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 2, child: Text('TUBES', textAlign: TextAlign.center, style: headerStyle)),
          Expanded(flex: 2, child: Text('WEIGHT', textAlign: TextAlign.center, style: headerStyle)),
          if (showActionColumn) const SizedBox(width: 44),
        ],
      ),
    );
  }
}
