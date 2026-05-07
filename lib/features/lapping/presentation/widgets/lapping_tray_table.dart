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
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: ContentCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _buildScannedHeader(),
            ...List.generate(traysToShow.length, (index) {
              final t = traysToShow[index];
              final trayKey = t.primaryTrayModel.trayCode?.toLowerCase() ?? '';
              final qty = trayOverrideQuantities[trayKey] ?? 0;
              final pw = t.item?.pieceWeight ?? 0;
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
                    Expanded(flex: 2, child: Text(t.primaryTrayModel.trayCode ?? '-', style: const TextStyle(fontSize: 13, color: Colors.black87))),
                    Expanded(flex: 4, child: Text(t.processedItem?.description ?? t.item?.description ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                    Expanded(flex: 2, child: Text(t.item?.colorDescription?.isNotEmpty == true ? t.item!.colorDescription! : '-', style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text(t.item?.sizeDescription?.isNotEmpty == true ? t.item!.sizeDescription! : '-', style: const TextStyle(fontSize: 11, color: Colors.black87))),
                    Expanded(flex: 2, child: Text((t.item?.perGarmentTube ?? 0) > 0 ? t.item!.perGarmentTube!.toStringAsFixed(0) : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo.shade700))),                    Expanded(
                      flex: 2, 
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            qty.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    Expanded(flex: 2, child: Builder(builder: (_) {
                      final pgt = t.item?.perGarmentTube ?? 0;
                      final garmentPcs = pgt > 0 ? qty * pgt : 0;
                      return Text(garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade700));
                    })),
                    Expanded(flex: 2, child: Text('${(qty * pw).toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 13, color: Colors.black87))),
                    const SizedBox(width: 8),
                    GestureDetector(
                        onTap: () => onRemove(t, trayKey),
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
            }),
          ],
        ),
      ),
    );
  }
}
