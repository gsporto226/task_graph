import 'package:task_graph/src/task.dart';

/// An ordered collection of tasks forming a DAG.
///
/// Edges are not declared here: they come from each [Task.dependencies]
/// getter, which is the single source of truth for scheduling. The graph
/// guarantees unique task names and preserves insertion order (used for
/// deterministic outcome ordering).
class TaskGraph {
  final List<Task<dynamic>> _tasks = <Task<dynamic>>[];
  final Set<String> _names = <String>{};

  /// Adds [task] to the graph.
  ///
  /// Throws [ArgumentError] if a task with the same name was already added.
  void add(Task<dynamic> task) {
    if (!_names.add(task.name)) {
      throw ArgumentError.value(task.name, 'name', 'Duplicate task name');
    }
    _tasks.add(task);
  }

  /// The tasks in insertion order.
  List<Task<dynamic>> get tasks => List.unmodifiable(_tasks);
}
