import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/lapping/model/lapping_model.dart';

class LappingScannerUI extends StatelessWidget {
  final String? selectedWorkOrderId;
  final Map<String, List<LappingModel>> scannedTraysByWO;
  final TextEditingController trayQtyController;
  final FocusNode focusNode;
  final VoidCallback onScanPressed;

  const LappingScannerUI({
    super.key,
    required this.selectedWorkOrderId,
    required this.scannedTraysByWO,
    required this.trayQtyController,
    required this.focusNode,
    required this.onScanPressed,
  });

  @override
  Widget build(BuildContext context) {
    final traysToShow = scannedTraysByWO[selectedWorkOrderId] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Scanner Card Header (GBS / Batch list Style) ─────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
              bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                color: Color(0xFF0D47A1),
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'SCANNED TRAYS LIST',
                  style: TextStyle(
                    color: Color(0xFF263238),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '${traysToShow.length} Trays',
                style: const TextStyle(
                  color: Color(0xFF546E7A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // ── Scanner Interaction Body ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Tubes Input
              SizedBox(
                width: 100,
                height: 48,
                child: TextField(
                  controller: trayQtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  focusNode: focusNode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                  decoration: InputDecoration(
                    labelText: 'TUBES',
                    labelStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Scan Button
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onScanPressed,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: const Text(
                      'SCAN NEW TRAY',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
