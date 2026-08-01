/// Compile-time configuration.
///
/// Values come from `--dart-define`, normally via a file that is *not*
/// committed:
///
/// ```sh
/// cp dart_define.example.json dart_define.json   # then fill it in
/// flutter run --dart-define-from-file=dart_define.json
/// ```
///
/// `String.fromEnvironment` is a const constructor, so these are baked into the
/// binary at build time and tree-shake correctly. They are deliberately *not*
/// read from a runtime `.env` asset: shipping one inside the app bundle gives no
/// extra protection and one more thing to forget.
///
/// The publishable (formerly "anon") key is a public, RLS-scoped credential — it
/// is fine in a client build. The service-role / secret key never belongs here;
/// it stays server-side, in Supabase Edge Function secrets.
library;

abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase renamed the client-side key from "anon" to "publishable", and
  /// which one `supabase start` prints depends on the CLI version. Accept both
  /// so a fresh clone works either way.
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _anonKey;

  /// Whether the app has enough configuration to talk to Supabase at all.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Human-readable reason the app is not configured, or `null` when it is.
  static String? get misconfigurationReason {
    if (isConfigured) return null;
    final missing = [
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
    ];
    return 'Missing ${missing.join(' and ')}. '
        'Run with --dart-define-from-file=dart_define.json '
        '(copy dart_define.example.json first).';
  }
}
