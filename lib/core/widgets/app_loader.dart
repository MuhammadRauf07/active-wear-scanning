import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppLoaderContextAttach extends StatelessWidget {
  final Widget child;

  const AppLoaderContextAttach({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLoader.attachContext(context);
    });
    return child;
  }
}

class AppLoader {
  static final AppLoader _instance = AppLoader._internal();
  static BuildContext? _context;
  static bool _isDialogVisible = false;

  AppLoader._internal();

  factory AppLoader() => _instance;

  static void attachContext(BuildContext context) {
    _context = context;
  }

  static void show({
    String message = 'Please wait...',
    Widget? customIndicator,
    Color backgroundColor = Colors.white,
    double width = 200,
    double elevation = 20,
    double blurSigma = 4.0,
    TextStyle? textStyle,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) {
    if (_context == null || _isDialogVisible) return;
    _isDialogVisible = true;

    showGeneralDialog(
      context: _context!,
      barrierDismissible: false,
      barrierLabel: "Loader",
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim, __, ___) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Opacity(
          opacity: anim.value,
          child: Center(
            child: Material(
              elevation: elevation,
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                width: width,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: borderRadius,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    customIndicator ?? const CupertinoActivityIndicator(radius: 16),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: textStyle ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
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

  static void hide() {
    try {
      if (_isDialogVisible && _context != null) {
        // Safe check to see if context is still valid
        final navigator = Navigator.of(_context!, rootNavigator: true);
        if (navigator.canPop()) {
          navigator.pop();
        }
        _isDialogVisible = false;
      }
    } catch (e) {
      debugPrint('⚠️ AppLoader hide error: $e');
      _isDialogVisible = false; // Reset anyway
    }
  }
}
