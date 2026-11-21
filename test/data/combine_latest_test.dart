import 'dart:async';

import 'package:expense_splitter_app/data/store/combine_latest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<int> a;
  late StreamController<String> b;
  late StreamController<bool> c;

  setUp(() {
    a = StreamController<int>();
    b = StreamController<String>();
    c = StreamController<bool>();
  });

  Stream<String> combined() =>
      combineLatest3(a.stream, b.stream, c.stream, (x, y, z) => '$x$y$z');

  test('waits for every stream, then emits on each change', () async {
    final events = <String>[];
    final subscription = combined().listen(events.add);

    a.add(1);
    b.add('x');
    await pumpEventQueue();
    expect(events, isEmpty);

    c.add(true);
    await pumpEventQueue();
    expect(events, ['1xtrue']);

    a.add(2);
    b.add('y');
    await pumpEventQueue();
    expect(events, ['1xtrue', '2xtrue', '2ytrue']);

    await subscription.cancel();
  });

  test('passes errors through without stopping', () async {
    final events = <Object>[];
    final subscription = combined().listen(events.add, onError: events.add);

    a.addError(StateError('denied'));
    a.add(1);
    b.add('x');
    c.add(false);
    await pumpEventQueue();

    expect(events, [isA<StateError>(), '1xfalse']);
    await subscription.cancel();
  });

  test('cancelling stops listening to every source', () async {
    final subscription = combined().listen((_) {});
    await pumpEventQueue();
    expect(a.hasListener && b.hasListener && c.hasListener, isTrue);

    await subscription.cancel();

    expect(a.hasListener || b.hasListener || c.hasListener, isFalse);
  });

  test('finishes once every source has', () async {
    final done = Completer<void>();
    combined().listen((_) {}, onDone: done.complete);

    await a.close();
    await b.close();
    await pumpEventQueue();
    expect(done.isCompleted, isFalse);

    await c.close();
    await pumpEventQueue();
    expect(done.isCompleted, isTrue);
  });
}
