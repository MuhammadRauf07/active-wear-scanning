import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/wip/model/wip_model.dart';
import 'package:active_wear_scanning/features/wip/presentation/widgets/wip_batch_card.dart';

class WipOperationCard extends StatelessWidget {
  final WipOperationModel operationModel;
  final List<WipBatchModel>? batches;
  final bool isLoading;
  final bool isExpanded;
  final Set<int> expandedBatchIds;
  final VoidCallback onToggleOperation;
  final Function(int batchHeaderId) onToggleBatch;

  const WipOperationCard({
    super.key,
    required this.operationModel,
    required this.batches,
    required this.isLoading,
    required this.isExpanded,
    required this.expandedBatchIds,
    required this.onToggleOperation,
    required this.onToggleBatch,
  });

  @override
  Widget build(BuildContext context) {
    final op = operationModel.operation;
    final int batchCount = batches != null ? batches!.length : operationModel.batchCount;
    final double weightKg = operationModel.totalWeight / 1000.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? const Color(0xFF1B64A3) : const Color(0xFFE2E8F0),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: const Color(0xFF1B64A3).withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Operation Header Card
          InkWell(
            onTap: onToggleOperation,
            child: Container(
              padding: const EdgeInsets.all(14),
              color: isExpanded
                  ? const Color(0xFF1B64A3).withValues(alpha: 0.03)
                  : Colors.white,
              child: Row(
                children: [
                  // Operation Icon Badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isExpanded ? const Color(0xFF1B64A3) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.alt_route_rounded,
                      size: 18,
                      color: isExpanded ? Colors.white : const Color(0xFF1B64A3),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Operation Name & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          op.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isExpanded ? const Color(0xFF1B64A3) : const Color(0xFF334155),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Work-in-Progress Tracking • ${operationModel.totalTubes.toStringAsFixed(0)} Tubes • ${weightKg.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Active Batch Count Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: batchCount > 0
                          ? const Color(0xFF1B64A3)
                          : const Color(0xFF94A3B8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (batchCount > 0)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.layers_rounded, size: 11, color: Colors.white),
                          ),
                        Text(
                          '$batchCount BATCHES',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: batchCount > 0 ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Expand Icon
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isExpanded ? const Color(0xFF1B64A3) : const Color(0xFFCBD5E1),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Batches Content
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10.5),
                  bottomRight: Radius.circular(10.5),
                ),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF1B64A3).withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
              ),
              child: _buildExpandedContent(),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF1B64A3))),
        ),
      );
    }

    if (batches == null || batches!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No batches currently active in this operation.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVE BATCHES (${batches!.length})',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Tap batch to view trays',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: batches!.length,
          itemBuilder: (context, index) {
            final batch = batches![index];
            final isBatchExpanded = expandedBatchIds.contains(batch.batchHeaderId);

            return WipBatchCard(
              batch: batch,
              isExpanded: isBatchExpanded,
              isLast: index == batches!.length - 1,
              onToggleExpand: () => onToggleBatch(batch.batchHeaderId),
            );
          },
        ),
      ],
    );
  }
}
