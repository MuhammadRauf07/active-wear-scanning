import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:flutter/material.dart';

/// Displays the internal tray table in [ProcessingBatchDetailsScreen].
///
/// Receives [trays] and rework state via constructor instead of reading
/// parent state directly. The [onReworkToggle] callback lets the parent
/// call setState when a checkbox changes.
class ProcessingTrayTable extends StatelessWidget {
  final List<ProductionProgressResponseModel> trays;
  final bool isReworkMode;
  final Set<int> selectedReworkTrayIds;
  final void Function(int progressId, bool selected) onReworkToggle;
  final void Function(bool selected)? onSelectAllToggle;

  const ProcessingTrayTable({
    super.key,
    required this.trays,
    required this.isReworkMode,
    required this.selectedReworkTrayIds,
    required this.onReworkToggle,
    this.onSelectAllToggle,
  });

  static final _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );

  @override
  Widget build(BuildContext context) {
    if (trays.isEmpty) {
      return const Center(child: Text('No trays found'));
    }

    final bool isAllSelected = trays.isNotEmpty &&
        trays.every((t) => selectedReworkTrayIds.contains(t.productionProgress.id));
    final bool isAnySelected = trays.isNotEmpty &&
        trays.any((t) => selectedReworkTrayIds.contains(t.productionProgress.id));

    return ContentCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // ── Table header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('TRAY CODE', style: _headerStyle)),
                Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: _headerStyle)),
                Expanded(flex: 2, child: Text('COLOR', style: _headerStyle)),
                Expanded(flex: 2, child: Text('SIZE', style: _headerStyle)),
                Expanded(flex: 2, child: Text('PCS PER TUBE', style: _headerStyle)),
                Expanded(flex: 2, child: Text('TUBES', style: _headerStyle)),
                Expanded(flex: 2, child: Text('PCS', style: _headerStyle)),
                if (isReworkMode)
                  SizedBox(
                    width: 44,
                    child: Checkbox(
                      visualDensity: VisualDensity.compact,
                      value: isAllSelected ? true : (isAnySelected ? null : false),
                      tristate: true,
                      activeColor: Colors.orange,
                      onChanged: (v) {
                        if (onSelectAllToggle != null) {
                          // If it is checked or null (tristate), toggling from unchecked/tristate -> check all
                          // If fully checked -> uncheck all
                          onSelectAllToggle!(v == true);
                        }
                      },
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
          // ── Tray rows (Internally Scrollable) ─────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: trays.length,
              itemBuilder: (ctx, idx) {
                final t = trays[idx];
                final isSel = selectedReworkTrayIds.contains(t.productionProgress.id);
                final tubes = t.productionProgress.primaryQuantity ?? 0;
                final pgt = t.item.perGarmentTube ?? 0;
                final garmentPcs = pgt > 0 ? tubes * pgt : 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          t.primaryTrayModel.trayCode ?? '-',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          t.item.description ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          t.item.colorDescription?.isNotEmpty == true
                              ? t.item.colorDescription!
                              : '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          t.item.sizeDescription?.isNotEmpty == true
                              ? t.item.sizeDescription!
                              : '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          pgt > 0 ? pgt.toStringAsFixed(0) : '-',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          tubes.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      if (isReworkMode)
                        SizedBox(
                          width: 44,
                          child: Checkbox(
                            visualDensity: VisualDensity.compact,
                            value: isSel,
                            activeColor: Colors.orange,
                            onChanged: (v) =>
                                onReworkToggle(t.productionProgress.id!, v ?? false),
                          ),
                        )
                      else
                        const SizedBox(width: 8),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
