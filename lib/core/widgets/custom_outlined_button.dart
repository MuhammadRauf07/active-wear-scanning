import 'package:active_wear_scanning/core/widgets/tap_bouncer.dart';
import 'package:flutter/material.dart';

class CustomOutlinedButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final double? iconSize;
  final double? textSize;
  final double? buttonHeight;
  final Color? fillColor;
  final Color? textColor;
  final Color borderColor;
  final Alignment? alignment;
  final VoidCallback? onPressed;

  const CustomOutlinedButton({
    this.label,
    this.icon,
    this.iconSize,
    this.textSize,
    this.buttonHeight,
    this.fillColor,
    this.textColor,
    this.alignment,
    required this.borderColor,
    this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (onPressed != null) {
          TapDeBouncer.run(onPressed!);
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: buttonHeight ?? 42,
        alignment: alignment ?? Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: fillColor ?? Colors.transparent,
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,

          /// Ensures the button resizes to fit content
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor, size: iconSize ?? 18),
              const SizedBox(width: 8),

              /// Adds spacing only when the icon exists
            ],
            Flexible(
              child: label != null
                  ? Text(
                      label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      /// Ensures text is truncated if too long
                      style: TextStyle(color: textColor, fontSize: textSize ?? 14, fontWeight: FontWeight.w600),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
