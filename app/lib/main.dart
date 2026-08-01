/// Entry point: render the first frame, then connect.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/env.dart';
import 'src/notify/notifications.dart';
import 'src/state/app_state.dart';
import 'src/theme/tokens.dart';
import 'src/ui/shell.dart';

/// Nothing may be awaited before [runApp]. `Supabase.initialize` awaits a
/// platform channel (shared_preferences); if that hangs — a stale plugin
/// registrant after a dependency change is enough — the first frame never
/// renders and iOS just leaves its white launch screen up, with no way to see
/// why. Render first, connect after: the graph is a client-side fixture, so
/// the demo runs whether or not the socket ever opens.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Tokens.init();
  runApp(const EightXFriendsApp());
}

class EightXFriendsApp extends StatefulWidget {
  const EightXFriendsApp({super.key});

  @override
  State<EightXFriendsApp> createState() => _EightXFriendsAppState();
}

class _EightXFriendsAppState extends State<EightXFriendsApp> {
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = AppState();
    _start();
  }

  /// Starting unconfigured is allowed on purpose: a fresh clone should run,
  /// and every screen still works — only cross-device sync goes quiet.
  Future<void> _start() async {
    unawaited(
      Notifications.init().then((_) => Notifications.requestPermission()),
    );
    if (Env.isConfigured) {
      try {
        // A timeout turns "hangs forever on a blank screen" into a demo that
        // simply runs offline.
        await Supabase.initialize(
          url: Env.supabaseUrl,
          publishableKey: Env.supabaseKey,
        ).timeout(const Duration(seconds: 10));
      } catch (_) {
        // Fall through: the channel degrades to offline on its own.
      }
    }
    await _state.boot();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '8x Friends',
      debugShowCheckedModeBanner: false,
      theme: Tokens.theme(),
      home: AppScope(notifier: _state, child: const Shell()),
    );
  }
}
