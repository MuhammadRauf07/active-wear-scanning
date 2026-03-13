import 'package:flutter/material.dart';

class DynamicInfoDisplay extends StatelessWidget {
  final bool? isSelected;
  final Color? containerColor;
  final Color? iconColor;
  final Color? textColor;

  /// new optional text color
  final Map<String, dynamic> items;

  const DynamicInfoDisplay({
    super.key,
    required this.items,
    this.isSelected,
    this.containerColor,
    this.iconColor,
    this.textColor,

    /// added here
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> rows = [];
    List<Widget> currentRowChildren = [];

    items.forEach((key, item) {
      var newItem = InfoItem(
        isSelected: isSelected ?? false,
        icon: item['icon'],
        label: item['label'],
        value: item['value'] ?? '',
        backgroundColor: containerColor,
        iconColor: iconColor,
        textColor: textColor,

        /// pass it down
      );

      currentRowChildren.add(Expanded(child: newItem));

      if (currentRowChildren.length == 2) {
        rows.add(Row(children: List.from(currentRowChildren)));
        currentRowChildren.clear();
      }
    });

    if (currentRowChildren.isNotEmpty) {
      rows.add(Row(children: currentRowChildren));
    }

    return Column(children: rows);
  }
}

class InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isSelected;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;

  /// new optional text color

  const InfoItem({
    super.key,
    required this.icon,
    required this.value,
    required this.isSelected,
    required this.label,
    this.backgroundColor,
    this.iconColor,
    this.textColor,

    /// added here
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: backgroundColor ?? (isSelected ? const Color(0xffd5e3f4) : Colors.grey[100])),
            child: Icon(icon, size: 16, color: iconColor ?? (isSelected ? const Color(0xFF1976D2) : Colors.blueAccent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.trim(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF1976D2) // priority 1
                        : textColor ?? Colors.grey[600],

                    /// priority 2 else default
                  ),
                ),
                Text(
                  value.trim(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF1976D2).withValues(alpha: 0.5)
                        /// priority 1
                        : textColor ?? Colors.grey[800],

                    /// priority 2 else default
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
