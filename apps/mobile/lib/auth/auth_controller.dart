import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/client.dart';

class SignUpInput {
  const SignUpInput({
    required this.email,
    required this.password,
    required this.birthDate,
    required this.timezone,
  });

  final String email;
  final String password;
  final String birthDate;
  final String timezone;
}

class SkillOption {
  const SkillOption({required this.id, required this.name});

  final String id;
  final String name;

  factory SkillOption.fromJson(Map<String, dynamic> json) {
    return SkillOption(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class AuthController extends ChangeNotifier {
  AuthController({ApiClient? client, FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    _client =
        client ??
        ApiClient(
          baseUrl: ApiClient.defaultBase,
          readTokens: _readTokens,
          writeTokens: _persistTokens,
        );
  }

  late final ApiClient _client;
  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  String? _accessToken;
  bool _profileReady = false;
  bool _bootstrapped = false;

  String? get accessToken => _accessToken;
  bool get profileReady => _profileReady;
  bool get bootstrapped => _bootstrapped;
  ApiClient get client => _client;

  Future<TokenPair?> _readTokens() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) {
      return null;
    }
    return (access: access, refresh: refresh);
  }

  Future<void> _persistTokens(TokenPair pair) async {
    await _storage.write(key: _accessKey, value: pair.access);
    await _storage.write(key: _refreshKey, value: pair.refresh);
    _accessToken = pair.access;
  }

  Future<void> bootstrap() async {
    final tokens = await _readTokens();
    _accessToken = tokens?.access;
    if (_accessToken != null) {
      await refreshProfileReady();
    }
    _bootstrapped = true;
    notifyListeners();
  }

  Future<void> refreshProfileReady() async {
    final response = await _client.get('/v1/me');
    if (response.statusCode != 200) {
      return;
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    _profileReady = map['profileReady'] == true;
    notifyListeners();
  }

  Future<String?> signUp(SignUpInput input) async {
    final response = await _client.post(
      '/v1/auth/sign-up',
      body: {
        'email': input.email.trim(),
        'password': input.password,
        'birth_date': input.birthDate,
        'timezone': input.timezone,
      },
    );
    if (response.statusCode == 201) {
      await _storePairFromBody(response.body);
      _profileReady = false;
      notifyListeners();
      return null;
    }
    return apiErrorMessage(response);
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      '/v1/auth/sign-in',
      body: {'email': email.trim(), 'password': password},
    );
    if (response.statusCode == 200) {
      await _storePairFromBody(response.body);
      await refreshProfileReady();
      return null;
    }
    return apiErrorMessage(response);
  }

  Future<void> signOut() async {
    final tokens = await _readTokens();
    if (tokens != null) {
      await _client.post(
        '/v1/auth/sign-out',
        body: {'refresh': tokens.refresh},
        auth: true,
      );
    }
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    _accessToken = null;
    _profileReady = false;
    notifyListeners();
  }

  Future<void> _storePairFromBody(String body) async {
    final map = jsonDecode(body) as Map<String, dynamic>;
    final access = map['access'] as String;
    final refresh = map['refresh'] as String;
    await _persistTokens((access: access, refresh: refresh));
  }

  Future<List<SkillOption>> fetchSkills({String query = ''}) async {
    final response = await _client.get('/v1/skills', query: {'q': query});
    if (response.statusCode != 200) {
      return const [];
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .cast<Map<String, dynamic>>()
          .map(SkillOption.fromJson)
          .toList();
    }
    if (decoded is Map<String, dynamic> && decoded['skills'] is List) {
      return (decoded['skills'] as List)
          .cast<Map<String, dynamic>>()
          .map(SkillOption.fromJson)
          .toList();
    }
    return const [];
  }

  Future<String?> completeSetup({
    required String displayName,
    required List<String> languages,
    required String timezone,
    required List<Map<String, dynamic>> teach,
    required List<Map<String, dynamic>> learn,
    required List<Map<String, dynamic>> slots,
  }) async {
    var response = await _client.patch(
      '/v1/me',
      body: {
        'displayName': displayName,
        'languages': languages,
        'timezone': timezone,
      },
    );
    if (response.statusCode != 200) {
      return apiErrorMessage(response) ?? 'Could not save profile.';
    }

    response = await _client.put(
      '/v1/me/skills',
      body: {'teach': teach, 'learn': learn},
    );
    if (response.statusCode != 204) {
      return apiErrorMessage(response) ?? 'Could not save skills.';
    }

    response = await _client.put(
      '/v1/me/availability',
      body: {'slots': slots},
    );
    if (response.statusCode != 204) {
      return apiErrorMessage(response) ?? 'Could not save availability.';
    }

    response = await _client.patch('/v1/me', body: {'ready': true});
    if (response.statusCode != 200) {
      return apiErrorMessage(response) ?? 'Could not finish setup.';
    }
    _profileReady = true;
    notifyListeners();
    return null;
  }
}
