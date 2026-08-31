# task_graph

Generic, pure-Dart, **zero-dependency** dependency-graph task scheduler.
Inspired by the [Zig build system](https://ziglang.org/learn/build-system/):
a DAG of tasks that are independently and concurrently run, with
"transitive failure" semantics for dependents of failed tasks.

## Usage

```dart
final graph = TaskGraph()
  ..add(storage)                          // no dependencies
  ..add(logger)                           // no dependencies
  ..add(LocalStorageTask(
    storage: storage,                     // typed task reference = edge
    logger: logger,
    builder: LocalStorageTask.defaultBuilder,
  ));

final result = await TaskRunner.run(graph, observer: myObserver);
print(result.summary()); // e.g. "17/18 tasks succeeded (1 failed)"
if (result.succeeded) {
  final storage = await storageTask.value; // typed value
}
```

## API

- **`Task<T>`** — declare `dependencies` (typed references to other tasks;
  the single source of truth for edges), do the work in `run()` (throw on
  failure). `value` completes with the result. `FunctionTask<T>` wraps a
  closure for trivial tasks.
- **`TaskGraph`** — ordered set of uniquely-named tasks.
- **`TaskRunner.run(graph, {observer, maxConcurrent})`** — validates the
  graph (unknown deps, cycles via Kahn's algorithm — before executing
  anything) and dispatches from a ready-queue: a task starts the instant
  its last dependency settles. No level barriers.
- **`TaskRunResult`** — per-task `TaskOutcome`s (state + duration + error),
  root-cause-only `failures`, `succeeded`, `summary()`.

## Semantics

| Concern | Behavior |
|---|---|
| Scheduling | Ready-queue: independent tasks run concurrently; optional `maxConcurrent` cap (Zig's `-j`) |
| Failure | Task state `failure`; error + stack captured in the result |
| Dependents of failed tasks | Skipped with state `dependencyFailure` ("transitive failure"); their `run()` never executes; `value` completes with `TaskDependencyFailureException` |
| Error attribution | Only actually-executed tasks appear in `failures` (root causes only) |
| Always-run tasks | `runOnDependencyFailure == true` — a task that still dispatches when upstream failed (for terminal tasks like "start the app or show the error page") |
| Cycles | `TaskCycleException` before any task runs |
| Unhandled errors | The runner `ignore()`s every task's `value` future; awaiting them is still safe |

## Observability

Implement `TaskObserver` (`onTaskStart` / `onTaskEnd`) to log transitions
with durations — mirroring Zig's Build Summary output.
