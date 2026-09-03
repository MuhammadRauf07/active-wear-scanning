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

  static const _headerStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Color(0xFF455A64), // Slate Grey
    letterSpacing: 0.2,
  );

  static const _cellStyle = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: Color(0xFF263238),
  );

  static const _blueCellStyle = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1B64A3),
  );

  @override
  Widget build(BuildContext context) {
    final traysToShow = scannedTraysByWO[selectedWorkOrderId] ?? [];
    return Column(
      children: [
        // ── Table Header (Centrally aligned columns) ─────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9), // Light Slate
            border: Border(bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5)),
          ),
          child: Row(
            children: [
              _buildHeadCell('TRAY CODE', 4),
              _buildHeadCell('ITEM DESCRIPTION', 6),
              _buildHeadCell('COLOR', 3),
              _buildHeadCell('SIZE', 2),
              _buildHeadCell('PCS/TUBE', 3),
              _buildHeadCell('TUBES', 2),
              _buildHeadCell('PCS', 2),
              _buildHeadCell('WEIGHT', 3),
              const SizedBox(
                width: 44,
                child: Text('ACTION', textAlign: TextAlign.center, style: _headerStyle),
              ),
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
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.12), width: 1)),
                ),
                child: Row(
                  children: [
                    // Tray Code
                    Expanded(
                      flex: 4,
                      child: Text(
                        t.primaryTrayModel.trayCode ?? '-',
                        textAlign: TextAlign.center,
                        style: _blueCellStyle,
                      ),
                    ),

                    // Item Description
                    Expanded(
                      flex: 6,
                      child: Text(
                        t.processedItem?.description ?? t.item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: _cellStyle,
                      ),
                    ),

                    // Color
                    Expanded(
                      flex: 3,
                      child: Text(
                        t.item.colorDescription?.isNotEmpty == true ? t.item.colorDescription! : '-',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _cellStyle,
                      ),
                    ),

                    // Size
                    Expanded(
                      flex: 2,
                      child: Text(
                        t.item.sizeDescription?.isNotEmpty == true ? t.item.sizeDescription! : '-',
                        textAlign: TextAlign.center,
                        style: _cellStyle,
                      ),
                    ),

                    // Pcs / Tube
                    Expanded(
                      flex: 3,
                      child: Text(
                        pgt > 0 ? pgt.toStringAsFixed(0) : '-',
                        textAlign: TextAlign.center,
                        style: _cellStyle,
                      ),
                    ),

                    // Tubes
                    Expanded(
                      flex: 2,
                      child: Text(
                        qty.toStringAsFixed(0),
                        textAlign: TextAlign.center,
                        style: _cellStyle.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),

                    // Pcs
                    Expanded(
                      flex: 2,
                      child: Text(
                        garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-',
                        textAlign: TextAlign.center,
                        style: _cellStyle,
                      ),
                    ),

                    // Weight
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${(qty * pw).toStringAsFixed(1)} g',
                        textAlign: TextAlign.center,
                        style: _cellStyle,
                      ),
                    ),

                    // Delete Tray Action
                    SizedBox(
                      width: 44,
                      child: Center(
                        child: IconButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
                                    SizedBox(width: 8),
                                    Text('Confirm Delete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                                  ],
                                ),
                                content: Text('Are you sure you want to delete tray "${t.primaryTrayModel.trayCode ?? '-'}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              onRemove(t, trayKey);
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                          tooltip: 'Delete Tray',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
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

  Widget _buildHeadCell(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: _headerStyle,
      ),
    );
  }
}
