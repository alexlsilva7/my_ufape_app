import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'app/app_shell.dart';
import 'app/app_repositories.dart';
import 'core/app_state.dart';
import 'core/theme/app_theme.dart';
import 'features/academic/catalog_screen.dart';
import 'features/academic/matrix_screen.dart';
import 'features/academic/schedule_screen.dart';
import 'features/admin/admin_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';

export 'app/academic_navigation.dart' show navigateAcademic, destinations;
export 'app/app_shell.dart' show AppShell;
export 'core/theme/app_theme.dart' show appTheme;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  final state = AppState(repositories: AppRepositories());
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
    load();
  }

  Future<void> load() async {
    await state.initialize();
    if (mounted) setState(() => ready = true);
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ready
      ? MyUfapeApp(state: state, initialLocation: initialLocation)
      : MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
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
          listenable: widget.state,
          builder: (context, _) => AppShell(
            state: widget.state,
            location: route.uri.path,
            child: child,
          ),
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, route) => HomeScreen(state: widget.state),
          ),
          GoRoute(
            path: '/schedule',
            builder: (context, route) => ScheduleScreen(state: widget.state),
          ),
          GoRoute(
            path: '/matriz',
            builder: (context, route) => MatrixScreen(state: widget.state),
          ),
          GoRoute(
            path: '/disciplinas',
            builder: (context, route) => CatalogScreen(state: widget.state),
          ),
          GoRoute(
            path: '/calendario',
            builder: (context, route) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, route) => AdminScreen(state: widget.state),
          ),
          GoRoute(
            path: '/configuracoes',
            builder: (context, route) => SettingsScreen(state: widget.state),
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
    listenable: widget.state,
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
