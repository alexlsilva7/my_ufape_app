import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_ufape/core/exceptions/persistence_exception.dart';
import 'package:my_ufape/data/repositories/local/shared_preferences_local_storage_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  final calls = <String>[];
  var accepted = false;

  setUp(() {
    SharedPreferences.resetStatic();
    calls.clear();
    accepted = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method.startsWith('getAll')) return <String, Object>{};
          return accepted;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('false from setString is a persistence failure, not success', () async {
    final storage = SharedPreferencesLocalStorageRepository();
    await expectLater(
      storage.write('grade', '8'),
      throwsA(isA<PersistenceException>()),
    );
    expect(calls, contains('setString'));
    accepted = true;
    await storage.write('grade', '8');
  });

  test('false from remove is a persistence failure, not success', () async {
    final storage = SharedPreferencesLocalStorageRepository();
    await expectLater(
      storage.remove('grade'),
      throwsA(isA<PersistenceException>()),
    );
    expect(calls, contains('remove'));
    accepted = true;
    await storage.remove('grade');
  });
}
