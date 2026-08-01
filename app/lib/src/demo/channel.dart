/// The one cross-device wire: a Supabase Realtime *broadcast* channel.
library;

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The well-known topic both phones join. Nothing else is ever joined.
const String _topic = '8x-friends-demo';

/// One broadcast event name for every message; the envelope carries the type.
const String _event = 'demo';

/// How often we try again while the socket is not up.
const Duration _retryInterval = Duration(seconds: 4);

/// A broadcast-only channel between the two demo phones.
///
/// No tables, no RLS. The topic is public, so the publishable key alone should
/// be enough — but an anonymous session is the configuration this project has
/// actually seen work, so one is started (best-effort) before subscribing.
/// Every call is best-effort: if `Supabase.initialize` never completed, or the
/// socket never opens, the channel silently reports [isConnected] as `false`
/// and the app runs solo.
class DemoChannel {
  DemoChannel({required this.onEvent});

  /// Called for every message from the *other* device.
  final void Function(String type, Map<String, dynamic> payload) onEvent;

  RealtimeChannel? _channel;
  Timer? _retry;
  String _selfId = '';
  bool _connected = false;
  bool _failed = false;
  bool _disposed = false;

  bool get isConnected => _connected;

  /// Joins `8x-friends-demo`. Never throws; retries quietly.
  Future<void> join(String selfId) async {
    if (_disposed) return;
    _selfId = selfId;
    _attach();
    _retry ??= Timer.periodic(_retryInterval, (_) => _tick());
  }

  /// Fire and forget. A closed socket is not an error.
  void send(String type, Map<String, dynamic> payload) {
    if (_disposed || type.isEmpty) return;
    final channel = _channel;
    if (channel == null) return;
    unawaited(_push(channel, {'type': type, 'from': _selfId, 'data': payload}));
  }

  void dispose() {
    _disposed = true;
    _connected = false;
    _retry?.cancel();
    _retry = null;
    _detach();
  }

  // --- internals ------------------------------------------------------------

  Future<void> _push(
    RealtimeChannel channel,
    Map<String, dynamic> envelope,
  ) async {
    try {
      // The SDK writes its own `type` and `event` keys into the map it is
      // given, so the envelope has to travel nested under `payload`.
      await channel.sendBroadcastMessage(
        event: _event,
        payload: {'payload': envelope},
      );
    } catch (_) {
      // Venue Wi-Fi. The other phone simply does not hear this beat.
    }
  }

  void _receive(Map<String, dynamic> message) {
    try {
      final body = message['payload'];
      if (body is! Map) return;
      final envelope = Map<String, dynamic>.from(body);
      if (envelope['from'] == _selfId) return;
      final type = envelope['type'];
      if (type is! String || type.isEmpty) return;
      final data = envelope['data'];
      onEvent(type, data is Map ? Map<String, dynamic>.from(data) : const {});
    } catch (_) {
      // A malformed message, or a listener that threw, must never surface.
    }
  }

  void _tick() {
    if (_disposed || _connected) return;
    if (_channel == null || _failed) _attach();
  }

  void _attach() {
    if (_disposed) return;
    _detach();
    try {
      final client = Supabase.instance.client;
      _signIn(client);
      final channel = client.channel(
        _topic,
        // `private: false` is the default; saying it out loud makes it obvious
        // that no RLS check is expected on this topic.
        opts: const RealtimeChannelConfig(self: false, private: false),
      );
      _channel = channel;
      // Set before subscribing: a status callback may land synchronously, and
      // it must not be overwritten by a stale `false` afterwards.
      _failed = false;
      channel.onBroadcast(event: _event, callback: _receive);
      channel.subscribe((status, error) => _onStatus(channel, status, error));
    } catch (_) {
      // Supabase was never initialised. Offline is a valid state here.
      _failed = true;
      _detach();
    }
  }

  /// Starts an anonymous session if there is none, without waiting for it.
  ///
  /// The subscribe below must happen either way: the topic is public, so it may
  /// well work with no session at all. If the sign-in lands a moment late, the
  /// [_retryInterval] loop re-attaches and picks it up.
  void _signIn(SupabaseClient client) {
    try {
      if (client.auth.currentUser != null) return;
      // `unawaited` alone would let a rejection escape into the zone.
      unawaited(
        client.auth.signInAnonymously().then<void>((_) {}, onError: (_) {}),
      );
    } catch (_) {
      // No session is not a reason to skip the join.
    }
  }

  void _onStatus(
    RealtimeChannel channel,
    RealtimeSubscribeStatus status,
    Object? error,
  ) {
    if (_disposed) return;
    // A replaced channel keeps emitting: leaving a topic fires `closed` on the
    // *old* channel, which can arrive after the new one is already subscribed.
    // Without this guard that stale `closed` marks us failed and the 4 s loop
    // tears down a healthy channel, forever.
    if (!identical(channel, _channel)) return;
    // `closed`, `channelError` and `timedOut` all land here and all set
    // `_failed`, which is what makes `_tick` re-attach within [_retryInterval].
    _connected = status == RealtimeSubscribeStatus.subscribed;
    _failed = !_connected;
  }

  void _detach() {
    final channel = _channel;
    _channel = null;
    _connected = false;
    if (channel == null) return;
    unawaited(_remove(channel));
  }

  Future<void> _remove(RealtimeChannel channel) async {
    try {
      await Supabase.instance.client.removeChannel(channel);
    } catch (_) {
      // Nothing to clean up if the client is gone.
    }
  }
}
