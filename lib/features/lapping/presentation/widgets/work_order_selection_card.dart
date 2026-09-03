import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/lapping/model/lapping_model.dart';
import 'package:active_wear_scanning/features/lapping/model/work_order_summary.dart';

class WorkOrderSelectionCard extends StatelessWidget {
  final Map<String, WorkOrderSummary> workOrders;
  final String? selectedWorkOrderId;
  final Map<String, List<LappingModel>> scannedTraysByWO;
  final Map<String, double> trayOverrideQuantities;
  final Map<String, double> itemWasteQuantities;
  final ValueChanged<String?> onSelected;
  final ValueChanged<WorkOrderSummary> onAddWaste;
  final ValueChanged<String>? onDeleteWaste;

  const WorkOrderSelectionCard({
    super.key,
    required this.workOrders,
    required this.selectedWorkOrderId,
    required this.scannedTraysByWO,
    required this.trayOverrideQuantities,
    this.itemWasteQuantities = const {},
    required this.onSelected,
    required this.onAddWaste,
    this.onDeleteWaste,
  });

  static const _headerStyle = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w900,
    color: Color(0xFF64748B),
    letterSpacing: 0.4,
  );

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

        // ── Table Header (Centrally aligned columns) ────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5)),
          ),
          child: Row(
            children: [
              _buildHeadCell('WORK ORDER', 4),
              _buildHeadCell('ITEM DESCRIPTION', 6),
              _buildHeadCell('TRAYS', 2),
              _buildHeadCell('TUBES', 2),
              _buildHeadCell('RE-ASSIGN', 2, color: const Color(0xFF059669)),
              _buildHeadCell('WASTAGE QTY', 3, color: const Color(0xFFDC2626)),
              const SizedBox(
                width: 32,
                child: Text('SEL', textAlign: TextAlign.center, style: _headerStyle),
              ),
              const SizedBox(
                width: 38,
                child: Text('ACTION', textAlign: TextAlign.center, style: _headerStyle),
              ),
            ],
          ),
        ),

        // ── Rows ───────────────────────────────────────────────────────────
        ...List.generate(workOrders.values.length, (index) {
          final wo = workOrders.values.elementAt(index);
          final isSelected = selectedWorkOrderId == wo.id;
          final reassigned = (scannedTraysByWO[wo.id] ?? []).fold<double>(
            0,
            (sum, t) => sum + (trayOverrideQuantities[t.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0),
          );
          final waste = itemWasteQuantities[wo.id] ?? 0.0;

          return InkWell(
            onTap: () => onSelected(wo.id),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0F9FF) : (index.isOdd ? const Color(0xFFF8FAFC) : Colors.white),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
                  left: isSelected ? const BorderSide(color: Color(0xFF0D47A1), width: 4) : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  // Work Order
                  Expanded(
                    flex: 4,
                    child: Text(
                      wo.description,
                      textAlign: TextAlign.center,
                      style: _cellStyle(isSelected, isBold: true),
                    ),
                  ),

                  // Item Description
                  Expanded(
                    flex: 6,
                    child: Text(
                      wo.componentDescription,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _cellStyle(isSelected, isSmall: true),
                    ),
                  ),

                  // Trays
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${wo.trayCount}',
                      textAlign: TextAlign.center,
                      style: _cellStyle(isSelected),
                    ),
                  ),

                  // Tubes
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${wo.originalPieces.toInt()}',
                      textAlign: TextAlign.center,
                      style: _cellStyle(isSelected, color: const Color(0xFF0D47A1), isBold: true),
                    ),
                  ),

                  // Re-Assign
                  Expanded(
                    flex: 2,
                    child: Text(
                      reassigned > 0 ? '${reassigned.toInt()}' : '-',
                      textAlign: TextAlign.center,
                      style: _cellStyle(isSelected, color: const Color(0xFF059669), isBold: true),
                    ),
                  ),

                  // Wastage QTY
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: waste > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFECACA), width: 1),
                              ),
                              child: Text(
                                waste.toInt().toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            )
                          : const Text(
                              '0',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                    ),
                  ),

                  // Selection Radio
                  SizedBox(
                    width: 32,
                    child: Center(
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: Radio<String>(
                          value: wo.id,
                          groupValue: selectedWorkOrderId,
                          activeColor: const Color(0xFF0D47A1),
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) => onSelected(val),
                        ),
                      ),
                    ),
                  ),

                  // 3-Dot Action Menu
                  SizedBox(
                    width: 38,
                    child: Center(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          popupMenuTheme: PopupMenuThemeData(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: Colors.white,
                            elevation: 6,
                          ),
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: Color(0xFF546E7A),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Line Actions',
                          onSelected: (value) async {
                            if (value == 'add_waste') {
                              onAddWaste(wo);
                            } else if (value == 'delete_waste') {
                              if (onDeleteWaste != null) {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
                                        SizedBox(width: 8),
                                        Text('Delete Waste', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                                      ],
                                    ),
                                    content: Text(
                                      'Are you sure you want to delete waste for "${wo.componentDescription}"?',
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFDC2626),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 0,
                                        ),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete Waste', style: TextStyle(fontWeight: FontWeight.w800)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  onDeleteWaste!(wo.id);
                                }
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem<String>(
                              value: 'add_waste',
                              child: Row(
                                children: [
                                  Icon(Icons.playlist_add_rounded, size: 18, color: Color(0xFF1B64A3)),
                                  SizedBox(width: 10),
                                  Text('Add / Manage Waste', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                ],
                              ),
                            ),
                            if (waste > 0 && onDeleteWaste != null)
                              const PopupMenuItem<String>(
                                value: 'delete_waste',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                    SizedBox(width: 10),
                                    Text('Delete Waste', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildHeadCell(String label, int flex, {Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: color ?? const Color(0xFF455A64),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  TextStyle _cellStyle(bool isSelected, {bool isBold = false, bool isSmall = false, Color? color}) {
    return TextStyle(
      fontSize: isSmall ? 10 : 11,
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
      color: color ?? (isSelected ? const Color(0xFF1E293B) : const Color(0xFF475569)),
    );
  }
}
