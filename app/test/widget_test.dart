import 'package:eightx_friends/src/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The widget-level smoke test was dropped when `main()` grew a real shell:
  // pumping it starts a Ticker and an anonymous sign-in, neither of which
  // belongs in `flutter test`. `flutter analyze` is the gate for the UI.
  test('supabaseKey falls back from publishable to legacy anon', () {
    // Whichever name is defined at build time, exactly one value surfaces.
    expect(Env.supabaseKey, isA<String>());
    expect(Env.isConfigured, Env.misconfigurationReason == null);
  });
}
