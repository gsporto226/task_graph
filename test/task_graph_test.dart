import 'package:task_graph/src/function_task.dart';
import 'package:task_graph/src/task_graph.dart';
import 'package:test/test.dart';

void main() {
  group('TaskGraph', () {
    test('empty graph has no tasks', () {
      expect(TaskGraph().tasks, isEmpty);
    });

    test('add preserves insertion order', () {
      final a = FunctionTask<int>(name: 'a', function: () => 1);
      final b = FunctionTask<int>(name: 'b', function: () => 2);
      final graph = TaskGraph()
        ..add(a)
        ..add(b);
      expect(graph.tasks, [a, b]);
    });

    test('add rejects duplicate names', () {
      final graph = TaskGraph()
        ..add(FunctionTask<int>(name: 'dup', function: () => 1));
      expect(
        () => graph.add(FunctionTask<int>(name: 'dup', function: () => 2)),
        throwsArgumentError,
      );
    });
  });
}
