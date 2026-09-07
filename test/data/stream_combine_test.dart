import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/data/repositories/stream_combine.dart';

void main() {
  test(
    'emits after the first value from every source and updates latest',
    () async {
      final a = StreamController<int>();
      final b = StreamController<String>();
      final c = StreamController<bool>();
      addTearDown(() async {
        await a.close();
        await b.close();
        await c.close();
      });

      final values = <String>[];
      final subscription = combineLatest3(
        a.stream,
        b.stream,
        c.stream,
        (a, b, c) => '$a$b$c',
      ).listen(values.add);
      a.add(1);
      b.add('x');
      await Future<void>.delayed(Duration.zero);
      expect(values, isEmpty);
      c.add(true);
      a.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(values, ['1xtrue', '2xtrue']);
      await subscription.cancel();
    },
  );

  test('completes after all sources complete once values exist', () async {
    final a = Stream.value(1);
    final b = Stream.value(2);
    final c = Stream.value(3);
    expect(
      combineLatest3(a, b, c, (a, b, c) => a + b + c),
      emitsInOrder(<Object>[6, emitsDone]),
    );
  });

  test('completes immediately when a source is empty', () async {
    expect(
      combineLatest3(
        Stream<int>.empty(),
        Stream.value(2),
        Stream.value(3),
        (a, b, c) => a + b + c,
      ),
      emitsDone,
    );
  });

  test('forwards errors and remains subscribed', () async {
    final a = StreamController<int>();
    final b = StreamController<int>();
    final c = StreamController<int>();
    addTearDown(() async {
      await a.close();
      await b.close();
      await c.close();
    });
    final errors = <Object>[];
    final values = <int>[];
    final subscription = combineLatest3(
      a.stream,
      b.stream,
      c.stream,
      (a, b, c) => a + b + c,
    ).listen(values.add, onError: errors.add);
    a.add(1);
    b.add(2);
    c.add(3);
    a.addError(StateError('source failed'));
    a.add(4);
    await Future<void>.delayed(Duration.zero);
    expect(errors.single, isA<StateError>());
    expect(values, [6, 9]);
    await subscription.cancel();
  });

  test('cancelling the result cancels every source', () async {
    var cancellations = 0;
    Stream<int> source() => Stream<int>.multi((multi) {
      multi.onCancel = () {
        cancellations++;
      };
    });
    final subscription = combineLatest3(
      source(),
      source(),
      source(),
      (a, b, c) => a + b + c,
    ).listen((_) {});
    await subscription.cancel();
    expect(cancellations, 3);
  });

  test('preserves typed four and five source callers', () async {
    expect(
      combineLatest4(
        Stream.value(1),
        Stream.value(2),
        Stream.value(3),
        Stream.value(4),
        (a, b, c, d) => a + b + c + d,
      ),
      emits(10),
    );
    expect(
      combineLatest5(
        Stream.value(1),
        Stream.value(2),
        Stream.value(3),
        Stream.value(4),
        Stream.value(5),
        (a, b, c, d, e) => a + b + c + d + e,
      ),
      emits(15),
    );
  });
}
