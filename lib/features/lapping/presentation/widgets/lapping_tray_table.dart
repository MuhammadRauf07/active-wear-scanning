import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/lapping/model/lapping_model.dart';

class LappingTrayTable extends StatelessWidget {
  final String? selectedWorkOrderId;
  final Map<String, List<LappingModel>> scannedTraysByWO;
  final Map<String, double> trayOverrideQuantities;
  final Function(LappingModel tray, String trayKey) onRemove;

  const LappingTrayTable({
    super.key,
    required this.selectedWorkOrderId,
    required this.scannedTraysByWO,
    required this.trayOverrideQuantities,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final traysToShow = scannedTraysByWO[selectedWorkOrderId] ?? [];
    return Column(
      children: [
        // ── Table Header ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
          ),
          child: Row(
            children: [
              _buildHeadCell('TRAY CODE', 2),
              _buildHeadCell('ITEM DESCRIPTION', 4),
              _buildHeadCell('COLOR', 2, textAlign: TextAlign.center),
              _buildHeadCell('SIZE', 2, textAlign: TextAlign.center),
              _buildHeadCell('PCS PER TUBE', 2, textAlign: TextAlign.center),
              _buildHeadCell('TUBES', 2, textAlign: TextAlign.center),
              _buildHeadCell('PCS', 2, textAlign: TextAlign.center),
              _buildHeadCell('WEIGHT', 2, textAlign: TextAlign.center),
              const SizedBox(width: 44),
            ],
          ),
        ),

        // ── Table Rows ─────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: traysToShow.length,
            itemBuilder: (context, index) {
              final t = traysToShow[index];
              final trayKey = t.primaryTrayModel.trayCode?.toLowerCase() ?? '';
              final qty = trayOverrideQuantities[trayKey] ?? 0;
              final pw = t.item.pieceWeight ?? 0;
              final pgt = t.item.perGarmentTube;
              final garmentPcs = pgt > 0 ? qty * pgt : 0;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: index.isOdd ? const Color(0xFFF8FAFC) : Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(t.primaryTrayModel.trayCode ?? '-', style: _cellStyle(isBold: true, color: const Color(0xFF0D47A1)))),
                    Expanded(flex: 4, child: Text(t.processedItem?.description ?? t.item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: _cellStyle(isSmall: true))),
                    Expanded(flex: 2, child: Text(t.item.colorDescription ?? '-', textAlign: TextAlign.center, style: _cellStyle(isBold: true))),
                    Expanded(flex: 2, child: Text(t.item.sizeDescription ?? '-', textAlign: TextAlign.center, style: _cellStyle())),
                    Expanded(flex: 2, child: Text(pgt > 0 ? pgt.toStringAsFixed(0) : '-', textAlign: TextAlign.center, style: _cellStyle(color: const Color(0xFF1B64A3)))),
                    Expanded(
                      flex: 2,
                      child: Text(
                        qty.toStringAsFixed(0),
                        textAlign: TextAlign.center,
                        style: _cellStyle(isBold: true),
                      ),
                    ),
                    Expanded(flex: 2, child: Text(garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-', textAlign: TextAlign.center, style: _cellStyle(color: const Color(0xFF059669), isBold: true))),
                    Expanded(flex: 2, child: Text('${(qty * pw).toStringAsFixed(1)} g', textAlign: TextAlign.center, style: _cellStyle())),
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
                          onRemove(t, trayKey);
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeadCell(String label, int flex, {TextAlign textAlign = TextAlign.start}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: textAlign,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
      ),
    );
  }

  TextStyle _cellStyle({bool isBold = false, bool isSmall = false, Color? color}) {
    return TextStyle(
      fontSize: isSmall ? 10 : 11,
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
      color: color ?? const Color(0xFF1E293B),
    );
  }
}
