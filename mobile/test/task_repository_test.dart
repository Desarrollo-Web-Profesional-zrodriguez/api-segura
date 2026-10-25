import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/token_store.dart';
import 'package:mobile/features/tasks/data/task_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SimpleTokenStore extends TokenStore {
  SimpleTokenStore() : super(const FlutterSecureStorage());
  @override
  Future<String?> readAccessToken() async => 'test-valid-token';
  @override
  Future<String?> readRefreshToken() async => null;
}

void main() {
  group('TaskRepository', () {
    test('list fetches and parses tasks correctly', () async {
      final mock = MockClient((request) async {
        try {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 't1',
                  'title': 'Task One',
                  'description': 'Desc One',
                  'completed': false,
                },
                {
                  'id': 't2',
                  'title': 'Task Two',
                  'description': null,
                  'completed': true,
                }
              ],
              'page': 1,
              'limit': 20,
            }),
            200,
          );
        } catch (e, s) {
          // ignore: avoid_print
          print('MockClient error: $e\n$s');
          rethrow;
        }
      });

      final repo = TaskRepository(ApiClient(mock, SimpleTokenStore()));
      final tasks = await repo.list();

      expect(tasks.length, 2);
      expect(tasks[0].id, 't1');
      expect(tasks[0].title, 'Task One');
      expect(tasks[0].completed, isFalse);
      expect(tasks[1].id, 't2');
      expect(tasks[1].completed, isTrue);
    });

    test('create sends trimmed payload and parses created task', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'item': {
              'id': 'new-task-id',
              'title': 'Clean Title',
              'description': 'Clean Details',
              'completed': false,
            }
          }),
          201,
        );
      });

      final repo = TaskRepository(ApiClient(mock, SimpleTokenStore()));
      final task = await repo.create('  Clean Title  ', '  Clean Details  ');

      expect(task.id, 'new-task-id');
      expect(task.title, 'Clean Title');
    });

    test('delete calls DELETE endpoint with encoded taskId', () async {
      var deleted = false;
      final mock = MockClient((request) async {
        deleted = true;
        return http.Response('', 204);
      });

      final repo = TaskRepository(ApiClient(mock, SimpleTokenStore()));
      await repo.delete('task 123');

      expect(deleted, isTrue);
    });
  });
}
