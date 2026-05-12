import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:flutter/material.dart';

/// A single scanned tray row in the [BatchScanningScreen] tray table.
///
/// The delete action is forwarded to the parent via [onDelete] so the parent
/// can update [_scannedTrays], [_quantityControllers], and [_batchedProgressIds].
class ScanningTrayRow extends StatelessWidget {
  final int index;
  final ProductionProgressResponseModel tray;
  final VoidCallback onDelete;

  const ScanningTrayRow({
    super.key,
    required this.index,
    required this.tray,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tubes = tray.productionProgress.primaryQuantity ?? 0;
    final pgt = tray.item?.perGarmentTube ?? 0;
    final garmentPcs = pgt > 0 ? tubes * pgt : 0;
    final pw = tray.item?.pieceWeight;
    final weight = (pw != null && pw > 0) ? tubes * pw : null;

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
          // Tray code
          Expanded(
            flex: 3,
            child: Text(
              tray.primaryTrayModel.trayCode ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.black),
            ),
          ),
          // Work order
          Expanded(
            flex: 2,
            child: Text(
              tray.workOrderHeader?.workOrderCode ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.black),
            ),
          ),
          // Size
          Expanded(
            flex: 2,
            child: Text(
              tray.item?.sizeDescription?.isNotEmpty == true
                  ? tray.item!.sizeDescription!
                  : '-',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.black),
            ),
          ),
          // PCS/TUBE
          Expanded(
            flex: 2,
            child: Text(
              pgt > 0 ? pgt.toStringAsFixed(0) : '-',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.black),
            ),
          ),
          // TUBES (quantity box)
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
                  tubes.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black),
                ),
              ),
            ),
          ),
          // PCS
          Expanded(
            flex: 2,
            child: Text(
              garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.black),
            ),
          ),
          // WEIGHT
          Expanded(
            flex: 2,
            child: Text(
              weight != null ? '${weight.toStringAsFixed(2)} g' : '-',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.black),
            ),
          ),
          const SizedBox(width: 8),
          // Delete button
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
