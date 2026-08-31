import 'package:task_graph/src/exceptions.dart';
import 'package:task_graph/src/task_graph.dart';
import 'package:task_graph/src/task_runner.dart';
import 'package:task_graph/src/task_state.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('TaskRunner success scheduling', () {
    test('linear chain runs in dependency order', () async {
      final order = <String>[];
      ScriptedTask make(String name, List<ScriptedTask> deps) => ScriptedTask(
        name,
        deps: deps,
        onRun: (_) => order.add(name),
      );

      final a = make('a', const []);
      final b = make('b', [a]);
      final c = make('c', [b]);

      final result = await TaskRunner.run(
        TaskGraph()
          ..add(a)
          ..add(b)
          ..add(c),
      );

      expect(order, ['a', 'b', 'c']);
      expect(result.succeeded, isTrue);
      expect(result.failures, isEmpty);
      expect(result.outcomes.map((o) => o.task.name), ['a', 'b', 'c']);
      expect(
        result.outcomes.every((o) => o.state == TaskState.success),
        isTrue,
      );
      expect(await a.value, 1);
    });

    test('diamond runs and succeeds, deps before dependents', () async {
      final order = <String>[];
      ScriptedTask make(String name, List<ScriptedTask> deps) => ScriptedTask(
        name,
        deps: deps,
        onRun: (_) => order.add(name),
      );

      final a = make('a', const []);
      final b = make('b', [a]);
      final c = make('c', [a]);
      final d = make('d', [b, c]);

      final result = await TaskRunner.run(
        TaskGraph()
          ..add(a)
          ..add(b)
          ..add(c)
          ..add(d),
      );

      expect(result.succeeded, isTrue);
      expect(order.first, 'a');
      expect(order.last, 'd');
      expect(order.toSet().length, 4);
    });

    test('independent tasks all run', () async {
      var ran = 0;
      final a = ScriptedTask('a', onRun: (_) => ran++);
      final b = ScriptedTask('b', onRun: (_) => ran++);

      final result = await TaskRunner.run(
        TaskGraph()
          ..add(a)
          ..add(b),
      );

      expect(ran, 2);
      expect(result.succeeded, isTrue);
      expect(result.summary(), '2/2 tasks succeeded');
    });

    test('empty graph succeeds', () async {
      final result = await TaskRunner.run(TaskGraph());
      expect(result.succeeded, isTrue);
      expect(result.summary(), '0/0 tasks succeeded');
      expect(result.outcomes, isEmpty);
    });
  });

  group('TaskRunner validation', () {
    test('unknown dependency throws before executing', () async {
      var ran = false;
      final missing = ScriptedTask('missing', onRun: (_) => ran = true);
      final b = ScriptedTask('b', deps: [missing]);

      await expectLater(
        TaskRunner.run(TaskGraph()..add(b)),
        throwsA(isA<TaskUnknownDependencyException>()),
      );
      expect(ran, isFalse);
    });

    test('two-task cycle throws and nothing runs', () async {
      var ran = 0;
      final a = ScriptedTask('a', onRun: (_) => ran++);
      final b = ScriptedTask('b', deps: [a], onRun: (_) => ran++);
      a.addDependency(b);

      await expectLater(
        TaskRunner.run(
          TaskGraph()
            ..add(a)
            ..add(b),
        ),
        throwsA(isA<TaskCycleException>()),
      );
      expect(ran, 0);
    });

    test('self-cycle throws', () async {
      final s = ScriptedTask('s');
      s.addDependency(s);

      await expectLater(
        TaskRunner.run(TaskGraph()..add(s)),
        throwsA(isA<TaskCycleException>()),
      );
    });
  });
}
