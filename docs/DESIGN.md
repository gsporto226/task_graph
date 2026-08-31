# task_graph — design

Generic, pure-Dart, zero-dependency dependency-graph task scheduler. Inspired
by the Zig build system: a DAG of steps that are independently and
concurrently run, "transitive failure" for dependents of failed steps, and
fail-fast cycle detection.

## Core API

```dart
abstract class Task<T> {
  String get name;
  Iterable<Task> get dependencies; // single source of truth for edges
  FutureOr<T> run();               // throws on failure
  bool get runOnDependencyFailure; // default false
  TaskState get state;             // pending | running | success | failure | dependencyFailure
  Object? get error;               // failure/skip cause
  Future<T> get value;             // completes with T on success, throws otherwise
}

class TaskGraph { void add(Task task); List<Task> get tasks; }

abstract interface class TaskObserver {
  void onTaskStart(Task task);
  void onTaskEnd(Task task, TaskState endState, Duration duration, Object? error);
}

class TaskRunner {
  static Future<TaskRunResult> run(TaskGraph graph, {TaskObserver? observer, int? maxConcurrent});
}

class TaskRunResult {
  List<TaskOutcome> outcomes;      // one per task, graph order
  List<TaskOutcome> get failures;  // root causes only (state == failure)
  bool get succeeded;
  String summary();                // "15/17 tasks succeeded (1 failed, 1 dependency-failed)"
}
```

## Scheduling semantics (Zig build → task_graph)

| Zig concept | task_graph |
|---|---|
| DAG of steps run independently and concurrently | In-process DAG; typed in-memory `Future<T> value` outputs instead of file-based `LazyPath` |
| Transitive failure (dependents of a failed step are skipped) | `TaskState.dependencyFailure`; only actually-executed tasks report errors (root causes only) |
| Thread-pool dispatch, `-j<N>` cap | Ready-queue dispatch: a task starts the instant its last dependency succeeds; optional `maxConcurrent` cap |
| Cycle detection at graph build | Kahn's algorithm pass at `run()` start, before executing anything (`TaskCycleException`) |
| Build Summary with per-step durations | `TaskRunResult.summary()` + `TaskObserver` callbacks |
| `b.addSystemCommand()` factory helpers | `FunctionTask<T>` for ad-hoc tasks |
| `if: always()`-style escape (CI schedulers) | `runOnDependencyFailure` — a task that runs even when upstream failed (used by ciapp's `RunAppTask` so the error page still renders) |

A dependency "settles" (success, failure, or skip) regardless of outcome,
decrementing dependents' indegrees. A task reaching indegree 0 with any
non-success dependency is skipped unless `runOnDependencyFailure` is set.

## Consumers (ciapp)

- Pre-`runApp` init: 17 tasks in `pre_initialization/_tasks/`, wired by
  `createPreInitializationGraph`; `RunAppTask` is the final node and calls
  `runApp` (success) or renders `PreInitializationErrorPage` (failure).
  Riverpod overrides are produced by ciapp-local `OverrideProducingTask` —
  the engine has no Riverpod knowledge.
- Post-`runApp` init (splash): 4 tasks in `initialization/_tasks/`, wrapped by
  `InitializationProcess` (exposes `initialization` future, same splash
  contract as the old `InitializationService`).

Data flow stays compile-time typed: tasks hold typed references to the tasks
they depend on; builder records use `valueAsResult(task)` (`Right(value)`
futures) so existing `Either<Erro, T>` builder bodies remain verbatim.
