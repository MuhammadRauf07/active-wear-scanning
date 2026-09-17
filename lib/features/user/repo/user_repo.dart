import 'dart:convert';
import 'dart:io';
import 'package:active_wear_scanning/core/config/app_config.dart';
import 'package:active_wear_scanning/features/user/model/active_wear_user.dart';
import 'package:active_wear_scanning/features/user/repo/profile.dart';
import 'package:flutter/cupertino.dart';
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
      debugPrint("❌ LOGIN ERROR 400 RESPONSE: Code ${error.code} | Message: ${error.message}");
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

  Future<PlexApiResult> fetchUserRoles(String token, String userName) async {
    final List<String> roles = [];

    // 1. Try decoding roles directly from JWT token payload as quick/fallback source
    try {
      final jwtRoles = _decodeRolesFromJwt(token);
      if (jwtRoles.isNotEmpty) {
        roles.addAll(jwtRoles);
      }
    } catch (e) {
      debugPrint("JWT Role decoding warning: $e");
    }

    // 2. Fetch from Identity Users API: /api/identity/users
    try {
      final response = await PlexNetworking.instance.get(
        '/api/identity/users?MaxResultCount=1000',
        headers: {
          'Authorization': 'Bearer $token',
          '__tenant': PlexSp.instance.getString("tenant") ?? "Activewear",
        },
      );

      if (response is PlexSuccess) {
        final data = response.response;
        List items = [];
        if (data is Map && data['items'] is List) {
          items = data['items'];
        } else if (data is List) {
          items = data;
        }

        for (final item in items) {
          if (item is Map) {
            final uName = item['userName']?.toString();
            final email = item['email']?.toString();
            if ((uName != null && uName.toLowerCase() == userName.toLowerCase()) ||
                (email != null && email.toLowerCase() == userName.toLowerCase())) {
              final rolesRaw = item['roleNames'];
              if (rolesRaw is List) {
                final fetchedRoles = rolesRaw.map((r) => r.toString()).toList();
                for (final r in fetchedRoles) {
                  if (!roles.contains(r)) roles.add(r);
                }
              }
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching identity user roles: $e");
    }

    return PlexApiResult(true, 200, "Success", roles);
  }

  List<String> _decodeRolesFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return [];

      final String normalizedPayload = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalizedPayload));
      final Map<String, dynamic> payload = jsonDecode(payloadString);

      final List<String> extractedRoles = [];

      final roleKeys = [
        'role',
        'roles',
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role',
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/role',
      ];

      for (final key in roleKeys) {
        if (payload.containsKey(key)) {
          final val = payload[key];
          if (val is List) {
            extractedRoles.addAll(val.map((e) => e.toString()));
          } else if (val is String && val.isNotEmpty) {
            extractedRoles.add(val);
          }
        }
      }

      return extractedRoles.toSet().toList();
    } catch (_) {
      return [];
    }
  }
}

