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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
        color: displayIndex.isEven ? Colors.white : Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(tray.trayCode, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black87))),
          Expanded(flex: 2, child: Text(tray.workOrderCode, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black87))),
          Expanded(flex: 4, child: Text(tray.itemDescription, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
          Expanded(
            flex: 2, 
            child: Text(tray.colorDescription.isNotEmpty ? tray.colorDescription : '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black87))
          ),
          Expanded(
            flex: 2, 
            child: Text(tray.sizeDescription.isNotEmpty ? tray.sizeDescription : '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black87))
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tray.primaryQuantity,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${((double.tryParse(tray.primaryQuantity) ?? 0.0) * tray.pieceWeight).toStringAsFixed(2)} g',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.cancel, size: 18, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
