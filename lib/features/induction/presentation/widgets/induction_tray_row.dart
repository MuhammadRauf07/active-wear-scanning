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
          Expanded(flex: 2, child: Text(tray.sizeDescription.isNotEmpty ? tray.sizeDescription : '-', textAlign: TextAlign.center, style: _cellStyle())),
          Expanded(
            flex: 2,
            child: Text(
              tray.primaryQuantity,
              textAlign: TextAlign.center,
              style: _cellStyle(isBold: true),
            ),
          ),
          Expanded(flex: 2, child: Text('${weight.toStringAsFixed(1)} g', textAlign: TextAlign.center, style: _cellStyle())),
          IconButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: const Text('Are you sure you want to delete this tray?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                onRemove();
              }
            },
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  TextStyle _cellStyle({bool isBold = false, bool isSmall = false, Color? color}) {
    return TextStyle(
      fontSize: isSmall ? 8.5 : 9.0,
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
      color: color ?? const Color(0xFF1E293B),
    );
  }
}
