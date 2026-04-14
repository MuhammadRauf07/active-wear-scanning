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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: topPadding ?? 32, left: horizontalPadding ?? 0, right: horizontalPadding ?? 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          isShowBackIcon == null || isShowBackIcon! ? CustomBackButton(onBackPress: onBackPress) : const SizedBox.shrink(),

          /// Assuming this is defined elsewhere in your project.
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading.trim(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                SizedBox(height: subtitle != null ? 8 : 0),
                subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 14, color: Colors.grey[600])) : const SizedBox.shrink(),
              ],
            ),
          ),
          callBack == null
              ? widget ?? Icon(icon, color: Colors.blueAccent)
              : SizedBox(
                  width: 100,
                  child: CustomOutlinedButton(
                    borderColor: Colors.blue,
                    label: buttonLabel,
                    fillColor: Colors.blueAccent,
                    textColor: Colors.white,
                    onPressed: callBack,
                  ),
                ),
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
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.blue, size: 18),
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
