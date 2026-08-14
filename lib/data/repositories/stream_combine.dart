import 'dart:async';

/// Combinateurs de flux minimalistes : chaque sortie n'est émise qu'une fois
/// toutes les sources ont livré une première valeur, puis à chaque nouvelle
/// valeur de n'importe laquelle d'entre elles.
Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  R Function(A a, B b, C c) combine,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  StreamSubscription<C>? subC;
  A? latestA;
  B? latestB;
  C? latestC;
  var hasA = false;
  var hasB = false;
  var hasC = false;

  void emit() {
    if (hasA && hasB && hasC) {
      controller.add(combine(latestA as A, latestB as B, latestC as C));
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subA = streamA.listen((value) {
        latestA = value;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = streamB.listen((value) {
        latestB = value;
        hasB = true;
        emit();
      }, onError: controller.addError);
      subC = streamC.listen((value) {
        latestC = value;
        hasC = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await subC?.cancel();
    },
  );

  return controller.stream;
}

Stream<R> combineLatest4<A, B, C, D, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  Stream<D> streamD,
  R Function(A a, B b, C c, D d) combine,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  StreamSubscription<C>? subC;
  StreamSubscription<D>? subD;
  A? latestA;
  B? latestB;
  C? latestC;
  D? latestD;
  var hasA = false;
  var hasB = false;
  var hasC = false;
  var hasD = false;

  void emit() {
    if (hasA && hasB && hasC && hasD) {
      controller.add(
        combine(latestA as A, latestB as B, latestC as C, latestD as D),
      );
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subA = streamA.listen((value) {
        latestA = value;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = streamB.listen((value) {
        latestB = value;
        hasB = true;
        emit();
      }, onError: controller.addError);
      subC = streamC.listen((value) {
        latestC = value;
        hasC = true;
        emit();
      }, onError: controller.addError);
      subD = streamD.listen((value) {
        latestD = value;
        hasD = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await subC?.cancel();
      await subD?.cancel();
    },
  );

  return controller.stream;
}

Stream<R> combineLatest5<A, B, C, D, E, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  Stream<D> streamD,
  Stream<E> streamE,
  R Function(A a, B b, C c, D d, E e) combine,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  StreamSubscription<C>? subC;
  StreamSubscription<D>? subD;
  StreamSubscription<E>? subE;
  A? latestA;
  B? latestB;
  C? latestC;
  D? latestD;
  E? latestE;
  var hasA = false;
  var hasB = false;
  var hasC = false;
  var hasD = false;
  var hasE = false;

  void emit() {
    if (hasA && hasB && hasC && hasD && hasE) {
      controller.add(
        combine(
          latestA as A,
          latestB as B,
          latestC as C,
          latestD as D,
          latestE as E,
        ),
      );
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subA = streamA.listen((value) {
        latestA = value;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = streamB.listen((value) {
        latestB = value;
        hasB = true;
        emit();
      }, onError: controller.addError);
      subC = streamC.listen((value) {
        latestC = value;
        hasC = true;
        emit();
      }, onError: controller.addError);
      subD = streamD.listen((value) {
        latestD = value;
        hasD = true;
        emit();
      }, onError: controller.addError);
      subE = streamE.listen((value) {
        latestE = value;
        hasE = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await subC?.cancel();
      await subD?.cancel();
      await subE?.cancel();
    },
  );

  return controller.stream;
}
