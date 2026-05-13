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
        color: index.isEven ? Colors.white : const Color(0xFFF5F2F9), // Light Purple/Lavender shade
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              displayCode,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: isEmpty ? Colors.grey : Colors.black),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              selectedPlanLine?.workOrderHeader.workOrderCode ?? "-",
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: isEmpty ? Colors.grey : Colors.black),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.sizeDescription.isNotEmpty ? tray.sizeDescription : "-",
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: isEmpty ? Colors.grey : Colors.black),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tray.perGarmentTube > 0 ? tray.perGarmentTube.toStringAsFixed(0) : '-',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: isEmpty ? Colors.grey : Colors.black),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: SizedBox(
                width: 44,
                height: 30,
                child: TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: isEmpty ? Colors.grey : Colors.black),
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
                if (pw == null || pw == 0) return const Text('-', textAlign: TextAlign.center, style: TextStyle(fontSize: 9));
                return Text(
                  '${(qty * pw).toStringAsFixed(1)} g',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9, color: Colors.black),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.cancel, size: 14, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
