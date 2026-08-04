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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          hoverColor: const Color(0xFFF8FAFC),
        ),
        child: ExpansionTile(
          onExpansionChanged: onExpansionChanged,
          backgroundColor: const Color(0xFFF8FAFC),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warehouse_rounded, size: 20, color: Color(0xFF334155)),
          ),
          title: Text(
            locator.locator.description,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E293B), letterSpacing: 0.3),
          ),
          subtitle: Row(
            children: [
              const Icon(Icons.business_center_rounded, size: 10, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                locator.department.name.toUpperCase(),
                style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ],
          ),
          trailing: isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF0D47A1))))
              : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF94A3B8), size: 22),
          children: [
            if (groupedData.isEmpty && !isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: WIPEmptyState(),
              )
            else ...[
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                ),
                child: Column(
                  children: [
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
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
