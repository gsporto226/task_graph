import 'package:task_graph/src/task.dart';
import 'package:task_graph/src/task_state.dart';

/// The terminal outcome of a single task within a run.
class TaskOutcome {
  /// Creates an outcome.
  const TaskOutcome({
    required this.task,
    required this.state,
    required this.duration,
    this.error,
    this.stackTrace,
  });

  /// The task this outcome belongs to.
  final Task<dynamic> task;

  /// Terminal state of the task.
  final TaskState state;

  /// Time spent executing. Zero for dependency-failure skips.
  final Duration duration;

  /// The failure cause, when [state] is failure or dependencyFailure.
  final Object? error;

  /// The stack trace captured with [error], when present.
  final StackTrace? stackTrace;
}

/// The aggregate result of a `TaskRunner.run` execution.
class TaskRunResult {
  /// Creates a result.
  const TaskRunResult({required this.outcomes});

  /// One outcome per task, in graph insertion order.
  final List<TaskOutcome> outcomes;

  /// Outcomes of tasks that executed and threw (root causes only; skipped
  /// tasks are not included).
  List<TaskOutcome> get failures =>
      outcomes.where((o) => o.state == TaskState.failure).toList();

  /// Whether no task failed. Dependency-failure skips do not count.
  bool get succeeded => failures.isEmpty;

  /// Zig-build-style one-line summary.
  String summary() {
    final total = outcomes.length;
    final ok = outcomes.where((o) => o.state == TaskState.success).length;
    final failed = failures.length;
    final skipped = outcomes
        .where((o) => o.state == TaskState.dependencyFailure)
        .length;
    final line = '$ok/$total tasks succeeded';
    if (failed == 0 && skipped == 0) {
      return line;
    }
    return '$line ($failed failed, $skipped dependency-failed)';
  }
}
