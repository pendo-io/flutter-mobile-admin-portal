// Dart imports:
import 'dart:convert';
import 'dart:core';

// Flutter imports:
import 'package:flutter/foundation.dart';
//import 'package:flutter_redux/flutter_redux.dart';

// Package imports:
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:invoiceninja_flutter/utils/platforms.dart';
//import 'package:invoiceninja_flutter/main_app.dart';
//import 'package:invoiceninja_flutter/redux/app/app_state.dart';
import 'package:version/version.dart';

// Project imports:
import 'package:invoiceninja_flutter/.env.dart';
import 'package:invoiceninja_flutter/constants.dart';
import 'package:invoiceninja_flutter/utils/formatting.dart';
import 'package:invoiceninja_flutter/utils/strings.dart';
import 'package:invoiceninja_flutter/utils/connection_status.dart';

class WebClient {
  const WebClient();

  Future<bool> _isOnline() async {
    final ConnectionStatusSingleton connectionStatus =
        ConnectionStatusSingleton.getInstance();
    await connectionStatus.checkConnection();
    return connectionStatus.hasConnection;
  }

  Future<void> _cacheData(String key, dynamic data) async {
    final box = await Hive.openBox('cachedResponses');
    await box.put(key, data);
  }

  Future<dynamic> _getCachedData(String key) async {
    final box = await Hive.openBox('cachedResponses');
    final data = box.get(key);
    return data;
  }

  Future<dynamic> get(
    String url,
    String? token, {
    bool rawResponse = false,
  }) async {
    if (Config.DEMO_MODE) {
      throw 'Server requests are not supported in the demo';
    }

    if (!url.contains('?')) {
      url += '?';
    }

    if (url.contains('/api/') && !url.contains('per_page')) {
      url += '&per_page=999999';
    }

    if (!url.contains('t=')) {
      url += '&t=${DateTime.now().millisecondsSinceEpoch}';
    }

    print('GET: $url');

    final isOnline = await _isOnline();
    if (isOnline) {
      final client = http.Client();
      final http.Response response = await client.get(
        Uri.parse(url),
        headers: _getHeaders(url, token),
      );
      client.close();

      _checkResponse(url, response);

      if (rawResponse) {
        return response;
      }

      final dynamic jsonResponse = json.decode(response.body);

      // Cache the response
      await _cacheData(url, jsonResponse);

      return jsonResponse;
    } else {
      final cachedData = await _getCachedData(url);
      if (cachedData != null) {
        print('Returning cached data');
        return cachedData;
      }
      throw 'No internet connection available';
    }
  }

  Future<dynamic> post(
    String url,
    String? token, {
    dynamic data,
    List<MultipartFile>? multipartFiles,
    String? secret,
    String? password,
    String? idToken,
    bool rawResponse = false,
  }) async {
    _preCheck();

    if (!url.contains('?')) {
      url += '?';
    }

    print('POST: $url');
    if (!kReleaseMode && Config.DEBUG_REQUESTS) {
      printWrapped('Data: $data');
    }
    http.Response response;

    final isOnline = await _isOnline();
    print("isOnline: $isOnline");
    if (isOnline) {
      if (multipartFiles != null) {
        response = await _uploadFiles(url, token, multipartFiles, data: data);
      } else {
        final headers = _getHeaders(
          url,
          token,
          secret: secret,
          password: password,
          idToken: idToken,
        );
        //print('Headers: $headers');

        final client = http.Client();
        response = await client
            .post(
              Uri.parse(url),
              body: data,
              headers: headers,
            )
            .timeout(
              Duration(
                seconds: rawResponse ? kMaxRawPostSeconds : kMaxPostSeconds,
              ),
            );
        client.close();
      }

      _checkResponse(url, response);

      if (rawResponse) {
        return response;
      }

      final dynamic jsonResponse = json.decode(response.body);

      // Cache the response
      await _cacheData(url + data, jsonResponse);

      return jsonResponse;
    } else {
      final cachedData = await _getCachedData(url + data);
      if (cachedData != null) {
        print('Returning cached data');
        return cachedData;
      }
      throw 'No internet connection available';
    }
  }

  Future<dynamic> put(
    String url,
    String? token, {
    dynamic data,
    MultipartFile? multipartFile,
    String? password,
    String? idToken,
  }) async {
    _preCheck();

    if (!url.contains('?')) {
      url += '?';
    }

    print('PUT: $url');
    if (!kReleaseMode && Config.DEBUG_REQUESTS) {
      printWrapped('Data: $data');
    }
    http.Response response;

    if (multipartFile != null) {
      response = await _uploadFiles(url, token, [multipartFile],
          data: data, method: 'PUT');
    } else {
      final client = http.Client();
      response = await client.put(
        Uri.parse(url),
        body: data,
        headers: _getHeaders(
          url,
          token,
          password: password,
          idToken: idToken,
        ),
      );
      client.close();
    }

    _checkResponse(url, response);

    return json.decode(response.body);
  }

  Future<dynamic> delete(
    String url,
    String? token, {
    String? password,
    String? idToken,
    dynamic data,
  }) async {
    _preCheck();

    if (!url.contains('?')) {
      url += '?';
    }

    print('Delete: $url');

    final client = http.Client();
    final http.Response response = await client.delete(
      Uri.parse(url),
      headers: _getHeaders(
        url,
        token,
        password: password,
        idToken: idToken,
      ),
      body: data,
    );
    client.close();

    _checkResponse(url, response);

    return json.decode(response.body);
  }
}

Map<String, String> _getHeaders(
  String url,
  String? token, {
  String? secret,
  String? password,
  String? idToken,
}) {
  if (url.startsWith(Constants.hostedApiUrl)) {
    secret = Config.API_SECRET;
  }
  final headers = <String, String>{
    'X-CLIENT-PLATFORM': getPlatformName(),
    'X-CLIENT-VERSION': kClientVersion,
    'X-API-SECRET': secret ?? '',
    'X-Requested-With': 'XMLHttpRequest',
    'Content-Type': 'application/json; charset=utf-8',
  };

  if ((token ?? '').isNotEmpty) {
    headers['X-API-Token'] = token ?? '';
  }

  if ((idToken ?? '').isNotEmpty) {
    headers['X-API-OAUTH-PASSWORD'] = idToken ?? '';
  }

  if ((password ?? '').isNotEmpty) {
    headers['X-API-PASSWORD-BASE64'] = base64Encode(utf8.encode(password!));
  }

  return headers;
}

void _checkResponse(String url, http.Response response) {
  if (!kReleaseMode) {
    print('Response: ${formatSize(response.bodyBytes.length)}');
    if (Config.DEBUG_REQUESTS) {
      printWrapped('${response.statusCode} ${response.body}');
      print('Headers: ${response.headers}');
    }
  }

  final serverVersion = response.headers['x-app-version'];
  final minClientVersion = response.headers['x-minimum-client-version'];

  if (response.statusCode >= 500) {
    throw _parseError(
        response.statusCode, response.body, response.reasonPhrase);
  } else if (serverVersion == null) {
    throw 'Error: please check that Invoice Ninja v5 is installed on the server\n\nURL: $url\n\nResponse: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}\n\nHeaders: ${response.headers}}';
  } else if (Version.parse(kClientVersion) < Version.parse(minClientVersion!)) {
    throw 'Error: client not supported, please update to the latest version [Current v$kClientVersion < Minimum v$minClientVersion]';
  } else if (Version.parse(serverVersion) < Version.parse(kMinServerVersion)) {
    throw 'Error: server not supported, please update to the latest version [Current v$serverVersion < Minimum v$kMinServerVersion]';
  } else if (response.statusCode >= 400) {
    throw _parseError(
        response.statusCode, response.body, response.reasonPhrase);
  }
}

void _preCheck() {
  if (Config.DEMO_MODE) {
    throw 'Server requests are not supported in the demo';
  }

  /*
  final store = StoreProvider.of<AppState>(navigatorKey.currentContext);
  if (store.state.isSaving) {
    throw 'Please wait for the current request to complete';
  }
  */
}

String _parseError(int code, String response, String? reason) {
  String message = '';

  if ((reason ?? '').isNotEmpty) {
    message += reason!;
  }

  if (response.contains('DOCTYPE html')) {
    return '$code: An error occurred';
  }

  try {
    final Map<String, dynamic> jsonResponse = json.decode(response);

    if (message.isNotEmpty) {
      message += ' • ';
    }

    if (jsonResponse.containsKey('message')) {
      message += jsonResponse['message'];
    } else if (jsonResponse.containsKey('error')) {
      message += jsonResponse['error'];
    } else {
      message += response;
    }

    if (jsonResponse['errors'] != null &&
        (jsonResponse['errors'] as Map).isNotEmpty) {
      message += '\n';
      try {
        jsonResponse['errors'].forEach((String field, dynamic errors) {
          (errors as List<dynamic>)
              .forEach((dynamic error) => message += '\n • $error');
        });
      } catch (error) {
        print('Failed to parse error: $error');
      }
    }
  } catch (error) {
    print('Failed to parse error: $error');
  }

  return '$code: $message';
}

Future<http.Response> _uploadFiles(
    String url, String? token, List<MultipartFile> multipartFiles,
    {String method = 'POST', dynamic data}) async {
  final request = http.MultipartRequest(method, Uri.parse(url))
    ..fields.addAll(data ?? {})
    ..headers.addAll(_getHeaders(url, token))
    ..files.addAll(multipartFiles);

  return await http.Response.fromStream(await request.send())
      .timeout(const Duration(minutes: 10));
}
