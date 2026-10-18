import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/repositories/auth_repository.dart';

/// Sessions are intentionally memory-only. Authorization is checked by Express.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({http.Client? client, String? url, String? key})
    : _client = client ?? http.Client(),
      _url = url ?? supabaseUrl,
      _key = key ?? publishableKey;
  final http.Client _client;
  final String _url, _key;
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  String? accessToken;
  String? _refreshToken;
  DateTime? _expiry;
  Future<void>? _refreshing;
  @override
  bool get configured {
    if (_url.isEmpty || _key.isEmpty) return false;
    if (_key.startsWith('sb_publishable_')) return true;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(_key.split('.')[1]))),
      );
      return payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    if (!configured) {
      throw StateError(
        'Configure SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY no build Flutter.',
      );
    }
    await _token('password', {'email': email.trim(), 'password': password});
  }

  Future<void> _token(String grant, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          Uri.parse(
            '${_url.replaceFirst(RegExp(r'/$'), '')}/auth/v1/token?grant_type=$grant',
          ),
          headers: {'apikey': _key, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw StateError(
        '${data['msg'] ?? data['error_description'] ?? data['message'] ?? 'Não foi possível entrar.'}',
      );
    }
    accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    _expiry = DateTime.now().add(
      Duration(seconds: (data['expires_in'] as num?)?.toInt() ?? 3600),
    );
  }

  @override
  Future<String?> token() async {
    if (accessToken == null) return null;
    if (_expiry!.isBefore(DateTime.now().add(const Duration(seconds: 60)))) {
      final pending = _refreshing ??= _token('refresh_token', {
        'refresh_token': _refreshToken,
      });
      try {
        await pending;
      } catch (_) {
        clear();
        rethrow;
      } finally {
        if (identical(_refreshing, pending)) _refreshing = null;
      }
    }
    return accessToken;
  }

  @override
  Future<void> signOut() async {
    try {
      if (accessToken != null) {
        final response = await _client
            .post(
              Uri.parse(
                '${_url.replaceFirst(RegExp(r'/$'), '')}/auth/v1/logout?scope=local',
              ),
              headers: {'apikey': _key, 'Authorization': 'Bearer $accessToken'},
            )
            .timeout(const Duration(seconds: 20));
        if (response.statusCode >= 400) {
          throw StateError(
            'Sessão local encerrada; não foi possível revogar a sessão no servidor.',
          );
        }
      }
    } finally {
      clear();
    }
  }

  @override
  void clear() {
    accessToken = null;
    _refreshToken = null;
    _expiry = null;
  }

  @override
  void dispose() {
    clear();
    _client.close();
  }
}
