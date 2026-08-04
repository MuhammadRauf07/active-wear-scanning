import 'package:flutter/material.dart';

enum SnackBarType { success, error, warning, info }

class AppSnackBar {
  static OverlayEntry? _currentOverlayEntry;

  static void show(
    BuildContext context, {
    required String message,
    required SnackBarType type,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    // Dismiss any existing SnackBar overlay immediately
    dismiss();

    final overlayState = Overlay.of(context);
    
    _currentOverlayEntry = OverlayEntry(
      builder: (context) => _SnackBarOverlay(
        message: message,
        type: type,
        title: title,
        duration: duration,
        onDismiss: () {
          dismiss();
        },
      ),
    );

    overlayState.insert(_currentOverlayEntry!);
  }

  static void dismiss() {
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;
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

class _SnackBarOverlay extends StatefulWidget {
  final String message;
  final SnackBarType type;
  final String? title;
  final Duration duration;
  final VoidCallback onDismiss;

  const _SnackBarOverlay({
    required this.message,
    required this.type,
    this.title,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_SnackBarOverlay> createState() => _SnackBarOverlayState();
}

class _SnackBarOverlayState extends State<_SnackBarOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _yOffsetAnimation;
  late final Animation<double> _opacityAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _yOffsetAnimation = Tween<double>(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Play slide and fade entry animation
    _controller.forward();

    // Auto dismiss after specified duration
    Future.delayed(widget.duration, () {
      if (mounted && !_isDismissing) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_isDismissing) return;
    setState(() {
      _isDismissing = true;
    });
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color iconColor;
    final Color textColor;
    final Color borderAccent;
    final IconData icon;
    final String defaultTitle;

    switch (widget.type) {
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

    final snackTitle = widget.title ?? defaultTitle;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          bottom: 96 + _yOffsetAnimation.value,
          left: 16,
          right: 16,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: Container(
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
                    // Vertical accent strip on left
                    Container(
                      width: 6,
                      height: 52,
                      color: borderAccent,
                    ),
                    const SizedBox(width: 16),
                    
                    // Notification Icon
                    Icon(icon, color: iconColor, size: 22),
                    const SizedBox(width: 12),
                    
                    // Text Content
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
                              widget.message,
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
                      onPressed: _dismiss,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
