/// The scripted beats. Everything the jury sees "happen by itself".
library;

import 'dart:async';

/// Pure timers. No Supabase, no Flutter — just the show's timing.
///
/// A beat is keyed, so scheduling the same person twice replaces the pending
/// one instead of firing it twice. [flush] is the stage rescue: it runs every
/// pending beat right now.
class Director {
  Director();

  /// 6 s — Hannan accepting the plan.
  static const hannanDelay = Duration(seconds: 6);

  /// 5 s — Hannan accepting a connection request.
  static const connectDelay = Duration(seconds: 5);

  final Map<String, (Timer, void Function())> _pending = {};

  void scheduleAccept(String personId, void Function() run) =>
      _schedule('accept:$personId', hannanDelay, run);

  void scheduleConnectionAccept(String personId, void Function() run) =>
      _schedule('connect:$personId', connectDelay, run);

  /// Runs every pending beat immediately. The stage rescue button.
  void flush() {
    final beats = _pending.values.toList(growable: false);
    _pending.clear();
    for (final (timer, run) in beats) {
      timer.cancel();
      _run(run);
    }
  }

  void cancelAll() {
    for (final (timer, _) in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
  }

  void dispose() => cancelAll();

  void _schedule(String key, Duration delay, void Function() run) {
    _pending.remove(key)?.$1.cancel();
    final timer = Timer(delay, () {
      _pending.remove(key);
      _run(run);
    });
    _pending[key] = (timer, run);
  }

  void _run(void Function() run) {
    try {
      run();
    } catch (_) {
      // One beat failing must never take the rest of the show down.
    }
  }
}
