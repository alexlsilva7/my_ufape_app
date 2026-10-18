import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ufape/app/app_repositories.dart';
import 'package:my_ufape/core/data_source.dart';
import 'package:my_ufape/data/repositories/supabase/supabase_data_store.dart';
import 'package:my_ufape/domain/repositories/auth_repository.dart';

class TestAuth implements AuthRepository {
  String? value;
  @override
  bool get configured => true;
  @override
  Future<void> signIn(String email, String password) async {
    value = 'admin-token';
  }

  @override
  Future<String?> token() async => value;
  @override
  Future<void> signOut() async {
    clear();
  }

  @override
  void clear() {
    value = null;
  }

  @override
  void dispose() {
    clear();
  }
}

void main() {
  test('Supabase mode queries JSON tables directly and isolates public/admin tokens', () async {
    final requests = <http.Request>[];
    final repositories = AppRepositories(
      source: DataSource.supabase,
      supabaseUrl: 'https://test.supabase.co',
      supabaseKey: 'sb_publishable_test',
      authFactory: TestAuth.new,
      supabaseClientFactory: () => MockClient((request) async {
        requests.add(request);
        expect(request.headers['apikey'], 'sb_publishable_test');
        expect(request.url.path, startsWith('/rest/v1/'));
        if (request.url.path.endsWith('/flutter_is_academic_admin')) {
          expect(request.headers['Authorization'], 'Bearer admin-token');
          return http.Response('true', 200);
        }
        if (request.method == 'POST') {
          if (request.headers['Authorization'] != 'Bearer admin-token') {
            return http.Response('{"message":"RLS denied"}', 403);
          }
          return http.Response('', 204);
        }
        if (request.method == 'PATCH') {
          expect(request.headers['Authorization'], 'Bearer admin-token');
          expect(request.url.path, endsWith('/site_feedback'));
          return http.Response(
            jsonEncode([
              {
                'id': 'feedback',
                ...jsonDecode(request.body) as Map<String, dynamic>,
              },
            ]),
            200,
          );
        }
        final data = switch (request.url.path.split('/').last) {
          'courses' => [
            {
              'id': 'bcc',
              'data': {
                'id': 'bcc',
                'name': 'BCC',
                'semesters': ['2026.2'],
              },
            },
          ],
          'course_curricula' => [
            {
              'course_id': 'bcc',
              'data': {
                'subjects': [
                  {'id': 'subject'},
                ],
              },
            },
          ],
          'course_contents' => [
            {
              'course_id': 'bcc',
              'data': {'disciplinas': []},
            },
          ],
          'course_schedules' => [
            {
              'course_id': 'bcc',
              'semester': '2026.2',
              'data': [
                {'id': 'class'},
              ],
              'updated_at': '2026-10-18T00:00:00Z',
            },
          ],
          _ => <dynamic>[],
        };
        return http.Response(jsonEncode(data), 200);
      }),
      apiFactory: (_) => throw StateError(
        'Academic Supabase operations must not call Express',
      ),
    );
    addTearDown(repositories.dispose);
    final result = await repositories.courses.get('bcc', semester: '2026.2');
    expect(result['resolvedSemester'], '2026.2');
    expect(result['curriculum']['subjects'], hasLength(1));
    expect(result['schedule'], hasLength(1));
    expect(
      requests.every((r) => !r.headers.containsKey('Authorization')),
      isTrue,
    );
    await expectLater(
      repositories.courses.updateMetadata('bcc', {'name': 'Unauthorized'}),
      throwsStateError,
    );

    final admin = repositories.createAdminScope();
    addTearDown(admin.dispose);
    await expectLater(admin.admin.validateSession(), throwsStateError);
    await admin.auth.signIn('admin@example.com', 'password');
    await admin.admin.validateSession();
    await admin.courses.updateMetadata('bcc', {
      'name': 'Authorized',
      'shortName': 'BCC',
    });
    final write = requests.last;
    expect(write.method, 'POST');
    expect(jsonDecode(write.body)['data']['name'], 'Authorized');
    expect(write.headers['Authorization'], 'Bearer admin-token');
    final feedback = await admin.feedback.update(
      'feedback',
      status: 'reviewing',
      notes: 'Reviewed',
    );
    expect(feedback['item']['internal_notes'], 'Reviewed');
    expect(requests.last.method, 'PATCH');
    requests.clear();
    await repositories.courses.list();
    expect(
      requests.every((r) => !r.headers.containsKey('Authorization')),
      isTrue,
    );
  });

  test(
    'Supabase pagination does not lose rows and propagates permission failures',
    () async {
      final offsets = <String?>[];
      final store = SupabaseDataStore(
        url: 'https://test.supabase.co',
        key: 'sb_publishable_test',
        client: MockClient((request) async {
          offsets.add(request.url.queryParameters['offset']);
          if (request.url.path.endsWith('/courses')) {
            final offset = int.parse(offsets.last!);
            return http.Response(
              jsonEncode([
                for (var i = offset; i < (offset == 0 ? 500 : 501); i++)
                  {'id': '$i'},
              ]),
              200,
            );
          }
          return http.Response('{"message":"permission denied"}', 403);
        }),
      );
      addTearDown(store.dispose);
      expect(await store.select('courses'), hasLength(501));
      expect(offsets, ['0', '500']);
      await expectLater(store.select('site_feedback'), throwsStateError);
      expect(
        () => SupabaseDataStore(
          url: 'https://test.supabase.co',
          key: 'sb_secret_forbidden',
        ),
        throwsArgumentError,
      );
    },
  );
}
