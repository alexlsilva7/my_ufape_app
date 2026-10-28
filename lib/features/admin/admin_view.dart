import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../services/files.dart';
import '../../data/parsers/admin_data.dart';
import 'admin_view_model.dart';
import '../../app/admin_navigation_guard.dart';
import 'widgets/admin_components.dart';
import 'widgets/admin_confirmation_dialog.dart';
import 'widgets/admin_login_form.dart';
import 'widgets/admin_import_section.dart';
import 'widgets/admin_import_review_dialog.dart';
import 'widgets/admin_dashboard.dart';
import 'widgets/admin_workspace.dart';
import 'widgets/admin_course_settings.dart';
import 'widgets/admin_record_filters.dart';
import 'widgets/admin_records_section.dart';
import 'widgets/admin_structure_section.dart';

export '../../app/admin_navigation_guard.dart' show AdminNavigationGuard;

class AdminView extends StatefulWidget {
  const AdminView({super.key, required this.viewModel});
  final AdminViewModel viewModel;
  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  AdminViewModel get _model => widget.viewModel;
  String _lastResumeToken = '';
  bool _syncingFields = false, _confirming = false;
  int _feedbackRevision = 0;
  String get _id => _model.id;
  bool get _creating => _model.creating;
  List<Json> get _courses => _model.courses;
  List<Json> get _schedule => _model.schedule;
  Json get _course => _model.course;
  Json get _curriculum => _model.curriculum;
  final _email = TextEditingController(), _password = TextEditingController();
  final _name = TextEditingController(),
      _short = TextEditingController(),
      _idInput = TextEditingController();
  final _semester = TextEditingController(), _search = TextEditingController();
  final _paste = TextEditingController(),
      _sourceText = TextEditingController(),
      _modelName = TextEditingController();
  final _resume = TextEditingController();
  bool get _busy => _model.isBusy;
  bool get _initializing => _model.initializing;
  bool get _authorized => _model.authorized;
  String get _message => _model.message;
  set _message(String value) => _model.showMessage(value);
  String _section = 'dashboard', _profile = '', _period = '';
  String _importTarget = 'curriculum';
  String get _extractMode => _model.extractionMode;
  String get _resultMode => _model.resultMode;
  Json get _pipeline => _model.pipeline;
  final List<Json> _files = [];
  Json? get _snapshot => _model.snapshot;
  Json? get _extracted => _model.extracted;
  bool get _extracting => _model.extracting;
  bool _feedbackDirty = false, _feedbackSaving = false;
  String get _monitorError => _model.monitorError;

  @override
  void initState() {
    super.initState();
    _model.addListener(_modelChanged);
    for (final controller in [_idInput, _name, _short, _semester]) {
      controller.addListener(_fieldsChanged);
    }
    AdminNavigationGuard.check = _canLeave;
    _initialize();
  }

  @override
  void dispose() {
    AdminNavigationGuard.check = null;
    for (final controller in [_idInput, _name, _short, _semester]) {
      controller.removeListener(_fieldsChanged);
    }
    _model.removeListener(_modelChanged);
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
      _modelName,
      _resume,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    await _model.initialize();
    if (!mounted) return;
    _syncFields();
    _resetFilters();
    if (_creating) setState(() => _section = 'settings');
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    await _model.run(action, success: success);
  }

  Future<void> _login() async {
    final loggedIn = await _model.login(_email.text, _password.text);
    if (!mounted || !loggedIn) return;
    _password.clear();
    _syncFields();
    _resetFilters();
    if (_creating) setState(() => _section = 'settings');
  }

  void _modelChanged() {
    if (!mounted) return;
    if (_lastResumeToken != _model.resumeToken) {
      _lastResumeToken = _model.resumeToken;
      _resume.text = _lastResumeToken;
    }
    setState(() {});
  }

  void _fieldsChanged() {
    if (!_syncingFields) {
      _model.updateFields(
        inputId: _idInput.text,
        name: _name.text,
        shortName: _short.text,
        semester: _semester.text,
      );
    }
  }

  void _syncFields() {
    _syncingFields = true;
    _idInput.text = _model.inputId;
    _name.text = _model.name;
    _short.text = _model.shortName;
    _semester.text = _model.semester;
    _syncingFields = false;
  }

  void _resetFilters() {
    _profile = '';
    _period = '';
    _search.clear();
  }

  Future<void> _reloadCourses() async {
    (await _model.reloadCourses(
      preferredId: widget.viewModel.selectedCourse?.id,
    )).getOrThrow();
    if (!mounted) return;
    _syncFields();
    _resetFilters();
    if (_creating) _section = 'settings';
  }

  Future<void> _loadCourse(String id, {String? semester}) async {
    (await _model.loadCourse(id, semester: semester)).getOrThrow();
    if (!mounted) return;
    _syncFields();
    _resetFilters();
  }

  void _newCourse() {
    _model.newCourse();
    _syncFields();
    _resetFilters();
    _section = 'settings';
  }

  bool get _dirty => _authorized && _model.hasPendingChanges;
  void _editDraft(void Function() action) {
    try {
      action();
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
  }

  Future<bool> _confirm(String title, String body) async {
    if (!mounted || _confirming) return false;
    _confirming = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AdminConfirmationDialog(title: title, message: body),
      );
      return mounted && confirmed == true;
    } finally {
      _confirming = false;
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_confirming || _busy || _extracting || _feedbackSaving) return;
    if ((!_dirty && !_feedbackDirty) ||
        await _confirm(
          'Alterações não salvas',
          'Descartar o rascunho e as notas pendentes antes de continuar?',
        )) {
      if (mounted && !_busy && !_extracting && !_feedbackSaving) {
        setState(() {
          if (_feedbackDirty) _feedbackRevision++;
          _feedbackDirty = false;
        });
        await _run(action);
      }
    }
  }

  Future<bool> _canLeave() async {
    if (!mounted || _confirming) return false;
    if (_extracting || _busy || _feedbackSaving) {
      setState(
        () => _message = 'Aguarde a operação em andamento antes de sair.',
      );
      return false;
    }
    if (!_authorized) return true;
    final allowed =
        (!_dirty && !_feedbackDirty) ||
        await _confirm(
          'Alterações não salvas',
          'Descartar o rascunho e as notas pendentes antes de sair?',
        );
    return mounted && allowed && !_busy && !_extracting && !_feedbackSaving;
  }

  Future<void> _navigate(String next) async {
    if (_confirming || _feedbackSaving) return;
    if (_section != next &&
        _feedbackDirty &&
        !await _confirm(
          'Notas não salvas',
          'Descartar as alterações deste feedback?',
        )) {
      return;
    }
    if (mounted && !_feedbackSaving) {
      setState(() {
        if (_section != next) _feedbackDirty = false;
        _section = next;
      });
    }
  }

  Future<void> _save(String domain) =>
      _model.saveCourse(CourseEditDomain.values.byName(domain));

  @override
  Widget build(BuildContext context) {
    if (_initializing) return const Center(child: CircularProgressIndicator());
    if (!_authorized) {
      return AdminLoginForm(
        serverAuthConfigured: _model.authConfigured,
        sessionConfigured: _model.sessionConfigured,
        busy: _busy,
        showRetry: !_model.hasConfiguration,
        message: _message,
        emailController: _email,
        passwordController: _password,
        onLogin: _login,
        onRetry: _initialize,
      );
    }
    final content = _content();
    return PopScope(
      canPop:
          !_dirty &&
          !_busy &&
          !_extracting &&
          !_feedbackDirty &&
          !_feedbackSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && await _canLeave() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AdminWorkspace(
        busy: _busy,
        dirty: _dirty,
        creating: _creating,
        extracting: _extracting,
        isLocal: _model.isLocal,
        courseId: _id,
        courses: _courses,
        message: _message,
        supportsMigration: _model.supportsMigration,
        selectedSection: _section,
        onNavigate: _navigate,
        onChooseCourse: _chooseCourse,
        onSignOut: _signOut,
        onDismissMessage: () => setState(() => _message = ''),
        content: content,
      ),
    );
  }

  void _chooseCourse(String? value) => _guard(() async {
    if (value == '__new__') {
      _newCourse();
    } else if (value != null) {
      await _loadCourse(value);
    }
  });
  void _signOut() => _guard(_model.signOut);

  Widget _saveButton(String domain) => FilledButton.icon(
    onPressed: _busy || _extracting ? null : () => _save(domain),
    icon: const Icon(Icons.save_outlined),
    label: Text(
      _model.isLocal ? 'Salvar neste dispositivo' : 'Salvar no servidor',
    ),
  );
  Widget _content() => switch (_section) {
    'settings' => _settingsView(),
    'catalog' => _recordsView(false),
    'structure' => _structureView(),
    'schedule' => _recordsView(true),
    'import' => _importView(),
    'feedback' => AdminFeedback(
      key: ValueKey(_feedbackRevision),
      viewModel: _model,
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
    'migration' => AdminMigration(viewModel: _model),
    _ => AdminDashboard(
      courseName: _name.text,
      courseCount: _courses.length,
      subjectCount: records(_curriculum['subjects']).length,
      profileCount: records(_curriculum['profiles']).length,
      offeringCount: _schedule.length,
      dataSource: _model.dataSourceLabel,
      isLocal: _model.isLocal,
      onNavigate: (key) => setState(() => _section = key),
    ),
  };

  Widget _settingsView() => AdminCourseSettings(
    creating: _creating,
    busy: _busy,
    course: _course,
    idController: _idInput,
    nameController: _name,
    shortNameController: _short,
    onFieldsChanged: () => setState(() {}),
    onVisibilityChanged: _model.setVisibility,
    onSemesterVisible: _model.setSemesterVisible,
    onPreferSemester: _model.preferSemester,
    onDelete: _deleteCourse,
    saveAction: _saveButton('settings'),
  );
  Future<void> _deleteCourse() async {
    if (await _confirm(
      'Excluir ${_name.text}?',
      'Esta ação remove todos os dados deste curso do servidor.',
    )) {
      await _run(() async {
        (await _model.deleteCourse()).getOrThrow();
        await _reloadCourses();
      }, success: 'Curso excluído.');
    }
  }

  Widget _filters() => AdminRecordFilters(
    searchController: _search,
    selectedProfile: _profile,
    selectedPeriod: _period,
    curriculum: _curriculum,
    onSearchChanged: () => setState(() {}),
    onProfileChanged: (value) => setState(() => _profile = value),
    onPeriodChanged: (value) => setState(() => _period = value),
  );
  Widget _recordsView(bool schedule) => AdminRecordsSection(
    schedule: schedule,
    scheduleRows: _schedule,
    curriculum: _curriculum,
    course: _course,
    searchController: _search,
    selectedProfile: _profile,
    selectedPeriod: _period,
    semesterController: _semester,
    busy: _busy,
    creating: _creating,
    onFieldsChanged: () => setState(() {}),
    onOpenEnteredSemester: _openEnteredSemester,
    onOpenSemester: (semester) =>
        _guard(() => _loadCourse(_id, semester: semester)),
    onEditRecord: (index) => _editRecord(schedule, index: index),
    onDeleteRecord: (index) => _deleteRecord(schedule, index),
    onEditWhole: () => _editWhole(schedule),
    filters: _filters(),
    saveAction: _saveButton(schedule ? 'schedule' : 'curriculum'),
  );
  void _openEnteredSemester() {
    final semester = _semester.text;
    if (!RegExp(r'^\d{4}\.[12]$').hasMatch(semester)) {
      setState(() => _message = 'Use AAAA.1 ou AAAA.2.');
      return;
    }
    _guard(() => _loadCourse(_id, semester: semester));
  }

  Future<void> _deleteRecord(bool schedule, int index) async {
    final list = schedule ? _schedule : records(_curriculum['subjects']);
    final row = list[index];
    final error = _model.recordDeletionError(schedule, index);
    if (error != null) {
      setState(() => _message = error);
      return;
    }
    if (await _confirm(
      'Excluir registro?',
      '${row['name']} será removido do rascunho.',
    )) {
      if (mounted) _editDraft(() => _model.deleteRecord(schedule, index));
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
    _editDraft(() => _model.editRecord(schedule, result, index: index));
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

  Widget _structureView() => AdminStructureSection(
    curriculum: _curriculum,
    selectedProfile: _profile,
    selectedPeriod: _period,
    searchController: _search,
    onEditProfile: _editProfile,
    onEditRequirements: _editRequirements,
    onEditWhole: () => _editWhole(false),
    onDeleteProfile: _deleteProfile,
    onEditLinks: _editLinks,
    onActiveProfileChanged: (id) =>
        setState(() => _model.setCurriculumField('activeProfileId', id)),
    filters: _filters(),
    saveAction: _saveButton('curriculum'),
  );
  Future<void> _editRequirements() async {
    final result = await _jsonDialog(
      'Requisitos e cargas horárias',
      _curriculum['requisitos'] ?? {},
    );
    if (result is Map) {
      _editDraft(() => _model.setCurriculumField('requisitos', result));
    }
  }

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
    if (mounted) {
      _editDraft(
        () => _model.editProfile(
          object(result),
          originalId: profile?['id']?.toString(),
        ),
      );
    }
  }

  Future<void> _deleteProfile(Json profile) async {
    final error = _model.profileDeletionError('${profile['id']}');
    if (error != null) {
      setState(() => _message = error);
      return;
    }
    if (await _confirm(
      'Excluir perfil?',
      'Remove o perfil ${profile['name']} e suas disciplinas do rascunho.',
    )) {
      if (mounted) {
        _editDraft(() {
          _model.deleteProfile('${profile['id']}');
          _profile = '';
        });
      }
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
    if (mounted) {
      _editDraft(() => _model.editLinks('${node['id']}', object(result)));
    }
  }

  Future<void> _reviewImport(
    dynamic incoming, {
    required bool schedule,
    bool merge = false,
  }) async {
    try {
      final preview = _model.prepareImport(
        incoming,
        schedule: schedule,
        merge: merge,
      );
      final apply = await showDialog<bool>(
        context: context,
        builder: (_) => AdminImportReviewDialog(preview: preview),
      );
      if (apply == true && mounted && _model.applyImport(preview)) {
        setState(() {
          _syncFields();
          if (!schedule) _profile = '';
        });
      }
    } catch (error) {
      if (mounted) _model.showMessage('$error');
    }
  }

  Widget _importView() => AdminImportSection(
    importTarget: _importTarget,
    extractMode: _extractMode,
    supportsExtraction: _model.supportsExtraction,
    busy: _busy,
    extracting: _extracting,
    pasteController: _paste,
    modelController: _modelName,
    sourceTextController: _sourceText,
    resumeController: _resume,
    files: _files,
    monitorError: _monitorError,
    snapshot: _snapshot,
    extracted: _extracted,
    onTargetChanged: (value) => setState(() => _importTarget = value),
    onModeChanged: _model.setExtractionMode,
    onOpenJson: _openJson,
    onReviewJson: _reviewPastedJson,
    onExport: _exportDraft,
    onEditPipeline: _editPipeline,
    onPickSources: _pickSources,
    onStart: _startExtraction,
    onRemoveFile: (file) => setState(() => _files.remove(file)),
    onResumeChanged: () => setState(() {}),
    onResume: _resumeExtraction,
    onReviewResult: () =>
        _reviewImport(_extracted, schedule: _resultMode == 'schedule'),
    onDownloadResult: () =>
        saveJson('extracao-${_resume.text}.json', _extracted!),
  );
  Future<void> _openJson() async {
    try {
      final text = await importJson();
      if (text != null && mounted) setState(() => _paste.text = text);
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
  }

  void _reviewPastedJson(bool merge) {
    try {
      _reviewImport(
        jsonDecode(_paste.text),
        schedule: _importTarget == 'schedule',
        merge: merge,
      );
    } catch (error) {
      setState(() => _message = 'JSON inválido: $error');
    }
  }

  Future<void> _exportDraft() => _run(
    () => saveJson(
      '$_id-${_importTarget == 'schedule' ? _semester.text : 'curriculo'}.json',
      _importTarget == 'schedule'
          ? {'semester': _semester.text, 'disciplines': _schedule}
          : _curriculum,
    ),
  );
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
    try {
      _model.setPipeline(object(result));
    } catch (error) {
      _model.showMessage('$error');
    }
  }

  Future<void> _startExtraction() => _model.startExtraction(
    files: _files,
    textContent: _sourceText.text,
    model: _modelName.text,
  );

  Future<void> _resumeExtraction() =>
      _model.resumeExtraction(token: _resume.text, model: _modelName.text);
}
