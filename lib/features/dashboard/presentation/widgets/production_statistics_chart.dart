import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/features/wip/repo/wip_repo.dart';
import 'package:active_wear_scanning/features/wip/model/wip_model.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

// ── Data model for a single locator's aggregated stats ───────────────────────
class LocatorStat {
  final int id;
  final String name;
  final double quantity;
  final Color color;
  final List<ProductionProgressResponseModel> trays;
  final bool isKnitting;

  LocatorStat({
    required this.id,
    required this.name,
    required this.quantity,
    required this.color,
    required this.trays,
    required this.isKnitting,
  });
}

// ── Main Widget ───────────────────────────────────────────────────────────────
class ProductionStatisticsChart extends StatefulWidget {
  const ProductionStatisticsChart({super.key});

  @override
  State<ProductionStatisticsChart> createState() => _ProductionStatisticsChartState();
}

class _ProductionStatisticsChartState extends State<ProductionStatisticsChart> {
  final WipRepo _wipRepo = WipRepo();
  bool _isLoading = true;
  String? _error;
  int? _touchedIndex;

  List<LocatorStat> _stats = [];
  double _totalPieces = 0;

  static const _chartColors = [
    Color(0xFFE91E63),
    Color(0xFFFF9800),
    Color(0xFF29B6F6),
    Color(0xFF9C27B0),
    Color(0xFF4CAF50),
    Color(0xFFF44336),
    Color(0xFF009688),
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // ── Data Fetching ─────────────────────────────────────────────────────────
  Future<void> _fetchData() async {
    try {
      final locRes = await _wipRepo.fetchLocators();
      if (!locRes.success || locRes.data == null) {
        if (mounted) setState(() { _error = 'Failed to load locators'; _isLoading = false; });
        return;
      }

      final allLocs = locRes.data as List<LocatorResponse>;
      final floorLocs = allLocs
          .where((l) => (l.locator.logicalWH?.toUpperCase() ?? '').contains('FLOOR'))
          .toList()
          .reversed
          .toList();

      final List<LocatorStat> tempStats = [];
      double totalPieces = 0;
      int colorIdx = 0;

      for (final l in floorLocs) {
        final locId = l.locator.id;

        final wipRes = await _wipRepo.fetchWipDetails(locId);
        if (wipRes.success && wipRes.data != null) {
          final trays = wipRes.data as List<ProductionProgressResponseModel>;
          final locPieces = trays.fold<double>(0, (sum, t) => sum + (t.productionProgress.primaryQuantity ?? 0));

          if (locPieces > 0) {
            final name = l.locator.description;
            tempStats.add(LocatorStat(
              id: locId,
              name: name,
              quantity: locPieces,
              color: _chartColors[colorIdx % _chartColors.length],
              trays: trays,
              isKnitting: name.toLowerCase().contains('knit'),
            ));
            totalPieces += locPieces;
            colorIdx++;
          }
        }
      }

      tempStats.sort((a, b) => b.quantity.compareTo(a.quantity));

      if (mounted) {
        setState(() {
          _stats = tempStats;
          _totalPieces = totalPieces;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── Interaction: tap slice → show bottom sheet ────────────────────────────
  void _onSliceTapped(int index) {
    if (index < 0 || index >= _stats.length) return;
    setState(() => _touchedIndex = index);
    _showDrillDownSheet(_stats[index]);
  }

  void _showDrillDownSheet(LocatorStat stat) {
    // Aggregate pieces per work-order (Knitting) or per batch (Processing)
    final groups = <String, double>{};
    for (final t in stat.trays) {
      final String key;
      if (stat.isKnitting) {
        final wo = t.workOrderHeader.workOrderCode;
        final item = t.item.description;
        key = item.isNotEmpty ? '$wo — $item' : wo;
      } else {
        final batch = t.batchHeader?.batchHeaderCode ??
            t.productionProgress.batchHeaderId?.toString() ??
            'Unknown';
        final color = t.batchHeader?.colorDescription ?? '';
        key = color.isNotEmpty ? '$batch ($color)' : batch;
      }
      groups[key] = (groups[key] ?? 0) + (t.productionProgress.primaryQuantity ?? 0);
    }

    final sortedGroups = groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sortedGroups.fold<double>(0, (s, e) => s + e.value);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),

              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(color: stat.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stat.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(total / 12).toStringAsFixed(1)} Dzns',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4A5568)),
                        ),
                        Text(
                          '${sortedGroups.length} ${stat.isKnitting ? "Work Orders" : "Batches"}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Divider(color: Colors.grey.shade200, thickness: 1, indent: 20, endIndent: 20),

              // ── Column Headers ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        stat.isKnitting ? 'Work Order / Item' : 'Batch / Color',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
                      ),
                    ),
                    Text('DZNS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
                    const SizedBox(width: 46),
                    Text('%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
                  ],
                ),
              ),

              // ── Items List ────────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  itemCount: sortedGroups.length,
                  separatorBuilder: (context, idx) => Divider(color: Colors.grey.shade100, height: 1),
                  itemBuilder: (_, i) {
                    final e = sortedGroups[i];
                    final pct = total > 0 ? (e.value / total * 100) : 0;
                    final dzns = e.value / 12;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.key,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: total > 0 ? e.value / total : 0,
                                    backgroundColor: Colors.grey.shade100,
                                    color: stat.color,
                                    minHeight: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 48,
                            child: Text(dzns.toStringAsFixed(1), textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4A5568))),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 38,
                            child: Text('${pct.toStringAsFixed(0)}%', textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: stat.color)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _touchedIndex = null);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section title row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PRODUCTION STATISTICS',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF4A5568)),
            ),
            if (!_isLoading && _error == null && _totalPieces > 0)
              Text(
                '${(_totalPieces / 12).toStringAsFixed(0)} DZNS',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF718096)),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Card containing chart + legend
        ContentCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(32),
                      child: Text(_error!, style: const TextStyle(color: Colors.red))))
                  : _stats.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(32),
                          child: Text('No production data available.')))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ── Pie Chart ─────────────────────────────────
                            Expanded(
                              flex: 5,
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 0,
                                    pieTouchData: PieTouchData(
                                      touchCallback: (FlTouchEvent event, PieTouchResponse? response) {
                                        if (event is FlTapUpEvent) {
                                          final idx = response?.touchedSection?.touchedSectionIndex ?? -1;
                                          if (idx >= 0) _onSliceTapped(idx);
                                        }
                                      },
                                    ),
                                    sections: List.generate(_stats.length, (i) {
                                      final stat = _stats[i];
                                      final isTouched = _touchedIndex == i;
                                      final pct = _totalPieces > 0 ? (stat.quantity / _totalPieces * 100) : 0;
                                      return PieChartSectionData(
                                        color: stat.color,
                                        value: stat.quantity,
                                        title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
                                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                        radius: isTouched ? 82 : 70,
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),

                            // ── Legend ────────────────────────────────────
                            Expanded(
                              flex: 6,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(_stats.length, (i) {
                                  final stat = _stats[i];
                                  final pct = _totalPieces > 0 ? (stat.quantity / _totalPieces * 100) : 0;
                                  final isTouched = _touchedIndex == i;
                                  return GestureDetector(
                                    onTap: () => _onSliceTapped(i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: isTouched ? stat.color.withValues(alpha: 0.08) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 8, height: 8,
                                                decoration: BoxDecoration(color: stat.color, shape: BoxShape.circle),
                                              ),
                                              const SizedBox(width: 8),
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 95),
                                                child: Text(
                                                  stat.name,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: isTouched ? FontWeight.w700 : FontWeight.w500,
                                                    color: const Color(0xFF4A5568),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${pct.toStringAsFixed(0)}%',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: stat.color),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
        ),
        const SizedBox(height: 6),
        if (!_isLoading && _stats.isNotEmpty)
          Center(
            child: Text(
              'Tap a slice or legend item for details',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
      ],
    );
  }
}
