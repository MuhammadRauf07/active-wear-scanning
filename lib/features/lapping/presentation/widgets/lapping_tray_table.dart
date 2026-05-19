import 'package:flutter/material.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
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

  static final _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );

  Widget _buildScannedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('TRAY CODE', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('COLOR', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('SIZE', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('PCS/TUBE', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('TUBES', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('PCS', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('WEIGHT', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

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
              _buildHeadCell('COLOR', 2),
              _buildHeadCell('SIZE', 2),
              _buildHeadCell('P/TUBE', 2),
              _buildHeadCell('TUBES', 2),
              _buildHeadCell('PCS', 2),
              _buildHeadCell('WEIGHT', 2),
              const SizedBox(width: 44),
            ],
          ),
        ),

        // ── Table Rows ─────────────────────────────────────────────────────
        ...List.generate(traysToShow.length, (index) {
          final t = traysToShow[index];
          final trayKey = t.primaryTrayModel.trayCode?.toLowerCase() ?? '';
          final qty = trayOverrideQuantities[trayKey] ?? 0;
          final pw = t.item?.pieceWeight ?? 0;
          final pgt = t.item?.perGarmentTube ?? 0;
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
                Expanded(flex: 4, child: Text(t.processedItem?.description ?? t.item?.description ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis, style: _cellStyle(isSmall: true))),
                Expanded(flex: 2, child: Text(t.item?.colorDescription ?? '-', style: _cellStyle(isBold: true))),
                Expanded(flex: 2, child: Text(t.item?.sizeDescription ?? '-', style: _cellStyle())),
                Expanded(flex: 2, child: Text(pgt > 0 ? pgt.toStringAsFixed(0) : '-', style: _cellStyle(color: const Color(0xFF1B64A3)))),
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFCBD5E1))),
                    child: Text(qty.toStringAsFixed(0), textAlign: TextAlign.center, style: _cellStyle(isBold: true)),
                  ),
                ),
                Expanded(flex: 2, child: Text(garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-', style: _cellStyle(color: const Color(0xFF059669), isBold: true))),
                Expanded(flex: 2, child: Text('${(qty * pw).toStringAsFixed(1)} g', style: _cellStyle())),
                IconButton(
                  onPressed: () => onRemove(t, trayKey),
                  icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHeadCell(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
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
