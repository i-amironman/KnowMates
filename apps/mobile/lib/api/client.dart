import 'dart:convert';

import 'package:http/http.dart' as http;

typedef TokenPair = ({String access, String refresh});

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.readTokens,
    required this.writeTokens,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  static const defaultBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:8080',
  );

  final String baseUrl;
  final Future<TokenPair?> Function() readTokens;
  final Future<void> Function(TokenPair pair) writeTokens;
  final http.Client _http;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<http.Response> get(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query);
  }

  Future<http.Response> post(String path, {Object? body, bool auth = false}) {
    return _send('POST', path, body: body, auth: auth);
  }

  Future<http.Response> patch(String path, {Object? body}) {
    return _send('PATCH', path, body: body, auth: true);
  }

  Future<http.Response> put(String path, {Object? body}) {
    return _send('PUT', path, body: body, auth: true);
  }

  Future<http.Response> delete(String path) {
    return _send('DELETE', path, auth: true);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
    bool retried = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final tokens = await readTokens();
      final access = tokens?.access;
      if (access == null || access.isEmpty) {
        return http.Response('{"error":"unauthorized"}', 401);
      }
      headers['Authorization'] = 'Bearer $access';
    }
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    final response = await _dispatch(method, uri, headers, encoded);
    if (auth && response.statusCode == 401 && !retried) {
      final refreshed = await _refresh();
      if (refreshed) {
        return _send(method, path, query: query, body: body, auth: auth, retried: true);
      }
    }
    return response;
  }

  Future<http.Response> _dispatch(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    switch (method) {
      case 'GET':
        return _http.get(uri, headers: headers);
      case 'POST':
        return _http.post(uri, headers: headers, body: body);
      case 'PATCH':
        return _http.patch(uri, headers: headers, body: body);
      case 'PUT':
        return _http.put(uri, headers: headers, body: body);
      case 'DELETE':
        return _http.delete(uri, headers: headers);
      default:
        throw ArgumentError('unsupported method $method');
    }
  }

  Future<bool> _refresh() async {
    final tokens = await readTokens();
    final refresh = tokens?.refresh;
    if (refresh == null || refresh.isEmpty) {
      return false;
    }
    final response = await _http.post(
      _uri('/v1/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );
    if (response.statusCode != 200) {
      return false;
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final access = map['access'] as String?;
    final nextRefresh = map['refresh'] as String?;
    if (access == null || nextRefresh == null) {
      return false;
    }
    await writeTokens((access: access, refresh: nextRefresh));
    return true;
  }

  void close() => _http.close();
}

String? apiErrorMessage(http.Response response) {
  try {
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final code = map['error'] as String?;
    if (code == null) {
      return null;
    }
    return _knownErrors[code] ?? code;
  } catch (_) {
    return null;
  }
}

const _knownErrors = {
  'underage': 'You need to be 18 or older.',
  'email_taken': 'That email is already registered.',
  'bad_credentials': 'Email or password is wrong.',
  'password_too_short': 'Password must be at least 10 characters.',
};
