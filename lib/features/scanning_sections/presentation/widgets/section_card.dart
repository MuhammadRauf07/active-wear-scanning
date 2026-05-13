import 'package:flutter/material.dart';

class SectionCard extends StatefulWidget {
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

  @override
  State<SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<SectionCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  IconData _getSectionIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('dashboard')) return Icons.auto_graph_rounded;
    if (t.contains('tray scanning')) return Icons.qr_code_scanner_rounded;
    if (t.contains('gbs')) return Icons.lan_rounded;
    if (t.contains('batch')) return Icons.layers_rounded;
    if (t.contains('processing')) return Icons.settings_input_component_rounded;
    if (t.contains('induction')) return Icons.vibration_rounded;
    if (t.contains('wip')) return Icons.bolt_rounded;
    if (t.contains('tracking')) return Icons.radar_rounded;
    return Icons.widgets_rounded;
  }

  Color _getGlowColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('dashboard') || t.contains('gbs')) return const Color(0xFF00E5FF); // Cyber Cyan
    if (t.contains('wip')) return const Color(0xFF00E676); // Neon Green
    if (t.contains('processing')) return const Color(0xFFFF1744); // Electric Red
    return const Color(0xFFFFD600); // Vivid Yellow
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = _getGlowColor(widget.title);

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
        onTapCancel: () => setState(() => _isHovered = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 100,
          margin: const EdgeInsets.only(bottom: 12),
          transform: _isHovered ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: const Color(0xFF0056D2), // Vibrant Royal Blue
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? glowColor.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? glowColor.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.15),
                blurRadius: _isHovered ? 25 : 15,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // NEON GROUNDING STRIP (Bottom Pulse)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: glowColor,
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withValues(alpha: 0.6 + (0.4 * _pulseController.value)),
                              blurRadius: 10 + (10 * _pulseController.value),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // CONTENT
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
                  child: Row(
                    children: [
                      // NEON ICON CIRCLE
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.2),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Center(
                          child: Icon(
                            _getSectionIcon(widget.title),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // TEXT
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                                height: 1.2,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
