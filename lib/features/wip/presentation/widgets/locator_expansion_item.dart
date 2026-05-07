import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/wip/model/wip_model.dart';
import 'package:active_wear_scanning/features/wip/model/wip_group.dart';
import 'package:active_wear_scanning/features/wip/presentation/widgets/wip_empty_state.dart';
import 'package:active_wear_scanning/features/wip/presentation/widgets/wip_table_header.dart';
import 'package:active_wear_scanning/features/wip/presentation/widgets/wip_group_row.dart';

class LocatorExpansionItem extends StatelessWidget {
  final LocatorResponse locator;
  final List<WIPGroup> groupedData;
  final bool isLoading;
  final ValueChanged<bool> onExpansionChanged;
  final Function(WIPGroup) onViewDetails;

  const LocatorExpansionItem({
    super.key,
    required this.locator,
    required this.groupedData,
    required this.isLoading,
    required this.onExpansionChanged,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final deptCode = locator.department.code.toUpperCase();
    final isKnitting = deptCode == 'KNITTING';
    final isProcessing = deptCode == 'PROCESSING';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warehouse_outlined, size: 20, color: Colors.blue.shade700),
          ),
          title: Text(
            locator.locator.description,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
          ),
          subtitle: Text(
            'Dept: ${locator.department.name}',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade400, fontWeight: FontWeight.w500),
          ),
          trailing: isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.keyboard_arrow_down, color: Colors.blue.shade200),
          children: [
            if (groupedData.isEmpty && !isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: WIPEmptyState(),
              )
            else ...[
              const Divider(height: 1),
              WIPTableHeader(isKnitting: isKnitting, isProcessing: isProcessing),
              ...List.generate(groupedData.length, (idx) {
                return WIPGroupRow(
                  index: idx,
                  group: groupedData[idx],
                  isKnitting: isKnitting,
                  isProcessing: isProcessing,
                  onViewDetails: () => onViewDetails(groupedData[idx]),
                );
              }),
              const SizedBox(height: 12),
            ]
          ],
        ),
      ),
    );
  }
}
