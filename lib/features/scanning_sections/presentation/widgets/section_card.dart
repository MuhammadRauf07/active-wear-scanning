import 'dart:ui';
import 'package:flutter/material.dart';

class SectionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String sectionCode;
  final double progressValue;
  final bool? isShowProgress;
  final VoidCallback onTap;
  final bool enabled;

  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sectionCode,
    required this.progressValue,
    this.isShowProgress,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<SectionCard> {
  bool _isHovered = false;

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
    if (t.contains('carton packing') || t.contains('cartanization')) return Icons.inventory_2_rounded;
    if (t.contains('md receiving') || t.contains('md')) return Icons.move_to_inbox_rounded;
    if (t.contains('po') || t.contains('style')) return Icons.style_rounded;
    return Icons.widgets_rounded;
  }

  Color _getGlowColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('dashboard') || t.contains('gbs')) return const Color(0xFF00E5FF); // Cyber Cyan
    if (t.contains('wip')) return const Color(0xFF00E676); // Neon Green
    if (t.contains('processing')) return const Color(0xFFFF1744); // Electric Red
    if (t.contains('carton packing') || t.contains('cartanization')) return const Color(0xFFFF9100); // Orange
    if (t.contains('md receiving') || t.contains('md')) return const Color(0xFFD500F9); // Neon Purple
    return const Color(0xFFFFD600); // Vivid Yellow
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() { _isHovered = true; }) : null,
        onTapUp: widget.enabled ? (_) => setState(() { _isHovered = false; }) : null,
        onTapCancel: widget.enabled ? () => setState(() { _isHovered = false; }) : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: 100,
          margin: const EdgeInsets.only(bottom: 12),
          transform: _isHovered && widget.enabled ? (Matrix4.identity()..scale(1.03)) : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              // Soft Multi-layered Shadow
              BoxShadow(
                color: (widget.enabled ? const Color(0xFF0D47A1) : const Color(0xFF64748B))
                    .withValues(alpha: _isHovered && widget.enabled ? 0.3 : 0.15),
                blurRadius: _isHovered && widget.enabled ? 30 : 20,
                offset: const Offset(0, 12),
              ),
              if (_isHovered && widget.enabled)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: -5,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: (widget.enabled ? const Color(0xFF0D47A1) : const Color(0xFF64748B))
                      .withValues(alpha: widget.enabled ? 0.85 : 0.5), // Glassy Royal Blue vs Faded Slate
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: widget.enabled ? 0.2 : 0.1),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    // CONTENT
                    Opacity(
                      opacity: widget.enabled ? 1.0 : 0.45, // Premium faded glassmorphic aesthetic
                      child: Padding(
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
