import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/carton_packing/model/carton_packing_scanned_item.dart';

class CartonPackingRow extends StatelessWidget {
  final int index;
  final PackingInstructionResponseModel item;
  final VoidCallback onRemove;

  const CartonPackingRow({
    super.key,
    required this.index,
    required this.item,
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
    final detail = item.packingInstructionLineDetail;
    final header = item.packingInstructionHeader;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Carton ID
          Expanded(
            flex: 4,
            child: Text(
              detail.uniqueId,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _blueCellStyle,
            ),
          ),
          // Carton Group
          Expanded(
            flex: 4,
            child: Text(
              header.cartonGroup,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: _cellStyle,
            ),
          ),
          // Packs per Carton
          Expanded(
            flex: 2,
            child: Text(
              header.packsPerCarton.toString(),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: _cellStyle,
            ),
          ),
          const SizedBox(width: 8),
          // Action Delete
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
