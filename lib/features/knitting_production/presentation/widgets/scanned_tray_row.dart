import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/knitting_production/model/scanned_tray.dart';
import 'package:active_wear_scanning/features/knitting_production/model/plan_header_model.dart';

class ScannedTrayRow extends StatelessWidget {
  final int index;
  final ScannedTray tray;
  final TextEditingController quantityController;
  final PlanLineResponseModel? selectedPlanLine;
  final VoidCallback onDelete;

  const ScannedTrayRow({
    super.key,
    required this.index,
    required this.tray,
    required this.quantityController,
    this.selectedPlanLine,
    required this.onDelete,
  });

  static const _cellStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Color(0xFF263238), // Standard Black
  );

  static const _blueCellStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1B64A3), // Premium Blue
  );

  @override
  Widget build(BuildContext context) {
    final isEmpty = tray.trayCode.isEmpty;
    final displayCode = isEmpty ? '-' : tray.trayCode;

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
          // Tray Code (Now Blue)
          Expanded(
            flex: 6,
            child: Text(
              displayCode,
              textAlign: TextAlign.center,
              style: _blueCellStyle.copyWith(
                color: isEmpty ? Colors.grey : const Color(0xFF1B64A3),
              ),
            ),
          ),
          
          // Work Order (Now Black)
          Expanded(
            flex: 4,
            child: Text(
              selectedPlanLine?.workOrderHeader.workOrderCode ?? "-",
              textAlign: TextAlign.center,
              style: _cellStyle,
            ),
          ),
          
          // Size
          Expanded(
            flex: 4,
            child: Text(
              tray.sizeDescription.isNotEmpty ? tray.sizeDescription : "-",
              textAlign: TextAlign.center,
              style: _cellStyle,
            ),
          ),
          
          // Pcs Per Tube
          Expanded(
            flex: 4,
            child: Text(
              tray.perGarmentTube > 0 ? tray.perGarmentTube.toStringAsFixed(0) : '-',
              textAlign: TextAlign.center,
              style: _cellStyle,
            ),
          ),
          
          // Tubes
          Expanded(
            flex: 4,
            child: Text(
              quantityController.text,
              textAlign: TextAlign.center,
              style: _cellStyle,
            ),
          ),
          
          // Pcs
          Expanded(
            flex: 4,
            child: Builder(
              builder: (_) {
                final qty = double.tryParse(quantityController.text) ?? 0;
                final garmentPcs = (tray.perGarmentTube > 0) ? (qty * tray.perGarmentTube) : 0;
                return Text(
                  garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-',
                  textAlign: TextAlign.center,
                  style: _cellStyle,
                );
              },
            ),
          ),
          
          // Weight
          Expanded(
            flex: 4,
            child: Builder(
              builder: (_) {
                final qty = double.tryParse(quantityController.text) ?? 0;
                final pw = selectedPlanLine?.item.pieceWeight;
                if (pw == null || pw == 0) return const Text('-', textAlign: TextAlign.center, style: _cellStyle);
                return Text(
                  '${(qty * pw).toStringAsFixed(1)} g',
                  textAlign: TextAlign.center,
                  style: _cellStyle,
                );
              },
            ),
          ),
          
          // Delete Action
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDelete,
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
