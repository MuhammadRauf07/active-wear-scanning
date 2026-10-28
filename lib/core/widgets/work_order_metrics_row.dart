import 'package:flutter/material.dart';

class WorkOrderMetricsRow extends StatelessWidget {
  final String workOrderDate;
  final String fabricationType;
  final String scannedTrays;
  final String scannedTubes;
  final EdgeInsetsGeometry padding;

  const WorkOrderMetricsRow({
    super.key,
    required this.workOrderDate,
    required this.fabricationType,
    required this.scannedTrays,
    required this.scannedTubes,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 6),
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth >= 600;

    final items = [
      {
        'label': 'WORK ORDER DATE',
        'icon': Icons.event_note_rounded,
        'value': workOrderDate.isNotEmpty ? workOrderDate : '---',
      },
      {
        'label': 'FABRICATION',
        'icon': Icons.texture_rounded,
        'value': fabricationType.isNotEmpty ? fabricationType : '---',
      },
      {
        'label': 'SCANNED TRAYS',
        'icon': Icons.layers_rounded,
        'value': scannedTrays,
      },
      {
        'label': 'SCANNED TUBES',
        'icon': Icons.analytics_rounded,
        'value': scannedTubes,
      },
    ];

    return Padding(
      padding: padding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items.map((item) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 10 : 6,
                  vertical: isTablet ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFB0BEC5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          size: isTablet ? 12 : 11,
                          color: const Color(0xFF1976D2),
                        ),
                        SizedBox(width: isTablet ? 6 : 4),
                        Expanded(
                          child: Text(
                            item['label'] as String,
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 8.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF546E7A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['value'] as String,
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF263238),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

