import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int status;
  final String message;
  const ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class AcademicApi {
  final String baseUrl;
  final http.Client _client;
  static String get defaultBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    return configured.isNotEmpty
        ? configured
        : kIsWeb
        ? Uri.base.origin
        : 'http://localhost:3000';
  }

  AcademicApi({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? defaultBaseUrl,
      _client = client ?? http.Client();
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
    String? token,
    Duration? timeout,
  }) async {
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/$'), '')}${path.startsWith('/') ? '' : '/'}$path',
    );
    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final deadline =
        timeout ??
        (path.contains('/extract-')
            ? const Duration(minutes: 30)
            : const Duration(seconds: 12));
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(deadline),
    ).timeout(deadline);
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        data is Map
            ? (data['error'] ??
                      data['message'] ??
                      'Erro HTTP ${response.statusCode}')
                  .toString()
            : 'Erro HTTP ${response.statusCode}',
      );
    }
    if (data == null && response.statusCode != 204) {
      throw const FormatException(
        'O servidor retornou uma resposta JSON inválida.',
      );
    }
    return data;
  }

  void close() => _client.close();
}
