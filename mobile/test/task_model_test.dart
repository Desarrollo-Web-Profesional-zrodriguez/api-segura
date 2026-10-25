import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/tasks/domain/task.dart';

void main() {
  group('Task model', () {
    test('parses from valid JSON response', () {
      final json = {
        'id': 'clx123456789',
        'title': 'Test task',
        'description': 'Details here',
        'completed': true,
      };

      final task = Task.fromJson(json);

      expect(task.id, 'clx123456789');
      expect(task.title, 'Test task');
      expect(task.description, 'Details here');
      expect(task.completed, isTrue);
    });

    test('toWriteJson excludes sensitive fields like id or ownerId', () {
      const task = Task(
        id: 'clx123456789',
        title: 'Safe Task',
        description: 'Safe details',
        completed: false,
      );

      final writeJson = task.toWriteJson();

      expect(writeJson.containsKey('id'), isFalse);
      expect(writeJson.containsKey('ownerId'), isFalse);
      expect(writeJson['title'], 'Safe Task');
      expect(writeJson['description'], 'Safe details');
      expect(writeJson['completed'], isFalse);
    });
  });
}
