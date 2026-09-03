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
      margin: EdgeInsets.only(
        top: topPadding ?? 12,
        left: horizontalPadding ?? 16,
        right: horizontalPadding ?? 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB0BEC5),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading.trim(),
                  style: const TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.w800, 
                    color: Color(0xFF263238),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!, 
                    style: const TextStyle(
                      fontSize: 10, 
                      color: Color(0xFF546E7A),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (callBack != null)
            SizedBox(
              height: 38,
              child: ElevatedButton(
                onPressed: callBack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor ?? const Color(0xFF1B64A3),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(buttonLabel ?? 'Save', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
