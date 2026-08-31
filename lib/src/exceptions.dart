/// Thrown by `TaskRunner.run` before executing anything when the graph
/// contains a dependency cycle.
class TaskCycleException implements Exception {
  /// Creates an exception listing the tasks forming the cycle.
  TaskCycleException(this.cycle);

  /// Names of the tasks forming the cycle, in traversal order.
  final List<String> cycle;

  @override
  String toString() =>
      'TaskCycleException: dependency cycle detected: '
      '${cycle.join(' -> ')}';
}

/// The error carried by a task that was skipped because an upstream
/// dependency failed.
class TaskDependencyFailureException implements Exception {
  /// Creates the constant skip error.
  const TaskDependencyFailureException();

  @override
  String toString() =>
      'TaskDependencyFailureException: skipped because an upstream '
      'dependency failed';
}

/// Thrown when a task declares a dependency on a task that is not present
/// in the graph.
class TaskUnknownDependencyException implements Exception {
  /// Creates an exception for [task] depending on unknown [dependency].
  TaskUnknownDependencyException({
    required this.task,
    required this.dependency,
  });

  /// Name of the task declaring the missing dependency.
  final String task;

  /// Name of the missing dependency.
  final String dependency;

  @override
  String toString() =>
      'TaskUnknownDependencyException: task "$task" depends on '
      '"$dependency", which is not in the graph';
}
