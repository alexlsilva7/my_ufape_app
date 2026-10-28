import 'package:flutter/material.dart';

import '../../app/app_repositories.dart';
import '../../core/academic_context.dart';
import '../../core/data_source.dart';
import '../../data/repositories/personal/personal_storage_repository.dart';
import '../../data/repositories/personal/backup_repository.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(
    this.repositories,
    this.context,
    this.storage,
    this.backups,
  );
  final AppRepositories repositories;
  final AcademicContext context;
  final PersonalStorageRepository storage;
  final BackupRepository backups;
  bool _disposed = false;
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isLocal => repositories.isLocal;
  bool get canEditServer => repositories.source == DataSource.api;
  String get apiBaseUrl => repositories.apiBaseUrl;
  String get dataSourceLabel => repositories.dataSourceLabel;

  void restore() {
    if (_disposed) return;
    _themeMode = switch (storage.read('themePreference')) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    notifyListeners();
  }

  Future<void> cycleTheme() => setThemeMode(switch (_themeMode) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  });
  Future<void> setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    final saving = storage.write('themePreference', mode.name);
    notifyListeners();
    return saving;
  }

  Future<void> setApiBaseUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('Informe um endereço HTTP ou HTTPS válido.');
    }
    repositories.setApiBaseUrl(url.trim());
    await storage.write('flutter_api_base_url', url.trim());
    await refresh();
    await storage.flush();
  }

  Future<void> refresh() => context.refresh();
  String exportBackup() => backups.export();
  Future<bool> importBackup(String value) async {
    if (!await backups.import(value, context.courses)) return false;
    if (_disposed) return false;
    restore();
    context.selectedSemester =
        storage.read('selectedSemester') ?? context.selectedSemester;
    final course = context.courses
        .where((e) => e.id == storage.read('selectedCourse'))
        .firstOrNull;
    await context.selectCourse(course);
    await storage.flush();
    return true;
  }

  Future<void> initialize() async {
    await storage.initialize();
    if (_disposed) return;
    final configured = storage.read('flutter_api_base_url');
    if (repositories.source == DataSource.api &&
        configured != null &&
        configured.isNotEmpty) {
      repositories.setApiBaseUrl(configured);
    }
    restore();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
