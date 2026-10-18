import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_state.dart';
import '../../app/app_repositories.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/extraction_repository.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../domain/repositories/migration_repository.dart';
import '../../services/files.dart';
import 'admin_data.dart';
import 'admin_navigation_guard.dart';

export 'admin_navigation_guard.dart' show AdminNavigationGuard;

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.state});
  final AppState state;
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminRepositories _repositories;
  AuthRepository get _session => _repositories.auth;
  final _email = TextEditingController(), _password = TextEditingController();
  final _name = TextEditingController(),
      _short = TextEditingController(),
      _idInput = TextEditingController();
  final _semester = TextEditingController(), _search = TextEditingController();
  final _paste = TextEditingController(),
      _sourceText = TextEditingController(),
      _model = TextEditingController();
  final _resume = TextEditingController();
  Json? _config;
  bool _initializing = true,
      _authorized = false,
      _busy = false,
      _creating = false;
  String _message = '',
      _section = 'dashboard',
      _id = '',
      _profile = '',
      _period = '';
  List<Json> _courses = [], _schedule = [];
  Json _course = {}, _curriculum = {}, _baselines = {};
  String _importTarget = 'curriculum', _extractMode = 'tree';
  String _resultMode = 'tree';
  Json _pipeline = {'concurrency': 1, 'models': <String, dynamic>{}};
  final List<Json> _files = [];
  Json? _snapshot, _extracted;
  Timer? _monitor;
  bool _extracting = false, _polling = false;
  bool _feedbackDirty = false, _feedbackSaving = false;
  String _monitorError = '';
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _repositories = widget.state.repositories.createAdminScope();
    AdminNavigationGuard.check = _canLeave;
    _initialize();
  }

  @override
  void dispose() {
    AdminNavigationGuard.check = null;
    _monitor?.cancel();
    _repositories.dispose();
    for (final controller in [
      _email,
      _password,
      _name,
      _short,
      _idInput,
      _semester,
      _search,
      _paste,
      _sourceText,
      _model,
      _resume,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _config = await _repositories.admin.configuration();
      if (_config!['authRequired'] == false) {
        _authorized = true;
        await _reloadCourses();
      }
    } catch (error) {
      _message = '$error';
    }
    if (mounted) setState(() => _initializing = false);
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await action();
      if (success != null && mounted) _message = success;
    } catch (error) {
      _message = '$error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() => _run(() async {
    await _session.signIn(_email.text, _password.text);
    try {
      await _repositories.admin.validateSession();
      _password.clear();
      _authorized = true;
      await _reloadCourses();
    } catch (_) {
      _authorized = false;
      await _session.signOut();
      rethrow;
    }
  });
  Future<void> _reloadCourses() async {
    final result = await _repositories.courses.list();
    _courses = records(result['courses']);
    if (_courses.isNotEmpty) {
      final preferredId = _id.isNotEmpty
          ? _id
          : widget.state.selectedCourse?.id;
      await _loadCourse(
        _courses.any((row) => row['id'] == preferredId)
            ? preferredId!
            : '${_courses.first['id']}',
      );
    } else {
      _newCourse();
    }
  }

  Future<void> _loadCourse(String id, {String? semester}) async {
    final version = ++_loadVersion;
    final data = object(
      await _repositories.courses.get(
        id,
        semester: semester,
        strict: semester != null,
      ),
    );
    if (!mounted || version != _loadVersion) return;
    // Build the complete next draft before replacing the current one. A failed
    // response or normalization must not make a half-loaded course look edited.
    final nextCourse = object(data['course']);
    final nextCurriculum = normalizeCurriculum(data['curriculum']);
    final nextSchedule = records(data['schedule']);
    final nextSemester =
        semester ??
        '${data['resolvedSemester'] ?? (nextCourse['visibleSemesters'] as List? ?? []).firstOrNull ?? (nextCourse['semesters'] as List? ?? []).lastOrNull ?? ''}';
    nextCourse['visibleSemesters'] ??= cloneJson(nextCourse['semesters'] ?? []);
    _creating = false;
    _id = id;
    _course = nextCourse;
    _name.text = '${_course['name'] ?? ''}';
    _short.text = '${_course['shortName'] ?? ''}';
    _idInput.text = id;
    _curriculum = nextCurriculum;
    _schedule = nextSchedule;
    _semester.text = nextSemester;
    _profile = '';
    _period = '';
    _search.clear();
    _takeBaseline();
  }

  void _newCourse() {
    _creating = true;
    _id = '';
    _idInput.clear();
    _name.clear();
    _short.clear();
    _semester.clear();
    _course = {
      'hidden': false,
      'showSchedule': true,
      'showDisciplines': true,
      'showMatriz': true,
      'visibleSemesters': [],
      'semesters': [],
    };
    _curriculum = normalizeCurriculum({});
    _schedule = [];
    _section = 'settings';
    _takeBaseline();
  }

  Json _settings() => {
    'name': _name.text.trim(),
    'shortName': _short.text.trim(),
    for (final key in [
      'hidden',
      'showSchedule',
      'showDisciplines',
      'showMatriz',
      'visibleSemesters',
    ])
      key: _course[key],
  };
  void _takeBaseline() {
    _baselines = {
      'settings': jsonEncode(_settings()),
      'curriculum': jsonEncode(_curriculum),
      'schedule': jsonEncode({
        'semester': _semester.text,
        'schedule': _schedule,
      }),
    };
  }

  bool get _dirty =>
      _authorized &&
      _baselines.isNotEmpty &&
      (_baselines['settings'] != jsonEncode(_settings()) ||
          _baselines['curriculum'] != jsonEncode(_curriculum) ||
          _baselines['schedule'] !=
              jsonEncode({'semester': _semester.text, 'schedule': _schedule}));
  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _guard(Future<void> Function() action) async {
    if (_busy || _extracting || _feedbackSaving) return;
    if ((!_dirty && !_feedbackDirty) ||
        await _confirm(
          'Alterações não salvas',
          'Descartar o rascunho e as notas pendentes antes de continuar?',
        )) {
      if (mounted) {
        _feedbackDirty = false;
        await _run(action);
      }
    }
  }

  Future<bool> _canLeave() async {
    if (_extracting || _busy || _feedbackSaving) {
      setState(
        () => _message = 'Aguarde a operação em andamento antes de sair.',
      );
      return false;
    }
    if (!_authorized) return true;
    return (!_dirty && !_feedbackDirty) ||
        await _confirm(
          'Alterações não salvas',
          'Descartar o rascunho e as notas pendentes antes de sair?',
        );
  }

  Future<void> _navigate(String next) async {
    if (_feedbackSaving) return;
    if (_section != next &&
        _feedbackDirty &&
        !await _confirm(
          'Notas não salvas',
          'Descartar as alterações deste feedback?',
        )) {
      return;
    }
    if (mounted) {
      setState(() {
        if (_section != next) _feedbackDirty = false;
        _section = next;
      });
    }
  }

  Future<void> _save(String domain) => _run(
    () async {
      if (_name.text.trim().isEmpty || _short.text.trim().isEmpty) {
        throw const FormatException('Informe nome e sigla do curso.');
      }
      final id = _creating ? _idInput.text.trim() : _id;
      if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(id)) {
        throw const FormatException(
          'Identificador: letras minúsculas, números, hífen ou sublinhado.',
        );
      }
      if (domain != 'settings' && _creating) {
        throw const FormatException('Salve o novo curso primeiro.');
      }
      if (domain == 'settings') {
        if (_creating) {
          if (_courses.any((course) => course['id'] == id)) {
            throw const FormatException(
              'Já existe um curso com este identificador.',
            );
          }
          await _repositories.courses.save({
            'id': id,
            'name': _name.text.trim(),
            'shortName': _short.text.trim(),
          });
          _id = id;
          _creating = false;
        } else {
          await _repositories.courses.updateMetadata(id, {
            'name': _name.text.trim(),
            'shortName': _short.text.trim(),
          });
        }
        await _repositories.courses.updateVisibility(id, {
          for (final key in [
            'hidden',
            'showSchedule',
            'showDisciplines',
            'showMatriz',
            'visibleSemesters',
          ])
            key: _course[key],
        });
        _baselines['settings'] = jsonEncode(_settings());
      } else {
        if (domain == 'schedule' &&
            !RegExp(r'^\d{4}\.[12]$').hasMatch(_semester.text)) {
          throw const FormatException('Use um semestre AAAA.1 ou AAAA.2.');
        }
        if (domain == 'curriculum') {
          _curriculum = normalizeCurriculum(_curriculum);
        }
        final errors = validateAdminData(
          domain == 'schedule' ? _schedule : _curriculum,
          schedule: domain == 'schedule',
        );
        if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
        await _repositories.courses.save({
          'id': id,
          'name': _name.text.trim(),
          'shortName': _short.text.trim(),
          if (domain == 'curriculum')
            'curriculum': {
              ..._curriculum,
              'courseName': _name.text.trim(),
              'courseShortName': _short.text.trim(),
            },
          if (domain == 'schedule') ...{
            'semester': _semester.text,
            'schedule': _schedule
                .map((row) => {...row, 'semester': _semester.text})
                .toList(),
            'scheduleExtraction': _course['scheduleExtraction'],
          },
        });
        _baselines[domain] = domain == 'curriculum'
            ? jsonEncode(_curriculum)
            : jsonEncode({'semester': _semester.text, 'schedule': _schedule});
      }
      _courses = records((await _repositories.courses.list())['courses']);
      if (widget.state.repositories.isLocal) await widget.state.refresh();
    },
    success: widget.state.repositories.isLocal
        ? 'Alterações salvas neste dispositivo.'
        : 'Alterações salvas no servidor.',
  );

  @override
  Widget build(BuildContext context) {
    if (_initializing) return const Center(child: CircularProgressIndicator());
    if (!_authorized) return _loginView();
    final content = _content();
    return PopScope(
      canPop: !_dirty && !_extracting && !_feedbackDirty && !_feedbackSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop &&
            !_extracting &&
            await _confirm(
              'Alterações não salvas',
              'Descartar o rascunho e sair?',
            ) &&
            context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings_outlined),
                const Text(
                  'Admin My UFAPE',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (_dirty)
                  const Chip(
                    label: Text('Rascunho não salvo'),
                    avatar: Icon(Icons.edit_outlined, size: 16),
                  ),
                SizedBox(
                  width: 270,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _creating
                        ? '__new__'
                        : _id.isEmpty
                        ? null
                        : _id,
                    decoration: const InputDecoration(labelText: 'Curso'),
                    items: [
                      for (final course in _courses)
                        DropdownMenuItem(
                          value: '${course['id']}',
                          child: Text(
                            '${course['shortName']} · ${course['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const DropdownMenuItem(
                        value: '__new__',
                        child: Text('+ Novo curso'),
                      ),
                    ],
                    onChanged: _busy || _extracting
                        ? null
                        : (value) => _guard(() async {
                            if (value == '__new__') {
                              _newCourse();
                            } else if (value != null) {
                              await _loadCourse(value);
                            }
                          }),
                  ),
                ),
                if (!widget.state.repositories.isLocal)
                  TextButton.icon(
                    onPressed: _busy || _extracting
                        ? null
                        : () => _guard(() async {
                            await _session.signOut();
                            _authorized = false;
                          }),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sair'),
                  ),
              ],
            ),
          ),
          if (_message.isNotEmpty)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: SelectableText(_message),
                trailing: IconButton(
                  onPressed: () => setState(() => _message = ''),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 950;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (wide) SizedBox(width: 220, child: _navigation()),
                    Expanded(
                      child: Column(
                        children: [
                          if (!wide)
                            SizedBox(
                              height: 58,
                              child: _navigation(horizontal: true),
                            ),
                          Expanded(child: content),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginView() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 420,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_outline, size: 38),
                const SizedBox(height: 16),
                const Text(
                  'Admin My UFAPE',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Entre com uma conta autorizada para administrar os dados acadêmicos.',
                ),
                const SizedBox(height: 24),
                if (_config?['authConfigured'] != true)
                  const Text(
                    'Configure o Supabase e os administradores no servidor antes de entrar.',
                  ),
                if (!_session.configured)
                  const Text(
                    'Configure SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY no build Flutter.',
                  ),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) {
                    if (!_busy) _login();
                  },
                  decoration: const InputDecoration(labelText: 'Senha'),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed:
                      _busy ||
                          !_session.configured ||
                          _config?['authConfigured'] != true
                      ? null
                      : _login,
                  child: Text(_busy ? 'Verificando…' : 'Entrar'),
                ),
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: SelectableText(_message),
                  ),
                if (_config == null)
                  TextButton(
                    onPressed: () {
                      setState(() => _initializing = true);
                      _initialize();
                    },
                    child: const Text('Tentar novamente'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  static const _sections = {
    'dashboard': ('Visão geral', Icons.dashboard_outlined),
    'settings': ('Configurações', Icons.settings_outlined),
    'catalog': ('Disciplinas', Icons.menu_book_outlined),
    'structure': ('Estrutura e perfis', Icons.account_tree_outlined),
    'schedule': ('Oferta semestral', Icons.calendar_month_outlined),
    'import': ('Importar e extrair', Icons.upload_file_outlined),
    'feedback': ('Feedbacks', Icons.inbox_outlined),
    'migration': ('Migração de dados', Icons.storage_outlined),
  };
  Widget _navigation({bool horizontal = false}) {
    final children = _sections.entries
        .where(
          (entry) =>
              entry.key != 'migration' ||
              _config?['supportsMigration'] != false,
        )
        .map(
          (entry) => horizontal
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    selected: _section == entry.key,
                    label: Text(entry.value.$1),
                    onSelected: (_) => _navigate(entry.key),
                  ),
                )
              : ListTile(
                  selected: _section == entry.key,
                  leading: Icon(entry.value.$2),
                  title: Text(entry.value.$1),
                  onTap: () => _navigate(entry.key),
                ),
        )
        .toList();
    return horizontal
        ? ListView(scrollDirection: Axis.horizontal, children: children)
        : ListView(children: children);
  }

  Widget _page(String title, List<Widget> children, {Widget? action}) =>
      ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              ?action,
            ],
          ),
          const SizedBox(height: 22),
          ...children.expand((child) => [child, const SizedBox(height: 16)]),
        ],
      );
  Widget _panel(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ...children.expand((child) => [child, const SizedBox(height: 12)]),
        ],
      ),
    ),
  );
  Widget _saveButton(String domain) => FilledButton.icon(
    onPressed: _busy || _extracting ? null : () => _save(domain),
    icon: const Icon(Icons.save_outlined),
    label: Text(
      widget.state.repositories.isLocal
          ? 'Salvar neste dispositivo'
          : 'Salvar no servidor',
    ),
  );
  Widget _content() => switch (_section) {
    'settings' => _settingsView(),
    'catalog' => _recordsView(false),
    'structure' => _structureView(),
    'schedule' => _recordsView(true),
    'import' => _importView(),
    'feedback' => AdminFeedback(
      repository: _repositories.feedback,
      courses: _courses,
      onStateChanged: (dirty, saving) {
        if (mounted) {
          setState(() {
            _feedbackDirty = dirty;
            _feedbackSaving = saving;
          });
        }
      },
    ),
    'migration' => AdminMigration(repository: _repositories.migrations),
    _ => _page('Visão geral', [
      _panel(_name.text.isEmpty ? 'Bem-vindo à administração' : _name.text, [
        Text(
          '${_courses.length} cursos · ${records(_curriculum['subjects']).length} disciplinas · ${records(_curriculum['profiles']).length} perfis · ${_schedule.length} turmas',
        ),
        Text('Fonte dos dados: ${_config?['dataSource'] ?? 'servidor'}'),
        Text(
          widget.state.repositories.isLocal
              ? 'Revise os rascunhos e as importações antes de salvar. As alterações ficam somente neste dispositivo.'
              : 'Revise os rascunhos e as importações antes de salvar. As alterações só são publicadas ao salvar no servidor.',
        ),
      ]),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final key in [
            'settings',
            'catalog',
            'structure',
            'schedule',
            'import',
            'feedback',
          ])
            OutlinedButton.icon(
              onPressed: () => setState(() => _section = key),
              icon: Icon(_sections[key]!.$2),
              label: Text(_sections[key]!.$1),
            ),
        ],
      ),
    ]),
  };

  Widget _settingsView() => _page('Configurações do curso', [
    _panel('Identificação', [
      if (_creating)
        TextField(
          controller: _idInput,
          decoration: const InputDecoration(
            labelText: 'Identificador único',
            hintText: 'ciencia-da-computacao',
          ),
          onChanged: (_) => setState(() {}),
        ),
      TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Nome do curso'),
        onChanged: (_) => setState(() {}),
      ),
      TextField(
        controller: _short,
        decoration: const InputDecoration(labelText: 'Sigla'),
        onChanged: (_) => setState(() {}),
      ),
    ]),
    _panel('Visibilidade para os alunos', [
      for (final entry in {
        'hidden': 'Ocultar este curso',
        'showSchedule': 'Exibir horários',
        'showDisciplines': 'Exibir disciplinas',
        'showMatriz': 'Exibir matriz curricular',
      }.entries)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.value),
          value:
              _course[entry.key] == true ||
              (entry.key != 'hidden' && _course[entry.key] == null),
          onChanged: (value) => setState(() => _course[entry.key] = value),
        ),
    ]),
    _panel('Semestres disponíveis', [
      const Text(
        'Ative os semestres visíveis. O primeiro será aberto por padrão. Desativar preserva os dados cadastrados.',
      ),
      for (final semester in {
        ...(_course['visibleSemesters'] as List? ?? []),
        ...(_course['semesters'] as List? ?? []),
      })
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '$semester${(_course['visibleSemesters'] as List? ?? []).firstOrNull == semester ? ' · Padrão' : ''}',
          ),
          value: (_course['visibleSemesters'] as List? ?? []).contains(
            semester,
          ),
          onChanged: (value) => setState(() {
            final list = List<dynamic>.from(_course['visibleSemesters'] ?? []);
            value == true ? list.add(semester) : list.remove(semester);
            _course['visibleSemesters'] = list;
          }),
          secondary: IconButton(
            tooltip: 'Definir como padrão',
            icon: const Icon(Icons.vertical_align_top),
            onPressed: () => setState(
              () => _course['visibleSemesters'] = [
                semester,
                ...(_course['visibleSemesters'] as List? ?? []).where(
                  (item) => item != semester,
                ),
              ],
            ),
          ),
        ),
    ]),
    if (!_creating)
      _panel('Excluir curso', [
        const Text(
          'Remove este curso, todas as matrizes e todas as ofertas semestrais.',
        ),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  if (await _confirm(
                    'Excluir ${_name.text}?',
                    'Esta ação remove todos os dados deste curso do servidor.',
                  )) {
                    await _run(() async {
                      await _repositories.courses.delete(_id);
                      _id = '';
                      await _reloadCourses();
                    }, success: 'Curso excluído.');
                  }
                },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Excluir curso…'),
        ),
      ]),
  ], action: _saveButton('settings'));

  Widget _filters() => Wrap(
    spacing: 14,
    runSpacing: 12,
    children: [
      SizedBox(
        width: 270,
        child: TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Pesquisar nome ou código',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      SizedBox(
        width: 210,
        child: DropdownButtonFormField<String>(
          initialValue: _profile,
          decoration: const InputDecoration(labelText: 'Perfil'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Todos')),
            for (final profile in records(_curriculum['profiles']))
              DropdownMenuItem(
                value: '${profile['id']}',
                child: Text('${profile['name'] ?? profile['id']}'),
              ),
          ],
          onChanged: (value) => setState(() => _profile = value ?? ''),
        ),
      ),
      SizedBox(
        width: 150,
        child: TextFormField(
          key: ValueKey('period-$_period'),
          initialValue: _period,
          decoration: const InputDecoration(labelText: 'Período'),
          onChanged: (value) => setState(() => _period = value),
        ),
      ),
    ],
  );
  Widget _recordsView(bool schedule) {
    final list = schedule ? _schedule : records(_curriculum['subjects']);
    final filtered = list.asMap().entries.where((entry) {
      final row = entry.value;
      final text = '${row['name']} ${row['code']}'.toLowerCase();
      return text.contains(_search.text.toLowerCase()) &&
          (_profile.isEmpty || row['profile'] == _profile) &&
          (_period.isEmpty || '${row['period']}' == _period);
    });
    return _page(schedule ? 'Oferta semestral' : 'Catálogo de disciplinas', [
      if (schedule)
        _panel('Semestre letivo', [
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: TextField(
                  controller: _semester,
                  decoration: const InputDecoration(
                    labelText: 'AAAA.1 ou AAAA.2',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              OutlinedButton(
                onPressed: _busy || _creating
                    ? null
                    : () {
                        final semester = _semester.text;
                        if (!RegExp(r'^\d{4}\.[12]$').hasMatch(semester)) {
                          setState(() => _message = 'Use AAAA.1 ou AAAA.2.');
                          return;
                        }
                        _guard(() => _loadCourse(_id, semester: semester));
                      },
                child: const Text('Abrir semestre'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final semester in _course['semesters'] as List? ?? [])
                ActionChip(
                  label: Text('$semester'),
                  onPressed: () =>
                      _guard(() => _loadCourse(_id, semester: '$semester')),
                ),
            ],
          ),
        ]),
      _filters(),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _editRecord(schedule),
            icon: const Icon(Icons.add),
            label: Text(schedule ? 'Adicionar turma' : 'Adicionar disciplina'),
          ),
          OutlinedButton.icon(
            onPressed: () => _editWhole(schedule),
            icon: const Icon(Icons.code),
            label: const Text('Editar JSON completo'),
          ),
          Text('${filtered.length} de ${list.length} registros'),
        ],
      ),
      if (filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhum registro para estes filtros.'),
        ),
      for (final entry in filtered)
        Card(
          child: ListTile(
            isThreeLine: true,
            title: Text(
              '${entry.value['code'] ?? ''} · ${entry.value['name'] ?? 'Sem nome'}',
            ),
            subtitle: Text(
              schedule
                  ? '${entry.value['professor'] ?? 'Sem docente'} · Perfil ${entry.value['profile'] ?? '—'} · Período ${entry.value['period'] ?? '—'}\n${records(entry.value['sessions']).map((session) => '${session['day']}ª ${session['time']}').join(' · ')}'
                  : 'Perfil ${entry.value['profile'] ?? '—'} · Período ${entry.value['period'] ?? '—'} · ${object(entry.value['workload'])['total'] ?? '—'}h\n${entry.value['type'] ?? 'Tipo não informado'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Editar',
                  onPressed: _busy
                      ? null
                      : () => _editRecord(schedule, index: entry.key),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  onPressed: _busy
                      ? null
                      : () => _deleteRecord(schedule, entry.key),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
    ], action: _saveButton(schedule ? 'schedule' : 'curriculum'));
  }

  Future<void> _deleteRecord(bool schedule, int index) async {
    final list = schedule ? _schedule : records(_curriculum['subjects']);
    final row = list[index];
    if (!schedule) {
      final dependents = records(
        _curriculum['treeSubjects'],
      ).where((node) => (node['prereqs'] as List? ?? []).contains(row['id']));
      if (dependents.isNotEmpty) {
        setState(
          () => _message =
              'Remova primeiro os pré-requisitos em: ${dependents.map((node) => node['name']).join(', ')}.',
        );
        return;
      }
    }
    if (await _confirm(
      'Excluir registro?',
      '${row['name']} será removido do rascunho.',
    )) {
      setState(() {
        list.removeAt(index);
        if (schedule) {
          _schedule = list;
        } else {
          _curriculum['subjects'] = list;
          _curriculum['treeSubjects'] = records(_curriculum['treeSubjects'])
              .where((node) => node['id'] != row['id'])
              .toList();
          _curriculum = normalizeCurriculum(_curriculum);
        }
      });
    }
  }

  Future<void> _editRecord(bool schedule, {int? index}) async {
    final list = schedule ? _schedule : records(_curriculum['subjects']);
    final initial = index == null
        ? (schedule
              ? {
                  'id': const Uuid().v4(),
                  'name': '',
                  'code': null,
                  'professor': null,
                  'period': null,
                  'profile': _profile.isEmpty ? null : _profile,
                  'sessions': <dynamic>[],
                }
              : {
                  'id': const Uuid().v4(),
                  'code': '',
                  'name': '',
                  'type': 'Obrigatória',
                  'period': null,
                  'profile': _profile.isEmpty ? null : _profile,
                  'credits': null,
                  'workload': {
                    'teorica': null,
                    'pratica': null,
                    'extensao': null,
                    'total': null,
                  },
                  'prerequisites': [],
                  'corequisites': [],
                  'equivalences': [],
                  'ementa': null,
                })
        : list[index];
    final result = await showDialog<Json>(
      context: context,
      builder: (context) =>
          AcademicRecordEditor(initial: initial, schedule: schedule),
    );
    if (result == null || !mounted) return;
    if (index != null && result['id'] != initial['id']) {
      setState(
        () => _message = 'Preserve o identificador do registro existente para manter os vínculos.',
      );
      return;
    }
    setState(() {
      if (index == null) {
        list.add(result);
      } else {
        list[index] = result;
      }
      if (schedule) {
        _schedule = list;
      } else {
        _curriculum['subjects'] = list;
        final refs = records(result['prerequisites'])
            .map(
              (ref) =>
                  ref['id'] ??
                  list
                      .where(
                        (row) =>
                            row['code'] == ref['code'] &&
                            row['profile'] == result['profile'],
                      )
                      .firstOrNull?['id'],
            )
            .whereType<String>()
            .toList();
        _curriculum['treeSubjects'] = records(_curriculum['treeSubjects'])
            .map(
              (node) => node['id'] == result['id']
                  ? {...node, 'prereqs': refs}
                  : node,
            )
            .toList();
        _curriculum = normalizeCurriculum(_curriculum);
      }
    });
  }

  Future<dynamic> _jsonDialog(String title, dynamic value) async =>
      showDialog<dynamic>(
        context: context,
        builder: (context) => JsonEditorDialog(title: title, value: value),
      );
  Future<void> _editWhole(bool schedule) async {
    final result = await _jsonDialog(
      schedule ? 'Oferta: JSON completo' : 'Currículo: JSON completo',
      schedule ? _schedule : _curriculum,
    );
    if (result != null) await _reviewImport(result, schedule: schedule);
  }

  Widget _structureView() => _page('Estrutura curricular e perfis', [
    const Text(
      'Os pré-requisitos usam identificadores das disciplinas. O catálogo, os perfis e a estrutura são salvos juntos.',
    ),
    Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => _editProfile(),
          icon: const Icon(Icons.add),
          label: const Text('Novo perfil'),
        ),
        OutlinedButton(
          onPressed: () async {
            final result = await _jsonDialog(
              'Requisitos e cargas horárias',
              _curriculum['requisitos'] ?? {},
            );
            if (result is Map) {
              setState(() => _curriculum['requisitos'] = result);
            }
          },
          child: const Text('Requisitos gerais'),
        ),
        OutlinedButton(
          onPressed: () => _editWhole(false),
          child: const Text('JSON completo'),
        ),
      ],
    ),
    for (final profile in records(_curriculum['profiles']))
      Card(
        child: ListTile(
          title: Text(
            '${profile['name'] ?? profile['id']}${_curriculum['activeProfileId'] == profile['id'] ? ' · Padrão' : ''}',
          ),
          subtitle: Text(
            '${profile['id']} · ${profile['totalHours'] ?? '—'}h · ${records(profile['subjects']).length} disciplinas',
          ),
          trailing: Wrap(
            children: [
              IconButton(
                tooltip: 'Padrão',
                onPressed: () => setState(
                  () => _curriculum['activeProfileId'] = profile['id'],
                ),
                icon: const Icon(Icons.star_outline),
              ),
              IconButton(
                tooltip: 'Editar perfil',
                onPressed: () => _editProfile(profile),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Excluir perfil',
                onPressed: () => _deleteProfile(profile),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    _filters(),
    for (final node in records(_curriculum['treeSubjects']).where(
      (row) =>
          (_profile.isEmpty || row['profile'] == _profile) &&
          (_period.isEmpty || '${row['period']}' == _period) &&
          '${row['name']} ${row['code']}'.toLowerCase().contains(
            _search.text.toLowerCase(),
          ),
    ))
      _panel('${node['code'] ?? ''} · ${node['name']}', [
        Text(
          'Período ${node['period'] ?? '—'} · ${node['hours'] ?? '—'}h · ${node['type']}',
        ),
        Text(
          'Pré-requisitos: ${(node['prereqs'] as List? ?? []).map((id) => records(_curriculum['treeSubjects']).where((candidate) => candidate['id'] == id).firstOrNull?['name'] ?? id).join(', ')}',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => _editLinks(node),
            child: const Text('Editar relações e estrutura'),
          ),
        ),
      ]),
  ], action: _saveButton('curriculum'));
  Future<void> _editProfile([Json? profile]) async {
    final result = await _jsonDialog(
      profile == null ? 'Criar perfil' : 'Editar perfil',
      profile ??
          {
            'id': const Uuid().v4(),
            'name': 'Novo perfil',
            'description': '',
            'validFromSemester': '',
            'totalHours': null,
            'acexHours': null,
            'accHours': null,
            'optativeHours': null,
            'mandatoryHours': null,
            'requisitos': {},
            'subjects': [],
          },
    );
    if (result is! Map || '${result['id'] ?? ''}'.isEmpty) return;
    final profiles = records(_curriculum['profiles']);
    final index = profiles.indexWhere((row) => row['id'] == profile?['id']);
    if (profiles.any(
      (row) => row['id'] == result['id'] && row['id'] != profile?['id'],
    )) {
      setState(() => _message = 'Identificador de perfil repetido.');
      return;
    }
    if (profile != null && result['id'] != profile['id']) {
      setState(
        () => _message = 'Preserve o identificador do perfil existente.',
      );
      return;
    }
    setState(() {
      if (index < 0) {
        profiles.add(object(result));
      } else {
        profiles[index] = object(result);
      }
      _curriculum['profiles'] = profiles;
      _curriculum = normalizeCurriculum(_curriculum);
      _curriculum['activeProfileId'] ??= result['id'];
    });
  }

  Future<void> _deleteProfile(Json profile) async {
    final nodes = records(_curriculum['treeSubjects']);
    final removed = nodes
        .where((node) => node['profile'] == profile['id'])
        .map((node) => node['id'])
        .toSet();
    if (nodes.any(
      (node) =>
          !removed.contains(node['id']) &&
          (node['prereqs'] as List? ?? []).any(removed.contains),
    )) {
      setState(
        () => _message = 'Este perfil possui vínculos de pré-requisito externos. Remova esses vínculos antes.',
      );
      return;
    }
    if (await _confirm(
      'Excluir perfil?',
      'Remove o perfil ${profile['name']} e suas disciplinas do rascunho.',
    )) {
      setState(() {
        _curriculum['profiles'] = records(_curriculum['profiles'])
            .where((row) => row['id'] != profile['id'])
            .toList();
        _curriculum['subjects'] = records(_curriculum['subjects'])
            .where((row) => row['profile'] != profile['id'])
            .toList();
        _curriculum['treeSubjects'] = nodes
            .where((row) => row['profile'] != profile['id'])
            .toList();
        if (_curriculum['activeProfileId'] == profile['id']) {
          _curriculum['activeProfileId'] = records(_curriculum['profiles'])
              .firstOrNull?['id'];
        }
        _profile = '';
        _curriculum = normalizeCurriculum(_curriculum);
      });
    }
  }

  Future<void> _editLinks(Json node) async {
    final result = await _jsonDialog('Relações: ${node['name']}', {
      'id': node['id'],
      'type': node['type'],
      'prereqs': node['prereqs'] ?? [],
      'corequisites': node['corequisites'] ?? [],
      'equivalences': node['equivalences'] ?? [],
    });
    if (result is! Map) return;
    final ids = records(_curriculum['treeSubjects'])
        .map((row) => row['id'])
        .toSet();
    if ((result['prereqs'] as List? ?? []).any(
      (id) => !ids.contains(id) || id == node['id'],
    )) {
      setState(() => _message = 'Pré-requisito inexistente ou autorreferente.');
      return;
    }
    setState(() {
      _curriculum['treeSubjects'] = records(_curriculum['treeSubjects'])
          .map(
            (row) => row['id'] == node['id']
                ? {...row, ...object(result), 'id': node['id']}
                : row,
          )
          .toList();
      _curriculum['subjects'] = records(_curriculum['subjects'])
          .map(
            (row) => row['id'] == node['id']
                ? {
                    ...row,
                    'corequisites': result['corequisites'],
                    'equivalences': result['equivalences'],
                    'prerequisites': (result['prereqs'] as List? ?? []).map((
                      id,
                    ) {
                      final target = records(_curriculum['subjects'])
                          .where((candidate) => candidate['id'] == id)
                          .firstOrNull;
                      return {
                        'id': id,
                        'code': target?['code'],
                        'name': target?['name'],
                      };
                    }).toList(),
                  }
                : row,
          )
          .toList();
      _curriculum = normalizeCurriculum(_curriculum);
    });
  }

  Future<void> _reviewImport(
    dynamic incoming, {
    required bool schedule,
    bool merge = false,
  }) async {
    try {
      final raw = schedule
          ? (incoming is List
                ? incoming
                : object(incoming)['disciplines'] ??
                      object(incoming)['schedule'])
          : incoming;
      if (schedule && raw is! List) {
        throw const FormatException(
          'O JSON deve conter uma lista de turmas ou disciplines/schedule.',
        );
      }
      if (!schedule &&
          raw is! List &&
          (raw is! Map ||
              !['subjects', 'treeSubjects', 'profiles'].any(raw.containsKey))) {
        throw const FormatException(
          'O currículo deve conter subjects, treeSubjects ou profiles.',
        );
      }
      dynamic candidate = schedule ? records(raw) : normalizeCurriculum(raw);
      final before = schedule ? _schedule : _curriculum;
      if (merge) {
        List<Json> combine(List<Json> old, List<Json> next) {
          final out = records(cloneJson(old));
          for (final row in next) {
            final index = out.indexWhere(
              (item) => row['id'] != null
                  ? item['id'] == row['id']
                  : item['code'] == row['code'] &&
                        item['profile'] == row['profile'],
            );
            if (index < 0) {
              out.add(row);
            } else {
              out[index] = {...out[index], ...row};
            }
          }
          return out;
        }

        candidate = schedule
            ? combine(_schedule, records(candidate))
            : normalizeCurriculum({
                ..._curriculum,
                ...object(candidate),
                for (final key in ['subjects', 'treeSubjects', 'profiles'])
                  key: combine(
                    records(_curriculum[key]),
                    records(object(candidate)[key]),
                  ),
              });
      }
      final errors = validateAdminData(candidate, schedule: schedule);
      final changes = changesBetween(before, candidate);
      if (!mounted) return;
      final apply = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Revisar ${merge ? 'mesclagem' : 'substituição'}'),
          content: SizedBox(
            width: 780,
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Text(
                    '${changes.length} alterações · ${errors.length} problemas',
                  ),
                  if (errors.isNotEmpty)
                    SelectableText(
                      errors.join('\n'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  SelectableText(
                    changes.isEmpty
                        ? 'Nenhuma alteração.'
                        : changes.take(500).join('\n'),
                  ),
                  if (changes.length > 500)
                    const Text(
                      'Prévia limitada a 500 linhas; exporte o JSON para a comparação completa.',
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: errors.isNotEmpty || changes.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Aplicar ao rascunho'),
            ),
          ],
        ),
      );
      if (apply == true && mounted) {
        setState(() {
          if (schedule) {
            _schedule = records(candidate);
            if (incoming is Map &&
                RegExp(r'^\d{4}\.[12]$').hasMatch('${incoming['semester']}')) {
              _semester.text = '${incoming['semester']}';
            }
            _course['scheduleExtraction'] = incoming is Map
                ? incoming['_extraction']
                : null;
          } else {
            _curriculum = object(candidate);
            _profile = '';
          }
          _message = 'Importação aplicada ao rascunho. Revise e salve no servidor quando estiver pronto.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
  }

  Widget _importView() => _page('Importação e extração', [
    _panel('JSON acadêmico', [
      DropdownButtonFormField<String>(
        initialValue: _importTarget,
        decoration: const InputDecoration(labelText: 'Destino'),
        items: const [
          DropdownMenuItem(
            value: 'curriculum',
            child: Text('Currículo, perfis e estrutura'),
          ),
          DropdownMenuItem(value: 'schedule', child: Text('Oferta semestral')),
        ],
        onChanged: (value) => setState(() => _importTarget = value!),
      ),
      TextField(
        controller: _paste,
        minLines: 5,
        maxLines: 12,
        decoration: const InputDecoration(labelText: 'Cole o JSON'),
      ),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final text = await importJson();
                if (text != null && mounted) setState(() => _paste.text = text);
              } catch (error) {
                if (mounted) setState(() => _message = '$error');
              }
            },
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Abrir JSON'),
          ),
          for (final merge in [false, true])
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () {
                      try {
                        _reviewImport(
                          jsonDecode(_paste.text),
                          schedule: _importTarget == 'schedule',
                          merge: merge,
                        );
                      } catch (error) {
                        setState(() => _message = 'JSON inválido: $error');
                      }
                    },
              child: Text(merge ? 'Revisar mesclagem' : 'Revisar substituição'),
            ),
          OutlinedButton.icon(
            onPressed: () => _run(
              () => saveJson(
                '$_id-${_importTarget == 'schedule' ? _semester.text : 'curriculo'}.json',
                _importTarget == 'schedule'
                    ? {'semester': _semester.text, 'disciplines': _schedule}
                    : _curriculum,
              ),
            ),
            icon: const Icon(Icons.download),
            label: const Text('Exportar rascunho'),
          ),
        ],
      ),
    ]),
    if (_config?['supportsExtraction'] == false)
      const Text(
        'Neste modo, importe os dados pelo JSON acima. Extração por IA exige o serviço remoto no modo API.',
      ),
    if (_config?['supportsExtraction'] != false)
      _panel('Extrair PDF, imagem ou texto com IA', [
        const Text(
          'A extração usa o backend existente. O resultado sempre passa por revisão e não é publicado automaticamente.',
        ),
        DropdownButtonFormField<String>(
          initialValue: _extractMode,
          decoration: const InputDecoration(labelText: 'Tipo de extração'),
          items: const [
            DropdownMenuItem(
              value: 'tree',
              child: Text('Matriz / estrutura curricular'),
            ),
            DropdownMenuItem(
              value: 'linear',
              child: Text('Catálogo e ementas'),
            ),
            DropdownMenuItem(
              value: 'schedule',
              child: Text('Horários letivos'),
            ),
          ],
          onChanged: _extracting
              ? null
              : (value) => setState(() => _extractMode = value!),
        ),
        OutlinedButton(
          onPressed: _extracting ? null : _editPipeline,
          child: const Text('Configurar etapas e concorrência'),
        ),
        TextField(
          controller: _model,
          enabled: !_extracting,
          decoration: const InputDecoration(
            labelText: 'Modelo (opcional)',
            helperText:
                'Vazio usa o provedor e o modelo configurados no servidor.',
          ),
        ),
        TextField(
          controller: _sourceText,
          enabled: !_extracting,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Texto do documento (opcional)',
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _extracting ? null : _pickSources,
              icon: const Icon(Icons.attach_file),
              label: const Text('Adicionar documentos'),
            ),
            FilledButton.icon(
              onPressed: _extracting || _busy ? null : _startExtraction,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Iniciar extração'),
            ),
          ],
        ),
        for (final file in _files)
          ListTile(
            title: Text('${file['fileName']}'),
            trailing: IconButton(
              tooltip: 'Remover',
              onPressed: _extracting
                  ? null
                  : () => setState(() => _files.remove(file)),
              icon: const Icon(Icons.close),
            ),
          ),
        TextField(
          controller: _resume,
          enabled: !_extracting,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Token de retomada',
            helperText:
                'Guarde este identificador para retomar após uma interrupção.',
          ),
        ),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              onPressed: _extracting || _resume.text.trim().isEmpty
                  ? null
                  : _resumeExtraction,
              child: const Text('Retomar / reabrir resultado'),
            ),
            IconButton(
              tooltip: 'Copiar token',
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: _resume.text)),
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        if (_extracting) const LinearProgressIndicator(),
        if (_monitorError.isNotEmpty) Text(_monitorError),
        if (_snapshot != null) ...[
          Text(
            'Estado: ${_snapshot!['status']} · ${_snapshot!['completedCalls'] ?? 0} chamadas preservadas',
          ),
          for (final event in records(
            object(_snapshot!['activity'])['events'],
          ).reversed.take(12))
            Text('${event['stage']}: ${event['message']}'),
        ],
        if (_extracted != null) ...[
          const Text('Resultado pronto para revisão'),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: () => _reviewImport(
                  _extracted,
                  schedule: _resultMode == 'schedule',
                ),
                child: const Text('Revisar resultado'),
              ),
              OutlinedButton(
                onPressed: () =>
                    saveJson('extracao-${_resume.text}.json', _extracted!),
                child: const Text('Baixar resultado'),
              ),
            ],
          ),
          SelectableText(
            prettyJson(_extracted)
                .substring(0, prettyJson(_extracted).length.clamp(0, 5000)),
          ),
        ],
      ]),
  ]);
  Future<void> _pickSources() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final ext = file.extension?.toLowerCase();
      if (mounted) {
        setState(
          () => _files.add({
            'fileName': file.name,
            'mimeType': ext == 'pdf'
                ? 'application/pdf'
                : ext == 'jpg' || ext == 'jpeg'
                ? 'image/jpeg'
                : 'image/$ext',
            'base64Data': base64Encode(bytes),
          }),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
  }

  Future<void> _editPipeline() async {
    final result = await _jsonDialog(
      'Pipeline: concurrency (1–6), models por etapa (reading, inventory, catalogue, details, relations, repair)',
      _pipeline,
    );
    if (result is! Map || !mounted) return;
    final concurrency = result['concurrency'];
    if (concurrency is! int ||
        concurrency < 1 ||
        concurrency > 6 ||
        result['models'] is! Map) {
      setState(
        () => _message =
            'Use concurrency entre 1 e 6 e models como objeto por etapa.',
      );
      return;
    }
    setState(() => _pipeline = object(result));
  }

  Future<void> _startExtraction() async {
    if (_files.isEmpty && _sourceText.text.trim().isEmpty) {
      setState(() => _message = 'Envie documentos ou cole o texto.');
      return;
    }
    _resume.text = const Uuid().v4();
    _extracted = null;
    await _run(() async {
      _snapshot = object(
        await _repositories.extraction.start({
          'token': _resume.text,
          'mode': _extractMode,
          'input': {
            'files': _files,
            'textContent': _sourceText.text,
            if (_model.text.trim().isNotEmpty) 'model': _model.text.trim(),
            'pipeline': _pipeline,
          },
        }),
      );
    });
    if (_snapshot?['token'] == _resume.text) await _resumeExtraction();
  }

  Future<void> _poll() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      final result = object(
        await _repositories.extraction.get(_resume.text.trim()),
      );
      if (mounted) {
        setState(() {
          _snapshot = result;
          _monitorError = '';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _monitorError =
              'Acompanhamento indisponível: $error. A última etapa foi preservada.',
        );
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _resumeExtraction() async {
    if (_extracting) return;
    setState(() {
      _extracting = true;
      _message = '';
    });
    try {
      await _poll();
      final serverMode = _snapshot?['mode'];
      if (['tree', 'linear', 'schedule'].contains(serverMode)) {
        _extractMode = '$serverMode';
      }
      _monitor?.cancel();
      _monitor = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
      final result = object(
        await _repositories.extraction.resume(
          ExtractionMode.fromName(_extractMode),
          {
            'resumeToken': _resume.text.trim(),
            if (_model.text.trim().isNotEmpty) 'model': _model.text.trim(),
            'pipeline': _pipeline,
          },
        ),
      );
      if (mounted) {
        setState(() {
          _extracted = result;
          _resultMode = _extractMode;
          _message = 'Extração concluída. Revise o resultado antes de aplicar ao rascunho.';
        });
      }
      await _poll();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message =
              'Extração interrompida: $error. Retome usando o token preservado.',
        );
      }
    } finally {
      _monitor?.cancel();
      if (mounted) setState(() => _extracting = false);
    }
  }
}

class JsonEditorDialog extends StatefulWidget {
  const JsonEditorDialog({super.key, required this.title, required this.value});
  final String title;
  final dynamic value;
  @override
  State<JsonEditorDialog> createState() => _JsonEditorDialogState();
}

class _JsonEditorDialogState extends State<JsonEditorDialog> {
  late final _controller = TextEditingController(
    text: prettyJson(widget.value),
  );
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 850,
      height: 530,
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              expands: true,
              minLines: null,
              maxLines: null,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'JSON',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          try {
            Navigator.pop(context, jsonDecode(_controller.text));
          } catch (error) {
            setState(() => _error = 'JSON inválido: $error');
          }
        },
        child: const Text('Aplicar ao rascunho'),
      ),
    ],
  );
}

class AcademicRecordEditor extends StatefulWidget {
  const AcademicRecordEditor({
    super.key,
    required this.initial,
    required this.schedule,
  });
  final Json initial;
  final bool schedule;
  @override
  State<AcademicRecordEditor> createState() => _AcademicRecordEditorState();
}

class _AcademicRecordEditorState extends State<AcademicRecordEditor> {
  late final Json _row = object(cloneJson(widget.initial));
  String _error = '';
  final List<TextEditingController> _controllers = [];
  late final Map<String, TextEditingController> _fields = {
    for (final key in [
      'code',
      'name',
      'professor',
      'period',
      'profile',
      'type',
      'credits',
      'ementa',
    ])
      key: _controller('${_row[key] ?? ''}'),
  };
  late final _sessions = _controller(prettyJson(_row['sessions'] ?? []));
  late final _workload = _controller(prettyJson(_row['workload'] ?? {}));
  TextEditingController _controller(String value) {
    final controller = TextEditingController(text: value);
    _controllers.add(controller);
    return controller;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    try {
      for (final entry in _fields.entries) {
        _row[entry.key] = entry.value.text.trim().isEmpty
            ? null
            : entry.value.text.trim();
      }
      _row['period'] =
          num.tryParse(_fields['period']!.text) ??
          (_fields['period']!.text.isEmpty ? null : _fields['period']!.text);
      _row['credits'] = num.tryParse(_fields['credits']!.text);
      if (widget.schedule) {
        final value = jsonDecode(_sessions.text);
        if (value is! List) {
          throw const FormatException('Encontros deve ser uma lista.');
        }
        _row['sessions'] = value;
      } else {
        _row['workload'] = jsonDecode(_workload.text);
      }
      final errors = validateAdminData(
        widget.schedule
            ? [_row]
            : {
                'subjects': [_row],
              },
        schedule: widget.schedule,
      );
      if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
      Navigator.pop(context, _row);
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.schedule ? 'Editar turma' : 'Editar disciplina'),
    content: SizedBox(
      width: 680,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in {
              'code': 'Código',
              'name': 'Nome',
              if (widget.schedule) 'professor': 'Professor',
              'period': 'Período',
              'profile': 'Perfil (identificador)',
              if (!widget.schedule) ...{
                'type': 'Tipo acadêmico',
                'credits': 'Créditos',
                'ementa': 'Ementa',
              },
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextField(
                  controller: _fields[entry.key],
                  maxLines: entry.key == 'ementa' ? 4 : 1,
                  decoration: InputDecoration(labelText: entry.value),
                ),
              ),
            TextField(
              controller: widget.schedule ? _sessions : _workload,
              minLines: 5,
              maxLines: 10,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: widget.schedule
                    ? 'Encontros: JSON [{"day":1,"time":"07:30 - 08:30"}]'
                    : 'Carga horária (JSON)',
              ),
            ),
            TextButton(
              onPressed: () async {
                final result = await showDialog<dynamic>(
                  context: context,
                  builder: (context) => JsonEditorDialog(
                    title: 'Campos completos e referências',
                    value: _row,
                  ),
                );
                if (result is Map && context.mounted) {
                  Navigator.pop(context, object(result));
                }
              },
              child: const Text(
                'Editar todos os campos em JSON (pré-requisitos, equivalências e evidências)',
              ),
            ),
            if (_error.isNotEmpty)
              Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Aplicar ao rascunho')),
    ],
  );
}

const _feedbackStatuses = {
  'new': 'Novo',
  'reviewing': 'Em análise',
  'planned': 'Planejado',
  'resolved': 'Resolvido',
  'archived': 'Arquivado',
};
const _feedbackCategories = {
  'suggestion': 'Sugestão',
  'problem': 'Problema',
  'academic_data': 'Correção de dados acadêmicos',
  'other': 'Outro',
};

class AdminFeedback extends StatefulWidget {
  const AdminFeedback({
    super.key,
    required this.repository,
    required this.courses,
    required this.onStateChanged,
  });
  final FeedbackRepository repository;
  final List<Json> courses;
  final void Function(bool dirty, bool saving) onStateChanged;
  @override
  State<AdminFeedback> createState() => _AdminFeedbackState();
}

class _AdminFeedbackState extends State<AdminFeedback> {
  List<Json> _items = [];
  Json? _selected;
  int _total = 0, _offset = 0, _version = 0;
  String _statusFilter = '',
      _category = '',
      _course = '',
      _status = 'new',
      _error = '';
  final _notes = TextEditingController();
  bool _busy = false;
  bool get _dirty =>
      _selected != null &&
      (_status != _selected!['status'] ||
          _notes.text != (_selected!['internal_notes'] ?? ''));
  void _notify() => widget.onStateChanged(_dirty, _busy);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<bool> _discard() async =>
      !_dirty ||
      (await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Notas não salvas'),
              content: const Text('Descartar as alterações deste feedback?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Descartar'),
                ),
              ],
            ),
          ) ??
          false);
  Future<void> _change(VoidCallback action) async {
    if (_busy || !await _discard() || !mounted) return;
    setState(action);
    await _load();
  }

  Future<void> _load() async {
    final version = ++_version;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final data = await widget.repository.list(
        category: _category,
        status: _statusFilter,
        course: _course,
        offset: _offset,
      );
      if (!mounted || version != _version) return;
      _items = records(data['items']);
      _total = (data['total'] as num?)?.toInt() ?? 0;
      _selected = _items
          .where((row) => row['id'] == _selected?['id'])
          .firstOrNull;
      _status = '${_selected?['status'] ?? 'new'}';
      _notes.text = '${_selected?['internal_notes'] ?? ''}';
    } catch (error) {
      _error = '$error';
    } finally {
      if (mounted && version == _version) {
        setState(() => _busy = false);
        _notify();
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    _notify();
    try {
      final result = object(
        await widget.repository.update(
          '${_selected!['id']}',
          status: _status,
          notes: _notes.text,
        ),
      );
      _selected = object(result['item']);
      _status = '${_selected!['status']}';
      _notes.text = '${_selected!['internal_notes'] ?? ''}';
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _busy = false;
        });
      }
    }
    if (mounted) _notify();
  }

  Widget _filter(
    String label,
    String value,
    Map<String, String> options,
    void Function(String) change,
  ) => SizedBox(
    width: 210,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Todos')),
        for (final entry in options.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _busy
          ? null
          : (value) => _change(() {
              _selected = null;
              change(value!);
              _offset = 0;
            }),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && await _discard() && context.mounted) {
        Navigator.pop(context);
      }
    },
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Caixa de entrada de feedbacks',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 14),
        const Text(
          'Mensagens privadas dos visitantes. As notas são internas; salvar não envia uma resposta por e-mail.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _filter(
              'Situação',
              _statusFilter,
              _feedbackStatuses,
              (value) => _statusFilter = value,
            ),
            _filter(
              'Tipo',
              _category,
              _feedbackCategories,
              (value) => _category = value,
            ),
            _filter('Curso', _course, {
              for (final course in widget.courses)
                '${course['id']}': '${course['shortName']}',
            }, (value) => _course = value),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _change(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        Text('$_total feedbacks encontrados'),
        for (final item in _items)
          Card(
            child: ListTile(
              selected: _selected?['id'] == item['id'],
              title: Text(
                '${_feedbackCategories[item['category']] ?? item['category']} · ${_feedbackStatuses[item['status']] ?? item['status']}',
              ),
              subtitle: Text(
                '${item['message']}\n${item['created_at']} · ${item['name'] ?? 'Sem nome'}',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: _busy
                  ? null
                  : () async {
                      if (await _discard() && mounted) {
                        setState(() {
                          _selected = item;
                          _status = '${item['status']}';
                          _notes.text = '${item['internal_notes'] ?? ''}';
                        });
                      }
                    },
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _busy || _offset == 0
                  ? null
                  : () => _change(
                      () => _offset = (_offset - 25).clamp(0, _total),
                    ),
              child: const Text('Anterior'),
            ),
            Text(
              '${_total == 0 ? 0 : _offset + 1}–${(_offset + 25).clamp(0, _total)} de $_total',
            ),
            TextButton(
              onPressed: _busy || _offset + 25 >= _total
                  ? null
                  : () => _change(() => _offset += 25),
              child: const Text('Próxima'),
            ),
          ],
        ),
        if (_selected != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Detalhes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  SelectableText('${_selected!['message']}'),
                  const SizedBox(height: 14),
                  SelectableText(
                    'Nome: ${_selected!['name'] ?? 'Não informado'}\nE-mail: ${_selected!['email'] ?? 'Não informado'}\nRecebido: ${_selected!['created_at']}',
                  ),
                  ExpansionTile(
                    title: const Text('Contexto técnico'),
                    children: [
                      SelectableText(prettyJson(_selected!['metadata'])),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('status-${_selected!['id']}'),
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Situação'),
                    items: [
                      for (final entry in _feedbackStatuses.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            setState(() => _status = value!);
                            _notify();
                          },
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _notes,
                    enabled: !_busy,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 5000,
                    onChanged: (_) {
                      setState(() {});
                      _notify();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Notas internas',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy || !_dirty ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar feedback'),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class AdminMigration extends StatefulWidget {
  const AdminMigration({super.key, required this.repository});
  final MigrationRepository repository;
  @override
  State<AdminMigration> createState() => _AdminMigrationState();
}

class _AdminMigrationState extends State<AdminMigration> {
  Json? _inventory, _preview, _run;
  List<Json> _runs = [];
  final _selected = <String>{}, _overwrite = <String>{};
  bool _busy = false;
  String _message = '';
  int _done = 0, _total = 0;
  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await action();
    } catch (error) {
      _message = '$error';
      _preview = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze() => _action(() async {
    _inventory = object(await widget.repository.inventory());
    _preview = null;
    _overwrite.clear();
    _selected.removeWhere(
      (key) => !records(_inventory!['items']).any((row) => row['key'] == key),
    );
  });
  Future<void> _validate() => _action(() async {
    _preview = object(
      await widget.repository.validate({
        'selectedKeys': _selected.toList(),
        'overwriteKeys': _overwrite.toList(),
      }),
    );
    _selected
      ..clear()
      ..addAll(records(_preview!['items']).map((row) => '${row['key']}'));
  });
  Future<void> _execute() async {
    if (_preview?['ready'] != true) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Executar migração?'),
        content: const Text(
          'Os conjuntos selecionados serão gravados no Supabase conforme a prévia. Os itens marcados para substituição terão seus dados atualizados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Migrar selecionados'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    await _action(() async {
      final courses = List<dynamic>.from(_preview!['selectedCourseIds'] ?? []);
      _total = courses.length;
      _done = 0;
      _run = object(
        await widget.repository.start({
          'selectedKeys': _selected.toList(),
          'overwriteKeys': _overwrite.toList(),
          'fingerprint': _preview!['fingerprint'],
        }),
      );
      final failures = <String>[];
      for (final course in courses) {
        try {
          await widget.repository.importCourse('${_run!['id']}', '$course');
        } catch (error) {
          failures.add('$course: $error');
        }
        if (mounted) setState(() => _done++);
      }
      final latest = object(await widget.repository.get('${_run!['id']}'));
      _run = object(latest['run']);
      _preview = null;
      _message = failures.isEmpty
          ? 'Migração concluída. Confira o relatório antes de ativar o Supabase como fonte.'
          : 'Execução registrada com falhas: ${failures.join(' · ')}';
      _runs = records((await widget.repository.list())['runs']);
    });
  }

  Future<void> _report(String id) => _action(() async {
    final report = await widget.repository.report(id);
    await saveJson('my-ufape-migration-$id.json', report);
  });
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Migração de dados',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 14),
      const Text(
        'Analise os arquivos do servidor, valide o destino e revise cada diferença antes de importar para o Supabase.',
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _analyze,
            icon: const Icon(Icons.refresh),
            label: const Text('Analisar arquivos'),
          ),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _action(() async {
                    _runs = records(
                      object(await widget.repository.list())['runs'],
                    );
                  }),
            child: const Text('Carregar histórico'),
          ),
          FilledButton.tonal(
            onPressed:
                _busy ||
                    _selected.isEmpty ||
                    _inventory?['destinationConfigured'] != true
                ? null
                : _validate,
            child: const Text('Validar seleção'),
          ),
          FilledButton(
            onPressed: _busy || _preview?['ready'] != true ? null : _execute,
            child: const Text('Migrar selecionados'),
          ),
        ],
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_message.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SelectableText(_message),
        ),
      if (_inventory != null) ...[
        const SizedBox(height: 18),
        SelectableText('Origem: ${_inventory!['sourceDirectory']}'),
        Text(
          'Destino configurado: ${_inventory!['destinationConfigured'] == true ? 'Sim' : 'Não'}',
        ),
        for (final item in records(_inventory!['items']))
          Card(
            child: Column(
              children: [
                CheckboxListTile(
                  value: _selected.contains(item['key']),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          final key = '${item['key']}';
                          if (value == true) {
                            _selected.add(key);
                          } else {
                            _selected.remove(key);
                            _overwrite.remove(key);
                          }
                          _preview = null;
                        }),
                  title: Text(
                    '${item['courseName']} · ${item['kind']} ${item['semester'] ?? ''}',
                  ),
                  subtitle: Text(
                    '${item['sourceFile']} · ${item['records']} registros',
                  ),
                ),
                if (_selected.contains(item['key']))
                  CheckboxListTile(
                    value: _overwrite.contains(item['key']),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            value == true
                                ? _overwrite.add('${item['key']}')
                                : _overwrite.remove('${item['key']}');
                            _preview = null;
                          }),
                    title: const Text(
                      'Autorizar substituição se o destino for diferente',
                    ),
                  ),
              ],
            ),
          ),
        ExpansionTile(
          title: const Text('Arquivos ausentes ou ignorados'),
          children: [
            SelectableText(
              prettyJson({
                'missing': _inventory!['missing'],
                'ignoredFiles': _inventory!['ignoredFiles'],
              }),
            ),
          ],
        ),
      ],
      if (_preview != null) ...[
        const SizedBox(height: 18),
        Text(
          'Prévia: ${_preview!['ready'] == true ? 'Pronta' : 'Resolva os problemas'}',
        ),
        for (final item in records(_preview!['items']))
          ExpansionTile(
            title: Text(
              '${item['courseName']} · ${item['kind']} · ${item['status']}',
            ),
            subtitle: Text(
              '${item['records']} → ${item['destinationRecords']} registros no destino',
            ),
            children: [
              SelectableText(
                prettyJson({
                  'problems': item['problems'],
                  'warnings': item['warnings'],
                  'changes': item['changes'],
                }),
              ),
            ],
          ),
        if ((_preview!['errors'] as List? ?? []).isNotEmpty)
          SelectableText(prettyJson(_preview!['errors'])),
      ],
      if (_total > 0)
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text('$_done de $_total cursos processados'),
              LinearProgressIndicator(value: _done / _total),
            ],
          ),
        ),
      if (_run != null)
        ListTile(
          title: Text('Última execução: ${_run!['status']}'),
          subtitle: Text('${_run!['id']}'),
          trailing: IconButton(
            tooltip: 'Baixar relatório',
            onPressed: _busy ? null : () => _report('${_run!['id']}'),
            icon: const Icon(Icons.download),
          ),
        ),
      for (final run in _runs)
        ListTile(
          title: Text('${run['status']} · ${run['created_at']}'),
          subtitle: Text('${run['id']}'),
          trailing: IconButton(
            tooltip: 'Baixar relatório',
            onPressed: _busy ? null : () => _report('${run['id']}'),
            icon: const Icon(Icons.download),
          ),
        ),
    ],
  );
}
