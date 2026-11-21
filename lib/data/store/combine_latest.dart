import 'dart:async';

/// Emits [combine] of the latest value from each stream, once every stream has
/// produced one and again whenever any of them changes. Errors pass straight
/// through; it finishes when all of them have.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A a, B b) combine,
) {
  return _combineLatest([a, b]).map(
    (values) => combine(values[0] as A, values[1] as B),
  );
}

/// [combineLatest2] for three streams.
Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  R Function(A a, B b, C c) combine,
) {
  return _combineLatest([a, b, c]).map(
    (values) => combine(values[0] as A, values[1] as B, values[2] as C),
  );
}

Stream<List<Object?>> _combineLatest(List<Stream<Object?>> streams) {
  final subscriptions = <StreamSubscription<Object?>>[];
  final latest = List<Object?>.filled(streams.length, null);
  final received = List<bool>.filled(streams.length, false);
  var finished = 0;
  late final StreamController<List<Object?>> controller;

  controller = StreamController<List<Object?>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        subscriptions.add(
          streams[i].listen(
            (value) {
              latest[i] = value;
              received[i] = true;
              if (received.every((r) => r)) controller.add(List.of(latest));
            },
            onError: controller.addError,
            onDone: () {
              if (++finished == streams.length) controller.close();
            },
          ),
        );
      }
    },
    onPause: () {
      for (final s in subscriptions) {
        s.pause();
      }
    },
    onResume: () {
      for (final s in subscriptions) {
        s.resume();
      }
    },
    onCancel: () => Future.wait([for (final s in subscriptions) s.cancel()]),
  );
  return controller.stream;
}
