import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String sectionCode;
  final double progressValue;
  final bool? isShowProgress;
  final VoidCallback onTap;

  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sectionCode,
    required this.progressValue,
    this.isShowProgress,
    required this.onTap,
  });

  IconData _getSectionIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('dashboard')) return Icons.factory;
    if (t.contains('tray scanning')) return Icons.barcode_reader;
    if (t.contains('gbs')) return Icons.inventory_2;
    if (t.contains('batch')) return Icons.assignment;
    if (t.contains('processing')) return Icons.settings_rounded;
    if (t.contains('induction')) return Icons.warehouse;
    if (t.contains('wip')) return Icons.account_tree;
    if (t.contains('tracking')) return Icons.location_on;
    return Icons.folder;
  }

  Color _getGlowColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('dashboard') || t.contains('gbs')) return const Color(0xFF29B6F6); // Blue Glow
    if (t.contains('wip')) return const Color(0xFF66BB6A); // Green Glow
    return const Color(0xFFFFA726); // Orange Glow
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = _getGlowColor(title);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // MAIN METAL BODY
                Column(
                  children: [
                    // Top Metal Section
                    Expanded(
                      flex: 7,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.grey.shade400,
                              Colors.grey.shade600,
                              Colors.grey.shade400,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.2),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.1),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Bottom Dark Section
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          image: DecorationImage(
                            image: const NetworkImage('https://www.transparenttextures.com/patterns/carbon-fibre.png'), // Subtle texture
                            repeat: ImageRepeat.repeat,
                            opacity: 0.2,
                            colorFilter: ColorFilter.mode(Colors.grey.shade900, BlendMode.srcATop),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // GLOWING BARS
                // Top Border Glow
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(color: glowColor, blurRadius: 4, spreadRadius: 1),
                      ],
                    ),
                  ),
                ),
                // Middle Divider Glow
                Positioned(
                  bottom: 110 * 0.3 - 1,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          glowColor.withValues(alpha: 0.1),
                          glowColor,
                          glowColor.withValues(alpha: 0.1),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(color: glowColor.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1),
                      ],
                    ),
                  ),
                ),

                // CONTENT
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      // ICON BOX
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFF263238),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(2, 2)),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _getSectionIcon(title),
                            color: glowColor.withValues(alpha: 0.8),
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // TEXT
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Color(0xFF212121),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
