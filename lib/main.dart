import 'package:active_wear_scanning/core/config/app_config.dart';
import 'package:active_wear_scanning/features/gbs/repo/gbs_receiving_repo.dart';
import 'package:active_wear_scanning/features/induction/repo/induction_repo.dart';
import 'package:active_wear_scanning/features/scanning_sections/presentation/scanning_sections_screen.dart';
import 'package:active_wear_scanning/features/knitting_production/repo/knitting_production_repo.dart';
import 'package:active_wear_scanning/features/carton_packing/repo/carton_packing_repo.dart';
import 'package:active_wear_scanning/features/md_receiving/repo/md_receiving_repo.dart';
import 'package:active_wear_scanning/features/stitching_line_schedule/repo/stitching_line_schedule_repo.dart';
import 'package:active_wear_scanning/features/processing_waste_receiving/repo/processing_waste_repo.dart';
import 'package:active_wear_scanning/features/user/model/active_wear_user.dart';
import 'package:active_wear_scanning/features/user/repo/active_wear_user.dart';
import 'package:active_wear_scanning/features/user/repo/profile.dart';
import 'package:active_wear_scanning/features/dashboard/presentation/dashboard_screen.dart';
import 'package:active_wear_scanning/features/user/repo/user_repo.dart';
import 'package:flutter/material.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:plex/plex_networking/plex_networking.dart';
import 'package:plex/plex_package.dart';
import 'package:plex/plex_route.dart';
import 'package:plex/plex_screens/plex_login_screen.dart';
import 'package:plex/plex_utils/plex_messages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PlexNetworking.instance.allowBadCertificateForHTTPS();

  AppConfig.tenant = 'ActiveWare';

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
        String labelText = route.title;
        if (route.route == '/scanning') {
          labelText = 'Operations';
        } else if (route.route == '/dashboard') {
          labelText = 'Dashboard';
        }
        return NavigationDrawerDestination(
          icon: route.logo ?? const Icon(Icons.circle),
          label: Text(labelText),
        );
      },
      appInfo: PlexAppInfo(
        title: 'Active Wear Scanning',
        appLogo: Image.asset(
          'lib/core/assets/interloop-logo.png',
          height: 48,
          fit: BoxFit.contain,
        ),
        initialRoute: '/',
      ),
      onInitializationComplete: () {
        // // Force the app to clear memory and demand a login every single time it boots
        // PlexApp.app.logout();
        
        PlexNetworking.instance.allowBadCertificateForHTTPS();
        AppConfig.init();
        PlexNetworking.instance.setBasePath(AppConfig.baseUrl);
        PlexNetworking.instance.addHeaders = () async {
          final user = PlexApp.app.getUser() as TasdeeqUser?;
          return <String, String>{if (user != null) 'Authorization': 'Bearer ${user.accessToken}', '__tenant': "Activewear"};
        };
      },
      useAuthorization: true,
      loginConfig: PlexLoginConfig(
        // debugUsername: 'AwFlDev',
        // debugPassword: 'AwlfDev@8855$$',
        onLogin: (context, email, password) async {
          var resultToken = await fromPlex<UserRepo>().login(email, password);
          if (!resultToken.success) {
            context.showMessageError(resultToken.message);
            return null;
          }

          var token = resultToken.data as Token;
          var resultProfile = await fromPlex<UserRepo>().profile(token.accessToken);
          if (!resultProfile.success) {
            context.showMessageError(resultProfile.message);
            return null;
          }

          var profile = resultProfile.data as Profile;

          var user = TasdeeqUser.fromToken(token, profile);

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
            route: '/scanning',
            title: 'FOGLIGHT ACTIVEWEAR',
            logo: const Icon(Icons.apps_outlined),
            selectedLogo: const Icon(Icons.apps),
            screen: (context, {data}) => const ScanningSectionsScreen(),
          ),
          PlexRoute(
            route: '/dashboard',
            title: 'FOGLIGHT ACTIVEWEAR',
            logo: const Icon(Icons.dashboard_outlined),
            selectedLogo: const Icon(Icons.dashboard),
            screen: (context, {data}) => const DashboardScreen(),
          ),
        ],
      ),
      pages: [
        PlexRoute(
          route: '/scanning',
          title: 'FOGLIGHT ACTIVEWEAR',
          screen: (context, {data}) => const ScanningSectionsScreen(),
        ),
        PlexRoute(
          route: '/dashboard',
          title: 'FOGLIGHT ACTIVEWEAR',
          screen: (context, {data}) => const DashboardScreen(),
        ),
      ],
    ),
  );
}
