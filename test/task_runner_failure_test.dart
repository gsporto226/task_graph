import 'package:task_graph/src/exceptions.dart';
import 'package:task_graph/src/task_graph.dart';
import 'package:task_graph/src/task_runner.dart';
import 'package:task_graph/src/task_state.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('TaskRunner failure semantics', () {
    test('failing task records root cause and skips transitive dependents',
        () async {
      final error = Exception('boom');
      var dependentRan = false;
      final root = ScriptedTask('root', runError: error);
      final child = ScriptedTask(
        'child',
        deps: [root],
        onRun: (_) => dependentRan = true,
      );
      final grandChild = ScriptedTask('grandchild', deps: [child]);
      final sibling = ScriptedTask('sibling');

      final result = await TaskRunner.run(
        TaskGraph()
          ..add(root)
          ..add(child)
          ..add(grandChild)
          ..add(sibling),
      );

      expect(result.succeeded, isFalse);
      expect(result.failures, hasLength(1));
      expect(result.failures.single.error, same(error));
      expect(result.failures.single.stackTrace, isNotNull);
      expect(root.state, TaskState.failure);
      expect(child.state, TaskState.dependencyFailure);
      expect(dependentRan, isFalse);
      expect(grandChild.state, TaskState.dependencyFailure);
      expect(sibling.state, TaskState.success);
      await expectLater(
        child.value,
        throwsA(isA<TaskDependencyFailureException>()),
      );
      await expectLater(
        grandChild.value,
        throwsA(isA<TaskDependencyFailureException>()),
      );
    });

    test('summary counts failures and dependency-failures', () async {
      final ok = ScriptedTask('ok');
      final bad = ScriptedTask('bad', runError: Exception('nope'));
      final dependent = ScriptedTask('dependent', deps: [bad]);
      final app = ScriptedTask(
        'app',
        deps: [ok, bad, dependent],
        alwaysRun: true,
      );

      final result = await TaskRunner.run(
        TaskGraph()
          ..add(ok)
          ..add(bad)
          ..add(dependent)
          ..add(app),
      );

      expect(
        result.summary(),
        '2/4 tasks succeeded (1 failed, 1 dependency-failed)',
      );
      expect(app.state, TaskState.success);
    });

    test('always-run task runs last, after skipped dependents', () async {
      final order = <String>[];
      final bad = ScriptedTask(
        'bad',
        runError: Exception('nope'),
        onRun: (_) => order.add('bad'),
      );
      final dependent = ScriptedTask(
        'dependent',
        deps: [bad],
        onRun: (_) => order.add('dependent'),
      );
      final app = ScriptedTask(
        'app',
        deps: [bad, dependent],
        alwaysRun: true,
        onRun: (_) => order.add('app'),
      );

      await TaskRunner.run(
        TaskGraph()
          ..add(bad)
          ..add(dependent)
          ..add(app),
      );

      expect(order, ['bad', 'app']);
    });

    test('normal task with failed dep is still skipped even when an '
        'always-run sibling exists', () async {
      var dependentRan = false;
      final bad = ScriptedTask('bad', runError: Exception('nope'));
      final dependent = ScriptedTask(
        'dependent',
        deps: [bad],
        onRun: (_) => dependentRan = true,
      );
      final app = ScriptedTask('app', alwaysRun: true, deps: [bad, dependent]);

      final result = await TaskRunner.run(
        TaskGraph()
          ..add(bad)
          ..add(dependent)
          ..add(app),
      );

      expect(dependentRan, isFalse);
      expect(dependent.state, TaskState.dependencyFailure);
      expect(app.state, TaskState.success);
      expect(result.failures, hasLength(1));
    });
  });
}
