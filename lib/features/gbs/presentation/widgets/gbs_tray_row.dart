import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/gbs/model/gbs_scanned_tray.dart';

class GBSTrayRow extends StatelessWidget {
  final int index;
  final GBSScannedTray tray;
  final VoidCallback onRemove;

  const GBSTrayRow({
    super.key,
    required this.index,
    required this.tray,
    required this.onRemove,
  });

  static const _cellStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Color(0xFF263238),
  );

  static const _blueCellStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1B64A3),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              tray.trayCode,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: _blueCellStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.workOrderCode,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: _cellStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.sizeDescription.isNotEmpty ? tray.sizeDescription : '-',
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: _cellStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.perGarmentTube > 0 ? tray.perGarmentTube.toStringAsFixed(0) : '-',
              textAlign: TextAlign.center,
              style: _cellStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.primaryQuantity,
              textAlign: TextAlign.center,
              style: _cellStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Builder(
              builder: (_) {
                final tubes = double.tryParse(tray.primaryQuantity) ?? 0;
                final garmentPcs = (tray.perGarmentTube > 0) ? (tubes * tray.perGarmentTube) : 0;
                return Text(
                  garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-',
                  textAlign: TextAlign.center,
                  style: _cellStyle,
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${((double.tryParse(tray.primaryQuantity) ?? 0.0) * tray.pieceWeight).toStringAsFixed(1)} g',
              textAlign: TextAlign.center,
              style: _cellStyle,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red.shade400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
