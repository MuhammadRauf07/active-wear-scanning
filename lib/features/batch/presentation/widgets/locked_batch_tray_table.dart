import 'package:flutter/material.dart';

/// Expandable sub-table shown under a locked batch row in [BatchListScreen].
///
/// Receives the raw batch-line maps and a [trayIdToCode] lookup so it can
/// resolve tray codes from `trayId` without needing parent state directly.
class LockedBatchTrayTable extends StatelessWidget {
  final List<Map<String, dynamic>> lines;

  /// Maps `TrayDetail.id → trayCode`. Built from [_primaryTrayIdToCode] in parent.
  final Map<int, String> trayIdToCode;

  const LockedBatchTrayTable({
    super.key,
    required this.lines,
    required this.trayIdToCode,
  });

  static const _subHeaderStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Color(0xFF6B7280),
    letterSpacing: 0.4,
  );

  String _resolveTrayCode(Map<String, dynamic> line) {
    // Path 1: embedded tray detail in API response
    final embedded = line['trayDetail']?['trayCode']?.toString() ??
        line['primaryTray']?['trayCode']?.toString() ??
        line['tray']?['trayCode']?.toString();
    if (embedded != null && embedded.isNotEmpty) return embedded;
    // Path 2: lookup via trayId (the actual field name posted by batch scanning)
    final trayId = line['batchLines']?['trayId'] as int?;
    if (trayId != null) {
      final fromMap = trayIdToCode[trayId];
      if (fromMap != null && fromMap.isNotEmpty) return fromMap;
      return 'ID:$trayId';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(
            left: BorderSide(color: Colors.indigo.shade200, width: 3),
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(
              'No tray details available.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo.shade50.withValues(alpha: 0.4),
        border: Border(
          left: BorderSide(color: Colors.indigo.shade300, width: 3),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sub-table header ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              border:
                  Border(bottom: BorderSide(color: Colors.indigo.shade100)),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('TRAY CODE', style: _subHeaderStyle)),
                Expanded(
                    flex: 2,
                    child: Text('WORK ORDER', style: _subHeaderStyle)),
                Expanded(
                    flex: 4,
                    child:
                        Text('ITEM DESCRIPTION', style: _subHeaderStyle)),
                Expanded(
                    flex: 2,
                    child: Text('PCS PER TUBE',
                        style: _subHeaderStyle,
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: Text('TUBES',
                        style: _subHeaderStyle,
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: Text('PCS',
                        style: _subHeaderStyle,
                        textAlign: TextAlign.center)),
              ],
            ),
          ),
          // ── Sub-table rows ─────────────────────────────────────────────────
          ...lines.asMap().entries.map((entry) {
            final i = entry.key;
            final line = entry.value;
            final trayCode = _resolveTrayCode(line);
            final woCode =
                line['workOrderHeader']?['workOrderCode']?.toString() ?? '-';
            final itemDesc =
                line['item']?['description']?.toString() ?? '-';
            final pgt =
                (line['item']?['perGarmentTube'] as num?)?.toDouble() ?? 0;
            final tubes =
                (line['batchLines']?['primaryQuantity'] as num?)?.toDouble() ??
                    0;
            final pcs = pgt > 0 ? (tubes * pgt).toInt() : 0;
            final isTrayResolved =
                trayCode != '-' && !trayCode.startsWith('ID:');

            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: i.isEven
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.indigo.shade50.withValues(alpha: 0.3),
                border: Border(
                    bottom: BorderSide(color: Colors.indigo.shade50)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      trayCode,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      woCode,
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.black),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      itemDesc,
                      style: const TextStyle(
                          fontSize: 9, color: Colors.black),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      pgt > 0 ? pgt.toStringAsFixed(0) : '-',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.black),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      tubes.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.black),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      pcs > 0 ? pcs.toString() : '-',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.black),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
