import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reports that something in the database may have changed, and whether the
/// live connection is up. Returns the function that stops listening.
typedef ChangeFeed = void Function() Function({
  required void Function() onChange,
  required void Function(bool live) onStatus,
});

var _channelCounter = 0;

/// A [ChangeFeed] on one table over Supabase Realtime. Realtime applies the row
/// level security policies, so a customer is told about their own rows only.
ChangeFeed realtimeChangeFeed(
  SupabaseClient client, {
  required String table,
  PostgresChangeFilter? filter,
}) => ({required onChange, required onStatus}) {
  final channel = client
      .channel('live-$table-${_channelCounter++}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: filter,
        callback: (_) => onChange(),
      )
      .subscribe(
        (status, error) =>
            onStatus(status == RealtimeSubscribeStatus.subscribed),
      );
  return () => client.removeChannel(channel);
};

/// A value kept in step with the database: fetched once, then fetched again
/// whenever [feed] reports a change. While the live connection is not up it
/// polls every [pollInterval] instead, and it refreshes every [safetyInterval]
/// even when live, in case an event was missed during a reconnect.
///
/// Realtime reports a subscription as live slightly before the server really
/// delivers changes (it finishes setting up after the join). So the value is
/// fetched once more [settleDelay] after the connection comes up, to catch what
/// changed in that gap.
///
/// Before the first value, a failed fetch is passed on as an error. After it, a
/// failed fetch is ignored: a screen should not lose what it shows to a hiccup.
Stream<T> liveQuery<T>({
  required ChangeFeed feed,
  required Future<T> Function() fetch,
  Duration pollInterval = const Duration(seconds: 5),
  Duration safetyInterval = const Duration(seconds: 60),
  Duration settleDelay = const Duration(seconds: 2),
}) {
  late final StreamController<T> controller;
  void Function()? stopFeed;
  Timer? timer;
  Timer? settleTimer;
  var live = false;
  var closed = false;
  var refreshing = false;
  var again = false;
  var delivered = false;
  var ticks = 0;

  Future<void> refresh() async {
    if (closed) {
      return;
    }
    if (refreshing) {
      // A change arrived while fetching: fetch once more afterwards.
      again = true;
      return;
    }
    refreshing = true;
    try {
      do {
        again = false;
        try {
          final value = await fetch();
          if (!closed) {
            controller.add(value);
            delivered = true;
          }
        } catch (error, stackTrace) {
          if (!delivered && !closed) {
            controller.addError(error, stackTrace);
          }
        }
      } while (again && !closed);
    } finally {
      refreshing = false;
    }
  }

  controller = StreamController<T>(
    onListen: () {
      stopFeed = feed(
        onChange: refresh,
        onStatus: (isLive) {
          live = isLive;
          if (isLive) {
            // Catch up on whatever happened before the subscription was up,
            // and once more when the server has really started delivering.
            refresh();
            settleTimer?.cancel();
            settleTimer = Timer(settleDelay, refresh);
          }
        },
      );
      refresh();
      final safetyTicks =
          (safetyInterval.inMilliseconds / pollInterval.inMilliseconds).ceil();
      timer = Timer.periodic(pollInterval, (_) {
        ticks++;
        if (!live || ticks % safetyTicks == 0) {
          refresh();
        }
      });
    },
    onCancel: () {
      closed = true;
      timer?.cancel();
      settleTimer?.cancel();
      stopFeed?.call();
    },
  );
  return controller.stream;
}
