import 'package:active_wear_scanning/core/widgets/environment_switcher_button.dart';
import 'package:active_wear_scanning/features/carton_packing/presentation/carton_packing_screen.dart';
import 'package:active_wear_scanning/features/gbs/presentation/gbs_receiving_screen.dart';
import 'package:active_wear_scanning/features/induction/presentation/induction_store_screen.dart';
import 'package:active_wear_scanning/features/knitting_production/presentation/knitting_production_screen.dart';
import 'package:active_wear_scanning/features/lot_making/presentation/lot_list_screen.dart';
import 'package:active_wear_scanning/features/md_receiving/presentation/md_receiving_screen.dart';
import 'package:active_wear_scanning/features/processing/presentation/processing_screen.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/presentation/processing_waste_receiving_screen.dart';
import 'package:active_wear_scanning/features/scanning_sections/presentation/widgets/section_permission_helper.dart';
import 'package:active_wear_scanning/features/stitching_line_schedule/presentation/stitching_line_schedule_screen.dart';
import 'package:active_wear_scanning/features/tray_tracking/presentation/tray_tracking_screen.dart';
import 'package:active_wear_scanning/features/unhold_trays/presentation/unhold_trays_screen.dart';
import 'package:active_wear_scanning/features/user/repo/active_wear_user.dart';
import 'package:active_wear_scanning/features/wip/presentation/wip_screen.dart';
import 'package:flutter/material.dart';
import 'package:plex/plex_package.dart';

class _WorkstationModule {
  final String title;
  final IconData icon;
  final Widget Function(BuildContext) screen;

  const _WorkstationModule({
    required this.title,
    required this.icon,
    required this.screen,
  });
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final List<_WorkstationModule> _allModules = [
    _WorkstationModule(
      title: 'Knitting Production',
      icon: Icons.precision_manufacturing_rounded,
      screen: (c) => const KnittingProductionScreen(),
    ),
    _WorkstationModule(
      title: 'GBS Receiving',
      icon: Icons.inventory_2_rounded,
      screen: (c) => const GBSReceivingScreen(),
    ),
    _WorkstationModule(
      title: 'Lot Making',
      icon: Icons.layers_rounded,
      screen: (c) => const LotListScreen(),
    ),
    _WorkstationModule(
      title: 'Processing',
      icon: Icons.account_tree_rounded,
      screen: (c) => const ProcessingScreen(),
    ),
    _WorkstationModule(
      title: 'Induction Store',
      icon: Icons.warehouse_rounded,
      screen: (c) => const InductionStoreScreen(),
    ),
    _WorkstationModule(
      title: 'Stitching Line Schedule',
      icon: Icons.schedule_rounded,
      screen: (c) => const StitchingLineScheduleScreen(),
    ),
    _WorkstationModule(
      title: 'Tray Tracking',
      icon: Icons.track_changes_rounded,
      screen: (c) => const TrayTrackingScreen(),
    ),
    _WorkstationModule(
      title: 'WIP Monitoring',
      icon: Icons.insights_rounded,
      screen: (c) => const WIPScreen(),
    ),
    _WorkstationModule(
      title: 'Carton Packing',
      icon: Icons.all_inbox_rounded,
      screen: (c) => const CartonPackingScreen(),
    ),
    _WorkstationModule(
      title: 'MD Receiving',
      icon: Icons.move_to_inbox_rounded,
      screen: (c) => const MdReceivingScreen(),
    ),
    _WorkstationModule(
      title: 'Processing Waste Receiving',
      icon: Icons.delete_sweep_rounded,
      screen: (c) => const ProcessingWasteReceivingScreen(),
    ),
    _WorkstationModule(
      title: 'Unhold Trays',
      icon: Icons.lock_open_rounded,
      screen: (c) => const UnholdTraysScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = PlexApp.app.getUser() as TasdeeqUser?;
    final List<String> userRoles = user?.roleNames ?? [];
    final String displayName = (user?.name != null && user!.name.trim().isNotEmpty)
        ? user.name
        : ((user?.userName != null && user!.userName.trim().isNotEmpty)
            ? user.userName
            : 'Operator');
    final String userRoleText = userRoles.isNotEmpty ? userRoles.first : 'ActiveWear Staff';

    final permittedModules = _allModules
        .where((m) => SectionPermissionHelper.isSectionAllowed(m.title, userRoles))
        .toList();
    final displayModules = permittedModules.isNotEmpty ? permittedModules : _allModules;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, displayName, userRoleText),
              const SizedBox(height: 20),
              _buildWorkstationsSection(context, displayModules),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String displayName, String roleText) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.home_rounded,
                      color: Color(0xFF60A5FA),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Home',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'ActiveWear Operations',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const EnvironmentSwitcherButton(),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF3B82F6),
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, $displayName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        roleText,
                        style: const TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkstationsSection(BuildContext context, List<_WorkstationModule> modules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Authorized Workstations',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Direct access to your assigned stations',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${modules.length} Available',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 88,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final module = modules[index];
            return _buildWorkstationCard(context, module);
          },
        ),
      ],
    );
  }

  Widget _buildWorkstationCard(BuildContext context, _WorkstationModule module) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => module.screen(c)),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.22),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  module.icon,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  module.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
