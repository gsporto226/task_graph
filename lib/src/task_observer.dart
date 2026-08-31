import 'package:task_graph/src/task.dart';
import 'package:task_graph/src/task_state.dart';

/// Observes task lifecycle during a `TaskRunner` run.
abstract interface class TaskObserver {
  /// Called when [task] starts executing.
  void onTaskStart(Task<dynamic> task);

  /// Called when [task] reaches the terminal state [endState] after
  /// executing for [duration]. [error] is non-null for failures and
  /// dependency-failure skips.
  void onTaskEnd(
    Task<dynamic> task,
    TaskState endState,
    Duration duration,
    Object? error,
  );
}
