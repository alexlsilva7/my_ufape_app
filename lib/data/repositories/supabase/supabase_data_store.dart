import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/models.dart';
import '../../academic_data_store.dart';

class SupabaseDataStore implements AcademicDataStore {
  SupabaseDataStore({
    required this.url,
    required this.key,
    http.Client? client,
    this.token,
  }) : _client = client ?? http.Client() {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        !_publicKey(key)) {
      throw ArgumentError(
        'Configure SUPABASE_URL e uma SUPABASE_PUBLISHABLE_KEY pública válida.',
      );
    }
  }
  final String url, key;
  final http.Client _client;
  final Future<String?> Function()? token;
  bool _publicKey(String key) {
    if (key.startsWith('sb_publishable_')) return true;
    try {
      return asMap(
            jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(key.split('.')[1])),
              ),
            ),
          )['role'] ==
          'anon';
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, String> query = const {},
    Object? body,
    String? prefer,
  }) async {
    final accessToken = await token?.call();
    final uri = Uri.parse(
      '${url.replaceFirst(RegExp(r'/$'), '')}/rest/v1/$path',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'apikey': key,
        'Accept': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        if (body != null) 'Content-Type': 'application/json',
        'Prefer': ?prefer,
      });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 20)),
    ).timeout(const Duration(seconds: 20));
    dynamic result;
    if (response.bodyBytes.isNotEmpty) {
      result = jsonDecode(utf8.decode(response.bodyBytes));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = textOf(
        asMap(result)['message'],
        'Falha ao consultar o Supabase.',
      );
      throw StateError('Supabase (${response.statusCode}): $message');
    }
    return result;
  }

  Map<String, String> _filters(Map<String, String> filters) => {
    for (final e in filters.entries) e.key: 'eq.${jsonEncode(e.value)}',
  };
  @override
  Future<List<JsonMap>> select(
    String table, {
    Map<String, String> filters = const {},
  }) async {
    final rows = <JsonMap>[];
    // Respect PostgREST's default page limit without silently dropping rows.
    for (var offset = 0; ; offset += 500) {
      final page = await request(
        table,
        query: {
          'select': '*',
          ..._filters(filters),
          'limit': '500',
          'offset': '$offset',
          'order': table == 'course_schedules'
              ? 'course_id,semester'
              : ['course_curricula', 'course_contents'].contains(table)
              ? 'course_id'
              : 'id',
        },
      );
      if (page is! List) {
        throw const FormatException('Resposta Supabase inválida.');
      }
      rows.addAll(page.map(asMap));
      if (page.length < 500) return rows;
    }
  }

  @override
  Future<void> upsert(String table, JsonMap row) async {
    await request(
      table,
      method: 'POST',
      body: row,
      prefer: 'resolution=merge-duplicates,return=minimal',
    );
  }

  @override
  Future<void> delete(String table, Map<String, String> filters) async {
    if (filters.isEmpty) throw ArgumentError('Exclusão exige identificador.');
    await request(
      table,
      method: 'DELETE',
      query: _filters(filters),
      prefer: 'return=minimal',
    );
  }

  void dispose() => _client.close();
}
