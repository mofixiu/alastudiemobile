import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? secureStorage})
    : _client = client ?? http.Client(),
      _storage = secureStorage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'alastudie_access_token';
  static const _override = String.fromEnvironment('API_BASE_URL');
  static const _shareBaseOverride = String.fromEnvironment(
    'PUBLIC_SHARE_BASE_URL',
  );
  String get baseUrl => _override.isNotEmpty
      ? _override
      : Platform.isAndroid
      ? 'http://10.0.2.2:4000'
      : 'http://127.0.0.1:4000';
  String get shareBaseUrl =>
      (_shareBaseOverride.isNotEmpty ? _shareBaseOverride : baseUrl)
          .replaceFirst(RegExp(r'/$'), '');

  Future<String?> get token => _storage.read(key: _tokenKey);
  Future<void> saveToken(String value) =>
      _storage.write(key: _tokenKey, value: value);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return _decode(
      await _client
          .get(uri, headers: await _headers(authenticated))
          .timeout(const Duration(seconds: 8)),
    );
  }

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic> body = const {},
    bool authenticated = true,
  ]) async => _decode(
    await _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(authenticated),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8)),
  );

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async => _decode(
    await _client
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(true),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8)),
  );

  Future<Map<String, dynamic>> delete(String path) async => _decode(
    await _client
        .delete(Uri.parse('$baseUrl$path'), headers: await _headers(true))
        .timeout(const Duration(seconds: 8)),
  );

  Future<Map<String, String>> _headers(bool authenticated) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final value = await token;
      if (value != null) headers['Authorization'] = 'Bearer $value';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } catch (_) {
      body = {};
    }
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw ApiException(
        '${body['error'] ?? body['message'] ?? 'Request failed. Try again.'}',
        statusCode: response.statusCode,
      );
    return body;
  }

  void close() => _client.close();
}
