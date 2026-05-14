import 'dart:ui';
import 'package:flutter/material.dart';

class TrayTableHeader extends StatelessWidget {
  final double actionColumnWidth;

  const TrayTableHeader({
    super.key,
    this.actionColumnWidth = 40.0,
  });

  static const _headerStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Color(0xFF455A64), // Slate Grey
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9), // Very light slate blue/grey
        border: Border(
          bottom: BorderSide(color: Color(0xFFCFD8DC), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Tray Code', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 2, child: Text('Work Order', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 2, child: Text('Size', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 2, child: Text('Pcs/Tube', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 2, child: Text('Tubes', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 2, child: Text('Pcs', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 2, child: Text('Weight', textAlign: TextAlign.center, style: _headerStyle)),
          SizedBox(width: actionColumnWidth),
        ],
      ),
    );
  }
}
