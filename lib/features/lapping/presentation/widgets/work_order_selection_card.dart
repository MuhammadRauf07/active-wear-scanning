import 'package:flutter/material.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
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

  static final _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('WORK ORDER', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 6, child: Text('ITEM DESCRIPTION', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('TRAYS', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('TOTAL TUBES', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('RE-ASSIGN', style: _tableHeaderStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green))),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Select Work Order Line', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        ContentCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildTableHeader(),
              ...List.generate(workOrders.values.length, (index) {
                final wo = workOrders.values.elementAt(index);
                final isSelected = selectedWorkOrderId == wo.id;
                final reassigned = (scannedTraysByWO[wo.id] ?? []).fold<double>(0, (sum, t) =>
                sum + (trayOverrideQuantities[t.primaryTrayModel.trayCode?.toLowerCase() ?? ''] ?? 0));

                return InkWell(
                  onTap: () => onSelected(wo.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.05) : (index.isEven ? Colors.white : Colors.grey.shade50),
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade300),
                        right: BorderSide(color: Colors.grey.shade300),
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(wo.description, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                        Expanded(flex: 6, child: Text(wo.componentDescription, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                        Expanded(flex: 2, child: Text('${wo.trayCount}', style: const TextStyle(fontSize: 12, color: Colors.black87))),
                        Expanded(flex: 2, child: Text('${wo.cumulativePieces.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
                        Expanded(flex: 2, child: Text(reassigned > 0 ? '${reassigned.toInt()}' : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: reassigned > 0 ? Colors.green : Colors.grey))),
                        Radio<String>(
                          value: wo.id, 
                          groupValue: selectedWorkOrderId, 
                          activeColor: Colors.blue, 
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) => onSelected(val)
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
