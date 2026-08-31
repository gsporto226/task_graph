import 'dart:async';

import 'package:task_graph/src/task.dart';

/// A [Task] backed by an injected function.
///
/// The analogue of Zig's `b.addSystemCommand` helper: for trivial tasks,
/// avoid declaring a class by injecting a closure instead.
class FunctionTask<T> extends Task<T> {
  /// Creates a task that runs [function].
  FunctionTask({
    required super.name,
    required this.function,
    Iterable<Task<dynamic>> dependencies = const [],
  }) : _deps = dependencies;

  /// The function executed by this task.
  final FutureOr<T> Function() function;

  final Iterable<Task<dynamic>> _deps;

  @override
  Iterable<Task<dynamic>> get dependencies => _deps;

  @override
  FutureOr<T> run() => function();
}
