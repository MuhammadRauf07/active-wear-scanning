import 'dart:io';

import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart' hide PlexApiResult;
import 'package:active_wear_scanning/core/config/app_config.dart';
import 'package:active_wear_scanning/features/user/model/active_wear_user.dart';
import 'package:active_wear_scanning/features/user/repo/profile.dart';
import 'package:plex/plex_networking/plex_networking.dart';
import 'package:plex/plex_package.dart';
import 'package:plex/plex_sp.dart';

class UserRepo {
  Future<PlexApiResult> login(String email, String password) async {
    ///  Step 2: Perform login API call
    var response = await PlexNetworking.instance.post(
      AppConfig.login,
      formData: {"grant_type": "password", "username": email, "password": password, "client_id": "activewear_mobile", "scope": "FitTracker"},
    );

    if (response is PlexSuccess) {
      var token = Token.fromJson(response.response);

      PlexSp.instance.setString("email", email);
      PlexSp.instance.setString("password", password);
      PlexSp.instance.setString("access_token", token.accessToken);

      return PlexApiResult(true, 200, "Success", token);
    } else {
      var error = response as PlexError;
      if (error.code == HttpStatus.unauthorized) {
        PlexApp.app.logout();
      }
      return PlexApiResult(false, error.code, error.message, null);
    }
  }

  Future<PlexApiResult> profile(String token) async {
    var response = await PlexNetworking.instance.get(AppConfig.profile, headers: {'Authorization': 'Bearer $token', "__tenant": PlexSp.instance.getString("tenant") ?? ""});

    if (response is PlexSuccess) {
      var token = Profile.fromJson(response.response);
      return PlexApiResult(true, 200, "Success", token);
    } else {
      var error = response as PlexError;
      if (error.code == HttpStatus.unauthorized) {
        PlexApp.app.logout();
      }
      return PlexApiResult(false, error.code, error.message, null);
    }
  }
}
