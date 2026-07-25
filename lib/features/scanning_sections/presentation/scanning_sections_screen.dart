import 'package:active_wear_scanning/features/lot_making/presentation/lot_list_screen.dart';
import 'package:active_wear_scanning/features/gbs/presentation/gbs_receiving_screen.dart';
import 'package:active_wear_scanning/features/processing/presentation/processing_screen.dart';
import 'package:active_wear_scanning/features/induction/presentation/induction_store_screen.dart';
import 'package:active_wear_scanning/features/scanning_sections/presentation/widgets/section_card.dart';
import 'package:active_wear_scanning/features/knitting_production/presentation/knitting_production_screen.dart';
import 'package:active_wear_scanning/features/wip/presentation/wip_screen.dart';
import 'package:active_wear_scanning/features/tray_tracking/presentation/tray_tracking_screen.dart';
import 'package:active_wear_scanning/features/carton_packing/presentation/carton_packing_screen.dart';
import 'package:active_wear_scanning/features/md_receiving/presentation/md_receiving_screen.dart';
import 'package:active_wear_scanning/features/stitching_line_schedule/presentation/stitching_line_schedule_screen.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/presentation/processing_waste_receiving_screen.dart';
import 'package:flutter/material.dart';

class ScanningSectionsScreen extends StatelessWidget {
  const ScanningSectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFF1F5F9), // Slate Grey to match secondary screens
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
                            title: 'Knitting Production',
                            subtitle: 'Verify and trace manufacturing trays',
                            sectionCode: 'TRAY',
                            progressValue: 0.5,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const KnittingProductionScreen())),
                          ),
                          SectionCard(
                            title: 'GBS Receiving',
                            subtitle: 'Handle goods-based stock incoming',
                            sectionCode: 'TRAY',
                            progressValue: 0.5,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GBSReceivingScreen())),
                          ),
                        ]),
                      ),
                      _FadeSlideTransition(
                        delay: 100,
                        child: _buildRow(context, [
                          SectionCard(
                            title: 'Lot Making',
                            subtitle: 'Initialize new production lots',
                            sectionCode: 'TRAY',
                            progressValue: 0.5,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LotListScreen())),
                          ),
                          SectionCard(
                            title: 'Processing',
                            subtitle: 'Main production line tasks',
                            sectionCode: 'PROC',
                            progressValue: 0.5,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProcessingScreen())),
                          ),
                        ]),
                      ),
                      _FadeSlideTransition(
                        delay: 200,
                        child: _buildRow(context, [
                          SectionCard(
                            title: 'Induction Store',
                            subtitle: 'Log materials to production store',
                            sectionCode: 'TRAY',
                            progressValue: 0.5,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InductionStoreScreen())),
                          ),
                          SectionCard(
                            title: 'Stitching Line Schedule',
                            subtitle: 'Manage stitching line schedule',
                            sectionCode: 'POST',
                            progressValue: 0.5,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StitchingLineScheduleScreen())),
                          ),
                        ]),
                      ),
                      _FadeSlideTransition(
                        delay: 300,
                        child: _buildRow(context, [
                          SectionCard(
                            title: 'Tray Tracking',
                            subtitle: 'Location history of production trays',
                            sectionCode: 'TRACK',
                            progressValue: 0.5,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrayTrackingScreen())),
                          ),
                          SectionCard(
                            title: 'WIP Monitoring',
                            subtitle: 'Real-time production flow',
                            sectionCode: 'WIP',
                            progressValue: 0.75,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WIPScreen())),
                          ),
                        ]),
                      ),
                      _FadeSlideTransition(
                        delay: 400,
                        child: _buildRow(context, [
                          SectionCard(
                            title: 'Carton Packing',
                            subtitle: 'Box goods for logistics and delivery',
                            sectionCode: 'CART',
                            progressValue: 0.5,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartonPackingScreen())),
                          ),
                          SectionCard(
                            title: 'MD Receiving',
                            subtitle: 'Log incoming MD material items',
                            sectionCode: 'MDRC',
                            progressValue: 0.5,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MdReceivingScreen())),
                          ),
                        ]),
                      ),
                      _FadeSlideTransition(
                        delay: 500,
                        child: _buildRow(context, [
                          SectionCard(
                            title: 'Processing Waste Receiving',
                            subtitle: 'Log and receive waste products',
                            sectionCode: 'MDRC',
                            progressValue: 0.5,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProcessingWasteReceivingScreen())),
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
        _buildKPICard('Active Lots', '12', Icons.layers_outlined, Colors.blue),
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
          if (children.length > 1)
            children[1]
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _FadeSlideTransition extends StatefulWidget {
  final Widget child;
  final int delay;

  const _FadeSlideTransition({required this.child, required this.delay});

  @override
  State<_FadeSlideTransition> createState() => _FadeSlideTransitionState();
}

class _FadeSlideTransitionState extends State<_FadeSlideTransition> {
  late Future<void> _delayFuture;

  @override
  void initState() {
    super.initState();
    _delayFuture = Future.delayed(Duration(milliseconds: widget.delay));
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return FutureBuilder(
          future: _delayFuture,
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
      child: widget.child,
    );
  }
}
