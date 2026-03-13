import 'dart:io';

import 'package:plex/plex_networking/plex_networking.dart' hide PlexApiResult;
import 'package:plex/plex_package.dart';

import '../plex-result/plex_api_result.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal();

  Future<PlexApiResult> getList(String endNode, {Map<String, dynamic>? query, bool isRetry = false}) async {
    var response = await PlexNetworking.instance.get(endNode, query: query ?? {});

    if (response is PlexSuccess) {
      var data = response.response['items'] as List;
      return PlexApiResult(true, 200, "Success", List<Map<String, dynamic>>.from(data));
    } else {
      var error = response as PlexError;

      if (error.code == HttpStatus.unauthorized) {
        PlexApp.app.logout();
      }

      return PlexApiResult(false, error.code, error.message, null);
    }
  }

  Future<PlexApiResult> getObject(String endNode, {Map<String, dynamic>? query, bool isRetry = false}) async {
    var response = await PlexNetworking.instance.get(endNode, query: query ?? {});

    if (response is PlexSuccess) {
      var data = response.response;
      return PlexApiResult(true, 200, "Success", Map<String, dynamic>.from(data));
    } else {
      var error = response as PlexError;

      if (error.code == HttpStatus.unauthorized) {
        PlexApp.app.logout();
      }

      return PlexApiResult(false, error.code, error.message, null);
    }
  }

  Future<PlexApiResult> post(String endNode, {Map<String, dynamic>? body, bool isRetry = false}) async {
    var response = await PlexNetworking.instance.post(endNode, body: body);

    if (response is PlexSuccess) {
      var data = response.response;
      return PlexApiResult(true, 200, "Success", data);
    } else {
      var error = response as PlexError;

      if (error.code == HttpStatus.unauthorized) {
        PlexApp.app.logout();
      }

      return PlexApiResult(false, error.code, error.message, null);
    }
  }

  Future<PlexApiResult> put(String endNode, {Map<String, dynamic>? body, bool isRetry = false}) async {
    var response = await PlexNetworking.instance.put(endNode, body: body ?? {});

    if (response is PlexSuccess) {
      var data = response.response;
      return PlexApiResult(true, 200, "Success", Map<String, dynamic>.from(data));
    } else {
      var error = response as PlexError;

      if (error.code == HttpStatus.unauthorized) {
        PlexApp.app.logout();
      }

      return PlexApiResult(false, error.code, error.message, null);
    }
  }
}
