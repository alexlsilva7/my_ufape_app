import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/data_source.dart';
import '../data/academic_data_store.dart';
import '../data/repositories/api/api_admin_repository.dart';
import '../data/repositories/api/api_course_repository.dart';
import '../data/repositories/api/api_extraction_repository.dart';
import '../data/repositories/api/api_feedback_repository.dart';
import '../data/repositories/api/api_migration_repository.dart';
import '../data/repositories/local/local_admin_repository.dart';
import '../data/repositories/local/local_auth_repository.dart';
import '../data/repositories/local/local_contents_repository.dart';
import '../data/repositories/local/local_course_repository.dart';
import '../data/repositories/local/local_curriculum_repository.dart';
import '../data/repositories/local/local_feedback_repository.dart';
import '../data/repositories/local/local_json_store.dart';
import '../data/repositories/local/local_schedule_repository.dart';
import '../data/repositories/local/shared_preferences_local_storage_repository.dart';
import '../data/repositories/supabase/supabase_admin_repository.dart';
import '../data/repositories/supabase/supabase_auth_repository.dart';
import '../data/repositories/supabase/supabase_contents_repository.dart';
import '../data/repositories/supabase/supabase_course_repository.dart';
import '../data/repositories/supabase/supabase_curriculum_repository.dart';
import '../data/repositories/supabase/supabase_data_store.dart';
import '../data/repositories/supabase/supabase_feedback_repository.dart';
import '../data/repositories/supabase/supabase_schedule_repository.dart';
import '../data/repositories/unavailable_remote_repositories.dart';
import '../domain/repositories/admin_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/course_repository.dart';
import '../domain/repositories/extraction_repository.dart';
import '../domain/repositories/feedback_repository.dart';
import '../domain/repositories/local_storage_repository.dart';
import '../domain/repositories/migration_repository.dart';

/// The environment chooses providers once. Explicit dependencies remain injectable.
class AppRepositories {
  AppRepositories({
    DataSource? source,
    AcademicApi? api,
    CourseRepository? courses,
    FeedbackRepository? feedback,
    LocalStorageRepository? localStorage,
    Future<String> Function(String)? assetLoader,
    this.authFactory,
    AcademicApi Function(String)? apiFactory,
    String? supabaseUrl,
    String? supabaseKey,
    http.Client Function()? supabaseClientFactory,
    this.adminFactory,
  }) : source =
           source ?? (api != null ? DataSource.api : DataSource.environment),
       _api = api,
       _createApi = apiFactory ?? ((url) => AcademicApi(baseUrl: url)),
       _supabaseUrl = supabaseUrl ?? SupabaseAuthRepository.supabaseUrl,
       _supabaseKey = supabaseKey ?? SupabaseAuthRepository.publishableKey,
       _supabaseClientFactory = supabaseClientFactory ?? http.Client.new {
    this.localStorage =
        localStorage ?? SharedPreferencesLocalStorageRepository();
    switch (this.source) {
      case DataSource.local:
        final store = LocalJsonStore(
          storage: this.localStorage,
          assetLoader: assetLoader,
        );
        this.courses = courses ?? _documentCourses(store);
        this.feedback = feedback ?? LocalFeedbackRepository(store);
      case DataSource.supabase:
        final store = _newSupabaseStore();
        _publicSupabase = store;
        this.courses = courses ?? _documentCourses(store);
        this.feedback =
            feedback ??
            SupabaseFeedbackRepository(
              store,
              submissions: ApiFeedbackRepository(_apiClient),
            );
      case DataSource.api:
        this.courses = courses ?? ApiCourseRepository(_apiClient);
        this.feedback = feedback ?? ApiFeedbackRepository(_apiClient);
    }
  }

  final DataSource source;
  AcademicApi? _api;
  SupabaseDataStore? _publicSupabase;
  late final CourseRepository courses;
  late final FeedbackRepository feedback;
  late final LocalStorageRepository localStorage;
  final AuthRepository Function()? authFactory;
  final AcademicApi Function(String) _createApi;
  final String _supabaseUrl, _supabaseKey;
  final http.Client Function() _supabaseClientFactory;
  final AdminRepositories Function()? adminFactory;
  String get apiBaseUrl => _api?.baseUrl ?? AcademicApi.defaultBaseUrl;
  bool get isLocal => source == DataSource.local;
  String get dataSourceLabel => switch (source) {
    DataSource.local => 'JSON local · assets/data',
    DataSource.supabase => _supabaseUrl,
    DataSource.api => apiBaseUrl,
  };

  AcademicApi _apiClient() => _api ??= AcademicApi();
  SupabaseDataStore _newSupabaseStore({Future<String?> Function()? token}) =>
      SupabaseDataStore(
        url: _supabaseUrl,
        key: _supabaseKey,
        client: _supabaseClientFactory(),
        token: token,
      );

  CourseRepository _documentCourses(AcademicDataStore store) =>
      source == DataSource.local
      ? LocalCourseRepository(
          store,
          curricula: LocalCurriculumRepository(store),
          contents: LocalContentsRepository(store),
          schedules: LocalScheduleRepository(store),
        )
      : SupabaseCourseRepository(
          store,
          curricula: SupabaseCurriculumRepository(store),
          contents: SupabaseContentsRepository(store),
          schedules: SupabaseScheduleRepository(store),
        );

  void setApiBaseUrl(String url) {
    _api?.close();
    _api = _createApi(url);
  }

  AdminRepositories createAdminScope() {
    if (adminFactory != null) return adminFactory!();
    if (isLocal) {
      return AdminRepositories(
        auth: authFactory?.call() ?? LocalAuthRepository(),
        admin: LocalAdminRepository(),
        courses: courses,
        feedback: feedback,
        extraction: OfflineExtractionRepository(),
        migrations: UnavailableMigrationRepository(),
      );
    }
    final auth =
        authFactory?.call() ??
        SupabaseAuthRepository(url: _supabaseUrl, key: _supabaseKey);
    if (source == DataSource.supabase) {
      final store = _newSupabaseStore(token: auth.token);
      return AdminRepositories(
        auth: auth,
        admin: SupabaseAdminRepository(store),
        courses: _documentCourses(store),
        feedback: SupabaseFeedbackRepository(
          store,
          submissions: ApiFeedbackRepository(_apiClient),
        ),
        extraction: OfflineExtractionRepository(),
        migrations: UnavailableMigrationRepository(),
        onDispose: store.dispose,
      );
    }
    return AdminRepositories(
      auth: auth,
      admin: ApiAdminRepository(_apiClient, token: auth.token),
      courses: ApiCourseRepository(_apiClient, token: auth.token),
      feedback: ApiFeedbackRepository(_apiClient, token: auth.token),
      extraction: ApiExtractionRepository(_apiClient, token: auth.token),
      migrations: ApiMigrationRepository(_apiClient, token: auth.token),
    );
  }

  void dispose() {
    _api?.close();
    _publicSupabase?.dispose();
  }
}

class AdminRepositories {
  const AdminRepositories({
    required this.auth,
    required this.admin,
    required this.courses,
    required this.feedback,
    required this.extraction,
    required this.migrations,
    this.onDispose,
  });
  final AuthRepository auth;
  final AdminRepository admin;
  final CourseRepository courses;
  final FeedbackRepository feedback;
  final ExtractionRepository extraction;
  final MigrationRepository migrations;
  final void Function()? onDispose;
  void dispose() {
    auth.dispose();
    onDispose?.call();
  }
}
