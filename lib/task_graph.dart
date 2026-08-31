/// Generic dependency-graph task scheduler.
///
/// Inspired by build systems like Zig's build runner: tasks form a DAG,
/// independent tasks run concurrently from a ready-queue (no level
/// barriers), dependents of failed tasks are skipped ("transitive
/// failure"), and cycles are detected before anything executes.
library;

export 'src/exceptions.dart';
export 'src/function_task.dart';
export 'src/task.dart';
export 'src/task_graph.dart';
export 'src/task_observer.dart';
export 'src/task_run_result.dart';
export 'src/task_runner.dart';
export 'src/task_state.dart';
