import 'package:flutter/material.dart';

import '../../core/academic_context.dart';
import '../../core/models.dart';
import '../settings/settings_view_model.dart';

/// Presentation state for the home feature, composed from shared academic
/// selection and app settings without exposing the application facade.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this.context, this.settings) {
    context.addListener(_sourceChanged);
    settings.addListener(_sourceChanged);
  }

  final AcademicContext context;
  final SettingsViewModel settings;
  bool _disposed = false;

  List<CourseMeta> get courses => context.courses;
  CourseMeta? get selectedCourse => context.selectedCourse;
  bool get loading => context.loading;
  bool get offline => context.offline;
  String? get error => context.error;
  ThemeMode get themeMode => settings.themeMode;

  Future<void> refresh() => context.refresh();
  Future<void> selectCourse(CourseMeta? course) => context.selectCourse(course);
  Future<void> cycleTheme() => settings.cycleTheme();

  void _sourceChanged() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    context.removeListener(_sourceChanged);
    settings.removeListener(_sourceChanged);
    super.dispose();
  }
}
