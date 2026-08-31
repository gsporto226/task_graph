import 'dart:async';

import 'package:task_graph/src/exceptions.dart';
import 'package:task_graph/src/function_task.dart';
import 'package:task_graph/src/task.dart';
import 'package:task_graph/src/task_state.dart';
import 'package:test/test.dart';

class _CountingTask extends Task<int> {
  _CountingTask(this._value, {this.throwOnRun}) : super(name: 'counting');

  final int _value;
  final Exception? throwOnRun;

  @override
  FutureOr<int> run() {
    final throwable = throwOnRun;
    if (throwable != null) {
      throw throwable;
    }
    return _value;
  }
}

void main() {
  group('Task', () {
    test('starts pending with defaults', () {
      final task = _CountingTask(1);
      expect(task.state, TaskState.pending);
      expect(task.error, isNull);
      expect(task.name, 'counting');
      expect(task.dependencies, isEmpty);
      expect(task.runOnDependencyFailure, isFalse);
    });

    test('execute completes value and sets success (sync FutureOr)', () async {
      final task = _CountingTask(42);
      await task.execute();
      expect(task.state, TaskState.success);
      expect(await task.value, 42);
      expect(task.error, isNull);
    });

    test('execute works with async run', () async {
      final task = FunctionTask<int>(
        name: 'async',
        function: () async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
          return 7;
        },
      );
      await task.execute();
      expect(task.state, TaskState.success);
      expect(await task.value, 7);
    });

    test('execute catches sync throw, sets failure, rethrows', () async {
      final error = Exception('boom');
      final task = _CountingTask(0, throwOnRun: error);
      await expectLater(task.execute(), throwsA(same(error)));
      expect(task.state, TaskState.failure);
      expect(task.error, same(error));
      await expectLater(task.value, throwsA(same(error)));
    });

    test('execute catches async throw from run', () async {
      final error = Exception('async boom');
      final task = FunctionTask<int>(
        name: 'async-fail',
        function: () async => throw error,
      );
      await expectLater(task.execute(), throwsA(same(error)));
      expect(task.state, TaskState.failure);
      expect(task.error, same(error));
      await expectLater(task.value, throwsA(same(error)));
    });

    test('skip marks dependencyFailure and completes value with skip error',
        () async {
      final task = _CountingTask(0)..skip();
      expect(task.state, TaskState.dependencyFailure);
      expect(task.error, isA<TaskDependencyFailureException>());
      await expectLater(
        task.value,
        throwsA(isA<TaskDependencyFailureException>()),
      );
    });

    test('value does not surface as unhandled error when nobody listens',
        () async {
      final task = _CountingTask(0, throwOnRun: Exception('boom'));
      try {
        await task.execute();
      } on Object {
        // expected: the error is rethrown by execute
      }
      task.value.ignore();
      await Future<void>.delayed(Duration.zero);
      // If the error surfaced as unhandled, the test runner would fail.
    });
  });

  group('FunctionTask', () {
    test('wires name, dependencies and function', () async {
      final dep = _CountingTask(1);
      final task = FunctionTask<String>(
        name: 'fn',
        dependencies: [dep],
        function: () => 'ok',
      );
      expect(task.name, 'fn');
      expect(task.dependencies, [dep]);
      await task.execute();
      expect(await task.value, 'ok');
      expect(task.state, TaskState.success);
    });
  });
}
