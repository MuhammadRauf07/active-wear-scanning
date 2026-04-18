import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:async';

class AppLoader {
  static final AppLoader _instance = AppLoader._internal();
  static OverlayEntry? _overlayEntry;
  static bool _isVisible = false;

  AppLoader._internal();
  factory AppLoader() => _instance;

  static void show(
    BuildContext context, {
    String message = 'Please wait...',
    double width = 220,
  }) {
    if (_isVisible) return;
    _isVisible = true;

    // Use a small delay to ensure we are not in the middle of a build
    Timer.run(() {
      if (!_isVisible || _overlayEntry != null) return;

      final overlay = Overlay.of(context, rootOverlay: true);
      
      _overlayEntry = OverlayEntry(
        builder: (context) => Material(
          type: MaterialType.transparency,
          child: ExcludeSemantics(
            child: Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: GestureDetector(
                      onTap: () {},
                      behavior: HitTestBehavior.opaque,
                      child: Container(color: Colors.black.withOpacity(0.25)),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    width: width,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          height: 44,
                          width: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            decoration: TextDecoration.none,
                            letterSpacing: -0.2,
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
      );

      overlay.insert(_overlayEntry!);
    });
  }

  static void hide(BuildContext context) {
    _isVisible = false;
    
    // Clear the overlay entry immediately in the next microtask
    Timer.run(() {
      if (_overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }
}
