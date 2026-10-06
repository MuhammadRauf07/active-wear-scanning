import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:active_wear_scanning/core/config/app_config.dart';
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
      try {
        final resData = response.response;
        List data = [];
        if (resData is List) {
          data = resData;
        } else if (resData is Map) {
          if (resData.containsKey('items') && resData['items'] is List) {
            data = resData['items'] as List;
          } else if (resData.containsKey('data') && resData['data'] is List) {
            data = resData['data'] as List;
          } else if (resData.containsKey('result')) {
            final resNode = resData['result'];
            if (resNode is List) {
               data = resNode;
            } else if (resNode is Map && resNode.containsKey('items') && resNode['items'] is List) {
               data = resNode['items'] as List;
            } else {
               throw Exception("Result node is not a list and does not contain 'items'. Raw: $resNode");
            }
          } else {
            throw Exception("Response map does not contain 'items', 'data', or 'result' keys. Raw keys: ${resData.keys}");
          }
        } else {
          throw Exception("Response is completely unknown type: ${resData.runtimeType}");
        }
        return PlexApiResult(true, 200, "Success", List<Map<String, dynamic>>.from(data));
      } catch (e) {
        return PlexApiResult(false, 500, "Data parsing error: $e", null);
      }
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

  /// Fetch binary data such as PDF files or image blobs
  Future<PlexApiResult> getBytes(String endNode, {Map<String, dynamic>? query}) async {
    try {
      if (await PlexNetworking.instance.isNetworkAvailable() == false) {
        return PlexApiResult(false, 5001, 'Network not available', null);
      }

      String url = endNode;
      if (query != null && query.isNotEmpty) {
        url += "?";
        query.forEach((key, value) {
          url += "$key=$value&";
        });
        url = url.substring(0, url.length - 1);
      }

      var currentHeaders = <String, String>{};
      if (PlexNetworking.instance.addHeaders != null) {
        var constHeaders = await PlexNetworking.instance.addHeaders!.call();
        currentHeaders.addAll(constHeaders);
      }
      currentHeaders['Accept'] = 'text/plain, application/pdf, application/octet-stream, */*';
      currentHeaders['X-Requested-With'] = 'XMLHttpRequest';

      final fullUrl = Uri.parse(url).scheme.isNotEmpty ? url : "${AppConfig.baseUrl}$url";
      final uri = Uri.parse(fullUrl);

      final startTime = DateTime.now();
      print("Started: $fullUrl");

      final response = await http.get(uri, headers: currentHeaders).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print("Timeout getBytes: $fullUrl");
          return http.Response('Timeout', HttpStatus.requestTimeout);
        },
      );

      final diffInMillis = DateTime.now().difference(startTime).inMilliseconds;
      print("Completed: ${response.statusCode}: $fullUrl in ${diffInMillis}ms (length: ${response.bodyBytes.length})");

      if (response.statusCode == HttpStatus.ok) {
        return PlexApiResult(true, 200, "Success", response.bodyBytes);
      } else {
        print("Error getBytes ${response.statusCode}: ${response.body.isNotEmpty ? response.body.substring(0, response.body.length > 200 ? 200 : response.body.length) : 'empty body'}");
        if (response.statusCode == HttpStatus.unauthorized) {
          PlexApp.app.logout();
        }
        return PlexApiResult(
          false,
          response.statusCode,
          response.reasonPhrase ?? "Failed to fetch document (${response.statusCode})",
          null,
        );
      }
    } catch (e, stack) {
      print("Error downloading bytes from $endNode: $e\n$stack");
      return PlexApiResult(false, 500, "Error downloading bytes: $e", null);
    }
  }
}

