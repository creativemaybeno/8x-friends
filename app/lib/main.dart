import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/data/supabase_repository.dart';
import 'src/env.dart';
import 'src/state/app_state.dart';
import 'src/theme/tokens.dart';
import 'src/ui/shell.dart';

/// Nothing may be awaited before [runApp]. `Supabase.initialize` awaits a
/// platform channel (shared_preferences); if that hangs — a stale plugin
/// registrant after a dependency change is enough — the first frame never
/// renders and iOS just leaves its white launch screen up, with no way to see
/// why. Render first, connect after, and let the boot overlay report failures.
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
    _state = AppState(SupabaseGraphRepository());
    _start();
  }

  /// Starting unconfigured is allowed on purpose: a fresh clone should run, and
  /// the boot overlay says what is missing.
  Future<void> _start() async {
    if (!Env.isConfigured) return;
    try {
      // A timeout turns "hangs forever on a blank screen" into a message you
      // can read from the back of the room.
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseKey,
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      // Fall through: boot() will fail against the uninitialised client and
      // surface the reason on the overlay instead of dying silently here.
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
