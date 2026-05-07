import 'package:flutter/material.dart';

/// Standard empty state placeholder when no trays have been scanned yet.
class EmptyScanState extends StatelessWidget {
  final bool hasBorder;

  const EmptyScanState({
    super.key,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Text(
        'No scanned trays yet. Start by scanning a tray barcode.',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
      ),
    );

    if (hasBorder) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
        ),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: content,
    );
  }
}
