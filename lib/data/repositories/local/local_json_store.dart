import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models.dart';
import '../../../domain/repositories/local_storage_repository.dart';
import '../../academic_data_store.dart';

/// One persisted JSON document per data type; assets seed a new device.
class LocalJsonStore implements AcademicDataStore {
  LocalJsonStore({
    required this.storage,
    Future<String> Function(String)? assetLoader,
  }) : _load = assetLoader ?? rootBundle.loadString;
  final LocalStorageRepository storage;
  final Future<String> Function(String) _load;
  Future<JsonMap>? _seed;
  Future<void> _pending = Future.value();
  static const _prefix = 'local_data_v1_';
  static const tables = [
    'courses',
    'course_curricula',
    'course_contents',
    'course_schedules',
    'site_feedback',
  ];

  Future<JsonMap> _initialData() => _seed ??= _readAssets();
  Future<JsonMap> _readAssets() async {
    final result = <String, dynamic>{
      for (final table in tables) table: <dynamic>[],
    };
    final registry = jsonDecode(await _load('assets/data/courses.json'));
    final courses = asList(
      registry is List ? registry : asMap(registry)['courses'],
    );
    for (final value in courses) {
      final course = asMap(value);
      final id = textOf(course['id']);
      if (id.isEmpty) continue;
      result['courses'].add({'id': id, 'data': course});
      String source;
      try {
        source = await _load('assets/data/$id.json');
      } on FlutterError {
        continue;
      } on StateError {
        continue;
      } on Exception {
        continue;
      }
      final data = asMap(jsonDecode(source));
      for (final entry in {
        'course_curricula': 'curriculum',
        'course_contents': 'contents',
      }.entries) {
        if (data[entry.value] != null) {
          result[entry.key].add({'course_id': id, 'data': data[entry.value]});
        }
      }
      for (final entry in asMap(data['schedules']).entries) {
        result['course_schedules'].add({
          'course_id': id,
          'semester': entry.key,
          'data': entry.value,
          ...asMap(asMap(data['scheduleMetadata'])[entry.key]),
        });
      }
    }
    return result;
  }

  Future<List<JsonMap>> _rows(String table) async {
    if (!tables.contains(table)) {
      throw ArgumentError('Documento local desconhecido: $table');
    }
    final persisted = (await storage.readAll())['$_prefix$table'];
    final dynamic rows = persisted == null
        ? (await _initialData())[table]
        : jsonDecode(persisted);
    if (rows is! List) throw FormatException('JSON local inválido: $table');
    return rows.map((e) => asMap(jsonDecode(jsonEncode(e)))).toList();
  }

  bool _matches(JsonMap row, Map<String, String> filters) =>
      filters.entries.every((e) => textOf(row[e.key]) == e.value);

  @override
  Future<List<JsonMap>> select(
    String table, {
    Map<String, String> filters = const {},
  }) async {
    await _pending;
    return (await _rows(table)).where((row) => _matches(row, filters)).toList();
  }

  Future<void> _write(String table, void Function(List<JsonMap>) change) {
    final operation = _pending.then((_) async {
      final rows = await _rows(table);
      change(rows);
      await storage.write('$_prefix$table', jsonEncode(rows));
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<void> upsert(String table, JsonMap row) => _write(table, (rows) {
    final keys = table == 'course_schedules'
        ? ['course_id', 'semester']
        : ['course_curricula', 'course_contents'].contains(table)
        ? ['course_id']
        : ['id'];
    if (keys.any((key) => textOf(row[key]).isEmpty)) {
      throw const FormatException('Identificador local obrigatório.');
    }
    final index = rows.indexWhere(
      (old) => keys.every((key) => old[key] == row[key]),
    );
    final copy = asMap(jsonDecode(jsonEncode(row)));
    if (index < 0) {
      rows.add(copy);
    } else {
      rows[index] = copy;
    }
  });

  @override
  Future<void> delete(String table, Map<String, String> filters) =>
      _write(table, (rows) {
        rows.removeWhere((row) => _matches(row, filters));
      });
}
