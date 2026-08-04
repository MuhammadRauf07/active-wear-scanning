import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Theme Palette
  static const Color primaryBlue = Color(0xFF0D47A1);      // Primary controls, dashboard
  static const Color darkSlate = Color(0xFF455A64);        // Active machine, metadata tags
  static const Color successGreen = Color(0xFF2E7D32);     // Save buttons, successful status
  static const Color bgGrey = Color(0xFFF1F5F9);           // Slate grey screen background
  static const Color borderGrey = Color(0xFFB0BEC5);       // Muted slate borders

  // Standard Elevations & Shadows
  static List<BoxShadow> get premiumShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ];

  // Standardized Save Changes Button style
  static ButtonStyle saveButtonStyle({required bool isEnabled}) {
    return ElevatedButton.styleFrom(
      backgroundColor: successGreen,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.grey.shade200,
      disabledForegroundColor: Colors.grey.shade400,
      elevation: 0,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }
}

class HapticFeedbackHelper {
  // Light, rapid tick when barcode is scanned successfully
  static Future<void> scanSuccess() async {
    await HapticFeedback.lightImpact();
  }

  // Dual-pulse warning rumble on validation error or API error
  static Future<void> scanError() async {
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.vibrate();
  }

  // Subtle selection click when interactive button is pressed
  static Future<void> buttonClick() async {
    await HapticFeedback.selectionClick();
  }
}
