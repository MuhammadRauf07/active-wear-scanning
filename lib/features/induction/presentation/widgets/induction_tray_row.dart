import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/gbs/model/gbs_scanned_tray.dart';

class InductionTrayRow extends StatelessWidget {
  final int index;
  final GBSScannedTray tray;
  final int displayIndex;
  final VoidCallback onRemove;

  const InductionTrayRow({
    super.key,
    required this.index,
    required this.tray,
    required this.displayIndex,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final weight = (double.tryParse(tray.primaryQuantity) ?? 0.0) * tray.pieceWeight;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: displayIndex.isOdd ? const Color(0xFFF8FAFC) : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(tray.trayCode, style: _cellStyle(isBold: true, color: const Color(0xFF0D47A1)))),
          Expanded(flex: 2, child: Text(tray.workOrderCode, style: _cellStyle(isSmall: true))),
          Expanded(flex: 4, child: Text(tray.itemDescription, style: _cellStyle(isSmall: true), maxLines: 2, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(tray.colorDescription.isNotEmpty ? tray.colorDescription : '-', style: _cellStyle(isBold: true))),
          Expanded(flex: 2, child: Text(tray.sizeDescription.isNotEmpty ? tray.sizeDescription : '-', style: _cellStyle())),
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(tray.primaryQuantity, textAlign: TextAlign.center, style: _cellStyle(isBold: true)),
            ),
          ),
          Expanded(flex: 2, child: Text('${weight.toStringAsFixed(1)} g', style: _cellStyle())),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  TextStyle _cellStyle({bool isBold = false, bool isSmall = false, Color? color}) {
    return TextStyle(
      fontSize: isSmall ? 10 : 11,
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
      color: color ?? const Color(0xFF1E293B),
    );
  }
}
