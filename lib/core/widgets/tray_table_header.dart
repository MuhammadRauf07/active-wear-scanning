import 'dart:ui';
import 'package:flutter/material.dart';

class TrayTableHeader extends StatelessWidget {
  final double actionColumnWidth;
  final bool showWorkOrderColumn;
  final bool showLotColumn;
  final bool showBatchTubes;
  final bool showDetailedTubes;
  final bool showHoldColumn;

  const TrayTableHeader({
    super.key,
    this.actionColumnWidth = 40.0,
    this.showWorkOrderColumn = true,
    this.showLotColumn = false,
    this.showBatchTubes = false,
    this.showDetailedTubes = false,
    this.showHoldColumn = false,
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
          bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 6, child: Text('TRAY CODE', textAlign: TextAlign.center, style: _headerStyle)),
          if (showWorkOrderColumn)
            Expanded(flex: 4, child: Text('WORK ORDER', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 4, child: Text('SIZE', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 4, child: Text('PCS/TUBE', textAlign: TextAlign.center, style: _headerStyle)),
          if (showDetailedTubes) ...[
            Expanded(flex: 3, child: Text('ACTUAL', textAlign: TextAlign.center, style: _headerStyle)),
            Expanded(flex: 3, child: Text('ALREADY', textAlign: TextAlign.center, style: _headerStyle)),
            Expanded(flex: 3, child: Text('REMAIN', textAlign: TextAlign.center, style: _headerStyle)),
          ] else ...[
            Expanded(flex: 4, child: Text('TUBES', textAlign: TextAlign.center, style: _headerStyle)),
          ],
          Expanded(flex: 4, child: Text('PCS', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 4, child: Text('WEIGHT', textAlign: TextAlign.center, style: _headerStyle)),
          if (showLotColumn)
            Expanded(flex: 6, child: Text('LOT #', textAlign: TextAlign.center, style: _headerStyle)),
          if (showBatchTubes)
            Expanded(flex: 4, child: Text('BATCH TUBES', textAlign: TextAlign.center, style: _headerStyle)),
          if (showHoldColumn)
            Expanded(flex: 3, child: Text('HOLD', textAlign: TextAlign.center, style: _headerStyle)),
          SizedBox(width: actionColumnWidth),
        ],
      ),
    );
  }
}
