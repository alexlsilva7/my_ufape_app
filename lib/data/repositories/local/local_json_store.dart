import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models.dart';
import '../../../domain/repositories/local_storage_repository.dart';
import '../../academic_data_store.dart';
import '../../academic_batch.dart';

/// One persisted JSON document per data type; assets seed a new device.
class LocalJsonStore implements AcademicDataStore, AcademicCourseMetadataStore {
  LocalJsonStore({
    required this.storage,
    Future<String> Function(String)? assetLoader,
  }) : _load = assetLoader ?? rootBundle.loadString;
  final LocalStorageRepository storage;
  final Future<String> Function(String) _load;
  Future<List<JsonMap>>? _registry;
  final _assets = <String, Future<JsonMap>>{};
  final _decoded = <String, (String, List<JsonMap>)>{};
  // All local instances share the queue; recovery cannot race an active batch.
  static Future<void>? _pending;
  static Future<T> _serial<T>(Future<T> Function() action) {
    final previous = _pending;
    final operation = previous == null
        ? Future<T>.sync(action)
        : previous.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  static const journalKey = 'local_data_v1_pending_batch';
  static const _prefix = 'local_data_v1_';
  static const tables = [
    'courses',
    'course_curricula',
    'course_contents',
    'course_schedules',
    'site_feedback',
  ];

  Future<List<JsonMap>> _courses() => _registry ??= _readRegistry();
  Future<List<JsonMap>> _readRegistry() async {
    final registry = jsonDecode(await _load('assets/data/courses.json'));
    return asList(registry is List ? registry : asMap(registry)['courses'])
        .map(asMap)
        .toList();
  }

  Future<JsonMap> _asset(String id) => _assets.putIfAbsent(id, () async {
    String source;
    try {
      source = await _load('assets/data/$id.json');
    } on FlutterError {
      return {};
    } on StateError {
      return {};
    } on Exception {
      return {};
    }
    return asMap(jsonDecode(source));
  });

  static dynamic _copy(dynamic value) => switch (value) {
    Map value => value.map((key, item) => MapEntry(key, _copy(item))),
    List value => value.map(_copy).toList(),
    _ => value,
  };
  Future<List<JsonMap>> _seedRows(String table, {String? courseId}) async {
    if (table == 'site_feedback') return [];
    final courses = await _courses();
    if (table == 'courses') {
      return courses
          .map((course) => {'id': course['id'], 'data': course})
          .toList();
    }
    final selected = courses.where(
      (course) => courseId == null || course['id'] == courseId,
    );
    final documents = await Future.wait(
      selected.map((course) => _asset(textOf(course['id']))),
    );
    final rows = <JsonMap>[];
    for (final (index, course) in selected.indexed) {
      final data = documents[index];
      if (table == 'course_schedules') {
        for (final entry in asMap(data['schedules']).entries) {
          rows.add({
            'course_id': course['id'],
            'semester': entry.key,
            'data': entry.value,
            ...asMap(asMap(data['scheduleMetadata'])[entry.key]),
          });
        }
      } else {
        final key = table == 'course_curricula' ? 'curriculum' : 'contents';
        if (data[key] != null) {
          rows.add({'course_id': course['id'], 'data': data[key]});
        }
      }
    }
    return rows;
  }

  Future<List<JsonMap>> _rows(
    String table,
    Map<String, String> values, {
    Map<String, String> filters = const {},
    List<String>? columns,
  }) async {
    if (!tables.contains(table)) {
      throw ArgumentError('Documento local desconhecido: $table');
    }
    final persisted = values['$_prefix$table'];
    List<JsonMap> rows;
    if (persisted == null) {
      rows = await _seedRows(table, courseId: filters['course_id']);
    } else {
      final cached = _decoded[table];
      if (cached != null && cached.$1 == persisted) {
        rows = cached.$2;
      } else {
        final decoded = jsonDecode(persisted);
        if (decoded is! List) {
          throw FormatException('JSON local inválido: $table');
        }
        rows = decoded.map(asMap).toList();
        _decoded[table] = (persisted, rows);
      }
    }
    // Private decoded documents are never exposed. Only matches/projected fields
    // are copied, without encoding JSON a second time.
    return rows
        .where(
          (row) => filters.entries.every(
            (entry) => textOf(row[entry.key]) == entry.value,
          ),
        )
        .map(
          (row) => asMap(
            _copy(
              columns == null
                  ? row
                  : {
                      for (final key in columns)
                        if (row.containsKey(key)) key: row[key],
                    },
            ),
          ),
        )
        .toList();
  }

  Future<Map<String, String>> _fresh() => switch (storage) {
    ReloadableLocalStorageRepository store => store.readPersisted(),
    _ => storage.readAll(),
  };

  Future<Map<String, String>> _recover() async {
    var values = await _fresh();
    final encoded = values[journalKey];
    if (encoded == null) return values;
    final journal = jsonDecode(encoded);
    if (journal is! Map ||
        journal['version'] != 1 ||
        journal['before'] is! Map) {
      throw const FormatException(
        'Journal acadêmico inválido. Recuperação necessária.',
      );
    }
    final before = asMap(journal['before']);
    if (!before.containsKey('courses') ||
        before.keys.any((key) => !AcademicBatch.tables.contains(key)) ||
        before.values.any((value) => value != null && value is! String)) {
      throw const FormatException(
        'Journal acadêmico inválido. Recuperação necessária.',
      );
    }
    // Validate the complete journal before restoring any key.
    for (final value in before.values) {
      if (value != null && jsonDecode(value) is! List) {
        throw const FormatException('Snapshot de recuperação inválido.');
      }
    }
    for (final entry in before.entries) {
      if (entry.value == null) {
        await storage.remove('$_prefix${entry.key}');
      } else {
        await storage.write('$_prefix${entry.key}', entry.value as String);
      }
    }
    await storage.remove(journalKey);
    values = await _fresh();
    return values;
  }

  @override
  Future<List<JsonMap>> listCourseMetadata() => _serial(() async {
    final values = await _recover();
    final courses = await _rows('courses', values);
    final byCourse = <String, Set<String>>{};
    if (values.containsKey('${_prefix}course_schedules')) {
      for (final row in await _rows(
        'course_schedules',
        values,
        columns: ['course_id', 'semester'],
      )) {
        (byCourse[textOf(row['course_id'])] ??= {}).add(
          textOf(row['semester']),
        );
      }
    }
    return [
      for (final row in courses)
        {
          ...asMap(row['data']),
          'id': row['id'],
          'semesters': {
            ...asList(asMap(row['data'])['semesters']).map(textOf),
            ...?byCourse[textOf(row['id'])],
          }.toList()..sort(),
        },
    ];
  });

  @override
  Future<List<JsonMap>> select(
    String table, {
    Map<String, String> filters = const {},
    List<String>? columns,
  }) {
    final filterSnapshot = Map<String, String>.of(filters);
    final columnSnapshot = columns == null ? null : List<String>.of(columns);
    return _serial(
      () async => _rows(
        table,
        await _recover(),
        filters: filterSnapshot,
        columns: columnSnapshot,
      ),
    );
  }

  @override
  Future<void> writeCourse(String courseId, List<AcademicMutation> changes) {
    final batch = AcademicBatch(courseId, changes);
    return _serial(() async {
      final values = await _recover();
      final documents = <String, List<JsonMap>>{
        for (final table in AcademicBatch.tables)
          table: await _rows(table, values),
      };
      batch.apply(documents);
      final changedTables = <String>{
        'courses',
        ...batch.changes.map((change) => change['table'] as String),
        if (batch.changes.any(
          (change) =>
              change['table'] == 'courses' && change['action'] == 'delete',
        ))
          ...AcademicBatch.tables,
      };
      final before = {
        for (final table in changedTables) table: values['$_prefix$table'],
      };
      // Persist rollback data before publishing any of the new documents.
      await storage.write(
        journalKey,
        jsonEncode({'version': 1, 'before': before}),
      );
      try {
        for (final table in changedTables) {
          await storage.write('$_prefix$table', jsonEncode(documents[table]));
        }
        // Absence of the journal is the commit point, acknowledged by storage.
        await storage.remove(journalKey);
      } catch (error, stack) {
        try {
          await _recover();
        } catch (_) {
          // Keep the durable journal. Reads and subsequent writes fail closed
          // until recovery succeeds, including after process restart.
        }
        Error.throwWithStackTrace(error, stack);
      }
    });
  }

  @override
  Future<void> upsert(String table, JsonMap row) {
    if (AcademicBatch.tables.contains(table)) {
      return writeCourse(textOf(row[table == 'courses' ? 'id' : 'course_id']), [
        AcademicMutation.upsert(table, row),
      ]);
    }
    final copy = asMap(_copy(row));
    return _serial(() async {
      final rows = await _rows(table, await _recover());
      if (textOf(copy['id']).isEmpty) {
        throw const FormatException('Identificador local obrigatório.');
      }
      final index = rows.indexWhere((row) => row['id'] == copy['id']);
      if (index < 0) {
        rows.add(copy);
      } else {
        rows[index] = copy;
      }
      await storage.write('$_prefix$table', jsonEncode(rows));
    });
  }

  @override
  Future<void> delete(String table, Map<String, String> filters) {
    if (AcademicBatch.tables.contains(table)) {
      return writeCourse(
        textOf(filters[table == 'courses' ? 'id' : 'course_id']),
        [AcademicMutation.delete(table, Map.of(filters))],
      );
    }
    return _serial(() async {
      final rows = await _rows(table, await _recover());
      rows.removeWhere(
        (row) => filters.entries.every((e) => textOf(row[e.key]) == e.value),
      );
      await storage.write('$_prefix$table', jsonEncode(rows));
    });
  }
}
