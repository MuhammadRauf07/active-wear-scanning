import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class WipTrayTable extends StatelessWidget {
  final List<ProductionProgressResponseModel> trays;

  const WipTrayTable({
    super.key,
    required this.trays,
  });

  @override
  Widget build(BuildContext context) {
    if (trays.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: const Text(
          'No trays recorded for this batch.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
        ),
      );
    }

    const cellStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF263238));
    const blueCellStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1B64A3));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Row(
              children: [
                Expanded(flex: 7, child: Text('TRAY #', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.5))),
                Expanded(flex: 5, child: Text('WORK ORDER', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.5))),
                Expanded(flex: 5, child: Text('SIZE / ITEM', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.5))),
                Expanded(flex: 3, child: Text('TUBES', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.5))),
                Expanded(flex: 4, child: Text('WEIGHT', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.5))),
                Expanded(flex: 4, child: Text('STATUS', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.5))),
              ],
            ),
          ),
          // Rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: trays.length,
            itemBuilder: (context, index) {
              final t = trays[index];
              final qty = t.productionProgress.primaryQuantity ?? 0;
              final tubes = (t.productionProgress.secondaryQuantity ?? qty).toDouble();
              final pw = t.item.pieceWeight ?? 0;
              final weight = qty * pw;

              final bool isHold = t.productionProgress.holdFlag == true;
              final bool isStarted = t.productionProgress.isStarted == true;
              final bool isRework = t.productionProgress.reworkFlag == true;

              Color statusColor = const Color(0xFF64748B);
              String statusText = 'READY';
              if (isHold) {
                statusColor = Colors.red.shade700;
                statusText = 'HELD';
              } else if (isRework) {
                statusColor = Colors.orange.shade800;
                statusText = 'REWORK';
              } else if (isStarted) {
                statusColor = const Color(0xFF2E7D32);
                statusText = 'RUNNING';
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
                  border: index < trays.length - 1
                      ? Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1))
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(flex: 7, child: Text(t.primaryTrayModel.trayCode ?? '-', textAlign: TextAlign.center, style: blueCellStyle)),
                    Expanded(flex: 5, child: Text(t.workOrderHeader.workOrderCode, textAlign: TextAlign.center, style: cellStyle)),
                    Expanded(flex: 5, child: Text(t.item.sizeDescription ?? t.item.description, textAlign: TextAlign.center, style: cellStyle)),
                    Expanded(flex: 3, child: Text(tubes.toStringAsFixed(0), textAlign: TextAlign.center, style: cellStyle.copyWith(fontWeight: FontWeight.w700))),
                    Expanded(flex: 4, child: Text('${weight.toStringAsFixed(0)}g', textAlign: TextAlign.center, style: cellStyle)),
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: statusColor),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
