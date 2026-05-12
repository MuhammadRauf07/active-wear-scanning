import 'package:flutter/material.dart';

/// A standard table header for scanned tray lists.
/// Shows TRAY CODE, WO, SIZE, PCS/TBE, TUBES, PCS, WEIGHT.
class TrayTableHeader extends StatelessWidget {
  final double actionColumnWidth;

  const TrayTableHeader({
    super.key,
    this.actionColumnWidth = 40.0,
  });

  static final _style = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.bold,
    color: Colors.grey.shade700,
    letterSpacing: 0.3,
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
          Expanded(flex: 3, child: Text('TRAY CODE', textAlign: TextAlign.center, style: _style)),
          Expanded(flex: 2, child: Text('WORK ORDER', textAlign: TextAlign.center, style: _style)),
          Expanded(flex: 2, child: Text('SIZE', textAlign: TextAlign.center, style: _style)),
          Expanded(flex: 2, child: Text('PCS PER TUBE', textAlign: TextAlign.center, style: _style)),
          Expanded(flex: 2, child: Text('TUBES', textAlign: TextAlign.center, style: _style)),
          Expanded(flex: 2, child: Text('PCS', textAlign: TextAlign.center, style: _style)),
          Expanded(flex: 2, child: Text('WEIGHT', textAlign: TextAlign.center, style: _style)),
          SizedBox(width: actionColumnWidth),
        ],
      ),
    );
  }
}
