import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A utility class for creating customizable text widgets in the [ProKit] package.
class ProKitText extends StatelessWidget {
  final String? text;
  final double? size;
  final FontWeight? weight;
  final String? family;
  final Color? color;
  final int? lines;
  final TextAlign? align;
  final double? letterSpacing;
  final TextStyle? textStyle;
  final bool? isUnderlined;
  final List<ProKitTextSpan>? textSpans; // List of text spans for RichText
  final TextOverflow? overflow;
  final bool selectable; // Option for selectable text

  /// Creates an instance of [ProKitText].
  ///
  /// Parameters:
  /// - [text]: The string to display.
  /// - [size]: The font size.
  /// - [weight]: The font weight.
  /// - [color]: The text color.
  /// - [lines]: Maximum number of lines to display.
  /// - [letterSpacing]: The amount of space between letters.
  /// - [align]: The alignment of the text.
  /// - [isUnderlined]: Whether the text is underlined.
  /// - [textSpans]: List of text spans for RichText support.
  /// - [overflow]: The text overflow behavior.
  /// - [selectable]: Whether the text is selectable.
  const ProKitText({
    super.key,
    this.text,
    this.size,
    this.weight,
    this.family,
    this.color,
    this.lines,
    this.align,
    this.letterSpacing,
    this.textStyle,
    this.isUnderlined = false,
    this.textSpans,
    this.overflow,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? _textStyle(color, size, weight, isUnderlined, letterSpacing: letterSpacing);

    if (textSpans != null && textSpans!.isNotEmpty) {
      /// RichText for handling multiple spans
      return Semantics(
        label: text,

        /// Accessible label for screen readers
        child: RichText(
          textAlign: align ?? TextAlign.start,
          text: TextSpan(
            style: style,
            children: textSpans!
                .map((span) => TextSpan(text: span.text, style: span.style ?? style, recognizer: span.onTap != null ? (TapGestureRecognizer()..onTap = span.onTap) : null))
                .toList(),
          ),
        ),
      );
    } else if (selectable) {
      /// SelectableText for copy-pasting
      return SelectableText(
        text ?? "",
        maxLines: lines ?? 1,
        textAlign: align ?? TextAlign.start,
        style: style,
        onTap: () {
          if (textSpans != null && textSpans!.isNotEmpty) {
            for (var span in textSpans!) {
              if (span.onTap != null) {
                span.onTap!();
              }
            }
          }
        },
      );
    } else {
      /// Standard Text widget
      return Text(text ?? "", maxLines: lines ?? 1, textAlign: align ?? TextAlign.start, overflow: overflow ?? TextOverflow.ellipsis, style: style);
    }
  }

  /// Creates a [TextStyle] with customizable properties.
  ///
  /// Parameters:
  /// - [color]: The text color.
  /// - [size]: The font size.
  /// - [weight]: The font weight.
  /// - [isUnderlined]: Whether the text is underlined.
  /// - [letterSpacing]: The amount of space between letters.
  ///
  /// Returns:
  /// A [TextStyle] with the specified properties.
  TextStyle _textStyle(Color? color, double? size, FontWeight? weight, bool? isUnderlined, {double? letterSpacing, String? family}) {
    return TextStyle(
      color: color ?? Colors.black,
      fontSize: size ?? 14,
      fontWeight: weight ?? FontWeight.normal,
      decoration: isUnderlined == true ? TextDecoration.underline : TextDecoration.none,
      fontFamily: family ?? "Poppins",
      letterSpacing: letterSpacing ?? -0.03,
      decorationStyle: TextDecorationStyle.solid,
    );
  }
}

/// A utility class for creating customizable text spans in the [ProKit] package.
class ProKitTextSpan {
  final String text;
  final TextStyle? style;
  final VoidCallback? onTap;

  /// Creates an instance of [ProKitTextSpan].
  ///
  /// Parameters:
  /// - [text]: The string to display.
  /// - [style]: The custom text style.
  /// - [onTap]: The callback function for click events.
  const ProKitTextSpan({required this.text, this.style, this.onTap});
}
