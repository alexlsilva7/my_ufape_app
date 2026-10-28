import 'package:auto_injector/auto_injector.dart';
import 'package:flutter/services.dart';

import '../app/app_repositories.dart';
import '../core/academic_context.dart';
import '../core/app_state.dart';
import '../data/repositories/academic/academic_data_repository.dart';
import '../data/repositories/personal/backup_repository.dart';
import '../data/repositories/personal/completion_repository.dart';
import '../data/repositories/personal/matrix_progress_repository.dart';
import '../data/repositories/personal/personal_storage_repository.dart';
import '../data/repositories/personal/schedule_plan_repository.dart';
import '../domain/repositories/admin_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/course_repository.dart';
import '../domain/repositories/extraction_repository.dart';
import '../domain/repositories/feedback_repository.dart';
import '../domain/repositories/local_storage_repository.dart';
import '../domain/repositories/migration_repository.dart';
import '../features/academic/matrix/matrix_view_model.dart';
import '../features/academic/schedule/schedule_view_model.dart';
import '../features/academic/catalog/catalog_view_model.dart';
import '../features/calendar/calendar_view_model.dart';
import '../features/admin/admin_view_model.dart';
import '../features/feedback/feedback_view_model.dart';
import '../features/home/home_view_model.dart';
import '../features/settings/settings_view_model.dart';

/// Application lifetime, independent from other app instances and tests.
/// AppState owns resource disposal; the injector only releases registrations.
class AppDependencies {
  AppDependencies._(this._injector);
  final AutoInjector _injector;
  bool _disposed = false;
  T get<T>() {
    if (_disposed) throw StateError('Dependências descartadas.');
    return _injector.get<T>();
  }

  AppState get state => get<AppState>();
  void _release() {
    _disposed = true;
    _injector.dispose();
  }

  void dispose() {
    if (!_disposed) state.dispose();
  }
}

AppDependencies setupDependencies({
  AppRepositories? repositories,
  Future<String> Function(String)? assetLoader,
}) {
  final injector = AutoInjector();
  final dependencies = AppDependencies._(injector);
  // AppRepositories retains the existing local/API/Supabase provider selection
  // and resolves the current API client for each request after a server change.
  injector.addLazySingleton<AppRepositories>(
    () => repositories ?? AppRepositories(assetLoader: assetLoader),
  );
  injector.addLazySingleton<LocalStorageRepository>(
    () => injector.get<AppRepositories>().localStorage,
  );
  injector.addLazySingleton<CourseRepository>(
    () => injector.get<AppRepositories>().courses,
  );
  injector.addLazySingleton<FeedbackRepository>(
    () => injector.get<AppRepositories>().feedback,
  );
  injector.addLazySingleton<PersonalStorageRepository>(
    () => PersonalStorageRepositoryImpl(injector.get<LocalStorageRepository>()),
  );
  injector.addLazySingleton<AcademicDataRepository>(
    () => AcademicDataRepositoryImpl(
      injector.get<CourseRepository>(),
      injector.get<PersonalStorageRepository>(),
      injector.get<AppRepositories>().source,
      assetLoader ?? rootBundle.loadString,
    ),
  );
  injector.addLazySingleton<AcademicContext>(AcademicContext.new);
  injector.addLazySingleton<CompletionRepository>(CompletionRepositoryImpl.new);
  injector.addLazySingleton<SchedulePlanRepository>(
    SchedulePlanRepositoryImpl.new,
  );
  injector.addLazySingleton<MatrixProgressRepository>(
    MatrixProgressRepositoryImpl.new,
  );
  injector.addLazySingleton<BackupRepository>(BackupRepositoryImpl.new);
  injector.addLazySingleton<MatrixViewModel>(MatrixViewModel.new);
  injector.addLazySingleton<ScheduleViewModel>(ScheduleViewModel.new);
  injector.addLazySingleton<CatalogViewModel>(CatalogViewModel.new);
  injector.addLazySingleton<CalendarViewModel>(CalendarViewModel.new);
  injector.addLazySingleton<SettingsViewModel>(SettingsViewModel.new);
  injector.addLazySingleton<HomeViewModel>(HomeViewModel.new);
  injector.addLazySingleton<FeedbackViewModel>(
    () => FeedbackViewModel(
      injector.get<FeedbackRepository>(),
      injector.get<AcademicContext>(),
      isLocal: injector.get<AppRepositories>().isLocal,
    ),
  );
  injector.addLazySingleton<AppState>(
    () => AppState.injected(
      repositories: injector.get<AppRepositories>(),
      context: injector.get<AcademicContext>(),
      storage: injector.get<PersonalStorageRepository>(),
      data: injector.get<AcademicDataRepository>(),
      completions: injector.get<CompletionRepository>(),
      plan: injector.get<SchedulePlanRepository>(),
      matrix: injector.get<MatrixViewModel>(),
      timetable: injector.get<ScheduleViewModel>(),
      catalog: injector.get<CatalogViewModel>(),
      calendar: injector.get<CalendarViewModel>(),
      settings: injector.get<SettingsViewModel>(),
      home: injector.get<HomeViewModel>(),
      feedback: injector.get<FeedbackViewModel>(),
      releaseDependencies: dependencies._release,
    ),
  );
  injector.commit();
  return dependencies;
}

/// Screen lifetime. Authenticated repositories and drafts never enter the public
/// app injector, including when multiple administrative sessions are open.
class AdminDependencies {
  AdminDependencies._(this._injector);
  final AutoInjector _injector;
  bool _disposed = false;
  T get<T>() {
    if (_disposed) throw StateError('Sessão administrativa descartada.');
    return _injector.get<T>();
  }

  void dispose() {
    if (_disposed) return;
    get<CourseEditorViewModel>().dispose();
    get<AdminRepositories>().dispose();
    _disposed = true;
    _injector.dispose();
  }
}

AdminDependencies setupAdminDependencies(AppRepositories repositories) {
  final injector = AutoInjector();
  injector.addLazySingleton<AdminRepositories>(repositories.createAdminScope);
  injector.addLazySingleton<AuthRepository>(
    () => injector.get<AdminRepositories>().auth,
  );
  injector.addLazySingleton<AdminRepository>(
    () => injector.get<AdminRepositories>().admin,
  );
  injector.addLazySingleton<CourseRepository>(
    () => injector.get<AdminRepositories>().courses,
  );
  injector.addLazySingleton<FeedbackRepository>(
    () => injector.get<AdminRepositories>().feedback,
  );
  injector.addLazySingleton<ExtractionRepository>(
    () => injector.get<AdminRepositories>().extraction,
  );
  injector.addLazySingleton<MigrationRepository>(
    () => injector.get<AdminRepositories>().migrations,
  );
  injector.addLazySingleton<CourseEditorViewModel>(CourseEditorViewModel.new);
  injector.commit();
  return AdminDependencies._(injector);
}

AdminViewModel createAdminViewModel(AppState state) {
  final dependencies = setupAdminDependencies(state.repositories);
  return AdminViewModel(
    appRepositories: state.repositories,
    academicContext: state.context,
    adminRepositories: dependencies.get<AdminRepositories>(),
    editor: dependencies.get<CourseEditorViewModel>(),
    disposeScope: dependencies.dispose,
  );
}
