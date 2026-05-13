import 'package:active_wear_scanning/core/utils/dynamic_color_util.dart';
import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String sectionCode;
  final double progressValue;
  final bool? isShowProgress;
  final VoidCallback onTap;

  const
  SectionCard({super.key, required this.title, required this.subtitle, required this.sectionCode, required this.progressValue, this.isShowProgress, required this.onTap});

  IconData _getSectionIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('dashboard')) return Icons.factory_outlined;
    if (t.contains('tray scanning')) return Icons.qr_code_scanner;
    if (t.contains('gbs')) return Icons.inventory_2_outlined;
    if (t.contains('batch')) return Icons.assignment_outlined;
    if (t.contains('processing')) return Icons.settings_outlined;
    if (t.contains('induction')) return Icons.warehouse_outlined;
    if (t.contains('wip')) return Icons.account_tree_outlined;
    if (t.contains('tracking')) return Icons.location_on_outlined;
    return Icons.folder_outlined;
  }

  Color _getSectionColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('dashboard') || t.contains('gbs')) return const Color(0xFF1B64A3); // Industrial Blue
    if (t.contains('wip')) return const Color(0xFF2E7D32); // Green
    return const Color(0xFFE67E22); // Industrial Orange
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getSectionColor(title);
    final iconBgColor = accentColor.withValues(alpha: 0.1);

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: accentColor, width: 4),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getSectionIcon(title),
                        size: 28,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
