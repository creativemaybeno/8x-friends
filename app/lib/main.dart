import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/data/supabase_repository.dart';
import 'src/env.dart';
import 'src/state/app_state.dart';
import 'src/theme/tokens.dart';
import 'src/ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Tokens.init();

  // Starting unconfigured is allowed on purpose: `flutter run` should work on a
  // fresh clone before anyone has wired up Supabase credentials, and the boot
  // overlay says what is missing.
  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
    );
  }

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
    if (Env.isConfigured) {
      _state.boot();
    }
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
