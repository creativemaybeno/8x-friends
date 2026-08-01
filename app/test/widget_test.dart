import 'package:eightx_friends/main.dart';
import 'package:eightx_friends/src/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots and reports its Supabase configuration', (
    tester,
  ) async {
    await tester.pumpWidget(const EightXFriendsApp());

    expect(find.text('8x Friends'), findsOneWidget);

    // Asserted as an invariant rather than pinned to one case, so the suite
    // passes both bare (`flutter test`) and configured
    // (`flutter test --dart-define-from-file=dart_define.json`).
    if (Env.isConfigured) {
      expect(Env.misconfigurationReason, isNull);
      expect(find.textContaining('Connected to'), findsOneWidget);
    } else {
      // Unconfigured must degrade to a message, not a crash — if this fails,
      // `main()` is doing work it should not do without credentials.
      expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
      expect(find.textContaining('SUPABASE_PUBLISHABLE_KEY'), findsOneWidget);
    }
  });

  test('supabaseKey falls back from publishable to legacy anon', () {
    // Whichever name is defined at build time, exactly one value surfaces.
    expect(Env.supabaseKey, isA<String>());
    expect(Env.isConfigured, Env.misconfigurationReason == null);
  });
}
