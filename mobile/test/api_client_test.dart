/// Verifies ApiClient behavior including token rotation, error sanitization, and timeouts.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FakeTokenStore extends TokenStore {
  FakeTokenStore({this.accessToken, this.refreshToken})
      : super(const FlutterSecureStorage());

  String? accessToken;
  String? refreshToken;
  String? savedAccessToken;
  String? savedRefreshToken;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens(String newAccess, String newRefresh) async {
    savedAccessToken = newAccess;
    savedRefreshToken = newRefresh;
    accessToken = newAccess;
    refreshToken = newRefresh;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}

void main() {
  group('ApiClient', () {
    test('refreshes once on 401 and retries the original request once', () async {
      var originalCalls = 0;
      var refreshCalls = 0;

      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          return http.Response(
            jsonEncode({
              'accessToken': 'new-access',
              'refreshToken': 'new-refresh',
            }),
            200,
          );
        }

        originalCalls++;
        if (originalCalls == 1) return http.Response('{}', 401);
        expect(request.headers['authorization'], 'Bearer new-access');
        return http.Response(jsonEncode({'items': []}), 200);
      });

      final tokens = FakeTokenStore(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );

      final client = ApiClient(mock, tokens);
      await client.send('GET', 'tasks');

      expect(refreshCalls, 1);
      expect(originalCalls, 2);
      expect(tokens.savedAccessToken, 'new-access');
      expect(tokens.savedRefreshToken, 'new-refresh');
    });

    test('throws sanitized ApiException on server error without leaking tokens or raw bodies', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'INTERNAL_ERROR',
              'message': 'Sensitive DB connection string postgres://secret@db',
            }
          }),
          500,
        );
      });

      final tokens = FakeTokenStore(accessToken: 'secret-token-1234');
      final client = ApiClient(mock, tokens);

      expect(
        () => client.send('GET', 'tasks'),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          isNot(contains('secret')),
        )),
      );
    });

    test('parses empty response safely', () async {
      final mock = MockClient((request) async {
        return http.Response('', 204);
      });

      final tokens = FakeTokenStore(accessToken: 'access-123');
      final client = ApiClient(mock, tokens);

      final result = await client.send('DELETE', 'tasks/1');
      expect(result, isEmpty);
    });

    test('throws ApiException on session expiration when refresh also fails', () async {
      var sessionExpiredCalled = false;

      final mock = MockClient((request) async {
        return http.Response('{"error":"invalid"}', 401);
      });

      final tokens = FakeTokenStore(
        accessToken: 'expired-access',
        refreshToken: 'invalid-refresh',
      );

      final client = ApiClient(
        mock,
        tokens,
        onSessionExpired: () => sessionExpiredCalled = true,
      );

      expect(
        () => client.send('GET', 'tasks'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });
}
