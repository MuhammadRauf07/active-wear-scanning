import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/environment_switcher_button.dart';
import 'package:active_wear_scanning/features/carton_packing/presentation/carton_packing_screen.dart';
import 'package:active_wear_scanning/features/dashboard/presentation/widgets/production_statistics_chart.dart';
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
  final String subtitle;
  final String code;
  final IconData icon;
  final Color color;
  final Widget Function(BuildContext) screen;

  const _WorkstationModule({
    required this.title,
    required this.subtitle,
    required this.code,
    required this.icon,
    required this.color,
    required this.screen,
  });
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static final List<_WorkstationModule> _allModules = [
    _WorkstationModule(
      title: 'Knitting Production',
      subtitle: 'Verify and trace manufacturing trays',
      code: 'KNIT',
      icon: Icons.precision_manufacturing_rounded,
      color: const Color(0xFF0D47A1),
      screen: (c) => const KnittingProductionScreen(),
    ),
    _WorkstationModule(
      title: 'GBS Receiving',
      subtitle: 'Handle goods-based stock incoming',
      code: 'GBS',
      icon: Icons.inventory_2_rounded,
      color: const Color(0xFF00695C),
      screen: (c) => const GBSReceivingScreen(),
    ),
    _WorkstationModule(
      title: 'Lot Making',
      subtitle: 'Initialize and manage production lots',
      code: 'LOT',
      icon: Icons.layers_rounded,
      color: const Color(0xFFE65100),
      screen: (c) => const LotListScreen(),
    ),
    _WorkstationModule(
      title: 'Processing',
      subtitle: 'Main line batch and tray processing',
      code: 'PROC',
      icon: Icons.account_tree_rounded,
      color: const Color(0xFF6A1B9A),
      screen: (c) => const ProcessingScreen(),
    ),
    _WorkstationModule(
      title: 'Induction Store',
      subtitle: 'Log materials to production store',
      code: 'IND',
      icon: Icons.warehouse_rounded,
      color: const Color(0xFF2E7D32),
      screen: (c) => const InductionStoreScreen(),
    ),
    _WorkstationModule(
      title: 'Stitching Line Schedule',
      subtitle: 'Manage stitching line operations',
      code: 'STITCH',
      icon: Icons.schedule_rounded,
      color: const Color(0xFFC2185B),
      screen: (c) => const StitchingLineScheduleScreen(),
    ),
    _WorkstationModule(
      title: 'Tray Tracking',
      subtitle: 'Live location history of production trays',
      code: 'TRACK',
      icon: Icons.track_changes_rounded,
      color: const Color(0xFF0277BD),
      screen: (c) => const TrayTrackingScreen(),
    ),
    _WorkstationModule(
      title: 'WIP Monitoring',
      subtitle: 'Real-time production flow & locators',
      code: 'WIP',
      icon: Icons.insights_rounded,
      color: const Color(0xFF4527A0),
      screen: (c) => const WIPScreen(),
    ),
    _WorkstationModule(
      title: 'Carton Packing',
      subtitle: 'Box goods for logistics and delivery',
      code: 'CART',
      icon: Icons.all_inbox_rounded,
      color: const Color(0xFF37474F),
      screen: (c) => const CartonPackingScreen(),
    ),
    _WorkstationModule(
      title: 'MD Receiving',
      subtitle: 'Log incoming MD material items',
      code: 'MDRC',
      icon: Icons.move_to_inbox_rounded,
      color: const Color(0xFF00838F),
      screen: (c) => const MdReceivingScreen(),
    ),
    _WorkstationModule(
      title: 'Processing Waste Receiving',
      subtitle: 'Log and receive waste products',
      code: 'WASTE',
      icon: Icons.delete_sweep_rounded,
      color: const Color(0xFFAD1457),
      screen: (c) => const ProcessingWasteReceivingScreen(),
    ),
    _WorkstationModule(
      title: 'Unhold Trays',
      subtitle: 'Release held trays from Knitting/PBS',
      code: 'HOLD',
      icon: Icons.lock_open_rounded,
      color: const Color(0xFFD84315),
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
              _buildKPIOverview(),
              const SizedBox(height: 24),
              _buildWorkstationsSection(context, displayModules),
              const SizedBox(height: 24),
              _buildVisualStatsSection(),
              const SizedBox(height: 24),
              _buildSystemInfoCard(),
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
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.dashboard_customize_rounded,
                      color: Color(0xFF60A5FA),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MES PRODUCTION HUB',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'ActiveWear Operations',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
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

  Widget _buildKPIOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'Operational Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                title: 'Unplanned',
                subtitle: 'Pending Release',
                icon: Icons.pending_actions_rounded,
                color: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFF7ED),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKPICard(
                title: 'Planned',
                subtitle: 'Scheduled Lots',
                icon: Icons.assignment_turned_in_rounded,
                color: const Color(0xFF0284C7),
                bgColor: const Color(0xFFF0F9FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                title: 'Floor WIP',
                subtitle: 'In Active Flow',
                icon: Icons.precision_manufacturing_rounded,
                color: const Color(0xFF16A34A),
                bgColor: const Color(0xFFF0FDF4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKPICard(
                title: 'Live Tracking',
                subtitle: 'Tray Movement',
                icon: Icons.track_changes_rounded,
                color: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
                      fontSize: 16,
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
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final module = modules[index];
            return _buildWorkstationItem(context, module);
          },
        ),
      ],
    );
  }

  Widget _buildWorkstationItem(BuildContext context, _WorkstationModule module) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => module.screen(c)),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(module.icon, color: module.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            module.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: module.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            module.code,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: module.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      module.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'Live Production Analytics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        SizedBox(height: 8),
        ProductionStatisticsChart(),
      ],
    );
  }

  Widget _buildSystemInfoCard() {
    return ContentCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MES Floor Network: Connected',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Tenancy: ActiveWear • Production Synchronized',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
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

