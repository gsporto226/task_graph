import 'dart:async';

import 'package:task_graph/src/task.dart';
import 'package:task_graph/src/task_observer.dart';
import 'package:task_graph/src/task_state.dart';
import 'package:test/test.dart';

/// Test task with mutable dependencies and scripted behavior.
class ScriptedTask extends Task<int> {
  ScriptedTask(
    String name, {
    this.onRun,
    this.runError,
    this.alwaysRun = false,
    this.waitFor,
    List<Task<dynamic>> deps = const [],
  }) : _depList = List.of(deps),
       super(name: name);

  /// Called at the start of [run]; use it to record execution.
  void Function(ScriptedTask self)? onRun;

  /// When non-null, [run] throws it.
  Exception? runError;

  /// When non-null, [run] awaits it before completing — used to hold tasks
  /// open and control scheduling order in tests.
  Future<void> Function()? waitFor;

  @override
  bool get runOnDependencyFailure => alwaysRun;
  final bool alwaysRun;

  final List<Task<dynamic>> _depList;

  /// Mutable dependency list — allows building cycles in tests.
  void addDependency(Task<dynamic> task) => _depList.add(task);

  @override
  Iterable<Task<dynamic>> get dependencies => _depList;

  @override
  FutureOr<int> run() async {
    onRun?.call(this);
    final wait = waitFor;
    if (wait != null) {
      await wait();
    }
    final error = runError;
    if (error != null) {
      throw error;
    }
    return 1;
  }
}

/// Observer that records start/end events for assertions.
class RecordingObserver implements TaskObserver {
  /// Optional extra callbacks.
  RecordingObserver({this.onStart, this.onEnd});

  final List<String> events = <String>[];
  void Function(Task<dynamic> task)? onStart;
  void Function(Task<dynamic> task, TaskState endState)? onEnd;

  @override
  void onTaskStart(Task<dynamic> task) {
    events.add('start:${task.name}');
    onStart?.call(task);
  }

  @override
  void onTaskEnd(
    Task<dynamic> task,
    TaskState endState,
    Duration duration,
    Object? error,
  ) {
    expect(duration, greaterThanOrEqualTo(Duration.zero));
    events.add('end:${task.name}:${endState.name}');
    onEnd?.call(task, endState);
  }
}
