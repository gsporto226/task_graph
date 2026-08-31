/// Lifecycle states of a task within a graph execution.
enum TaskState {
  /// The task has not started executing yet.
  pending,

  /// The task is currently executing.
  running,

  /// The task completed successfully.
  success,

  /// The task executed and threw.
  failure,

  /// The task was skipped because an upstream dependency failed.
  dependencyFailure,
}
