import 'package:flutter/material.dart';

/// A standard table header for scanned tray lists.
/// Shows TRAY CODE, WORK ORDER, ITEM DESCRIPTION, COLOR, SIZE, PCS/TUBE, TUBES, PCS, WEIGHT.
class TrayTableHeader extends StatelessWidget {
  final double actionColumnWidth;

  const TrayTableHeader({
    super.key,
    this.actionColumnWidth = 40.0,
  });

  static final _style = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: Colors.grey.shade700,
    letterSpacing: 1.1,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('TRAY CODE', style: _style)),
          Expanded(flex: 2, child: Text('WORK ORDER', style: _style)),
          Expanded(flex: 3, child: Text('ITEM DESCRIPTION', style: _style)),
          Expanded(flex: 2, child: Text('COLOR', style: _style)),
          Expanded(flex: 2, child: Text('SIZE', style: _style)),
          Expanded(flex: 2, child: Text('PCS/TUBE', style: _style)),
          Expanded(flex: 2, child: Text('TUBES', style: _style)),
          Expanded(flex: 2, child: Text('PCS', style: _style)),
          Expanded(flex: 2, child: Text('WEIGHT', style: _style)),
          SizedBox(width: actionColumnWidth),
        ],
      ),
    );
  }
}
