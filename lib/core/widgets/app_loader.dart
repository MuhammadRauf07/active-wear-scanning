import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
                    filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                    child: GestureDetector(
                      onTap: () {},
                      behavior: HitTestBehavior.opaque,
                      child: Container(color: Colors.black.withOpacity(0.25)),
                    ),
                  ),
                ),
                Center(
                  child: Material(
                    elevation: 20,
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      width: width,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CupertinoActivityIndicator(radius: 16),
                          const SizedBox(height: 16),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
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
    
    // Clear the overlay entry immediately in the next microtask
    Timer.run(() {
      if (_overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }
}
