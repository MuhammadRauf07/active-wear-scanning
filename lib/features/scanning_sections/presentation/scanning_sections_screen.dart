import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/features/batch/presentation/batch_list_screen.dart';
import 'package:active_wear_scanning/features/gbs/presentation/gbs_receiving_screen.dart';
import 'package:active_wear_scanning/features/header/order_header_screen.dart';
import 'package:active_wear_scanning/features/processing/presentation/processing_screen.dart';
import 'package:active_wear_scanning/features/scanning_sections/presentation/widgets/section_card.dart';
import 'package:active_wear_scanning/features/tray/presentation/tray_scanning_screen.dart';
import 'package:flutter/material.dart';

class ScanningSectionsScreen extends StatelessWidget {
  const ScanningSectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomInspectionHeader(heading: 'Active Ware', isShowBackIcon: false, topPadding: 10, horizontalPadding: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SectionCard(
                          title: 'Order Header',
                          subtitle: 'Order header details',
                          sectionCode: 'ORDER',
                          progressValue: 0.5,
                          isShowProgress: true,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHeaderScreen()));
                          },
                        ),
                        const SizedBox(width: 12),
                        SectionCard(
                          title: 'Tray Scanning',
                          subtitle: 'Scan trays for inventory',
                          sectionCode: 'TRAY',
                          progressValue: 0.75,
                          isShowProgress: true,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const TrayScanningScreen()));
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        SectionCard(
                          title: 'GBS Receiving',
                          subtitle: 'Scan trays for GBS Receiving',
                          sectionCode: 'TRAY',
                          progressValue: 0.75,
                          isShowProgress: true,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const GBSReceivingScreen()));
                          },
                        ),
                        const SizedBox(width: 12),
                        SectionCard(
                          title: 'Batch',
                          subtitle: 'Scan trays to create batch',
                          sectionCode: 'TRAY',
                          progressValue: 0.75,
                          isShowProgress: true,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const BatchListScreen()));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SectionCard(
                          title: 'Processing',
                          subtitle: 'WIP transaction',
                          sectionCode: 'PROC',
                          progressValue: 0.0,
                          isShowProgress: false,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProcessingScreen()));
                          },
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()), // Empty half to keep sizing consistent
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
