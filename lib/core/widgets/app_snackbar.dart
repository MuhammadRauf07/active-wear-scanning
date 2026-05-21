import 'package:flutter/material.dart';

enum SnackBarType { success, error, warning, info }

class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    required SnackBarType type,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    final Color bgColor;
    final Color iconColor;
    final Color textColor;
    final Color borderAccent;
    final IconData icon;
    final String defaultTitle;

    switch (type) {
      case SnackBarType.success:
        bgColor = const Color(0xFFECFDF5);      // Soft Mint Green
        borderAccent = const Color(0xFF10B981); // Vibrant Emerald
        iconColor = const Color(0xFF059669);    // Dark Green Icon
        textColor = const Color(0xFF065F46);    // Rich Forest Text
        icon = Icons.check_circle_rounded;
        defaultTitle = 'Success';
        break;
      case SnackBarType.error:
        bgColor = const Color(0xFFFEF2F2);      // Soft Rose Red
        borderAccent = const Color(0xFFEF4444); // Vibrant Red
        iconColor = const Color(0xFFDC2626);    // Dark Crimson Icon
        textColor = const Color(0xFF991B1B);    // Deep Red Text
        icon = Icons.error_rounded;
        defaultTitle = 'Error';
        break;
      case SnackBarType.warning:
        bgColor = const Color(0xFFFFFBEB);      // Soft Amber Yellow
        borderAccent = const Color(0xFFF59E0B); // Vibrant Gold
        iconColor = const Color(0xFFD97706);    // Dark Amber Icon
        textColor = const Color(0xFF92400E);    // Rich Bronze Text
        icon = Icons.warning_rounded;
        defaultTitle = 'Warning';
        break;
      case SnackBarType.info:
        bgColor = const Color(0xFFF0F9FF);      // Soft Sky Blue
        borderAccent = const Color(0xFF0EA5E9); // Vibrant Blue
        iconColor = const Color(0xFF0284C7);    // Dark Azure Icon
        textColor = const Color(0xFF0369A1);    // Deep Navy Text
        icon = Icons.info_rounded;
        defaultTitle = 'Information';
        break;
    }

    final snackTitle = title ?? defaultTitle;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderAccent.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Colored vertical border strip on left edge
              Container(
                width: 6,
                height: 52, // Soft thin border height
                color: borderAccent,
              ),
              const SizedBox(width: 16),
              
              // Notification Icon
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              
              // Notification Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snackTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textColor.withValues(alpha: 0.85),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Close button
              IconButton(
                icon: Icon(Icons.close_rounded, color: textColor.withValues(alpha: 0.5), size: 16),
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  // Helper shortcuts
  static void showSuccess(BuildContext context, {required String message, String? title, Duration duration = const Duration(seconds: 4)}) {
    show(context, message: message, type: SnackBarType.success, title: title, duration: duration);
  }

  static void showError(BuildContext context, {required String message, String? title, Duration duration = const Duration(seconds: 5)}) {
    show(context, message: message, type: SnackBarType.error, title: title, duration: duration);
  }

  static void showWarning(BuildContext context, {required String message, String? title, Duration duration = const Duration(seconds: 4)}) {
    show(context, message: message, type: SnackBarType.warning, title: title, duration: duration);
  }

  static void showInfo(BuildContext context, {required String message, String? title, Duration duration = const Duration(seconds: 4)}) {
    show(context, message: message, type: SnackBarType.info, title: title, duration: duration);
  }
}
