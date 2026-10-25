import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/tasks/domain/task.dart';
import 'package:mobile/features/tasks/presentation/task_list_view.dart';

void main() {
  Widget buildTestWidget({
    required bool loading,
    required List<Task> tasks,
    String? errorMessage,
    VoidCallback? onRetry,
    ValueChanged<Task>? onToggle,
    ValueChanged<Task>? onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TaskListView(
          loading: loading,
          tasks: tasks,
          errorMessage: errorMessage,
          onRetry: onRetry ?? () {},
          onToggle: onToggle ?? (_) {},
          onDelete: onDelete ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('renders loading state with CircularProgressIndicator', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      loading: true,
      tasks: [],
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders error state with message and retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(buildTestWidget(
      loading: false,
      tasks: [],
      errorMessage: 'Could not connect to server',
      onRetry: () => retried = true,
    ));

    expect(find.text('Could not connect to server'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('renders empty state when task list is empty', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      loading: false,
      tasks: [],
    ));

    expect(find.text('No tasks yet. Add your first task.'), findsOneWidget);
  });

  testWidgets('renders populated task list and triggers callbacks', (tester) async {
    Task? toggledTask;
    Task? deletedTask;

    final sampleTasks = [
      const Task(
        id: 'task-1',
        title: 'Review API Security',
        description: 'Check IDOR and input validation',
        completed: false,
      ),
      const Task(
        id: 'task-2',
        title: 'Run Jest Tests',
        description: null,
        completed: true,
      ),
    ];

    await tester.pumpWidget(buildTestWidget(
      loading: false,
      tasks: sampleTasks,
      onToggle: (task) => toggledTask = task,
      onDelete: (task) => deletedTask = task,
    ));

    expect(find.text('Review API Security'), findsOneWidget);
    expect(find.text('Check IDOR and input validation'), findsOneWidget);
    expect(find.text('Run Jest Tests'), findsOneWidget);

    // Toggle first task
    final checkbox = find.byType(Checkbox).first;
    await tester.tap(checkbox);
    expect(toggledTask?.id, 'task-1');

    // Delete second task
    final deleteButton = find.byIcon(Icons.delete_outline).last;
    await tester.tap(deleteButton);
    expect(deletedTask?.id, 'task-2');
  });
}
