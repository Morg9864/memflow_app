import 'dart:async';

/// Combines streams using the latest value from every source.
///
/// The result starts emitting after each source has produced one value. An
/// empty source completes the result immediately; otherwise the result closes
/// after all sources have completed. Source errors are forwarded and do not
/// terminate the combined stream, matching Dart stream semantics.
Stream<R> _combineLatest<R>(
  List<Stream<Object?>> sources,
  R Function(List<Object?> values) combine,
) {
  late final StreamController<R> controller;
  final latest = List<Object?>.filled(sources.length, null);
  final hasValue = List<bool>.filled(sources.length, false);
  final subscriptions = List<StreamSubscription<Object?>?>.filled(
    sources.length,
    null,
  );
  var completedSources = 0;
  var stopped = false;
  var starting = false;
  var cleanupRequested = false;

  Future<void> cancelSources() async {
    final pending = subscriptions.whereType<StreamSubscription<Object?>>();
    await Future.wait(pending.map((subscription) => subscription.cancel()));
  }

  void stop() {
    if (stopped) return;
    stopped = true;
    if (starting) {
      cleanupRequested = true;
    } else {
      unawaited(cancelSources());
    }
  }

  void terminate() {
    if (stopped) return;
    stop();
    unawaited(controller.close());
  }

  void closeIfDone() {
    if (stopped) return;
    if (completedSources == sources.length) {
      stopped = true;
      unawaited(controller.close());
    }
  }

  void emitIfReady() {
    if (stopped || !hasValue.every((value) => value)) return;
    try {
      controller.add(combine(List<Object?>.unmodifiable(latest)));
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    }
  }

  controller = StreamController<R>(
    onListen: () {
      starting = true;
      for (var index = 0; index < sources.length; index++) {
        final sourceIndex = index;
        subscriptions[sourceIndex] = sources[sourceIndex].listen(
          (value) {
            if (stopped) return;
            latest[sourceIndex] = value;
            hasValue[sourceIndex] = true;
            emitIfReady();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!stopped) controller.addError(error, stackTrace);
          },
          onDone: () {
            if (stopped) return;
            completedSources++;
            if (!hasValue[sourceIndex]) {
              terminate();
            } else {
              closeIfDone();
            }
          },
          cancelOnError: false,
        );
      }
      starting = false;
      if (cleanupRequested) unawaited(cancelSources());
    },
    onCancel: stop,
  );

  return controller.stream;
}

Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  R Function(A a, B b, C c) combine,
) {
  return _combineLatest([
    streamA.cast<Object?>(),
    streamB.cast<Object?>(),
    streamC.cast<Object?>(),
  ], (values) => combine(values[0] as A, values[1] as B, values[2] as C));
}

Stream<R> combineLatest4<A, B, C, D, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  Stream<D> streamD,
  R Function(A a, B b, C c, D d) combine,
) {
  return _combineLatest(
    [
      streamA.cast<Object?>(),
      streamB.cast<Object?>(),
      streamC.cast<Object?>(),
      streamD.cast<Object?>(),
    ],
    (values) =>
        combine(values[0] as A, values[1] as B, values[2] as C, values[3] as D),
  );
}

Stream<R> combineLatest5<A, B, C, D, E, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  Stream<D> streamD,
  Stream<E> streamE,
  R Function(A a, B b, C c, D d, E e) combine,
) {
  return _combineLatest(
    [
      streamA.cast<Object?>(),
      streamB.cast<Object?>(),
      streamC.cast<Object?>(),
      streamD.cast<Object?>(),
      streamE.cast<Object?>(),
    ],
    (values) => combine(
      values[0] as A,
      values[1] as B,
      values[2] as C,
      values[3] as D,
      values[4] as E,
    ),
  );
}
