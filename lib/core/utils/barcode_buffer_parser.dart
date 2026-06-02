import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';

class BarcodeBufferParser {
  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  bool handleKey(KeyEvent event, void Function(String) onScanComplete) {
    // If loader is active/visible, block keystrokes and clear buffer to prevent API collisions
    if (AppLoader.isVisible) {
      _barcodeBuffer = '';
      return false;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final now = DateTime.now();
    if (_lastKeyPress != null && now.difference(_lastKeyPress!).inMilliseconds > 200) {
      _barcodeBuffer = '';
    }
    _lastKeyPress = now;

    final ch = event.character;
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        ch == '\n' || ch == '\r';

    if (isEnter) {
      if (_barcodeBuffer.isNotEmpty) {
        final code = _barcodeBuffer;
        _barcodeBuffer = '';
        onScanComplete(code);
        return true;
      }
    } else if (ch != null && ch.isNotEmpty) {
      _barcodeBuffer += ch;
    }
    return false;
  }
}
