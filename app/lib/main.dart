import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Starting unconfigured is allowed on purpose: `flutter run` should work on a
  // fresh clone before anyone has wired up Supabase credentials, and the home
  // screen says what is missing.
  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
    );
  }

  runApp(const EightXFriendsApp());
}

class EightXFriendsApp extends StatelessWidget {
  const EightXFriendsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '8x Friends',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7DE7F7),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const StartupScreen(),
    );
  }
}

/// Placeholder home. Replace with the real shell once the v2 designs in the
/// Claude Design project are being built out.
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reason = Env.misconfigurationReason;
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('8x Friends', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                reason ?? 'Connected to ${Uri.parse(Env.supabaseUrl).host}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: reason == null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
