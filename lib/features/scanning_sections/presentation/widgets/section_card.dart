import 'package:active_wear_scanning/core/utils/dynamic_color_util.dart';
import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String sectionCode;
  final double progressValue;
  final bool? isShowProgress;
  final VoidCallback onTap;

  const
  SectionCard({super.key, required this.title, required this.subtitle, required this.sectionCode, required this.progressValue, this.isShowProgress, required this.onTap});

  IconData _getSectionIcon(String code) {
    switch (code.toUpperCase()) {
      case 'TRAY':
        return Icons.inventory_2;
      case 'ORDER':
        return Icons.inventory_2;
      case 'SCAN':
        return Icons.qr_code_scanner;
      default:
        return Icons.folder_open;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: DynamicColorUtil.getBackgroundColor(progressValue),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: DynamicColorUtil.getDynamicTextColor(progressValue)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(color: DynamicColorUtil.getDynamicTextColor(progressValue), borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.all(8),
                    child: Icon(_getSectionIcon(sectionCode), size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DynamicColorUtil.getDynamicTextColor(progressValue)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Wrap(
                            children: [Text(subtitle, maxLines: 2, style: TextStyle(fontSize: 12, color: DynamicColorUtil.getDynamicTextColor(progressValue)))],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              const SizedBox(height: 12),
              if (isShowProgress == true)
                LinearProgressIndicator(
                  value: 1,
                  minHeight: 5,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(DynamicColorUtil.getDynamicTextColor(progressValue)),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
