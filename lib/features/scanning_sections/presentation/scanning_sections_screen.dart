import 'dart:io';
import 'dart:ui';
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
      body: Container(
        color: const Color(0xFFE3F2FD), // Solid Sky Blue
        child: SafeArea(
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
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0D47A1), // Deep Blue to match cards
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select a module to begin production tasks',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1976D2), // Medium Blue
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                      _FadeSlideTransition(
                        delay: 0,
                        child: _buildRow(context, [
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
                      ),
                      _FadeSlideTransition(
                        delay: 100,
                        child: _buildRow(context, [
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
                      ),
                      _FadeSlideTransition(
                        delay: 200,
                        child: _buildRow(context, [
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
                      ),
                      _FadeSlideTransition(
                        delay: 300,
                        child: _buildRow(context, [
                          SectionCard(
                            title: 'WIP Monitoring',
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
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }

  Widget _buildEnterpriseAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(0),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: const Icon(Icons.blur_on_rounded, color: Color(0xFF1E293B), size: 28),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ACTIVE WEAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: 1)),
              Text('Manufacturing Execution System', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF1E293B),
            child: Text('AJ', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIGrid() {
    return Row(
      children: [
        _buildKPICard('Active Batches', '12', Icons.layers_outlined, Colors.blue),
        const SizedBox(width: 12),
        _buildKPICard("Today's Output", '1,240', Icons.check_circle_outline, Colors.green),
        const SizedBox(width: 12),
        _buildKPICard('Pending Trays', '45', Icons.hourglass_empty_rounded, Colors.orange),
      ],
    );
  }

  Widget _buildKPICard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(0),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('+5%', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          ],
        ),
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

class _FadeSlideTransition extends StatelessWidget {
  final Widget child;
  final int delay;

  const _FadeSlideTransition({required this.child, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return FutureBuilder(
          future: Future.delayed(Duration(milliseconds: delay)),
          builder: (context, snapshot) {
            final isVisible = snapshot.connectionState == ConnectionState.done;
            return AnimatedOpacity(
              opacity: isVisible ? value : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Transform.translate(
                offset: Offset(0.0, (1.0 - (isVisible ? value : 0.0)) * 20),
                child: child,
              ),
            );
          },
        );
      },
      child: child,
    );
  }
}
