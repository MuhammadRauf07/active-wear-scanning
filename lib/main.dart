import 'package:active_wear_scanning/core/config/app_config.dart';
import 'package:active_wear_scanning/features/carton_packing/presentation/carton_packing_screen.dart';
import 'package:active_wear_scanning/features/carton_packing/repo/carton_packing_repo.dart';
import 'package:active_wear_scanning/features/home/presentation/home_screen.dart';
import 'package:active_wear_scanning/features/gbs/presentation/gbs_receiving_screen.dart';
import 'package:active_wear_scanning/features/gbs/repo/gbs_receiving_repo.dart';
import 'package:active_wear_scanning/features/induction/presentation/induction_store_screen.dart';
import 'package:active_wear_scanning/features/induction/repo/induction_repo.dart';
import 'package:active_wear_scanning/features/knitting_production/presentation/knitting_production_screen.dart';
import 'package:active_wear_scanning/features/knitting_production/repo/knitting_production_repo.dart';
import 'package:active_wear_scanning/features/lot_making/presentation/lot_list_screen.dart';
import 'package:active_wear_scanning/features/md_receiving/presentation/md_receiving_screen.dart';
import 'package:active_wear_scanning/features/md_receiving/repo/md_receiving_repo.dart';
import 'package:active_wear_scanning/features/processing/presentation/processing_screen.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/presentation/processing_waste_receiving_screen.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/repo/processing_waste_repo.dart';
import 'package:active_wear_scanning/features/scanning_sections/presentation/scanning_sections_screen.dart';
import 'package:active_wear_scanning/features/scanning_sections/presentation/widgets/section_permission_helper.dart';
import 'package:active_wear_scanning/features/stitching_line_schedule/presentation/stitching_line_schedule_screen.dart';
import 'package:active_wear_scanning/features/stitching_line_schedule/repo/stitching_line_schedule_repo.dart';
import 'package:active_wear_scanning/features/tray_tracking/presentation/tray_tracking_screen.dart';
import 'package:active_wear_scanning/features/unhold_trays/presentation/unhold_trays_screen.dart';
import 'package:active_wear_scanning/features/user/model/active_wear_user.dart';
import 'package:active_wear_scanning/features/user/repo/active_wear_user.dart';
import 'package:active_wear_scanning/features/user/repo/profile.dart';
import 'package:active_wear_scanning/features/user/repo/user_repo.dart';
import 'package:active_wear_scanning/features/wip/presentation/wip_screen.dart';
import 'package:flutter/material.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:plex/plex_networking/plex_networking.dart';
import 'package:plex/plex_package.dart';
import 'package:plex/plex_route.dart';
import 'package:plex/plex_screens/plex_login_screen.dart';
import 'package:plex/plex_utils/plex_messages.dart';

void main() {
  runActiveWearApp(
    defaultEnv: AppEnvironment.prod,
    appTitle: 'AWFL PROD',
  );
}

void runActiveWearApp({
  AppEnvironment defaultEnv = AppEnvironment.prod,
  String appTitle = 'AWFL PROD',
}) {
  WidgetsFlutterBinding.ensureInitialized();
  PlexNetworking.instance.allowBadCertificateForHTTPS();

  AppConfig.tenant = 'ActiveWare';
  AppConfig.initWithEnvironment(defaultEnv, title: appTitle);

  injectSingleton(UserRepo());
  injectSingleton(KnittingProductionRepo());
  injectSingleton(GBSReceivingRepo());
  injectSingleton(InductionRepo());
  injectSingleton(CartonPackingRepo());
  injectSingleton(MdReceivingRepo());
  injectSingleton(StitchingLineScheduleRepo());
  injectSingleton(ProcessingWasteRepo());

  runApp(
    PlexApp(
      generateDrawerNavigationButton: (route) {
        final user = PlexApp.app.getUser() as TasdeeqUser?;
        final List<String> userRoles = user?.roleNames ?? [];

        // Home is always visible to everyone
        if (route.route == '/home' || route.title == 'Home' || route.route == '/dashboard' || route.title == 'Dashboard') {
          return NavigationDrawerDestination(
            icon: route.logo ?? const Icon(Icons.home_outlined),
            selectedIcon: route.selectedLogo ?? route.logo ?? const Icon(Icons.home_rounded),
            label: const Text('Home'),
          );
        }

        // For Operations Overview (all sections grid)
        if (route.route == '/scanning' || route.title == 'Operations Overview') {
          final isAdmin = userRoles.any((r) {
            final n = r.toLowerCase().replaceAll(RegExp(r'[\s_\-\/\\]'), '');
            return n.contains('admin') || n.contains('superadmin') || n == 'root';
          });
          if (!isAdmin) {
            return const SizedBox.shrink();
          }
          return _DrawerModuleTile(route: route);
        }

        // For specific scanning sections, check permission against user roles
        if (!SectionPermissionHelper.isSectionAllowed(route.title, userRoles)) {
          return const SizedBox.shrink();
        }

        return _DrawerModuleTile(route: route);
      },
      appInfo: PlexAppInfo(
        title: appTitle,
        appLogo: Image.asset(
          'lib/core/assets/interloop-logo.png',
          height: 48,
          fit: BoxFit.contain,
        ),
        initialRoute: '/home',
      ),
      onInitializationComplete: () {
        PlexNetworking.instance.allowBadCertificateForHTTPS();
        AppConfig.initWithEnvironment(defaultEnv, title: appTitle);
        PlexNetworking.instance.setBasePath(AppConfig.baseUrl);
        PlexNetworking.instance.addHeaders = () async {
          final user = PlexApp.app.getUser() as TasdeeqUser?;
          return <String, String>{if (user != null) 'Authorization': 'Bearer ${user.accessToken}', '__tenant': "Activewear"};
        };
      },
      useAuthorization: true,
      loginConfig: PlexLoginConfig(
        onLogin: (context, email, password) async {
          var resultToken = await fromPlex<UserRepo>().login(email, password);
          if (!resultToken.success) {
            if (context.mounted) {
              context.showMessageError(resultToken.message);
            }
            return null;
          }

          var token = resultToken.data as Token;
          var resultProfile = await fromPlex<UserRepo>().profile(token.accessToken);
          if (!resultProfile.success) {
            if (context.mounted) {
              context.showMessageError(resultProfile.message);
            }
            return null;
          }


          var profile = resultProfile.data as Profile;

          List<String> roleNames = [];
          var resultRoles = await fromPlex<UserRepo>().fetchUserRoles(token.accessToken, profile.userName);
          if (resultRoles.success && resultRoles.data is List) {
            roleNames = List<String>.from(resultRoles.data);
          }

          var user = TasdeeqUser.fromToken(token, profile, roleNames: roleNames);

          return user;
        },
        userFromJson: (userData) {
          return TasdeeqUser.fromJson(userData);
        },
      ),
      dashboardConfig: PlexDashboardConfig(
        hideNavigationRailLogo: true,
        disableNavigationRail: true,
        showBrightnessSwitch: false,
        showThemeSwitch: false,
        showAnimationSwitch: false,
        disableExpandNavigationRail: false,
        disableBottomNavigation: true,
        dashboardScreens: [
          PlexRoute(
            route: '/home',
            title: 'Home',
            logo: const Icon(Icons.home_outlined),
            selectedLogo: const Icon(Icons.home_rounded),
            screen: (context, {data}) => const HomeScreen(),
          ),
          PlexRoute(
            route: '/knitting_production',
            title: 'Knitting Production',
            logo: const Icon(Icons.precision_manufacturing_outlined),
            selectedLogo: const Icon(Icons.precision_manufacturing),
            screen: (context, {data}) => const KnittingProductionScreen(),
          ),
          PlexRoute(
            route: '/gbs_receiving',
            title: 'GBS Receiving',
            logo: const Icon(Icons.inventory_2_outlined),
            selectedLogo: const Icon(Icons.inventory_2),
            screen: (context, {data}) => const GBSReceivingScreen(),
          ),
          PlexRoute(
            route: '/lot_making',
            title: 'Lot Making',
            logo: const Icon(Icons.layers_outlined),
            selectedLogo: const Icon(Icons.layers),
            screen: (context, {data}) => const LotListScreen(),
          ),
          PlexRoute(
            route: '/processing',
            title: 'Processing',
            logo: const Icon(Icons.account_tree_outlined),
            selectedLogo: const Icon(Icons.account_tree),
            screen: (context, {data}) => const ProcessingScreen(),
          ),
          PlexRoute(
            route: '/induction_store',
            title: 'Induction Store',
            logo: const Icon(Icons.warehouse_outlined),
            selectedLogo: const Icon(Icons.warehouse),
            screen: (context, {data}) => const InductionStoreScreen(),
          ),
          PlexRoute(
            route: '/stitching_schedule',
            title: 'Stitching Line Schedule',
            logo: const Icon(Icons.schedule_outlined),
            selectedLogo: const Icon(Icons.schedule),
            screen: (context, {data}) => const StitchingLineScheduleScreen(),
          ),
          PlexRoute(
            route: '/tray_tracking',
            title: 'Tray Tracking',
            logo: const Icon(Icons.track_changes_outlined),
            selectedLogo: const Icon(Icons.track_changes),
            screen: (context, {data}) => const TrayTrackingScreen(),
          ),
          PlexRoute(
            route: '/wip_monitoring',
            title: 'WIP Monitoring',
            logo: const Icon(Icons.insights_outlined),
            selectedLogo: const Icon(Icons.insights),
            screen: (context, {data}) => const WIPScreen(),
          ),
          PlexRoute(
            route: '/carton_packing',
            title: 'Carton Packing',
            logo: const Icon(Icons.all_inbox_outlined),
            selectedLogo: const Icon(Icons.all_inbox),
            screen: (context, {data}) => const CartonPackingScreen(),
          ),
          PlexRoute(
            route: '/md_receiving',
            title: 'MD Receiving',
            logo: const Icon(Icons.move_to_inbox_outlined),
            selectedLogo: const Icon(Icons.move_to_inbox),
            screen: (context, {data}) => const MdReceivingScreen(),
          ),
          PlexRoute(
            route: '/waste_receiving',
            title: 'Processing Waste Receiving',
            logo: const Icon(Icons.delete_sweep_outlined),
            selectedLogo: const Icon(Icons.delete_sweep),
            screen: (context, {data}) => const ProcessingWasteReceivingScreen(),
          ),
          PlexRoute(
            route: '/unhold_trays',
            title: 'Unhold Trays',
            logo: const Icon(Icons.lock_open_outlined),
            selectedLogo: const Icon(Icons.lock_open),
            screen: (context, {data}) => const UnholdTraysScreen(),
          ),
          PlexRoute(
            route: '/scanning',
            title: 'Operations Overview',
            logo: const Icon(Icons.apps_outlined),
            selectedLogo: const Icon(Icons.apps),
            screen: (context, {data}) => const ScanningSectionsScreen(),
          ),
        ],
      ),
      pages: [
        PlexRoute(
          route: '/home',
          title: 'Home',
          screen: (context, {data}) => const HomeScreen(),
        ),
        PlexRoute(
          route: '/knitting_production',
          title: 'Knitting Production',
          screen: (context, {data}) => const KnittingProductionScreen(),
        ),
        PlexRoute(
          route: '/gbs_receiving',
          title: 'GBS Receiving',
          screen: (context, {data}) => const GBSReceivingScreen(),
        ),
        PlexRoute(
          route: '/lot_making',
          title: 'Lot Making',
          screen: (context, {data}) => const LotListScreen(),
        ),
        PlexRoute(
          route: '/processing',
          title: 'Processing',
          screen: (context, {data}) => const ProcessingScreen(),
        ),
        PlexRoute(
          route: '/induction_store',
          title: 'Induction Store',
          screen: (context, {data}) => const InductionStoreScreen(),
        ),
        PlexRoute(
          route: '/stitching_schedule',
          title: 'Stitching Line Schedule',
          screen: (context, {data}) => const StitchingLineScheduleScreen(),
        ),
        PlexRoute(
          route: '/tray_tracking',
          title: 'Tray Tracking',
          screen: (context, {data}) => const TrayTrackingScreen(),
        ),
        PlexRoute(
          route: '/wip_monitoring',
          title: 'WIP Monitoring',
          screen: (context, {data}) => const WIPScreen(),
        ),
        PlexRoute(
          route: '/carton_packing',
          title: 'Carton Packing',
          screen: (context, {data}) => const CartonPackingScreen(),
        ),
        PlexRoute(
          route: '/md_receiving',
          title: 'MD Receiving',
          screen: (context, {data}) => const MdReceivingScreen(),
        ),
        PlexRoute(
          route: '/waste_receiving',
          title: 'Processing Waste Receiving',
          screen: (context, {data}) => const ProcessingWasteReceivingScreen(),
        ),
        PlexRoute(
          route: '/unhold_trays',
          title: 'Unhold Trays',
          screen: (context, {data}) => const UnholdTraysScreen(),
        ),
        PlexRoute(
          route: '/scanning',
          title: 'Operations Overview',
          screen: (context, {data}) => const ScanningSectionsScreen(),
        ),
      ],
    ),
  );
}

class _DrawerModuleTile extends StatelessWidget {
  final PlexRoute route;

  const _DrawerModuleTile({required this.route});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            // Close the navigation drawer
            Navigator.of(context).pop();
            // Open full screen route without Plex AppBar
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (c) => route.screen(c),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconTheme(
                  data: const IconThemeData(color: Color(0xFF475569), size: 22),
                  child: route.logo ?? const Icon(Icons.circle_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    route.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

