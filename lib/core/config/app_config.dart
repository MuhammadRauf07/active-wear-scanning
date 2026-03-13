class AppConfig {
  AppConfig._();

  static String baseUrl = 'https://10.0.12.30:4201';
  static String tenant = 'ActiveWare';
  static const login = "/connect/token";
  static const profile = "/api/account/my-profile";
  static String appVersion = '1.0.0';
  static bool enableLogging = true;
}
