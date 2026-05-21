import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

class AppLoader {
  static final AppLoader _instance = AppLoader._internal();
  static OverlayEntry? _overlayEntry;
  static bool _isVisible = false;

  static bool get isVisible => _isVisible;

  AppLoader._internal();
  factory AppLoader() => _instance;

  static void show(
    BuildContext context, {
    String message = 'Please wait...',
    double width = 240,
  }) {
    if (_isVisible) return;
    _isVisible = true;

    Timer.run(() {
      if (!_isVisible || _overlayEntry != null) return;

      final overlay = Overlay.of(context, rootOverlay: true);
      
      _overlayEntry = OverlayEntry(
        builder: (context) => Material(
          type: MaterialType.transparency,
          child: ExcludeSemantics(
            child: Stack(
              children: [
                // 1. Soft blurred premium backdrop
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: GestureDetector(
                      onTap: () {},
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
                
                // 2. Centered Premium Card
                Center(
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    tween: Tween<double>(begin: 0.85, end: 1.0),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                      width: width,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0), 
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: const Color(0xFF1B64A3).withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Modern glowing progressive spinner
                          const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B64A3)),
                              backgroundColor: Color(0xFFE2E8F0),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13, 
                              fontWeight: FontWeight.w900, 
                              color: Color(0xFF1E293B),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      overlay.insert(_overlayEntry!);
    });
  }

  static void hide(BuildContext context) {
    _isVisible = false;
    Timer.run(() {
      if (_overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }
}
