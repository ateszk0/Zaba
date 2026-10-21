import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/realtime/live_query.dart';

/// A feed the test drives by hand.
class FakeFeed {
  void Function()? _onChange;
  void Function(bool live)? _onStatus;
  var stopped = false;

  ChangeFeed get feed => ({required onChange, required onStatus}) {
    _onChange = onChange;
    _onStatus = onStatus;
    return () => stopped = true;
  };

  void change() => _onChange!();
  void status({required bool live}) => _onStatus!(live);
}

void main() {
  const poll = Duration(seconds: 5);
  const safety = Duration(seconds: 60);

  test('fetches once at the start and delivers the value', () {
    fakeAsync((async) {
      var fetches = 0;
      final values = <int>[];
      liveQuery<int>(
        feed: FakeFeed().feed,
        fetch: () async => ++fetches,
      ).listen(values.add);
      async.flushMicrotasks();

      expect(values, [1]);
    });
  });

  test('a change fetches again', () {
    fakeAsync((async) {
      final feed = FakeFeed();
      var fetches = 0;
      final values = <int>[];
      liveQuery<int>(
        feed: feed.feed,
        fetch: () async => ++fetches,
      ).listen(values.add);
      async.flushMicrotasks();

      feed.change();
      async.flushMicrotasks();

      expect(values, [1, 2]);
    });
  });

  test('changes that arrive while fetching make one more fetch, not many', () {
    fakeAsync((async) {
      final feed = FakeFeed();
      var fetches = 0;
      final release = <Completer<void>>[];
      final values = <int>[];
      liveQuery<int>(
        feed: feed.feed,
        fetch: () async {
          final n = ++fetches;
          final gate = Completer<void>();
          release.add(gate);
          await gate.future;
          return n;
        },
      ).listen(values.add);
      async.flushMicrotasks();
      expect(fetches, 1);

      feed.change();
      feed.change();
      feed.change();
      async.flushMicrotasks();
      expect(fetches, 1, reason: 'still waiting for the first fetch');

      release[0].complete();
      async.flushMicrotasks();
      expect(fetches, 2);
      release[1].complete();
      async.flushMicrotasks();

      expect(fetches, 2);
      expect(values, [1, 2]);
    });
  });

  test('without a live connection it polls; with one it does not', () {
    fakeAsync((async) {
      final feed = FakeFeed();
      var fetches = 0;
      liveQuery<int>(
        feed: feed.feed,
        fetch: () async => ++fetches,
        pollInterval: poll,
        safetyInterval: safety,
      ).listen((_) {});
      async.flushMicrotasks();
      expect(fetches, 1);

      async.elapse(poll * 3);
      expect(fetches, 4, reason: 'one poll per interval while not live');

      feed.status(live: true);
      async.flushMicrotasks();
      expect(fetches, 5, reason: 'going live catches up at once');

      async.elapse(const Duration(seconds: 2));
      expect(fetches, 6, reason: 'and again once the server has settled');

      async.elapse(poll * 4);
      expect(fetches, 6, reason: 'no polling while live');

      async.elapse(safety);
      expect(fetches, 7, reason: 'one safety refresh a minute');

      feed.status(live: false);
      async.elapse(poll);
      expect(fetches, 8, reason: 'polling again once the connection drops');
    });
  });

  test(
    'a failure before the first value is an error, and later success recovers',
    () {
      fakeAsync((async) {
        var fetches = 0;
        final values = <int>[];
        final errors = <Object>[];
        liveQuery<int>(
          feed: FakeFeed().feed,
          fetch: () async {
            if (++fetches == 1) {
              throw Exception('offline');
            }
            return fetches;
          },
          pollInterval: poll,
        ).listen(values.add, onError: errors.add);
        async.flushMicrotasks();
        expect(errors, hasLength(1));
        expect(values, isEmpty);

        async.elapse(poll);
        expect(values, [2]);
      });
    },
  );

  test(
    'a failure after the first value is ignored: the screen keeps its data',
    () {
      fakeAsync((async) {
        final feed = FakeFeed();
        var fetches = 0;
        final values = <int>[];
        final errors = <Object>[];
        liveQuery<int>(
          feed: feed.feed,
          fetch: () async {
            if (++fetches == 2) {
              throw Exception('hiccup');
            }
            return fetches;
          },
        ).listen(values.add, onError: errors.add);
        async.flushMicrotasks();

        feed.change();
        async.flushMicrotasks();
        expect(errors, isEmpty);

        feed.change();
        async.flushMicrotasks();
        expect(values, [1, 3]);
      });
    },
  );

  test('cancelling stops the feed, the polling and any late result', () {
    fakeAsync((async) {
      final feed = FakeFeed();
      var fetches = 0;
      final gate = Completer<void>();
      final values = <int>[];
      final subscription = liveQuery<int>(
        feed: feed.feed,
        fetch: () async {
          final n = ++fetches;
          if (n == 2) {
            await gate.future;
          }
          return n;
        },
        pollInterval: poll,
      ).listen(values.add);
      async.flushMicrotasks();

      feed.change();
      async.flushMicrotasks();
      subscription.cancel();
      gate.complete();
      async.elapse(poll * 5);

      expect(feed.stopped, isTrue);
      expect(fetches, 2, reason: 'no polling after cancel');
      expect(values, [1], reason: 'the late result is dropped');
    });
  });
}
