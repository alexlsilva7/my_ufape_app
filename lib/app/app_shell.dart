import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_state.dart';
import '../features/feedback/feedback_dialog.dart';
import 'academic_navigation.dart';

class AppShell extends StatelessWidget {
  final AppState state;
  final String location;
  final Widget child;
  const AppShell({
    super.key,
    required this.state,
    required this.location,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (location == '/') return Scaffold(body: SafeArea(child: child));
    final academic = [
      '/schedule',
      '/matriz',
      '/disciplinas',
    ].contains(location);
    return Scaffold(
      appBar: _header(context),
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            if (state.offline)
              Material(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Consulta offline · cópia local de referência. Os dados publicados podem ter mudado.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Atualizar dados',
                        onPressed: () => state.refresh(),
                        icon: const Icon(Icons.refresh, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            if (state.error != null && !state.offline)
              MaterialBanner(
                content: Text(state.error!),
                actions: [
                  TextButton(
                    onPressed: () => state.refresh(),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            Expanded(
              child: academic && state.selectedCourse == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 16,
                        children: [
                          const Icon(Icons.school_outlined, size: 48),
                          const Text('Selecione um curso para começar.'),
                          FilledButton(
                            onPressed: () => context.go('/'),
                            child: const Text('Escolher curso'),
                          ),
                        ],
                      ),
                    )
                  : child,
            ),
          ],
        ),
      ),
    );
  }

  AppBar _header(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final muted = dark ? const Color(0xff94a3b8) : const Color(0xff64748b);
    final title = switch (location) {
      '/schedule' => 'Grade Horária',
      '/matriz' => 'Matriz Curricular',
      '/disciplinas' => 'Catálogo de Disciplinas',
      '/calendario' => 'Calendário acadêmico',
      '/configuracoes' => 'Preferências',
      '/admin' => 'Administração',
      _ => 'My UFAPE',
    };
    final semesters = <String>{
      state.selectedSemester,
      ...?state.selectedCourse?.visibleSemesters,
    };
    final catalogDate = location == '/disciplinas'
        ? DateTime.tryParse(
            textOf(asMap(state.courseDetails['curriculum'])['export_date']),
          )?.toLocal()
        : null;
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    Widget actionIcon(IconData icon, {Color? color}) {
      final child = Icon(icon, size: 18, color: color);
      if (location != '/disciplinas') return child;
      return Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark ? const Color(0xff1e293b) : const Color(0xfff8fafc),
          border: Border.all(
            color: dark ? const Color(0xff334155) : const Color(0xffe2e8f0),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );
    }

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: mobile || location == '/disciplinas' ? 64 : 72,
      bottom: catalogDate == null
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(
                MediaQuery.textScalerOf(context).scale(20) + 4,
              ),
              child: Center(
                child: Container(
                  width: 1280,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Dados atualizados em ${twoDigits(catalogDate.day)}/${twoDigits(catalogDate.month)}/${catalogDate.year}, ${twoDigits(catalogDate.hour)}:${twoDigits(catalogDate.minute)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
              ),
            ),
      shape: Border(
        bottom: BorderSide(
          color: dark ? const Color(0xff1e293b) : const Color(0xffe2e8f0),
        ),
      ),
      title: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: location == '/disciplinas' && !mobile ? 24 : 8,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Voltar ao início',
                  onPressed: () => navigateAcademic(context, state, '/'),
                  icon: Icon(Icons.arrow_back, size: 19, color: muted),
                ),
                Image.asset(
                  dark
                      ? 'assets/images/my_ufape_logo_azul.png'
                      : 'assets/images/my_ufape_logo.png',
                  width: 30,
                  height: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mobile ? title : 'My UFAPE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: mobile ? 12 : 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        mobile
                            ? state.selectedCourse?.shortName ?? title
                            : '$title${state.selectedCourse == null ? '' : ' • ${state.selectedCourse!.name}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: location == '/disciplinas' ? 12 : 11,
                          fontWeight: FontWeight.w400,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (location == '/schedule')
                  Container(
                    width: 96,
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xff1e293b)
                          : const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: dark
                            ? const Color(0xff334155)
                            : const Color(0xffe2e8f0),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: state.selectedSemester,
                        isExpanded: true,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                        icon: const Icon(Icons.expand_more, size: 16),
                        items: [
                          for (final semester in semesters)
                            DropdownMenuItem(
                              value: semester,
                              child: Text(semester),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) state.selectSemester(value);
                        },
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Alternar tema: ${state.themeMode.name}',
                  onPressed: state.cycleTheme,
                  icon: actionIcon(
                    switch (state.themeMode) {
                      ThemeMode.system => Icons.brightness_auto_outlined,
                      ThemeMode.light => Icons.light_mode_outlined,
                      ThemeMode.dark => Icons.dark_mode_outlined,
                    },
                    color: location == '/disciplinas'
                        ? const Color(0xfff59e0b)
                        : null,
                  ),
                ),
                PopupMenuButton<String>(
                  key: const ValueKey('top-navigation'),
                  tooltip: 'Navegação e opções',
                  icon: actionIcon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'feedback') {
                      showDialog<void>(
                        context: context,
                        builder: (_) =>
                            FeedbackDialog(state: state, view: location),
                      );
                    } else {
                      navigateAcademic(context, state, value);
                    }
                  },
                  itemBuilder: (context) => [
                    for (final destination in destinations)
                      PopupMenuItem(
                        value: destination.$1,
                        child: Row(
                          spacing: 12,
                          children: [
                            Icon(destination.$2, size: 18),
                            Text(destination.$3),
                            if (location == destination.$1)
                              const Icon(Icons.check, size: 16),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'feedback',
                      child: Text('Enviar feedback'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
