import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_state.dart';
import '../features/admin/admin_navigation_guard.dart';

const destinations = [
  ('/', Icons.home_outlined, 'Início'),
  ('/schedule', Icons.calendar_view_week_outlined, 'Horário'),
  ('/matriz', Icons.account_tree_outlined, 'Matriz'),
  ('/disciplinas', Icons.menu_book_outlined, 'Disciplinas'),
  ('/calendario', Icons.event_outlined, 'Calendário'),
  ('/configuracoes', Icons.settings_outlined, 'Preferências'),
  ('/admin', Icons.admin_panel_settings_outlined, 'Administração'),
];
Future<void> navigateAcademic(
  BuildContext context,
  AppState state,
  String path,
) async {
  if (!await AdminNavigationGuard.allowLeave() || !context.mounted) return;
  final course = state.selectedCourse;
  context.go(
    Uri(
      path: path,
      queryParameters:
          course != null &&
              ['/schedule', '/matriz', '/disciplinas'].contains(path)
          ? {
              'course': course.id,
              'semester': state.selectedSemester,
              'profile': state.selectedProfile,
            }
          : null,
    ).toString(),
  );
}
