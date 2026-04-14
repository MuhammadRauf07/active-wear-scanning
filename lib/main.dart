import 'package:active_wear_scanning/core/config/app_config.dart';
import 'package:active_wear_scanning/features/gbs/repo/gbs_receiving_repo.dart';
import 'package:active_wear_scanning/features/scanning_sections/presentation/scanning_sections_screen.dart';
import 'package:active_wear_scanning/features/tray/repo/tray_scanning_repo.dart';
import 'package:active_wear_scanning/features/user/model/active_wear_user.dart';
import 'package:active_wear_scanning/features/user/repo/active_wear_user.dart';
import 'package:active_wear_scanning/features/user/repo/profile.dart';
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

  AppConfig.tenant = 'ActiveWare';

  injectSingleton(UserRepo());
  injectSingleton(TrayScanningRepo());
  injectSingleton(GBSReceivingRepo());

  runApp(
    PlexApp(
      appInfo: PlexAppInfo(title: 'Active Wear Scanning', appLogo: const Icon(Icons.qr_code_scanner), initialRoute: '/'),
      onInitializationComplete: () {
        // // Force the app to clear memory and demand a login every single time it boots
        // PlexApp.app.logout();
        
        PlexNetworking.instance.allowBadCertificateForHTTPS();
        PlexNetworking.instance.setBasePath(AppConfig.baseUrl);
        PlexNetworking.instance.addHeaders = () async {
          final user = PlexApp.app.getUser() as TasdeeqUser?;
          return <String, String>{if (user != null) 'Authorization': 'Bearer ${user.accessToken}', '__tenant': "ActiveWear"};
        };
      },
      useAuthorization: true,
      loginConfig: PlexLoginConfig(
        debugUsername: 'admin',
        debugPassword: 'AW123',
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
        disableExpandNavigationRail: true,
        disableBottomNavigation: true,
        dashboardScreens: [
          PlexRoute(
            route: '/scanning',
            title: 'Active Ware',
            logo: const Icon(Icons.home_outlined),
            selectedLogo: const Icon(Icons.home),
            screen: (context, {data}) => const ScanningSectionsScreen(),
          ),
        ],
      ),
      pages: [PlexRoute(route: '/scanning', title: 'Active Ware', screen: (context, {data}) => const ScanningSectionsScreen())],
    ),
  );
}
