import 'dart:async';

import 'package:task_graph/src/task_graph.dart';
import 'package:task_graph/src/task_runner.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('TaskRunner concurrency', () {
    test('maxConcurrent caps peak in-flight tasks', () async {
      var inFlight = 0;
      var peak = 0;
      final observer = RecordingObserver(
        onStart: (_) {
          inFlight++;
          if (inFlight > peak) {
            peak = inFlight;
          }
        },
        onEnd: (_, _) => inFlight--,
      );
      final slow1 = ScriptedTask(
        'slow1',
        waitFor: () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      final slow2 = ScriptedTask(
        'slow2',
        waitFor: () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );

      await TaskRunner.run(
        TaskGraph()
          ..add(slow1)
          ..add(slow2),
        observer: observer,
        maxConcurrent: 1,
      );

      expect(peak, 1);
    });

    test('unbounded dispatch runs independent tasks concurrently', () async {
      final gate = Completer<void>();
      final events = <String>[];
      final slow = ScriptedTask(
        'slow',
        waitFor: () => gate.future,
        onRun: (_) => events.add('start:slow'),
      );
      final fast = ScriptedTask(
        'fast',
        waitFor: () async {},
        onRun: (_) => events.add('start:fast'),
      );

      final runFuture = TaskRunner.run(
        TaskGraph()
          ..add(slow)
          ..add(fast),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(events, containsAllInOrder(<String>['start:slow', 'start:fast']));
      gate.complete();
      await runFuture;
    });

    test('observer sees start/end for every task with matching states',
        () async {
      final observer = RecordingObserver();
      final ok = ScriptedTask('ok');
      final bad = ScriptedTask('bad', runError: Exception('nope'));
      final dependent = ScriptedTask('dependent', deps: [bad]);

      await TaskRunner.run(
        TaskGraph()
          ..add(ok)
          ..add(bad)
          ..add(dependent),
        observer: observer,
      );

      expect(observer.events, [
        'start:ok',
        'start:bad',
        'end:ok:success',
        'end:bad:failure',
        'end:dependent:dependencyFailure',
      ]);
    });
  });
}
