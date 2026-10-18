import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ufape/data/repositories/supabase/supabase_auth_repository.dart';

void main() {
  test('rejects frontend secret and legacy service role keys', () {
    final serviceJwt =
        'x.${base64Url.encode(utf8.encode('{"role":"service_role"}'))}.x';
    for (final key in ['sb_secret_test', serviceJwt]) {
      final session = SupabaseAuthRepository(
        url: 'https://test.supabase.co',
        key: key,
      );
      expect(session.configured, isFalse);
      session.dispose();
    }
  });
  test(
    'refresh rotates once for concurrent callers and logout clears memory',
    () async {
      var refreshes = 0;
      var signedOut = false;
      final session = SupabaseAuthRepository(
        url: 'https://test.supabase.co',
        key: 'sb_publishable_test',
        client: MockClient((request) async {
          expect(request.headers['apikey'], 'sb_publishable_test');
          if (request.url.path.endsWith('/logout')) {
            signedOut = true;
            expect(request.headers['Authorization'], 'Bearer refreshed');
            return http.Response('{}', 204);
          }
          if (request.url.queryParameters['grant_type'] == 'password') {
            expect(jsonDecode(request.body), {
              'email': 'admin@example.com',
              'password': 'password',
            });
            return http.Response(
              '{"access_token":"first","refresh_token":"refresh1","expires_in":0}',
              200,
            );
          }
          refreshes++;
          expect(jsonDecode(request.body), {'refresh_token': 'refresh1'});
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response(
            '{"access_token":"refreshed","refresh_token":"refresh2","expires_in":3600}',
            200,
          );
        }),
      );
      await session.signIn(' admin@example.com ', 'password');
      expect(await Future.wait([session.token(), session.token()]), [
        'refreshed',
        'refreshed',
      ]);
      expect(refreshes, 1);
      await session.signOut();
      expect(signedOut, isTrue);
      expect(await session.token(), isNull);
      session.dispose();
    },
  );
}
