import 'package:task_graph/src/exceptions.dart';
import 'package:task_graph/src/task_state.dart';
import 'package:test/test.dart';

void main() {
  test('TaskState has the five lifecycle states', () {
    expect(TaskState.values, hasLength(5));
    expect(
      TaskState.values.map((s) => s.name),
      containsAllInOrder(<String>[
        'pending',
        'running',
        'success',
        'failure',
        'dependencyFailure',
      ]),
    );
  });

  test('TaskCycleException lists the cycle', () {
    final e = TaskCycleException(const ['a', 'b', 'a']);
    expect(e.toString(), contains('a -> b -> a'));
  });

  test('TaskDependencyFailureException is an Exception', () {
    expect(const TaskDependencyFailureException(), isA<Exception>());
  });

  test('TaskUnknownDependencyException names task and dependency', () {
    final e = TaskUnknownDependencyException(
      task: 'localStorage',
      dependency: 'widgetsBinding',
    );
    expect(e.toString(), contains('localStorage'));
    expect(e.toString(), contains('widgetsBinding'));
  });
}
