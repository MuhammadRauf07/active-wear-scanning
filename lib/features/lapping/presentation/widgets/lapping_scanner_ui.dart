import 'package:flutter/material.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/lapping/model/lapping_model.dart';

class LappingScannerUI extends StatelessWidget {
  final String? selectedWorkOrderId;
  final Map<String, List<LappingModel>> scannedTraysByWO;
  final TextEditingController trayQtyController;
  final FocusNode focusNode;
  final VoidCallback onScanPressed;
  final Widget childTable;

  const LappingScannerUI({
    super.key,
    required this.selectedWorkOrderId,
    required this.scannedTraysByWO,
    required this.trayQtyController,
    required this.focusNode,
    required this.onScanPressed,
    required this.childTable,
  });

  @override
  Widget build(BuildContext context) {
    final traysToShow = scannedTraysByWO[selectedWorkOrderId] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Tray Scanner', subtitle: 'Scan tray barcodes to assign them to this work order'),
        const SizedBox(height: 12),
        ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Scan Tray Barcode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Ready for scan bar (GBS style)
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ready for scan...',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 70,
                    height: 44,
                    child: TextField(
                      controller: trayQtyController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        FocusScope.of(context).requestFocus(focusNode);
                      },
                      decoration: InputDecoration(
                        hintText: 'Tubes',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CustomOutlinedButton(
                    label: 'Scan Tray',
                    borderColor: Colors.blue,
                    fillColor: Colors.blue,
                    textColor: Colors.white,
                    buttonHeight: 44,
                    onPressed: onScanPressed,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Scanned Trays (${traysToShow.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ],
        ),
        childTable,
      ],
    );
  }
}
