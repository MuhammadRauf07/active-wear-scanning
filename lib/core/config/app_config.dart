import 'package:plex/plex_networking/plex_networking.dart';
import 'package:plex/plex_sp.dart';

enum AppEnvironment {
  prod('PROD', 'https://10.111.2.40:4400'),
  uat('UAT', 'https://10.0.12.30:4201');

  final String label;
  final String url;
  const AppEnvironment(this.label, this.url);
}

class AppConfig {
  AppConfig._();

  /// Set to false to disable/hide environment switcher across the app in the future
  static const bool enableEnvironmentSwitcher = false;

  static const String _envKey = 'app_selected_environment';

  static AppEnvironment _currentEnv = AppEnvironment.prod;

  static AppEnvironment get currentEnvironment => _currentEnv;
  static String get baseUrl => _currentEnv.url;

  static String tenant = 'ActiveWare';
  static const login = "/connect/token";
  static const profile = "/api/account/my-profile";
  static String appVersion = '1.0.0';
  static bool enableLogging = true;

  /// Initializes the saved environment on app launch
  static void init() {
    final savedEnvLabel = PlexSp.instance.getString(_envKey);
    if (savedEnvLabel != null) {
      for (final env in AppEnvironment.values) {
        if (env.label == savedEnvLabel) {
          _currentEnv = env;
          break;
        }
      }
    }
  }

  /// Dynamically updates the active environment
  static void setEnvironment(AppEnvironment env) {
    _currentEnv = env;
    PlexSp.instance.setString(_envKey, env.label);
    PlexNetworking.instance.setBasePath(env.url);
  }
}

