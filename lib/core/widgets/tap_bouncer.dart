import 'package:flutter/animation.dart';

class TapDeBouncer {
  static bool _isTapped = false;
  static const Duration delay = Duration(milliseconds: 500);

  static void reset() => _isTapped = false;

  static Future<void> run(VoidCallback action) async {
    if (_isTapped) return;

    _isTapped = true;
    action();

    await Future.delayed(delay);
    reset();
  }
}
