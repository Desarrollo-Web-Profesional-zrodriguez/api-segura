import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../auth/data/auth_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';
import 'task_list_view.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(ref.watch(secureStorageProvider));
});

final authStateProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier(this.ref) : super(false) {
    _checkInitialAuth();
  }

  final Ref ref;

  Future<void> _checkInitialAuth() async {
    final token = await ref.read(tokenStoreProvider).readAccessToken();
    state = token != null;
  }

  void setAuthenticated(bool authenticated) {
    state = authenticated;
  }

  void signOut() {
    state = false;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    http.Client(),
    ref.read(tokenStoreProvider),
    onSessionExpired: () => ref.read(authStateProvider.notifier).signOut(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(apiClientProvider));
});

class TaskState {
  const TaskState({
    this.loading = false,
    this.tasks = const [],
    this.errorMessage,
  });

  final bool loading;
  final List<Task> tasks;
  final String? errorMessage;

  TaskState copyWith({
    bool? loading,
    List<Task>? tasks,
    String? errorMessage,
  }) {
    return TaskState(
      loading: loading ?? this.loading,
      tasks: tasks ?? this.tasks,
      errorMessage: errorMessage,
    );
  }
}

class TaskNotifier extends StateNotifier<TaskState> {
  TaskNotifier(this._repository) : super(const TaskState(loading: true)) {
    loadTasks();
  }

  final TaskRepository _repository;

  Future<void> loadTasks() async {
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final tasks = await _repository.list();
      state = state.copyWith(loading: false, tasks: tasks);
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.toString());
    }
  }

  Future<void> addTask(String title, String? description) async {
    try {
      final task = await _repository.create(title, description);
      state = state.copyWith(tasks: [task, ...state.tasks]);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> toggleTask(Task task) async {
    try {
      final updated = await _repository.setCompleted(task, !task.completed);
      state = state.copyWith(
        tasks: state.tasks.map((t) => t.id == task.id ? updated : t).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteTask(Task task) async {
    try {
      await _repository.delete(task.id);
      state = state.copyWith(
        tasks: state.tasks.where((t) => t.id != task.id).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final tasksProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  return TaskNotifier(ref.watch(taskRepositoryProvider));
});

class TaskPage extends ConsumerWidget {
  const TaskPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Tasks'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              ref.read(authStateProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: TaskListView(
        loading: taskState.loading,
        tasks: taskState.tasks,
        errorMessage: taskState.errorMessage,
        onRetry: () => ref.read(tasksProvider.notifier).loadTasks(),
        onToggle: (task) => ref.read(tasksProvider.notifier).toggleTask(task),
        onDelete: (task) => ref.read(tasksProvider.notifier).deleteTask(task),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
        onPressed: () => _showAddTaskDialog(context, ref),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                ref.read(tasksProvider.notifier).addTask(
                      title,
                      descController.text.trim().isEmpty ? null : descController.text.trim(),
                    );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
