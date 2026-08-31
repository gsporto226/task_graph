import 'dart:async';
import 'dart:collection';

import 'package:task_graph/src/exceptions.dart';
import 'package:task_graph/src/task.dart';
import 'package:task_graph/src/task_graph.dart';
import 'package:task_graph/src/task_observer.dart';
import 'package:task_graph/src/task_run_result.dart';
import 'package:task_graph/src/task_state.dart';

/// Executes a [TaskGraph].
///
/// Zig-build-runner-inspired scheduling: the graph is validated and checked
/// for cycles before anything executes; then tasks are dispatched from a
/// ready-queue the moment their last dependency settles — no level barriers,
/// so independent tasks run concurrently. Dependents of a failed task are
/// skipped ("transitive failure") unless they opt in via
/// [Task.runOnDependencyFailure].
class TaskRunner {
  const TaskRunner._();

  /// Runs every task in [graph].
  ///
  /// Throws [TaskUnknownDependencyException] if a task depends on a task
  /// outside the graph, and [TaskCycleException] if the graph is cyclic —
  /// both before executing anything.
  static Future<TaskRunResult> run(
    TaskGraph graph, {
    TaskObserver? observer,
    int? maxConcurrent,
  }) async {
    final tasks = graph.tasks;
    _validateDependencies(tasks);

    final dependents = <Task<dynamic>, List<Task<dynamic>>>{
      for (final task in tasks) task: <Task<dynamic>>[],
    };
    for (final task in tasks) {
      for (final dependency in task.dependencies) {
        dependents[dependency]!.add(task);
      }
    }

    _assertAcyclic(tasks, dependents);

    // Silence "unhandled async error" for value futures nobody awaits.
    for (final task in tasks) {
      task.value.ignore();
    }

    return _Scheduler(
      tasks: tasks,
      dependents: dependents,
      observer: observer,
      maxConcurrent: maxConcurrent,
    ).run();
  }

  static void _validateDependencies(List<Task<dynamic>> tasks) {
    final names = tasks.map((task) => task.name).toSet();
    for (final task in tasks) {
      for (final dependency in task.dependencies) {
        if (!names.contains(dependency.name)) {
          throw TaskUnknownDependencyException(
            task: task.name,
            dependency: dependency.name,
          );
        }
      }
    }
  }

  /// Pure Kahn pass: throws [TaskCycleException] naming every task that is
  /// part of, or downstream of, a cycle.
  static void _assertAcyclic(
    List<Task<dynamic>> tasks,
    Map<Task<dynamic>, List<Task<dynamic>>> dependents,
  ) {
    final remaining = <Task<dynamic>, int>{
      for (final task in tasks) task: task.dependencies.length,
    };
    final queue = ListQueue<Task<dynamic>>.from(
      tasks.where((task) => remaining[task] == 0),
    );
    var processed = 0;
    while (queue.isNotEmpty) {
      final task = queue.removeFirst();
      processed++;
      for (final dependent in dependents[task]!) {
        final value = remaining[dependent]! - 1;
        remaining[dependent] = value;
        if (value == 0) {
          queue.add(dependent);
        }
      }
    }
    if (processed < tasks.length) {
      throw TaskCycleException([
        for (final task in tasks)
          if (remaining[task]! > 0) task.name,
      ]);
    }
  }
}

/// Mutable scheduling state for a single [TaskRunner.run] execution.
class _Scheduler {
  _Scheduler({
    required this.tasks,
    required this.dependents,
    required this.observer,
    required this.maxConcurrent,
  });

  final List<Task<dynamic>> tasks;
  final Map<Task<dynamic>, List<Task<dynamic>>> dependents;
  final TaskObserver? observer;
  final int? maxConcurrent;

  final Map<Task<dynamic>, TaskOutcome> _outcomes =
      <Task<dynamic>, TaskOutcome>{};
  late final Map<Task<dynamic>, int> _indegrees;
  late final ListQueue<Task<dynamic>> _ready;
  int _inFlight = 0;
  Completer<void>? _completer;

  Future<TaskRunResult> run() async {
    _indegrees = <Task<dynamic>, int>{
      for (final task in tasks) task: task.dependencies.length,
    };
    _ready = ListQueue<Task<dynamic>>.from(
      tasks.where((task) => _indegrees[task] == 0),
    );
    final completer = Completer<void>();
    _completer = completer;
    _pump();
    _maybeComplete();
    await completer.future;

    return TaskRunResult(
      outcomes: [for (final task in tasks) _outcomes[task]!],
    );
  }

  void _maybeComplete() {
    final completer = _completer;
    if (completer != null &&
        _outcomes.length == tasks.length &&
        _inFlight == 0 &&
        !completer.isCompleted) {
      completer.complete();
    }
  }

  void _pump() {
    while (_ready.isNotEmpty &&
        (maxConcurrent == null || _inFlight < maxConcurrent!)) {
      unawaited(_start(_ready.removeFirst()));
    }
  }

  /// Records [outcome], notifies the observer and releases dependents.
  void _settle(Task<dynamic> task, TaskOutcome outcome) {
    _outcomes[task] = outcome;
    observer?.onTaskEnd(task, outcome.state, outcome.duration, outcome.error);
    for (final dependent in dependents[task]!) {
      final remaining = _indegrees[dependent]! - 1;
      _indegrees[dependent] = remaining;
      if (remaining == 0) {
        _onDependencySettled(dependent);
      }
    }
    _pump();
    _maybeComplete();
  }

  /// A task reached indegree zero: dispatch or skip it.
  void _onDependencySettled(Task<dynamic> task) {
    if (_outcomes.containsKey(task)) {
      return;
    }
    final allSuccess = task.dependencies.every(
      (dependency) => _outcomes[dependency]?.state == TaskState.success,
    );
    if (allSuccess || task.runOnDependencyFailure) {
      _ready.add(task);
    } else {
      _skipNow(task);
    }
  }

  /// Marks [task] as skipped ("transitive failure") and releases its
  /// dependents, which may still dispatch if they opted in via
  /// [Task.runOnDependencyFailure].
  void _skipNow(Task<dynamic> task) {
    const error = TaskDependencyFailureException();
    _outcomes[task] = TaskOutcome(
      task: task,
      state: TaskState.dependencyFailure,
      duration: Duration.zero,
      error: error,
    );
    task.skip();
    observer?.onTaskEnd(
      task,
      TaskState.dependencyFailure,
      Duration.zero,
      error,
    );
    for (final dependent in dependents[task]!) {
      final remaining = _indegrees[dependent]! - 1;
      _indegrees[dependent] = remaining;
      if (remaining == 0) {
        _onDependencySettled(dependent);
      }
    }
    _maybeComplete();
  }

  Future<void> _start(Task<dynamic> task) async {
    if (_outcomes.containsKey(task)) {
      return;
    }
    _inFlight++;
    observer?.onTaskStart(task);
    final watch = Stopwatch()..start();
    TaskOutcome outcome;
    try {
      await task.execute();
      watch.stop();
      outcome = TaskOutcome(
        task: task,
        state: TaskState.success,
        duration: watch.elapsed,
      );
    } on Object catch (error, stackTrace) {
      watch.stop();
      outcome = TaskOutcome(
        task: task,
        state: TaskState.failure,
        duration: watch.elapsed,
        error: error,
        stackTrace: stackTrace,
      );
    }
    _inFlight--;
    _settle(task, outcome);
  }
}
