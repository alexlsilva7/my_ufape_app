import 'package:my_ufape/data/repositories/course_details_reader.dart';

import 'test_state.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ufape/app/app_repositories.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/data/repositories/api/api_course_repository.dart';
import 'package:my_ufape/data/repositories/supabase/supabase_auth_repository.dart';
import 'package:my_ufape/domain/repositories/course_repository.dart';
import 'package:my_ufape/domain/repositories/local_storage_repository.dart';

class MemoryStorage implements LocalStorageRepository {
  final values = <String, String>{
    'selectedCourse': 'bcc',
    'selectedSemester': '2026.1',
  };
  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class StubCourses with CourseDetailsReader implements CourseRepository {
  bool offline = false;
  final queries = <String>[];
  static const course = {'id': 'bcc', 'name': 'BCC', 'shortName': 'BCC'};
  @override
  Future<JsonMap> list() async {
    if (offline) throw StateError('Offline');
    return {
      'courses': [course],
    };
  }

  @override
  Future<JsonMap> getDocument(
    String id, {
    String? semester,
    bool strict = false,
    bool academicOnly = false,
  }) async {
    if (offline) throw StateError('Offline');
    queries.add('$id:$semester:$academicOnly');
    return {
      'course': course,
      'curriculum': {'subjects': []},
      'schedule': [],
    };
  }

  @override
  Future<void> save(JsonMap course) async => throw UnimplementedError();
  @override
  Future<void> updateMetadata(String id, JsonMap metadata) async =>
      throw UnimplementedError();
  @override
  Future<void> updateVisibility(String id, JsonMap visibility) async =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id) async => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'state accepts repository contracts and keeps its offline cache',
    () async {
      final courses = StubCourses();
      final storage = MemoryStorage();
      final repositories = AppRepositories(
        api: AcademicApi(
          client: MockClient((_) async => throw StateError('Unexpected HTTP')),
        ),
        courses: courses,
        localStorage: storage,
      );
      final state = createAppState(repositories: repositories);
      addTearDown(state.dispose);
      await state.initialize();
      expect(state.selectedCourse?.id, 'bcc');
      expect(courses.queries, ['bcc:2026.1:true']);
      expect(state.offline, isFalse);
      state.setThemeMode(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      expect(storage.values['themePreference'], 'dark');
      expect(storage.values.containsKey('flutter_cache_courses'), isTrue);

      courses.offline = true;
      await state.refresh();
      expect(state.offline, isTrue);
      expect(state.courseDetails?.course.toJson(), StubCourses.course);
      expect(state.error, isNull);
    },
  );

  test('Supabase sessions belong to admin scopes and never leak into public queries', () async {
    final headers = <String?>[];
    var revoked = 0;
    final repositories = AppRepositories(
      api: AcademicApi(
        baseUrl: 'https://test.invalid',
        client: MockClient((request) async {
          headers.add(request.headers['Authorization']);
          return http.Response('{"courses":[]}', 200);
        }),
      ),
      authFactory: () => SupabaseAuthRepository(
        url: 'https://test.supabase.co',
        key: 'sb_publishable_test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/logout')) {
            revoked++;
            expect(request.headers['Authorization'], 'Bearer admin-token');
            return http.Response('', 204);
          }
          return http.Response(
            '{"access_token":"admin-token","refresh_token":"refresh","expires_in":3600}',
            200,
          );
        }),
      ),
    );
    addTearDown(repositories.dispose);
    final first = repositories.createAdminScope();
    final second = repositories.createAdminScope();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await first.auth.signIn('admin@example.com', 'password');
    await first.courses.list();
    await repositories.courses.list();
    await second.courses.list();
    await first.auth.signOut();
    await first.courses.list();
    expect(headers, ['Bearer admin-token', null, null, null]);
    expect(revoked, 1);
  });

  test(
    'existing repositories follow server changes without losing overrides',
    () async {
      final hosts = <String>[];
      AcademicApi createApi(String url) => AcademicApi(
        baseUrl: url,
        client: MockClient((request) async {
          hosts.add(request.url.host);
          return http.Response('{"courses":[]}', 200);
        }),
      );
      final storage = MemoryStorage();
      final repositories = AppRepositories(
        api: createApi('https://first.invalid'),
        apiFactory: createApi,
        localStorage: storage,
      );
      addTearDown(repositories.dispose);
      final courses = repositories.courses;
      final admin = repositories.createAdminScope();
      addTearDown(admin.dispose);
      await courses.list();
      repositories.setApiBaseUrl('https://second.invalid');
      await courses.list();
      await admin.courses.list();
      expect(hosts, ['first.invalid', 'second.invalid', 'second.invalid']);
      expect(repositories.localStorage, same(storage));
    },
  );

  test(
    'course operations preserve query options and encode identifier segments',
    () async {
      final requests = <http.Request>[];
      final api = AcademicApi(
        baseUrl: 'https://test.invalid',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"course":{"id":"bcc"}}', 200);
        }),
      );
      addTearDown(api.close);
      final CourseRepository repository = ApiCourseRepository(() => api);
      await repository.get(
        'a/b ?',
        semester: '2026.2',
        strict: true,
        academicOnly: true,
      );
      await repository.updateMetadata('a/b ?', {'name': 'Curso'});
      await repository.delete('a/b ?');
      expect(requests.first.url.pathSegments, ['api', 'courses', 'a/b ?']);
      expect(requests.first.url.queryParameters, {
        'semester': '2026.2',
        'strict': 'true',
        'include': 'curriculum,contents,schedule',
      });
      expect(requests[1].url.pathSegments.last, 'metadata');
      expect(requests[1].method, 'PATCH');
      expect(jsonDecode(requests[1].body), {'name': 'Curso'});
      expect(requests.last.method, 'DELETE');
    },
  );
}
