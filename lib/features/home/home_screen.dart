import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/widgets/app_background.dart';
import '../../app/academic_navigation.dart' show navigateAcademic;
import '../feedback/feedback_dialog.dart';
import '../academic/academic_motion.dart';

const _indigo = Color(0xff4f46e5);
const _emerald = Color(0xff059669);
const _violet = Color(0xff7c3aed);

class HomeScreen extends StatelessWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      final ink = dark ? const Color(0xfff1f5f9) : const Color(0xff1e293b);
      final muted = dark ? const Color(0xff94a3b8) : const Color(0xff64748b);
      return Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme
              .apply(fontFamily: 'Inter', bodyColor: ink, displayColor: ink),
        ),
        child: DefaultTextStyle(
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: ink),
          child: AppBackground(
            child: LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
                key: const PageStorageKey('home-scroll'),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport.maxHeight),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            viewport.maxWidth < 600 ? 16 : 32,
                            viewport.maxWidth < 600 || viewport.maxHeight < 500
                                ? 80
                                : 64,
                            viewport.maxWidth < 600 ? 16 : 32,
                            viewport.maxWidth < 600 ? 40 : 96,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 896),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _hero(
                                  dark,
                                  muted,
                                  viewport.maxWidth,
                                  compact:
                                      viewport.maxWidth < 600 ||
                                      viewport.maxHeight < 500,
                                ),
                                SizedBox(
                                  height:
                                      viewport.maxWidth < 600 ||
                                          viewport.maxHeight < 500
                                      ? 24
                                      : 48,
                                ),
                                if (state.loading)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 16),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                    ),
                                  ),
                                if (state.offline || state.error != null)
                                  _status(context, muted),
                                _coursePanel(context, muted),
                                SizedBox(
                                  height: viewport.maxWidth < 600 ? 20 : 32,
                                ),
                                _calendar(context, muted),
                                SizedBox(
                                  height: viewport.maxWidth < 600 ? 28 : 48,
                                ),
                                _footer(context, muted),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _utilities(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _hero(bool dark, Color muted, double width, {bool compact = false}) =>
      Column(
        spacing: compact ? 12 : 16,
        children: [
          Image.asset(
            dark
                ? 'assets/images/my_ufape_logo_azul.png'
                : 'assets/images/my_ufape_logo.png',
            width: compact ? 64 : 96,
            height: compact ? 64 : 96,
            fit: BoxFit.contain,
            semanticLabel: 'My UFAPE Logo',
          ),
          Text(
            'My UFAPE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: !compact && width >= 768 ? 48 : 28,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              color: dark ? const Color(0xfff8fafc) : const Color(0xff0f172a),
            ),
          ),
          Text(
            'Seu assistente acadêmico para o planejamento e acompanhamento curricular',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 14 : 18,
              height: 1.55,
              color: muted,
            ),
          ),
        ],
      );

  Widget _utilities(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      _utility(
        context,
        Icons.settings_outlined,
        'Backups e preferências',
        () => navigateAcademic(context, state, '/configuracoes'),
      ),
      _utility(
        context,
        switch (state.themeMode) {
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
          ThemeMode.system => Icons.desktop_windows_outlined,
        },
        'Alternar tema: ${state.themeMode.name}',
        state.cycleTheme,
      ),
      _utility(
        context,
        Icons.admin_panel_settings_outlined,
        'Administração',
        () => navigateAcademic(context, state, '/admin'),
      ),
    ],
  );

  Widget _utility(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback tap,
  ) => SizedBox(
    width: 48,
    height: 48,
    child: Material(
      color: _surface(context),
      shape: CircleBorder(side: BorderSide(color: _border(context))),
      child: IconButton(
        tooltip: label,
        onPressed: tap,
        icon: Icon(icon, size: 18, color: const Color(0xff64748b)),
      ),
    ),
  );

  Widget _status(BuildContext context, Color muted) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Icon(
          state.offline ? Icons.cloud_off_outlined : Icons.error_outline,
          size: 18,
          color: muted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            state.offline
                ? 'Consulta offline · cópia local de referência. Os dados publicados podem ter mudado.'
                : state.error!,
            style: TextStyle(fontSize: 12, height: 1.5, color: muted),
          ),
        ),
        IconButton(
          tooltip: 'Atualizar dados',
          onPressed: state.refresh,
          icon: const Icon(Icons.refresh, size: 18),
        ),
      ],
    ),
  );

  Widget _coursePanel(BuildContext context, Color muted) => LayoutBuilder(
    builder: (context, constraints) {
      final course = state.selectedCourse;
      final padding = constraints.maxWidth >= 640 ? 32.0 : 16.0;
      return _panel(
        context,
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flex(
              mainAxisSize: MainAxisSize.min,
              direction: MediaQuery.textScalerOf(context).scale(14) > 21
                  ? Axis.vertical
                  : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                const _IconTile(kind: _LineIcon.book, color: _indigo, size: 40),
                Flexible(
                  flex: 1,
                  fit: FlexFit.loose,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        course?.name ?? 'Selecione seu curso',
                        style: TextStyle(
                          fontSize: constraints.maxWidth < 600 ? 18 : 20,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (course == null)
                        Text(
                          'Escolha seu curso para ver o horário letivo e matriz.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: muted,
                          ),
                        )
                      else
                        _textLink(
                          'Alterar curso',
                          () => state.selectCourse(null),
                          color: const Color(0xff6366f1),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(
              height: constraints.maxWidth < 600
                  ? 16
                  : course == null
                  ? 24
                  : 32,
            ),
            if (course == null)
              _courseChoices(context, muted)
            else ...[
              _features(context, muted),
            ],
          ],
        ),
      );
    },
  );

  Widget _courseChoices(BuildContext context, Color muted) => LayoutBuilder(
    builder: (context, constraints) {
      final courses = state.courses.where((c) => !c.hidden).toList();
      final columns =
          constraints.maxWidth >= 560 &&
              MediaQuery.textScalerOf(context).scale(14) <= 21
          ? 2
          : 1;
      if (courses.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.loading
                ? 'Carregando cursos…'
                : 'Nenhum curso disponível no momento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
        );
      }
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final course in courses)
            SizedBox(
              width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
              child: _HomeButton(
                accent: _indigo,
                radius: 12,
                onTap: () => state.selectCourse(course),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Flex(
                    mainAxisSize: MainAxisSize.min,
                    direction: MediaQuery.textScalerOf(context).scale(14) > 21
                        ? Axis.vertical
                        : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          course.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (constraints.maxWidth * .28).clamp(48, 100),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: muted.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            course.shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _features(BuildContext context, Color muted) {
    final course = state.selectedCourse!;
    final features = [
      if (course.hasSchedule && course.showSchedule)
        (
          _LineIcon.calendar,
          _indigo,
          'Horário Letivo',
          'Monte sua grade horária personalizada com as turmas ofertadas este semestre.',
          'Montar Grade',
          '/schedule',
        ),
      if (course.hasCurriculum && course.showDisciplines)
        (
          _LineIcon.book,
          _emerald,
          'Disciplinas',
          'Consulte a lista completa de disciplinas, ementas e pré-requisitos do curso.',
          'Consultar Catálogo',
          '/disciplinas',
        ),
      if (course.hasCurriculum && course.showMatriz)
        (
          _LineIcon.layers,
          _violet,
          'Matriz Curricular',
          'Visualize a estrutura curricular de forma organizada por períodos letivos.',
          'Visualizar Grade',
          '/matriz',
        ),
    ];
    if (features.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nenhum módulo está disponível para este curso no momento.',
          style: TextStyle(color: muted),
        ),
      );
    }
    Widget card(int i, {bool compact = false}) {
      final (icon, color, title, description, action, path) = features[i];
      if (compact) {
        return _compactNavigationCard(
          context,
          muted,
          icon: icon,
          color: color,
          title: title,
          description: description,
          action: action,
          path: path,
        );
      }
      final foreground = Theme.of(context).brightness == Brightness.dark
          ? Color.lerp(color, Colors.white, .4)!
          : color;
      return _HomeButton(
        accent: color,
        onTap: () => navigateAcademic(context, state, path),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 256),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconTile(kind: icon, color: color),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.55,
                        letterSpacing: -.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.625,
                        color: muted,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    spacing: 4,
                    children: [
                      Flexible(
                        child: Text(
                          action,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: foreground,
                          ),
                        ),
                      ),
                      _StrokeIcon(_LineIcon.arrow, color: foreground, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 24,
              children: [
                for (var i = 0; i < features.length; i++)
                  Expanded(child: card(i)),
              ],
            ),
          );
        }
        return Column(
          spacing: 12,
          children: [
            for (var i = 0; i < features.length; i++)
              SizedBox(width: double.infinity, child: card(i, compact: true)),
          ],
        );
      },
    );
  }

  Widget _compactNavigationCard(
    BuildContext context,
    Color muted, {
    required _LineIcon icon,
    required Color color,
    required String title,
    required String description,
    required String action,
    required String path,
  }) {
    final foreground = Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(color, Colors.white, .4)!
        : color;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          description,
          style: TextStyle(fontSize: 13, height: 1.5, color: muted),
        ),
        Row(
          spacing: 8,
          children: [
            Flexible(
              child: Text(
                action,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
            _StrokeIcon(_LineIcon.arrow, color: foreground, size: 16),
          ],
        ),
      ],
    );
    return _HomeButton(
      key: ValueKey('home-link-$path'),
      accent: color,
      onTap: () => navigateAcademic(context, state, path),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MediaQuery.textScalerOf(context).scale(14) > 21
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  _IconTile(kind: icon, color: color, size: 40),
                  body,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  _IconTile(kind: icon, color: color, size: 40),
                  Expanded(child: body),
                ],
              ),
      ),
    );
  }

  Widget _calendar(BuildContext context, Color muted) => LayoutBuilder(
    builder: (context, constraints) =>
        constraints.maxWidth < 600 ||
            MediaQuery.textScalerOf(context).scale(14) > 21
        ? _compactNavigationCard(
            context,
            muted,
            icon: _LineIcon.calendar,
            color: _indigo,
            title: 'Calendário acadêmico',
            description: 'Consulte o mês atual e amplie as páginas do calendário oficial.',
            action: 'Abrir calendário',
            path: '/calendario',
          )
        : _desktopCalendar(context, muted),
  );

  Widget _desktopCalendar(BuildContext context, Color muted) => _HomeButton(
    accent: _indigo,
    border: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff312e81)
        : const Color(0xffc7d2fe),
    onTap: () => navigateAcademic(context, state, '/calendario'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        spacing: 16,
        children: [
          const _IconTile(kind: _LineIcon.calendar, color: _indigo),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                const Text(
                  'Calendário acadêmico',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.55,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Consulte o mês atual e amplie as páginas do calendário oficial.',
                  style: TextStyle(fontSize: 14, height: 1.5, color: muted),
                ),
              ],
            ),
          ),
          const _StrokeIcon(
            _LineIcon.arrow,
            color: Color(0xff6366f1),
            size: 20,
          ),
        ],
      ),
    ),
  );

  Widget _footer(BuildContext context, Color muted) => Container(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: _border(context))),
    ),
    padding: const EdgeInsets.only(top: 24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 640 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21;
        final message = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            const Text(
              'Ajude a melhorar o My UFAPE',
              style: TextStyle(fontWeight: FontWeight.w600, height: 1.5),
            ),
            Text(
              'Envie sugestões ou relate problemas. Não é necessário criar uma conta.',
              style: TextStyle(fontSize: 12, height: 1.625, color: muted),
            ),
          ],
        );
        final feedback = FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _indigo,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => FeedbackDialog(state: state, view: '/'),
          ),
          icon: const _StrokeIcon(
            _LineIcon.chat,
            color: Colors.white,
            size: 16,
          ),
          label: const Text('Enviar feedback'),
        );
        final author = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Desenvolvido por ',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            _textLink(
              'Alex Lopes',
              () => _open('https://github.com/alexlsilva7'),
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xffe2e8f0)
                  : const Color(0xff334155),
              size: 12,
              underline: true,
            ),
          ],
        );
        final repo = Semantics(
          link: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () =>
                _open('https://github.com/alexlsilva7/my_ufape_app'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  _StrokeIcon(_LineIcon.github, color: muted, size: 16),
                  Flexible(
                    child: Text(
                      'Repositório no GitHub',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                  _StrokeIcon(_LineIcon.external, color: muted, size: 12),
                ],
              ),
            ),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide)
              Row(
                spacing: 24,
                children: [
                  Expanded(child: message),
                  feedback,
                ],
              )
            else ...[
              message,
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: feedback),
            ],
            const SizedBox(height: 20),
            if (wide)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [author, repo],
              )
            else ...[
              author,
              const SizedBox(height: 8),
              repo,
            ],
          ],
        );
      },
    ),
  );

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

Color _surface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff0f172a)
    : Colors.white;
Color _border(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff1e293b)
    : const Color(0xffe2e8f0);

Widget _textLink(
  String text,
  VoidCallback tap, {
  Color color = _indigo,
  double size = 14,
  bool underline = false,
}) => Semantics(
  button: true,
  child: InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(3),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: 1,
        child: Text(
          text,
          style: TextStyle(
            fontSize: size,
            height: 1.5,
            color: color,
            decoration: underline ? TextDecoration.underline : null,
            decorationColor: color,
          ),
        ),
      ),
    ),
  ),
);

Widget _panel(
  BuildContext context, {
  required Widget child,
  required EdgeInsets padding,
}) => Container(
  decoration: BoxDecoration(
    color: _surface(context),
    border: Border.all(color: _border(context)),
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [
      BoxShadow(color: Color(0x0d0f172a), blurRadius: 2, offset: Offset(0, 1)),
    ],
  ),
  padding: padding,
  child: child,
);

class _HomeButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accent;
  final Color? border;
  final double radius;
  const _HomeButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.accent,
    this.border,
    this.radius = 16,
  });
  @override
  State<_HomeButton> createState() => _HomeButtonState();
}

class _HomeButtonState extends State<_HomeButton> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: academicMotionDuration(context, 200),
        transform: Matrix4.translationValues(
          0,
          hover && academicMotionDuration(context, 200) != Duration.zero
              ? -3
              : 0,
          0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff0f172a)
                  .withValues(alpha: hover ? .10 : .08),
              blurRadius: hover ? 12 : 2,
              offset: Offset(0, hover ? 5 : 1),
            ),
          ],
        ),
        child: Material(
          color: _surface(context),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.radius),
            side: BorderSide(
              color: hover
                  ? widget.accent.withValues(alpha: .5)
                  : widget.border ?? _border(context),
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            hoverColor: widget.accent.withValues(alpha: .035),
            splashColor: widget.accent.withValues(alpha: .1),
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}

class _IconTile extends StatelessWidget {
  final _LineIcon kind;
  final Color color;
  final double size;
  const _IconTile({required this.kind, required this.color, this.size = 48});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = color == _emerald
        ? const Color(0xffecfdf5)
        : color == _violet
        ? const Color(0xfff5f3ff)
        : const Color(0xffeef2ff);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? color.withValues(alpha: .14) : background,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: _StrokeIcon(
        kind,
        color: dark ? Color.lerp(color, Colors.white, .35)! : color,
      ),
    );
  }
}

enum _LineIcon { book, calendar, layers, arrow, chat, github, external }

class _StrokeIcon extends StatelessWidget {
  final _LineIcon kind;
  final Color color;
  final double size;
  const _StrokeIcon(this.kind, {required this.color, this.size = 24});
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _StrokePainter(kind, color)),
  );
}

// Stroke geometry follows the site's Lucide icons.
class _StrokePainter extends CustomPainter {
  final _LineIcon kind;
  final Color color;
  const _StrokePainter(this.kind, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (kind) {
      case _LineIcon.book:
        path.moveTo(12, 7);
        path.cubicTo(9, 3, 4, 3, 2, 4);
        path.lineTo(2, 20);
        path.cubicTo(5, 19, 9, 19, 12, 22);
        path.cubicTo(15, 19, 19, 19, 22, 20);
        path.lineTo(22, 4);
        path.cubicTo(19, 3, 15, 3, 12, 7);
        path.lineTo(12, 22);
      case _LineIcon.calendar:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 5, 18, 17),
            const Radius.circular(2),
          ),
          pen,
        );
        path.moveTo(16, 3);
        path.lineTo(16, 7);
        path.moveTo(8, 3);
        path.lineTo(8, 7);
        path.moveTo(3, 11);
        path.lineTo(21, 11);
        for (final y in [15.0, 18.0]) {
          for (final x in [8.0, 12.0, 16.0]) {
            canvas.drawCircle(Offset(x, y), .75, Paint()..color = color);
          }
        }
      case _LineIcon.layers:
        path.moveTo(12, 2);
        path.lineTo(22, 7);
        path.lineTo(12, 12);
        path.lineTo(2, 7);
        path.close();
        path.moveTo(2, 12);
        path.lineTo(12, 17);
        path.lineTo(22, 12);
        path.moveTo(2, 17);
        path.lineTo(12, 22);
        path.lineTo(22, 17);
      case _LineIcon.arrow:
        path.moveTo(5, 12);
        path.lineTo(19, 12);
        path.moveTo(12, 5);
        path.lineTo(19, 12);
        path.lineTo(12, 19);
      case _LineIcon.chat:
        path.moveTo(21, 15);
        path.quadraticBezierTo(21, 18, 18, 18);
        path.lineTo(7, 18);
        path.lineTo(3, 22);
        path.lineTo(3, 6);
        path.quadraticBezierTo(3, 3, 6, 3);
        path.lineTo(18, 3);
        path.quadraticBezierTo(21, 3, 21, 6);
        path.close();
      case _LineIcon.external:
        path.moveTo(15, 3);
        path.lineTo(21, 3);
        path.lineTo(21, 9);
        path.moveTo(10, 14);
        path.lineTo(21, 3);
        path.moveTo(21, 14);
        path.lineTo(21, 19);
        path.quadraticBezierTo(21, 21, 19, 21);
        path.lineTo(5, 21);
        path.quadraticBezierTo(3, 21, 3, 19);
        path.lineTo(3, 5);
        path.quadraticBezierTo(3, 3, 5, 3);
        path.lineTo(10, 3);
      case _LineIcon.github:
        path.moveTo(9, 19);
        path.cubicTo(4, 21, 4, 16, 2, 16);
        path.moveTo(9, 22);
        path.lineTo(9, 18);
        path.cubicTo(9, 17, 9.2, 16, 10, 16);
        path.cubicTo(4, 15.5, 3, 13, 3, 10);
        path.cubicTo(3, 8, 4, 7, 4, 7);
        path.cubicTo(3.5, 5, 4, 3, 4, 3);
        path.cubicTo(6, 3, 8, 4, 8, 4);
        path.cubicTo(11, 3, 13, 3, 16, 4);
        path.cubicTo(16, 4, 18, 3, 20, 3);
        path.cubicTo(20, 3, 20.5, 5, 20, 7);
        path.cubicTo(20, 7, 21, 8, 21, 10);
        path.cubicTo(21, 13, 20, 15.5, 14, 16);
        path.cubicTo(15, 17, 15, 18, 15, 19);
        path.lineTo(15, 22);
    }
    canvas.drawPath(path, pen);
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) =>
      kind != oldDelegate.kind || color != oldDelegate.color;
}
