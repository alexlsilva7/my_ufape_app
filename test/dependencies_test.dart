import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:my_ufape/app/app_repositories.dart';
import 'package:my_ufape/config/dependencies.dart';
import 'package:my_ufape/core/academic_context.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/data/repositories/academic/academic_data_repository.dart';
import 'package:my_ufape/data/repositories/personal/backup_repository.dart';
import 'package:my_ufape/data/repositories/personal/completion_repository.dart';
import 'package:my_ufape/data/repositories/personal/matrix_progress_repository.dart';
import 'package:my_ufape/data/repositories/personal/personal_storage_repository.dart';
import 'package:my_ufape/data/repositories/personal/schedule_plan_repository.dart';
import 'package:my_ufape/domain/repositories/auth_repository.dart';
import 'package:my_ufape/domain/repositories/course_repository.dart';
import 'package:my_ufape/domain/repositories/local_storage_repository.dart';
import 'package:my_ufape/features/academic/matrix/matrix_view_model.dart';
import 'package:my_ufape/features/academic/schedule/schedule_view_model.dart';
import 'package:my_ufape/features/admin/admin_view_model.dart';
import 'package:my_ufape/features/settings/settings_view_model.dart';

import 'test_state.dart';

import 'repositories_test.dart' show StubCourses, MemoryStorage;

class TrackingAuth implements AuthRepository {
  String? accessToken;
  int disposals = 0;
  @override
  bool get configured => true;
  @override
  Future<void> signIn(String email, String password) async =>
      accessToken = email;
  @override
  Future<String?> token() async => accessToken;
  @override
  Future<void> signOut() async => clear();
  @override
  void clear() => accessToken = null;
  @override
  void dispose() {
    disposals++;
    clear();
  }
}

class TrackingRepositories extends AppRepositories {
  TrackingRepositories({List<TrackingAuth>? sessions})
    : super(
        api: AcademicApi(
          client: MockClient((_) async => throw StateError('Unexpected HTTP')),
        ),
        courses: StubCourses(),
        localStorage: MemoryStorage(),
        authFactory: () {
          final auth = TrackingAuth();
          sessions?.add(auth);
          return auth;
        },
      );
  int disposals = 0;
  @override
  void dispose() {
    disposals++;
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all application bindings resolve to one shared dependency graph',
    () async {
      final repositories = TrackingRepositories();
      final scope = setupDependencies(repositories: repositories);
      addTearDown(scope.dispose);
      final state = scope.state;
      expect(scope.state, same(state));
      expect(scope.get<AppRepositories>(), same(repositories));
      expect(
        scope.get<LocalStorageRepository>(),
        same(repositories.localStorage),
      );
      expect(scope.get<CourseRepository>(), same(repositories.courses));
      expect(scope.get<AcademicContext>(), same(state.context));
      expect(scope.get<PersonalStorageRepository>(), same(state.storage));
      expect(scope.get<AcademicDataRepository>(), same(state.data));
      expect(scope.get<MatrixViewModel>(), same(state.matrix));
      expect(scope.get<ScheduleViewModel>(), same(state.timetable));
      expect(scope.get<SettingsViewModel>(), same(state.settings));
      expect(state.matrix.context, same(state.context));
      expect(state.timetable.context, same(state.context));
      expect(state.settings.context, same(state.context));
      expect(scope.get<CompletionRepository>(), same(state.matrix.completions));
      expect(scope.get<SchedulePlanRepository>(), same(state.timetable.plan));
      expect(
        scope.get<MatrixProgressRepository>(),
        same(state.matrix.personalProgress),
      );
      expect(scope.get<BackupRepository>(), same(state.settings.backups));
      await state.initialize();
      expect(state.selectedCourse?.id, 'bcc');
    },
  );

  test(
    'independent containers never share academic selection or preferences',
    () async {
      final first = setupDependencies(repositories: TrackingRepositories());
      final second = setupDependencies(repositories: TrackingRepositories());
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await first.state.initialize();
      await second.state.initialize();
      expect(first.state.context, isNot(same(second.state.context)));
      expect(first.state.matrix, isNot(same(second.state.matrix)));
      expect(first.state.storage, isNot(same(second.state.storage)));
      await first.state.settings.setThemeMode(ThemeMode.dark);
      expect(second.state.themeMode, ThemeMode.light);
      await first.state.selectCourse(null);
      expect(second.state.selectedCourse?.id, 'bcc');
    },
  );

  test('administrative scopes isolate credentials and course drafts from public bindings', () async {
    final sessions = <TrackingAuth>[];
    final repositories = TrackingRepositories(sessions: sessions);
    final app = setupDependencies(repositories: repositories);
    final first = setupAdminDependencies(repositories);
    final second = setupAdminDependencies(repositories);
    addTearDown(app.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final firstAuth = first.get<AuthRepository>();
    final secondAuth = second.get<AuthRepository>();
    await firstAuth.signIn('admin-one', 'password');
    expect(await secondAuth.token(), isNull);
    expect(
      first.get<CourseRepository>(),
      isNot(same(app.get<CourseRepository>())),
    );
    expect(
      second.get<CourseRepository>(),
      isNot(same(first.get<CourseRepository>())),
    );
    final editor = first.get<CourseEditorViewModel>();
    expect(first.get<CourseEditorViewModel>(), same(editor));
    expect(editor.repository, same(first.get<CourseRepository>()));
    editor.newCourse();
    editor.updateFields(name: 'Draft one');
    expect(second.get<CourseEditorViewModel>().name, isEmpty);
    first.dispose();
    first.dispose();
    expect(sessions.first.disposals, 1);
    expect(sessions.last.disposals, 0);
    expect(() => first.get<AuthRepository>(), throwsStateError);
    expect(await secondAuth.token(), isNull);
  });

  test(
    'state or container can own shutdown without double-disposing resources',
    () async {
      final repositories = TrackingRepositories();
      final scope = setupDependencies(repositories: repositories);
      final state = scope.state;
      await state.initialize();
      state.dispose();
      scope.dispose();
      state.dispose();
      expect(repositories.disposals, 1);
      expect(() => scope.get<MatrixViewModel>(), throwsStateError);
    },
  );

  test(
    'disposing a container and creating a composed state are supported',
    () async {
      final repositories = TrackingRepositories();
      final unused = setupDependencies(repositories: repositories);
      unused.dispose();
      unused.dispose();
      expect(repositories.disposals, 1);
      final state = createAppState(repositories: TrackingRepositories());
      addTearDown(state.dispose);
      expect(state.matrix.context, same(state.context));
      await state.initialize();
      expect(state.courses.single.id, 'bcc');
    },
  );
}
