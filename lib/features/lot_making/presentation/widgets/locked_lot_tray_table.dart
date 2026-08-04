import 'package:flutter/material.dart';

/// Expandable sub-table shown under a locked lot row in [LotListScreen].
///
/// Receives the raw batch-line maps and a [trayIdToCode] lookup so it can
/// resolve tray codes from `trayId` without needing parent state directly.
class LockedLotTrayTable extends StatelessWidget {
  final List<Map<String, dynamic>> lines;

  /// Maps `TrayDetail.id → trayCode`. Built from [_primaryTrayIdToCode] in parent.
  final Map<int, String> trayIdToCode;

  const LockedLotTrayTable({
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
    // Path 2: lookup via trayId (the actual field name posted by lot making)
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
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
            SizedBox(width: 8),
            Text(
              'No tray details found in this lot.',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent, // Fix: Transparent to allow parent border to connect
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sub-table header ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              border: Border(
                top: BorderSide(color: Color(0xFFCBD5E1)),
                bottom: BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
            child: Row(
              children: [
                _buildSubHeaderCell('TRAY #', 2),
                _buildSubHeaderCell('WORK ORDER', 2),
                _buildSubHeaderCell('ITEM DESCRIPTION', 4),
                _buildSubHeaderCell('PCS/TUBE', 2, align: TextAlign.center),
                _buildSubHeaderCell('TUBES', 2, align: TextAlign.center),
                _buildSubHeaderCell('TOTAL PCS', 2, align: TextAlign.center),
              ],
            ),
          ),
          
          // ── Sub-table rows ─────────────────────────────────────────────────
          ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lines.length,
            separatorBuilder: (context, index) => Container(height: 1, color: const Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final line = lines[index];
              final trayCode = _resolveTrayCode(line);
              final woCode = line['workOrderHeader']?['workOrderCode']?.toString() ?? '-';
              final itemDesc = line['item']?['description']?.toString() ?? '-';
              final pgt = (line['item']?['perGarmentTube'] as num?)?.toDouble() ?? 0;
              final tubes = (line['batchLines']?['primaryQuantity'] as num?)?.toDouble() ?? 0;
              final pcs = pgt > 0 ? (tubes * pgt).toInt() : 0;
              
              final bool isLast = index == lines.length - 1;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: isLast 
                      ? const BorderRadius.vertical(bottom: Radius.circular(8))
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildSubDataCell(trayCode, 2, isBold: true),
                    _buildSubDataCell(woCode, 2),
                    _buildSubDataCell(itemDesc, 4),
                    _buildSubDataCell(pgt > 0 ? pgt.toStringAsFixed(0) : '-', 2, align: TextAlign.center),
                    _buildSubDataCell(tubes.toStringAsFixed(0), 2, align: TextAlign.center),
                    _buildSubDataCell(pcs > 0 ? '$pcs' : '-', 2, align: TextAlign.center, isHighlight: true),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeaderCell(String label, int flex, {TextAlign align = TextAlign.start}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: const TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w900,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSubDataCell(String value, int flex, 
      {bool isBold = false, TextAlign align = TextAlign.start, bool isHighlight = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight: isBold || isHighlight ? FontWeight.w800 : FontWeight.w500,
          color: isHighlight ? const Color(0xFF1B64A3) : const Color(0xFF334155),
        ),
      ),
    );
  }
}

