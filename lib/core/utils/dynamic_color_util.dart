import 'package:flutter/material.dart';

class DynamicColorUtil {
  static Color getBackgroundColor(double value) {
    if (value == 100) return Colors.grey.shade200;
    if (value == 0.0) return const Color(0xffF8FAFC);
    if (value == -1) return  Colors.transparent;

    double opacity = 0.8;
    int alpha = (opacity * 255).toInt();

    if (value >= 1.0) {
      return const Color(0xFFecfdf5).withAlpha(alpha); /// Light Green
    } else if (value >= 0.75) {
      return const Color(0xFFfefce8).withAlpha(alpha); /// Light Yellow
    } else if (value >= 0.50) {
      return const Color(0xFFeff6ff).withAlpha(alpha); /// Light Blue
    } else {
      return const Color(0xFFfff1f2).withAlpha(alpha); /// Light Red
    }
  }

  static Color getDynamicTextColor(double? value) {
    if (value == 100) return Colors.blue;
    if (value == null) return const Color(0xFF000000);

    if (value >= 1.0) {
      return const Color(0xFF388E3C); /// Dark Green
    } else if (value >= 0.75) {
      return const Color(0xFFFBC02D); /// Dark Yellow
    } else if (value >= 0.50) {
      return const Color(0xFF1976D2); /// Dark Blue
    } else if (value > 0 && value < 0.5) {
      return const Color(0xFFD32F2F); /// Dark Red
    } else {
      return Colors.grey.shade400; /// Neutral Gray
    }
  }
}
