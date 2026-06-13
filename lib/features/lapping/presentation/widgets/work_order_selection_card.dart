import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/lapping/model/lapping_model.dart';
import 'package:active_wear_scanning/features/lapping/model/work_order_summary.dart';

class WorkOrderSelectionCard extends StatelessWidget {
  final Map<String, WorkOrderSummary> workOrders;
  final String? selectedWorkOrderId;
  final Map<String, List<LappingModel>> scannedTraysByWO;
  final Map<String, double> trayOverrideQuantities;
  final ValueChanged<String?> onSelected;

  const WorkOrderSelectionCard({
    super.key,
    required this.workOrders,
    required this.selectedWorkOrderId,
    required this.scannedTraysByWO,
    required this.trayOverrideQuantities,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Card Header ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B), // Dark Slate
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: const Row(
            children: [
              Icon(Icons.list_alt_rounded, color: Color(0xFF60A5FA), size: 18),
              SizedBox(width: 10),
              Text(
                'WORK ORDER LINE SELECTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),

        // ── Table Header ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
          ),
          child: Row(
            children: [
              _buildHeadCell('WORK ORDER', 3),
              _buildHeadCell('ITEM DESCRIPTION', 5),
              _buildHeadCell('TRAYS', 2),
              _buildHeadCell('TUBES', 2),
              _buildHeadCell('RE-ASSIGN', 2, color: const Color(0xFF10B981)),
              const SizedBox(width: 32), // Space for Radio
            ],
          ),
        ),

        // ── Rows ───────────────────────────────────────────────────────────
        ...List.generate(workOrders.values.length, (index) {
          final wo = workOrders.values.elementAt(index);
          final isSelected = selectedWorkOrderId == wo.id;
          final reassigned = (scannedTraysByWO[wo.id] ?? []).fold<double>(0, (sum, t) =>
            sum + (trayOverrideQuantities[t.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0));

          return InkWell(
            onTap: () => onSelected(wo.id),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0F9FF) : (index.isOdd ? const Color(0xFFF8FAFC) : Colors.white),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                  left: isSelected ? const BorderSide(color: Color(0xFF0D47A1), width: 4) : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(wo.description, style: _cellStyle(isSelected, isBold: true))),
                  Expanded(flex: 5, child: Text(wo.componentDescription, style: _cellStyle(isSelected, isSmall: true))),
                  Expanded(flex: 2, child: Text('${wo.trayCount}', style: _cellStyle(isSelected))),
                  Expanded(flex: 2, child: Text('${wo.cumulativePieces.toInt()}', style: _cellStyle(isSelected, color: const Color(0xFF0D47A1), isBold: true))),
                  Expanded(flex: 2, child: Text(reassigned > 0 ? '${reassigned.toInt()}' : '-', style: _cellStyle(isSelected, color: const Color(0xFF10B981), isBold: true))),
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Radio<String>(
                      value: wo.id,
                      groupValue: selectedWorkOrderId,
                      activeColor: const Color(0xFF0D47A1),
                      visualDensity: VisualDensity.compact,
                      onChanged: (val) => onSelected(val),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8), // Padding at bottom of list
      ],
    );
  }

  Widget _buildHeadCell(String label, int flex, {Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color ?? const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  TextStyle _cellStyle(bool isSelected, {bool isBold = false, bool isSmall = false, Color? color}) {
    return TextStyle(
      fontSize: isSmall ? 10 : 12,
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
      color: color ?? (isSelected ? const Color(0xFF1E293B) : const Color(0xFF475569)),
    );
  }
}
