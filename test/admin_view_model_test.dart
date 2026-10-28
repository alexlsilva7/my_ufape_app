import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:my_ufape/app/app_repositories.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/core/data_source.dart';
import 'package:my_ufape/data/repositories/unavailable_remote_repositories.dart';
import 'package:my_ufape/domain/repositories/admin_repository.dart';
import 'package:my_ufape/domain/repositories/auth_repository.dart';
import 'package:my_ufape/domain/repositories/extraction_repository.dart';
import 'package:my_ufape/domain/repositories/feedback_repository.dart';
import 'package:my_ufape/domain/repositories/migration_repository.dart';
import 'package:my_ufape/features/admin/admin_view_model.dart';
import 'package:my_ufape/features/admin/widgets/admin_feedback.dart';
import 'package:my_ufape/features/admin/widgets/admin_migration.dart';

import 'course_editor_view_model_test.dart' show EditorCourses;
import 'repositories_test.dart' show MemoryStorage;
import 'test_state.dart';

class Session implements AuthRepository {
  Completer<void>? signingIn;
  Object? signOutFailure;
  int signIns = 0, signOuts = 0, clears = 0, disposals = 0;
  @override
  bool get configured => true;
  @override
  Future<void> signIn(String email, String password) async {
    signIns++;
    await signingIn?.future;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    if (signOutFailure != null) throw signOutFailure!;
  }

  @override
  Future<String?> token() async => null;
  @override
  void clear() => clears++;
  @override
  void dispose() => disposals++;
}

class Administration implements AdminRepository {
  Completer<JsonMap>? configurationResult;
  JsonMap config = {'authRequired': true, 'authConfigured': true};
  Object? validationFailure;
  int reads = 0, validations = 0;
  @override
  Future<JsonMap> configuration() async {
    reads++;
    return configurationResult?.future ?? config;
  }

  @override
  Future<void> validateSession() async {
    validations++;
    if (validationFailure != null) throw validationFailure!;
  }
}

class Extraction implements ExtractionRepository {
  Future<JsonMap> Function(JsonMap)? onStart;
  Future<JsonMap> Function(String)? onGet;
  Future<JsonMap> Function(ExtractionMode, JsonMap)? onResume;
  final starts = <JsonMap>[];
  final polls = <String>[];
  final resumes = <(ExtractionMode, JsonMap)>[];
  @override
  Future<JsonMap> start(JsonMap input) async {
    starts.add(input);
    return onStart == null ? {'token': input['token']} : onStart!(input);
  }

  @override
  Future<JsonMap> get(String token) async {
    polls.add(token);
    return onGet == null
        ? {'token': token, 'mode': 'tree', 'status': 'running'}
        : onGet!(token);
  }

  @override
  Future<JsonMap> resume(ExtractionMode mode, JsonMap input) async {
    resumes.add((mode, input));
    return onResume == null ? {'subjects': []} : onResume!(mode, input);
  }
}

class Inbox implements FeedbackRepository {
  Completer<JsonMap>? pending;
  Object? readFailure, writeFailure;
  int reads = 0, writes = 0;
  JsonMap item = {'id': 'one', 'status': 'new', 'internal_notes': ''};
  @override
  Future<void> submit(JsonMap feedback) async {}
  @override
  Future<JsonMap> list({
    String category = '',
    String status = '',
    String course = '',
    int offset = 0,
  }) async {
    reads++;
    if (readFailure != null) throw readFailure!;
    return pending?.future ??
        {
          'items': [item],
          'total': 1,
        };
  }

  @override
  Future<JsonMap> update(
    String id, {
    required String status,
    required String notes,
  }) async {
    writes++;
    if (writeFailure != null) throw writeFailure!;
    item = {'id': id, 'status': status, 'internal_notes': notes};
    return {'item': item};
  }
}

class Migration implements MigrationRepository {
  final calls = <String>[];
  Completer<void>? importing;
  Object? historyFailure;
  final preview = <String, dynamic>{
    'ready': true,
    'fingerprint': 'checked',
    'items': [
      {'key': 'bcc'},
    ],
    'selectedCourseIds': ['bcc', 'other'],
  };
  @override
  Future<JsonMap> inventory() async => {
    'destinationConfigured': true,
    'items': [
      {'key': 'bcc'},
    ],
  };
  @override
  Future<JsonMap> validate(JsonMap selection) async => preview;
  @override
  Future<JsonMap> start(JsonMap selection) async {
    calls.add('start');
    expect(selection['fingerprint'], 'checked');
    return {'id': 'run', 'status': 'running'};
  }

  @override
  Future<void> importCourse(String runId, String courseId) async {
    calls.add(courseId);
    await importing?.future;
    if (courseId == 'other') throw StateError('course failed');
  }

  @override
  Future<JsonMap> get(String runId) async => {
    'run': {'id': runId, 'status': 'partial'},
  };
  @override
  Future<JsonMap> list() async {
    if (historyFailure != null) throw historyFailure!;
    return {'runs': []};
  }

  @override
  Future<JsonMap> report(String runId) async => {'id': runId};
}

class Harness {
  Harness({
    Duration pollingInterval = const Duration(days: 1),
    FeedbackRepository? feedback,
    MigrationRepository? migrations,
  }) {
    final repositories = AppRepositories(
      source: DataSource.local,
      localStorage: MemoryStorage(),
      courses: courses,
    );
    state = createAppState(repositories: repositories);
    final scope = AdminRepositories(
      auth: auth,
      admin: admin,
      courses: courses,
      feedback: feedback ?? repositories.feedback,
      extraction: extraction,
      migrations: migrations ?? UnavailableMigrationRepository(),
    );
    final editor = CourseEditorViewModel(courses);
    model = AdminViewModel(
      appRepositories: repositories,
      academicContext: state.context,
      adminRepositories: scope,
      editor: editor,
      disposeScope: () {
        editor.dispose();
        scope.dispose();
      },
      tokenFactory: () => 'generated-token',
      pollingInterval: pollingInterval,
    );
  }
  final auth = Session();
  final admin = Administration();
  final extraction = Extraction();
  final courses = EditorCourses();
  late final AppState state;
  late final AdminViewModel model;
  void dispose() {
    model.dispose();
    state.dispose();
  }
}

void main() {
  testWidgets('migration UI validates selection and waits for confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = Migration();
    final h = Harness(migrations: repo);
    addTearDown(h.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: h.model,
            builder: (_, _) => AdminMigration(viewModel: h.model),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile).first);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    final validate = find.text('Validar seleção');
    await tester.ensureVisible(validate);
    await tester.tap(validate);
    await tester.pumpAndSettle();
    final execute = find.text('Migrar selecionados');
    await tester.ensureVisible(execute);
    await tester.tap(execute);
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    await tester.tap(execute);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: execute),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, ['start', 'bcc', 'other']);
    expect(h.model.migrationRun?['status'], 'partial');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  Future<void> prepareMigration(AdminViewModel model) async {
    await model.analyzeMigration();
    model.selectMigrationItem('bcc', true);
    await model.validateMigration();
  }

  test(
    'migration rejects changed confirmation and keeps immutable previews',
    () async {
      final repo = Migration();
      final h = Harness(migrations: repo);
      addTearDown(h.dispose);
      await prepareMigration(h.model);
      final preview = h.model.migrationPreview!;
      expect(() => preview['ready'] = false, throwsUnsupportedError);
      expect(() => h.model.migrationSelected.clear(), throwsUnsupportedError);
      h.model.selectMigrationItem('bcc', true, overwrite: true);
      await h.model.executeMigration(preview);
      expect(repo.calls, isEmpty);
      expect(h.model.migrationMessage, contains('seleção mudou'));
    },
  );

  test(
    'migration reports partial failures and keeps the run when history fails',
    () async {
      final repo = Migration()..historyFailure = StateError('history offline');
      final h = Harness(migrations: repo);
      addTearDown(h.dispose);
      await prepareMigration(h.model);
      await h.model.executeMigration(h.model.migrationPreview!);
      expect(repo.calls, ['start', 'bcc', 'other']);
      expect(h.model.migrationRun?['status'], 'partial');
      expect(h.model.migrationDone, 2);
      expect(h.model.migrationTotal, 2);
      expect(h.model.migrationMessage, contains('other:'));
      expect(h.model.migrationMessage, contains('histórico'));
      expect(h.model.migrationBusy, isFalse);
      expect(h.model.migrationPreview, isNull);
    },
  );

  test('migration blocks duplicate execution and stops issuing requests on disposal', () async {
    final repo = Migration()..importing = Completer();
    final h = Harness(migrations: repo);
    addTearDown(h.dispose);
    await prepareMigration(h.model);
    var notifications = 0;
    h.model.addListener(() => notifications++);
    final preview = h.model.migrationPreview!;
    final operation = h.model.executeMigration(preview);
    await Future<void>.delayed(Duration.zero);
    expect(h.model.isBusy, isTrue);
    await h.model.executeMigration(preview);
    h.model.selectMigrationItem('bcc', false);
    expect(h.model.migrationSelected, contains('bcc'));
    h.model.dispose();
    final previous = notifications;
    repo.importing!.complete();
    await operation;
    expect(repo.calls, ['start', 'bcc']);
    expect(notifications, previous);
  });

  testWidgets(
    'feedback form retains failed notes and clears dirty state after a confirmed save',
    (tester) async {
      final inbox = Inbox();
      final h = Harness(feedback: inbox);
      addTearDown(h.dispose);
      var dirty = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: h.model,
              builder: (_, _) => AdminFeedback(
                viewModel: h.model,
                courses: const [],
                onStateChanged: (value, _) => dirty = value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      final notes = find.widgetWithText(TextField, 'Notas internas');
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Keep these notes');
      await tester.pumpAndSettle();
      expect(dirty, isTrue);
      final save = find.widgetWithText(FilledButton, 'Salvar feedback');
      await tester.ensureVisible(save);
      inbox.writeFailure = StateError('denied');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(notes).controller!.text,
        'Keep these notes',
      );
      expect(dirty, isTrue);
      inbox.writeFailure = null;
      inbox.readFailure = StateError('refresh offline');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(dirty, isFalse);
      expect(inbox.item['internal_notes'], 'Keep these notes');
      await tester.drag(find.byType(ListView), const Offset(0, 1500));
      await tester.pumpAndSettle();
      expect(find.textContaining('Feedback salvo, mas'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'feedback refresh failure preserves the confirmed save and allows retry',
    () async {
      final inbox = Inbox();
      final h = Harness(feedback: inbox);
      addTearDown(h.dispose);
      expect(await h.model.loadFeedback(), isTrue);
      expect(
        () => h.model.feedbackItems.first['status'] = 'invalid',
        throwsUnsupportedError,
      );
      inbox.readFailure = StateError('offline');
      final saved = await h.model.saveFeedback(
        'one',
        status: 'resolved',
        notes: 'Done',
      );
      expect(saved?['internal_notes'], 'Done');
      expect(h.model.feedbackItems.single['status'], 'resolved');
      expect(h.model.feedbackMessage, contains('Feedback salvo'));
      expect(h.model.feedbackFailure?.cause, same(inbox.readFailure));
      expect(h.model.feedbackBusy, isFalse);
      inbox.readFailure = null;
      expect(await h.model.loadFeedback(), isTrue);
      expect(h.model.feedbackFailure, isNull);
    },
  );

  test('feedback write failure preserves the original item', () async {
    final inbox = Inbox();
    final h = Harness(feedback: inbox);
    addTearDown(h.dispose);
    await h.model.loadFeedback();
    inbox.writeFailure = StateError('write denied');
    expect(
      await h.model.saveFeedback('one', status: 'resolved', notes: 'Draft'),
      isNull,
    );
    expect(h.model.feedbackItems.single['status'], 'new');
    expect(h.model.feedbackFailure?.cause, same(inbox.writeFailure));
    expect(h.model.feedbackBusy, isFalse);
  });

  test(
    'feedback requests deduplicate and ignore results after disposal',
    () async {
      final inbox = Inbox()..pending = Completer();
      final h = Harness(feedback: inbox);
      addTearDown(h.dispose);
      var notifications = 0;
      h.model.addListener(() => notifications++);
      final read = h.model.loadFeedback();
      expect(await h.model.loadFeedback(), isFalse);
      expect(
        await h.model.saveFeedback('one', status: 'new', notes: ''),
        isNull,
      );
      expect(inbox.reads, 1);
      expect(inbox.writes, 0);
      h.model.dispose();
      final before = notifications;
      inbox.pending!.complete({
        'items': [inbox.item],
        'total': 1,
      });
      expect(await read, isFalse);
      expect(h.model.feedbackItems, isEmpty);
      expect(notifications, before);
    },
  );

  test(
    'failed logout clears credentials while preserving the login failure',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      final cause = StateError('not an administrator');
      h.admin.validationFailure = cause;
      h.auth.signOutFailure = StateError('logout offline');
      expect(await h.model.login('admin@example.test', 'password'), isFalse);
      expect(h.model.failure?.cause, same(cause));
      expect(h.model.authorized, isFalse);
      expect(h.auth.clears, 1);
      expect(h.model.isBusy, isFalse);
    },
  );

  test('import review validates without changing the draft and blocks invalid data', () async {
    final h = Harness();
    addTearDown(h.dispose);
    (await h.model.loadCourse('bcc')).getOrThrow();
    final preview = h.model.prepareImport([
      {'id': 'bad', 'name': '', 'sessions': []},
    ], schedule: true);
    expect(preview.errors, isNotEmpty);
    expect(preview.canApply, isFalse);
    expect(h.model.applyImport(preview), isFalse);
    expect(h.model.hasPendingChanges, isFalse);
    expect(() => preview.errors.clear(), throwsUnsupportedError);
    expect(
      () => h.model.prepareImport({'invalid': []}, schedule: false),
      throwsFormatException,
    );
  });

  test('import review snapshots input and includes semester and extraction changes', () async {
    final h = Harness();
    addTearDown(h.dispose);
    (await h.model.loadCourse('bcc')).getOrThrow();
    final input = <String, dynamic>{
      'semester': '2026.2',
      'schedule': [],
      '_extraction': {'source': 'original'},
    };
    final preview = h.model.prepareImport(input, schedule: true);
    expect(h.model.semester, '2026.1');
    expect(preview.canApply, isTrue);
    input['semester'] = '2027.1';
    (input['_extraction'] as Map)['source'] = 'modified';
    expect(h.model.applyImport(preview), isTrue);
    expect(h.model.semester, '2026.2');
    expect(h.model.course['scheduleExtraction']['source'], 'original');
    expect(h.model.hasPendingChanges, isTrue);
    expect(h.courses.submitted, isEmpty);
    final unchanged = h.model.prepareImport({
      'semester': '2026.2',
      'schedule': [],
      '_extraction': {'source': 'original'},
    }, schedule: true);
    expect(unchanged.canApply, isFalse);
  });

  test('import merge preserves existing fields and rejects a stale or foreign preview', () async {
    final h = Harness();
    addTearDown(h.dispose);
    (await h.model.loadCourse('bcc')).getOrThrow();
    h.model.replaceCurriculum({
      'subjects': [
        {'id': 'one', 'name': 'Original', 'code': 'ONE'},
      ],
    });
    final input = {
      'subjects': [
        {'id': 'one', 'name': 'Updated'},
        {'id': 'two', 'name': 'New', 'code': 'TWO'},
      ],
    };
    final preview = h.model.prepareImport(input, schedule: false, merge: true);
    expect(h.model.applyImport(preview), isTrue);
    expect(h.model.curriculum['subjects'], [
      {'id': 'one', 'name': 'Updated', 'code': 'ONE'},
      {'id': 'two', 'name': 'New', 'code': 'TWO'},
    ]);
    final stale = h.model.prepareImport({'subjects': []}, schedule: false);
    h.model.setCurriculumField('title', 'Edited after review');
    expect(h.model.applyImport(stale), isFalse);
    expect(h.model.curriculum['title'], 'Edited after review');
    expect(h.model.message, contains('rascunho mudou'));
    final current = h.model.prepareImport({'subjects': []}, schedule: false);
    (await h.model.loadCourse('bcc')).getOrThrow();
    expect(h.model.applyImport(current), isFalse);
    final other = Harness();
    addTearDown(other.dispose);
    (await other.model.loadCourse('bcc')).getOrThrow();
    expect(other.model.applyImport(current), isFalse);
  });

  test(
    'initialization deduplicates requests and retains a retryable failure',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      h.admin.configurationResult = Completer();
      final cause = StateError('configuration offline');
      final stack = StackTrace.fromString('configuration origin');
      final first = h.model.initialize();
      final second = h.model.initialize();
      expect(h.admin.reads, 1);
      h.admin.configurationResult!.completeError(cause, stack);
      await Future.wait([first, second]);
      expect(h.model.initializing, isFalse);
      expect(h.model.authorized, isFalse);
      expect(h.model.failure?.cause, same(cause));
      expect(
        h.model.failure?.stackTrace.toString(),
        contains('configuration origin'),
      );
      expect(h.model.hasPendingChanges, isFalse);

      h.admin.configurationResult = null;
      h.admin.config = {'authRequired': false};
      await h.model.initialize();
      expect(h.model.authorized, isTrue);
      expect(h.model.courses, hasLength(1));
      expect(h.model.failure, isNull);
    },
  );

  test(
    'failed session validation signs out and allows a subsequent login',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      final failure = StateError('not an administrator');
      h.admin.validationFailure = failure;
      expect(await h.model.login('admin@example.test', 'password'), isFalse);
      expect(h.model.authorized, isFalse);
      expect(h.model.isBusy, isFalse);
      expect(h.model.failure?.cause, same(failure));
      expect(h.auth.signOuts, 1);
      h.admin.validationFailure = null;
      expect(await h.model.login('admin@example.test', 'password'), isTrue);
      expect(h.model.authorized, isTrue);
      expect(h.model.hasPendingChanges, isFalse);
    },
  );

  test('disposing during authentication prevents further requests and notifications', () async {
    final h = Harness();
    addTearDown(h.dispose);
    h.auth.signingIn = Completer();
    var notifications = 0;
    h.model.addListener(() => notifications++);
    final loggingIn = h.model.login('admin@example.test', 'password');
    h.model.dispose();
    final previous = notifications;
    h.auth.signingIn!.complete();
    expect(await loggingIn, isFalse);
    expect(h.admin.validations, 0);
    expect(notifications, previous);
    expect(h.auth.disposals, 1);
  });

  test('start snapshots input, blocks duplicates and uses the server extraction mode', () async {
    final h = Harness();
    addTearDown(h.dispose);
    final start = Completer<JsonMap>();
    final resume = Completer<JsonMap>();
    h.extraction.onStart = (_) => start.future;
    h.extraction.onGet = (token) async => {'token': token, 'mode': 'schedule'};
    h.extraction.onResume = (_, _) => resume.future;
    final files = <JsonMap>[
      {'fileName': 'schedule.pdf', 'base64Data': 'data'},
    ];
    final operation = h.model.startExtraction(
      files: files,
      textContent: '',
      model: 'model-a',
    );
    await h.model.startExtraction(
      files: files,
      textContent: '',
      model: 'model-b',
    );
    files.first['fileName'] = 'changed.pdf';
    expect(h.extraction.starts, hasLength(1));
    expect(
      h.extraction.starts.single['input']['files'][0]['fileName'],
      'schedule.pdf',
    );
    expect(h.model.resumeToken, 'generated-token');
    expect(h.model.extracting, isTrue);
    start.complete({'token': 'generated-token'});
    await Future<void>.delayed(Duration.zero);
    expect(h.extraction.resumes.single.$1, ExtractionMode.schedule);
    resume.complete({'disciplines': []});
    await operation;
    expect(h.model.resultMode, 'schedule');
    expect(h.model.extracted, {'disciplines': []});
    expect(h.model.extracting, isFalse);
    expect(
      () => h.model.extracted!['disciplines'].add('mutation'),
      throwsUnsupportedError,
    );
  });

  test('poll errors preserve the snapshot, and interrupted extraction can be resumed', () async {
    final h = Harness();
    addTearDown(h.dispose);
    final initialPoll = Completer<JsonMap>();
    final resume = Completer<JsonMap>();
    h.extraction.onGet = (_) => initialPoll.future;
    h.extraction.onResume = (_, _) => resume.future;
    final operation = h.model.resumeExtraction(token: 'token-a', model: '');
    await h.model.refreshExtraction();
    expect(h.extraction.polls, ['token-a']);
    initialPoll.complete({
      'token': 'token-a',
      'mode': 'linear',
      'completedCalls': 3,
    });
    await Future<void>.delayed(Duration.zero);
    h.extraction.onGet = (_) async => throw StateError('poll offline');
    await h.model.refreshExtraction();
    expect(h.model.snapshot?['completedCalls'], 3);
    expect(h.model.monitorError, contains('poll offline'));
    final failure = StateError('resume offline');
    resume.completeError(failure);
    await operation;
    expect(h.model.failure?.cause, same(failure));
    expect(h.model.resumeToken, 'token-a');
    expect(h.model.extracting, isFalse);

    h.extraction.onGet = (token) async => {'token': token, 'mode': 'linear'};
    h.extraction.onResume = (_, _) async => {'subjects': []};
    await h.model.resumeExtraction(token: 'token-a', model: '');
    expect(h.model.failure, isNull);
    expect(h.model.monitorError, isEmpty);
    expect(h.model.extracted, {'subjects': []});
  });

  test('a late status response cannot overwrite a newer extraction', () async {
    final h = Harness();
    addTearDown(h.dispose);
    final firstResume = Completer<JsonMap>();
    final stalePoll = Completer<JsonMap>();
    h.extraction.onResume = (_, input) => input['resumeToken'] == 'token-a'
        ? firstResume.future
        : Future.value({'result': 'token-b'});
    final first = h.model.resumeExtraction(token: 'token-a', model: '');
    await Future<void>.delayed(Duration.zero);
    h.extraction.onGet = (token) => token == 'token-a'
        ? stalePoll.future
        : Future.value({'token': token, 'mode': 'schedule'});
    final pendingStatus = h.model.refreshExtraction();
    firstResume.complete({'result': 'token-a'});
    await first;
    await h.model.resumeExtraction(token: 'token-b', model: '');
    stalePoll.complete({'token': 'token-a', 'mode': 'tree'});
    await pendingStatus;
    expect(h.model.snapshot?['token'], 'token-b');
    expect(h.model.extracted?['result'], 'token-b');
    expect(h.model.resultMode, 'schedule');
  });

  testWidgets('disposal stops polling and ignores pending extraction results', (
    tester,
  ) async {
    final h = Harness(pollingInterval: const Duration(seconds: 3));
    addTearDown(h.dispose);
    final resume = Completer<JsonMap>();
    h.extraction.onResume = (_, _) => resume.future;
    var notifications = 0;
    h.model.addListener(() => notifications++);
    final operation = h.model.resumeExtraction(token: 'token-a', model: '');
    await tester.pump();
    expect(h.extraction.polls, hasLength(1));
    await tester.pump(const Duration(seconds: 3));
    expect(h.extraction.polls, hasLength(2));
    h.model.dispose();
    final previous = notifications;
    await tester.pump(const Duration(seconds: 9));
    resume.complete({'subjects': []});
    await tester.pump();
    await operation;
    expect(h.extraction.polls, hasLength(2));
    expect(h.model.extracted, isNull);
    expect(notifications, previous);
  });
}
