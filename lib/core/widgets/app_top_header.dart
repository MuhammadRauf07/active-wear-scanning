import 'package:flutter/material.dart';

import 'custom_outlined_button.dart';

class CustomInspectionHeader extends StatelessWidget {
  final String heading;
  final IconData? icon;
  final String? subtitle;
  final String? buttonLabel;
  final Widget? widget;
  final double? topPadding;
  final double? horizontalPadding;
  final bool? isShowBackIcon;
  final VoidCallback? callBack;
  final VoidCallback? onBackPress;
  final Color? buttonColor;

  const CustomInspectionHeader({
    super.key,
    required this.heading,
    this.icon,
    this.widget,
    this.topPadding,
    this.isShowBackIcon,
    this.subtitle,
    this.callBack,
    this.buttonLabel,
    this.onBackPress,
    this.horizontalPadding,
    this.buttonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: topPadding ?? 16, left: horizontalPadding ?? 16, right: horizontalPadding ?? 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isShowBackIcon == null || isShowBackIcon!) 
            CustomBackButton(onBackPress: onBackPress),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading.trim(),
                  style: const TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.w800, 
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!, 
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (callBack != null)
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: callBack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor ?? const Color(0xFF1B64A3),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(buttonLabel ?? 'Save', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            )
          else
            widget ?? Icon(icon, color: const Color(0xFF1B64A3)),
        ],
      ),
    );
  }
}

class CustomBackButton extends StatelessWidget {
  final VoidCallback? onBackPress;

  const CustomBackButton({super.key, this.onBackPress});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: IconButton(
        iconSize: 20,
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1B64A3)),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF1B64A3).withValues(alpha: 0.08),
          padding: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          if (onBackPress != null) {
            onBackPress!();
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
