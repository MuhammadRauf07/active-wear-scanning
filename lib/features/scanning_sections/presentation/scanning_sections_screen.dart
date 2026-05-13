import 'dart:io';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/features/batch/presentation/batch_list_screen.dart';
import 'package:active_wear_scanning/features/gbs/presentation/gbs_receiving_screen.dart';
import 'package:active_wear_scanning/features/header/order_header_screen.dart';
import 'package:active_wear_scanning/features/processing/presentation/processing_screen.dart';
import 'package:active_wear_scanning/features/induction/presentation/induction_store_screen.dart';
import 'package:active_wear_scanning/features/scanning_sections/presentation/widgets/section_card.dart';
import 'package:active_wear_scanning/features/tray/presentation/tray_scanning_screen.dart';
import 'package:active_wear_scanning/features/wip/presentation/wip_screen.dart';
import 'package:active_wear_scanning/features/tray_tracking/presentation/tray_tracking_screen.dart';
import 'package:active_wear_scanning/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';

class ScanningSectionsScreen extends StatelessWidget {
  const ScanningSectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'lib/core/assets/Gemini_Generated_Image_5eos4d5eos4d5eos.png',
              fit: BoxFit.cover,
            ),
          ),
          // Dark Overlay for readability
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Operations Modules',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select a module to begin production tasks',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildRow(context, [
                        SectionCard(
                          title: 'Dashboard',
                          subtitle: 'Primary system overview',
                          sectionCode: 'DASH',
                          progressValue: 0.5,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DashboardScreen())),
                        ),
                        SectionCard(
                          title: 'Tray Scanning',
                          subtitle: 'Verify and trace manufacturing trays',
                          sectionCode: 'TRAY',
                          progressValue: 0.5,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrayScanningScreen())),
                        ),
                      ]),
                      _buildRow(context, [
                        SectionCard(
                          title: 'GBS Receiving',
                          subtitle: 'Handle goods-based stock incoming',
                          sectionCode: 'TRAY',
                          progressValue: 0.5,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GBSReceivingScreen())),
                        ),
                        SectionCard(
                          title: 'Batch Creation',
                          subtitle: 'Initialize new production batches',
                          sectionCode: 'TRAY',
                          progressValue: 0.5,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BatchListScreen())),
                        ),
                      ]),
                      _buildRow(context, [
                        SectionCard(
                          title: 'Processing',
                          subtitle: 'Main production line tasks',
                          sectionCode: 'PROC',
                          progressValue: 0.5,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProcessingScreen())),
                        ),
                        SectionCard(
                          title: 'Induction Store',
                          subtitle: 'Log materials to production store',
                          sectionCode: 'TRAY',
                          progressValue: 0.5,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InductionStoreScreen())),
                        ),
                      ]),
                      _buildRow(context, [
                        SectionCard(
                          title: 'Work In Progress (WIP)',
                          subtitle: 'Real-time production flow',
                          sectionCode: 'WIP',
                          progressValue: 0.75,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WIPScreen())),
                        ),
                        SectionCard(
                          title: 'Tray Tracking',
                          subtitle: 'Location history of production trays',
                          sectionCode: 'TRACK',
                          progressValue: 0.5,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrayTrackingScreen())),
                        ),
                      ]),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          children[0],
          const SizedBox(width: 16),
          children[1],
        ],
      ),
    );
  }
}
