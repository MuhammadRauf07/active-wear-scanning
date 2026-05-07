import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:flutter/material.dart';

/// Scan summary card shown inside [ProcessingBatchDetailsScreen].
///
/// Computes all aggregates (total tubes, weight, WO/item groupings) locally
/// from the provided [trays] list so the parent screen stays clean.
class BatchScanSummary extends StatelessWidget {
  final List<ProductionProgressResponseModel> trays;
  final double? machineCapacity;

  const BatchScanSummary({
    super.key,
    required this.trays,
    this.machineCapacity,
  });

  @override
  Widget build(BuildContext context) {
    // ── Compute aggregates ───────────────────────────────────────────────────
    double totalPcs = 0;
    double totalWeight = 0;
    final Map<String, List<ProductionProgressResponseModel>> byWO = {};

    for (final t in trays) {
      final qty = t.productionProgress.primaryQuantity ?? 0;
      final pw = t.item.pieceWeight ?? 0;
      totalPcs += qty;
      totalWeight += qty * pw;
      final woCode = t.workOrderHeader?.workOrderCode ?? 'Unknown WO';
      byWO.putIfAbsent(woCode, () => []).add(t);
    }

    final capacity = machineCapacity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ───────────────────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 6),
            Text(
              'Scan Summary',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // ── Stat row ─────────────────────────────────────────────────────────
        IntrinsicHeight(
          child: Row(
            children: [
              _statTile('No. of Trays', '${trays.length}', Icons.layers_outlined),
              _verticalDivider(),
              _statTile(
                  'Total Tubes', totalPcs.toStringAsFixed(0), Icons.format_list_numbered),
              if (capacity != null && capacity > 0) ...[
                _verticalDivider(),
                _statTile('Capacity', capacity.toStringAsFixed(1),
                    Icons.settings_input_component),
              ],
              _verticalDivider(),
              _statTile('Allocated Weight', totalWeight.toStringAsFixed(1),
                  Icons.scale_outlined),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 4),

        // ── WO-grouped expandable list ────────────────────────────────────────
        ...byWO.entries.map((entry) {
          final woCode = entry.key;
          final woTrays = entry.value;

          final Map<String, List<ProductionProgressResponseModel>> byItem = {};
          double woPcs = 0;
          double woWeight = 0;
          for (final t in woTrays) {
            final qty = t.productionProgress.primaryQuantity ?? 0;
            final pw = t.item.pieceWeight ?? 0;
            woPcs += qty;
            woWeight += qty * pw;
            final itemDesc = t.item.description ?? 'Unknown';
            byItem.putIfAbsent(itemDesc, () => []).add(t);
          }

          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              childrenPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.assignment_outlined,
                    size: 16, color: Colors.blue.shade700),
              ),
              title: Text(woCode,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${woTrays.length} trays · ${woPcs.toStringAsFixed(0)} tubes · ${woWeight.toStringAsFixed(2)} g',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              children: [
                // Sub-header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      Expanded(
                          flex: 5,
                          child: Text('ITEM DESCRIPTION',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600))),
                      Expanded(
                          flex: 2,
                          child: Text('TRAYS',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600))),
                      Expanded(
                          flex: 2,
                          child: Text('TUBES',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600))),
                      Expanded(
                          flex: 3,
                          child: Text('WEIGHT',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600))),
                    ],
                  ),
                ),
                ...byItem.entries.toList().asMap().entries.map((e) {
                  final i = e.key;
                  final itemEntry = e.value;
                  final itemDesc = itemEntry.key;
                  final itemTrays = itemEntry.value;

                  double itemPcs = 0;
                  double itemWeight = 0;
                  for (final t in itemTrays) {
                    final qty = t.productionProgress.primaryQuantity ?? 0;
                    final pw = t.item.pieceWeight ?? 0;
                    itemPcs += qty;
                    itemWeight += qty * pw;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    color: i.isEven ? Colors.white : Colors.grey.shade50,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            itemDesc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${itemTrays.length}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            itemPcs.toStringAsFixed(0),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            '${itemWeight.toStringAsFixed(2)} g',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────
  static Widget _statTile(String label, String value, IconData icon,
      {Color? valueColor}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade600),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _verticalDivider() {
    return Container(
      width: 1,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}
