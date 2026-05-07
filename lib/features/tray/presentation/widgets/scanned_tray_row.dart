import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/tray/model/scanned_tray.dart';
import 'package:active_wear_scanning/features/tray/model/plan_header_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final isEmpty = tray.trayCode.isEmpty;
    final displayCode = isEmpty ? '-' : tray.trayCode;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
        color: index.isEven ? Colors.white : Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              displayCode,
              style: TextStyle(fontSize: 13, color: isEmpty ? Colors.grey : Colors.black87),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              selectedPlanLine?.workOrderHeader.workOrderCode ?? "-",
              style: TextStyle(fontSize: 12, color: isEmpty ? Colors.grey : Colors.black87),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              selectedPlanLine?.item.description ?? "-",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: isEmpty ? Colors.grey : Colors.black87),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.colorDescription.isNotEmpty ? tray.colorDescription : "-",
              style: TextStyle(fontSize: 11, color: isEmpty ? Colors.grey : Colors.black87, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.sizeDescription.isNotEmpty ? tray.sizeDescription : "-",
              style: TextStyle(fontSize: 11, color: isEmpty ? Colors.grey : Colors.black87),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.perGarmentTube > 0 ? tray.perGarmentTube.toStringAsFixed(0) : '-',
              style: TextStyle(fontSize: 12, color: isEmpty ? Colors.grey : Colors.indigo.shade700, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 55,
                height: 35,
                child: TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 1.5)),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Builder(
              builder: (_) {
                final qty = double.tryParse(quantityController.text) ?? 0;
                final garmentPcs = (tray.perGarmentTube > 0) ? (qty * tray.perGarmentTube) : 0;
                return Text(
                  garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isEmpty ? Colors.grey : Colors.teal.shade700,
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Builder(
              builder: (_) {
                final qty = double.tryParse(quantityController.text) ?? 0;
                final pw = selectedPlanLine?.item.pieceWeight;
                if (pw == null || pw == 0) return const Text('-', style: TextStyle(fontSize: 13));
                return Text('${(qty * pw).toStringAsFixed(2)} g', style: const TextStyle(fontSize: 13));
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
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
