import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'app/app_shell.dart';
import 'app/admin_route.dart';
import 'config/dependencies.dart';
import 'data/repositories/personal/personal_storage_repository.dart';
import 'core/app_state.dart';
import 'core/theme/app_theme.dart';
import 'features/academic/catalog/catalog_view.dart';
import 'features/academic/matrix/matrix_view.dart';
import 'features/academic/schedule/schedule_view.dart';
import 'features/calendar/calendar_view.dart';
import 'features/feedback/feedback_view.dart';
import 'features/home/home_view.dart';
import 'features/settings/settings_view.dart';

export 'app/academic_navigation.dart' show navigateAcademic, destinations;
export 'app/app_shell.dart' show AppShell;
export 'core/theme/app_theme.dart' show appTheme;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = setupDependencies();
  await dependencies.get<PersonalStorageRepository>().initialize();
  runApp(Bootstrap(dependencies: dependencies));
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key, this.dependencies});
  final AppDependencies? dependencies;
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late final AppDependencies _dependencies;
  late final AppState state;
  final initialLocation = kIsWeb
      ? (Uri.base.fragment.startsWith('/')
            ? Uri.base.fragment
            : Uri(
                path: Uri.base.path,
                query: Uri.base.hasQuery ? Uri.base.query : null,
              ).toString())
      : WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies ?? setupDependencies();
    state = _dependencies.state;
    load();
  }

  Future<void> load() async {
    await state.initialize();
    if (mounted) setState(() => ready = true);
  }

  @override
  void dispose() {
    _dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ready
      ? MyUfapeApp(state: state, initialLocation: initialLocation)
      : MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, _) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/my_ufape_logo_azul.png',
                    width: 100,
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Preparando o My UFAPE…'),
                ],
              ),
            ),
          ),
        );
}

class MyUfapeApp extends StatefulWidget {
  final AppState state;
  final String? initialLocation;
  const MyUfapeApp({super.key, required this.state, this.initialLocation});
  @override
  State<MyUfapeApp> createState() => _MyUfapeAppState();
}

class _MyUfapeAppState extends State<MyUfapeApp> {
  bool _readingRoute = false;
  bool _syncScheduled = false;
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_scheduleLocationSync);
    router.routeInformationProvider.addListener(_readLocation);
    WidgetsBinding.instance.addPostFrameCallback((_) => _readLocation());
  }

  Future<void> _readLocation() async {
    if (_readingRoute || !mounted) return;
    final uri = router.routeInformationProvider.value.uri;
    if (!['/schedule', '/matriz', '/disciplinas'].contains(uri.path)) return;
    _readingRoute = true;
    try {
      final state = widget.state;
      final id = uri.queryParameters['course'];
      if (id != null && id != state.selectedCourse?.id) {
        final course = state.courses.where((c) => c.id == id).firstOrNull;
        if (course == null) {
          router.go('/');
          return;
        }
        await state.selectCourse(course);
      }
      final semester = uri.queryParameters['semester'];
      if (semester != null && semester != state.selectedSemester) {
        await state.selectSemester(semester);
      }
      final profile = uri.queryParameters['profile'];
      if (profile != null &&
          profile != state.selectedProfile &&
          (profile == 'all' || state.profiles.any((p) => p.id == profile))) {
        await state.selectProfile(profile);
      }
    } finally {
      _readingRoute = false;
      _scheduleLocationSync();
    }
  }

  void _scheduleLocationSync() {
    if (_readingRoute || _syncScheduled || !mounted) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted || _readingRoute) return;
      final uri = router.routeInformationProvider.value.uri;
      final state = widget.state;
      if (!['/schedule', '/matriz', '/disciplinas'].contains(uri.path) ||
          state.selectedCourse == null ||
          state.loading) {
        return;
      }
      final next = Uri(
        path: uri.path,
        queryParameters: {
          'course': state.selectedCourse!.id,
          'semester': state.selectedSemester,
          'profile': state.selectedProfile,
        },
      );
      if (next.toString() != uri.toString()) router.replace(next.toString());
    });
  }

  late final router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      ShellRoute(
        builder: (context, route, child) => ListenableBuilder(
          listenable: Listenable.merge([widget.state, widget.state.settings]),
          builder: (context, _) => AppShell(
            state: widget.state,
            location: route.uri.path,
            child: child,
          ),
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, route) => HomeView(
              viewModel: widget.state.home,
              onFeedback: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    FeedbackView(viewModel: widget.state.feedback, view: '/'),
              ),
            ),
          ),
          GoRoute(
            path: '/schedule',
            builder: (context, route) =>
                ScheduleView(viewModel: widget.state.timetable),
          ),
          GoRoute(
            path: '/matriz',
            builder: (context, route) =>
                MatrixView(viewModel: widget.state.matrix),
          ),
          GoRoute(
            path: '/disciplinas',
            builder: (context, route) =>
                CatalogView(viewModel: widget.state.catalog),
          ),
          GoRoute(
            path: '/calendario',
            builder: (context, route) =>
                CalendarView(viewModel: widget.state.calendar),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, route) => AdminRoute(state: widget.state),
          ),
          GoRoute(
            path: '/configuracoes',
            builder: (context, route) =>
                SettingsView(viewModel: widget.state.settings),
          ),
        ],
      ),
    ],
    errorBuilder: (context, route) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Voltar ao início'),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    widget.state.removeListener(_scheduleLocationSync);
    router.routeInformationProvider.removeListener(_readLocation);
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state.settings,
    builder: (context, _) => MaterialApp.router(
      title: 'My UFAPE',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: widget.state.themeMode,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
    ),
  );
}
