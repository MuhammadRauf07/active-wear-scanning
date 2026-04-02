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

  Future<PlexApiResult> delete(String endNode, {bool isRetry = false}) async {
    var response = await PlexNetworking.instance.delete(endNode);

    if (response is PlexSuccess) {
      var data = response.response;
      return PlexApiResult(true, 204, "Deleted", data != null ? Map<String, dynamic>.from(data) : null);
    } else {
      var error = response as PlexError;

      // 204 No Content is a valid success response for DELETE requests.
      // Some HTTP clients report it as an "error" because the body is empty.
      if (error.code == HttpStatus.noContent || error.code == 204) {
        return PlexApiResult(true, 204, "Deleted", null);
      }

      if (error.code == HttpStatus.unauthorized) {
        PlexApp.app.logout();
      }

      return PlexApiResult(false, error.code, error.message, null);
    }
  }
}
