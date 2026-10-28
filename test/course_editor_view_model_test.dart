import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/core/exceptions/app_exception.dart';
import 'package:my_ufape/core/models.dart';
import 'package:my_ufape/features/admin/admin_view_model.dart';

import 'repositories_test.dart' show StubCourses;

JsonMap document(String id) => {
  'course': {
    'id': id,
    'name': 'Course $id',
    'shortName': id,
    'semesters': ['2026.1'],
    'visibleSemesters': ['2026.1'],
  },
  'curriculum': {'subjects': [], 'profiles': []},
  'schedule': [],
  'resolvedSemester': '2026.1',
};

class EditorCourses extends StubCourses {
  final documents = <String, JsonMap>{'bcc': document('bcc')};
  final calls = <String>[];
  final submitted = <JsonMap>[];
  final pendingLoads = <String, Completer<JsonMap>>{};
  Completer<void>? writing;
  Object? writeFailure, visibilityFailure, listFailure;
  @override
  Future<JsonMap> list() async {
    if (listFailure != null) throw listFailure!;
    return {'courses': documents.values.map((data) => data['course']).toList()};
  }

  @override
  Future<JsonMap> getDocument(
    String id, {
    String? semester,
    bool strict = false,
    bool academicOnly = false,
  }) async => pendingLoads[id]?.future ?? documents[id]!;
  @override
  Future<void> save(JsonMap course) async {
    calls.add('save');
    submitted.add(course);
    await writing?.future;
    if (writeFailure != null) throw writeFailure!;
    documents.putIfAbsent(course['id'], () => document(course['id']));
  }

  @override
  Future<void> updateMetadata(String id, JsonMap metadata) async {
    calls.add('metadata');
    submitted.add(metadata);
    await writing?.future;
    if (writeFailure != null) throw writeFailure!;
  }

  @override
  Future<void> updateVisibility(String id, JsonMap visibility) async {
    calls.add('visibility');
    if (visibilityFailure != null) throw visibilityFailure!;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete');
    if (writeFailure != null) throw writeFailure!;
    documents.remove(id);
  }
}

void main() {
  late EditorCourses repository;
  late CourseEditorViewModel vm;
  setUp(() {
    repository = EditorCourses();
    vm = CourseEditorViewModel(repository);
  });
  tearDown(() => vm.dispose());
  Future<void> load() async =>
      (await vm.reloadCourses(preferredId: 'bcc')).getOrThrow();

  test('new and untouched drafts stay clean and failed initial load creates no phantom draft', () async {
    repository.listFailure = StateError('offline');
    expect((await vm.reloadCourses()).isError(), isTrue);
    expect(vm.hasPendingChanges, isFalse);
    expect(vm.isLoading, isFalse);
    vm.newCourse();
    expect(vm.creating, isTrue);
    expect(vm.hasPendingChanges, isFalse);
    vm.updateFields(name: 'Novo');
    expect(vm.hasPendingChanges, isTrue);
  });

  test('validation rejects invalid IDs, missing names and duplicate creation before persistence', () async {
    await load();
    vm.newCourse();
    vm.updateFields(inputId: 'INVALID', name: 'New', shortName: 'N');
    expect((await vm.save(CourseEditDomain.settings)).isError(), isTrue);
    vm.updateFields(inputId: 'bcc');
    expect((await vm.save(CourseEditDomain.settings)).isError(), isTrue);
    vm.updateFields(inputId: 'new', name: '');
    expect((await vm.save(CourseEditDomain.settings)).isError(), isTrue);
    vm.updateFields(name: 'New');
    expect((await vm.save(CourseEditDomain.curriculum)).isError(), isTrue);
    expect(repository.calls, isEmpty);
  });

  test('each save marks only its confirmed domain clean', () async {
    await load();
    vm.updateFields(name: 'Changed');
    vm.setCurriculumField('export_date', '2026-10-28');
    expect((await vm.save(CourseEditDomain.settings)).isSuccess(), isTrue);
    expect(vm.isDirty(CourseEditDomain.settings), isFalse);
    expect(vm.isDirty(CourseEditDomain.curriculum), isTrue);
    expect((await vm.save(CourseEditDomain.curriculum)).isSuccess(), isTrue);
    expect(vm.hasPendingChanges, isFalse);
  });

  test(
    'write failure preserves cause, stack and pending edits for retry',
    () async {
      await load();
      vm.updateFields(name: 'Changed');
      final cause = StateError('disk rejected');
      repository.writeFailure = cause;
      final result = await vm.save(CourseEditDomain.settings);
      expect((result.exceptionOrNull() as AppException).cause, same(cause));
      expect(vm.failure?.stackTrace.toString(), isNotEmpty);
      expect(vm.hasPendingChanges, isTrue);
      expect(vm.isSaving, isFalse);
      repository.writeFailure = null;
      expect((await vm.save(CourseEditDomain.settings)).isSuccess(), isTrue);
      expect(vm.hasPendingChanges, isFalse);
    },
  );

  test(
    'partially created course retries visibility without duplicate creation',
    () async {
      vm.newCourse();
      vm.updateFields(inputId: 'new', name: 'New', shortName: 'N');
      repository.visibilityFailure = StateError('visibility rejected');
      expect((await vm.save(CourseEditDomain.settings)).isError(), isTrue);
      expect(vm.id, 'new');
      expect(vm.courses.any((row) => row['id'] == 'new'), isTrue);
      expect(vm.creating, isFalse);
      expect(vm.hasPendingChanges, isTrue);
      repository.visibilityFailure = null;
      expect((await vm.save(CourseEditDomain.settings)).isSuccess(), isTrue);
      expect(repository.calls.where((call) => call == 'save'), hasLength(1));
      expect(vm.hasPendingChanges, isFalse);
    },
  );

  test(
    'pending saves cannot run twice or acknowledge edits made after submission',
    () async {
      await load();
      vm.updateFields(name: 'Submitted');
      repository.writing = Completer<void>();
      final saving = vm.save(CourseEditDomain.settings);
      expect(vm.isSaving, isTrue);
      expect(vm.hasPendingChanges, isTrue);
      expect((await vm.save(CourseEditDomain.settings)).isError(), isTrue);
      vm.updateFields(name: 'Newer draft');
      repository.writing!.complete();
      expect((await saving).isSuccess(), isTrue);
      expect(vm.name, 'Newer draft');
      expect(vm.hasPendingChanges, isTrue);
      expect(repository.submitted.single['name'], 'Submitted');
    },
  );

  test(
    'late loads cannot overwrite a newer selection or a newly started draft',
    () async {
      repository.pendingLoads['bcc'] = Completer<JsonMap>();
      final older = vm.loadCourse('bcc');
      repository.documents['other'] = document('other');
      await vm.loadCourse('other');
      repository.pendingLoads['bcc']!.complete(document('bcc'));
      await older;
      expect(vm.id, 'other');
      repository.pendingLoads['bcc'] = Completer<JsonMap>();
      final late = vm.loadCourse('bcc');
      vm.newCourse();
      vm.updateFields(name: 'New');
      repository.pendingLoads['bcc']!.complete(document('bcc'));
      await late;
      expect(vm.creating, isTrue);
      expect(vm.name, 'New');
    },
  );

  test(
    'normalization failure preserves previous draft and read-only snapshots',
    () async {
      await load();
      vm.updateFields(name: 'Unsaved');
      repository.documents['bad'] = {
        ...document('bad'),
        'curriculum': {
          'subjects': [
            {'id': 'same', 'code': 'A', 'name': 'A'},
            {'id': 'same', 'code': 'B', 'name': 'B'},
          ],
        },
      };
      expect((await vm.loadCourse('bad')).isError(), isTrue);
      expect(vm.id, 'bcc');
      expect(vm.name, 'Unsaved');
      expect(vm.hasPendingChanges, isTrue);
      expect(() => vm.course['name'] = 'external', throwsUnsupportedError);
      expect(
        () => (vm.curriculum['subjects'] as List).clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'schedule validates semester and tracks extraction metadata as pending',
    () async {
      await load();
      vm.updateFields(semester: 'invalid');
      expect((await vm.save(CourseEditDomain.schedule)).isError(), isTrue);
      expect(repository.calls, isEmpty);
      vm.applySchedule([], semester: '2026.2', extraction: {'source': 'new'});
      expect(vm.isDirty(CourseEditDomain.schedule), isTrue);
      expect((await vm.save(CourseEditDomain.schedule)).isSuccess(), isTrue);
      expect(repository.submitted.single['scheduleExtraction'], {
        'source': 'new',
      });
      expect(vm.hasPendingChanges, isFalse);
    },
  );

  test(
    'list refresh failure does not turn a confirmed save into a failed write',
    () async {
      await load();
      vm.updateFields(name: 'Saved');
      repository.listFailure = StateError('list failed');
      expect((await vm.save(CourseEditDomain.settings)).isSuccess(), isTrue);
      expect(vm.hasPendingChanges, isFalse);
      expect(vm.warningMessage, contains('Dados salvos'));
    },
  );

  test('record and profile commands validate stable identifiers outside the screen', () async {
    await load();
    vm.editProfile({'id': 'P1', 'name': 'Perfil', 'subjects': []});
    expect(vm.curriculum['activeProfileId'], 'P1');
    expect(() => vm.editProfile({'id': 'P1'}), throwsFormatException);
    vm.editRecord(true, {'id': 'offer', 'name': 'Oferta', 'sessions': []});
    expect(
      () => vm.editRecord(true, {'id': 'other'}, index: 0),
      throwsFormatException,
    );
    expect(vm.schedule.single['id'], 'offer');
    vm.deleteRecord(true, 0);
    expect(vm.schedule, isEmpty);
    vm.deleteProfile('P1');
    expect(vm.curriculum['profiles'], isEmpty);
  });

  test('failed deletion retains course and draft for retry', () async {
    await load();
    vm.updateFields(name: 'Pending');
    repository.writeFailure = StateError('delete failed');
    expect((await vm.deleteCourse()).isError(), isTrue);
    expect(vm.id, 'bcc');
    expect(vm.hasPendingChanges, isTrue);
  });

  test(
    'disposed editor ignores in-flight completion without notifying',
    () async {
      final local = CourseEditorViewModel(repository);
      repository.pendingLoads['bcc'] = Completer<JsonMap>();
      var notifications = 0;
      local.addListener(() => notifications++);
      final loading = local.loadCourse('bcc');
      local.dispose();
      final before = notifications;
      repository.pendingLoads['bcc']!.complete(document('bcc'));
      await loading;
      expect(notifications, before);
    },
  );
  test(
    'dirty cache remains exact after undo and independent domain mutations',
    () async {
      await load();
      final name = vm.name, semester = vm.semester;
      vm.updateFields(name: 'Changed');
      expect(vm.isDirty(CourseEditDomain.settings), isTrue);
      for (var i = 0; i < 1000; i++) {
        expect(vm.hasPendingChanges, isTrue);
      }
      vm.updateFields(name: name);
      expect(vm.hasPendingChanges, isFalse);
      vm.updateFields(semester: '2026.2');
      expect(vm.isDirty(CourseEditDomain.schedule), isTrue);
      vm.updateFields(semester: semester);
      expect(vm.hasPendingChanges, isFalse);
      vm.setVisibility('hidden', true);
      expect(vm.isDirty(CourseEditDomain.settings), isTrue);
      vm.setVisibility('hidden', null);
      expect(vm.hasPendingChanges, isFalse);
      final original = vm.curriculum;
      vm.setCurriculumField('export_date', 'today');
      expect(vm.isDirty(CourseEditDomain.curriculum), isTrue);
      vm.replaceCurriculum(original);
      expect(vm.hasPendingChanges, isFalse);
      vm.editRecord(true, {'id': 'offer', 'name': 'Offer', 'sessions': []});
      expect(vm.isDirty(CourseEditDomain.schedule), isTrue);
      vm.deleteRecord(true, 0);
      expect(vm.hasPendingChanges, isFalse);
    },
  );
}
