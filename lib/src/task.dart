import 'dart:async';

import 'package:task_graph/src/exceptions.dart';
import 'package:task_graph/src/task_state.dart';

/// A unit of work in a task graph.
///
/// Tasks declare their upstream [dependencies] (the single source of truth
/// for graph edges), do their work in [run], and expose their completion
/// through [value]. Tasks are executed by `TaskRunner`, which drives the
/// internal [execute] and [skip] hooks.
abstract class Task<T> {
  /// Creates a task with the given [name].
  Task({required this.name});

  /// Name of this task, unique per graph; used in logs and summaries.
  final String name;

  /// The tasks that must settle before this one may run.
  Iterable<Task<dynamic>> get dependencies => const [];

  /// The task's work. Throwing marks the task as failed.
  FutureOr<T> run();

  /// Whether this task should still run when an upstream dependency failed.
  ///
  /// Used for terminal tasks that must render an outcome either way (for
  /// example, starting the app or showing an error page).
  bool get runOnDependencyFailure => false;

  TaskState _state = TaskState.pending;
  Object? _error;
  final Completer<T> _completer = Completer<T>();

  /// Current lifecycle state of this task.
  TaskState get state => _state;

  /// The failure or skip cause; null while [state] is not terminal.
  Object? get error => _error;

  /// Completes with the task's value on success; throws otherwise.
  ///
  /// Callers that may not await this future should call `ignore()` to
  /// prevent unhandled async errors.
  Future<T> get value => _completer.future;

  /// Internal: driven by `TaskRunner`.
  ///
  /// Marks the task running, awaits [run] and completes [value]. If [run]
  /// throws, the task is marked failed, [value] completes with the error and
  /// the error is rethrown to the runner.
  Future<void> execute() async {
    _state = TaskState.running;
    try {
      final result = await Future.sync(run);
      _state = TaskState.success;
      _completer.complete(result);
    } on Object catch (error, stackTrace) {
      _state = TaskState.failure;
      _error = error;
      _completer.completeError(error, stackTrace);
      rethrow;
    }
  }

  /// Internal: driven by `TaskRunner`.
  ///
  /// Marks the task as skipped due to a failed upstream dependency and
  /// completes [value] with a [TaskDependencyFailureException].
  void skip() {
    _state = TaskState.dependencyFailure;
    _error = const TaskDependencyFailureException();
    _completer.completeError(_error!);
  }
}
