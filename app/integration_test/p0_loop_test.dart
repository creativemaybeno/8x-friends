// Drives the real P0 demo loop on a real device against the LIVE backend.
//   flutter test integration_test/p0_loop_test.dart -d <simulator-id> \
//     --dart-define-from-file=dart_define.json
import 'package:eightx_friends/src/data/supabase_repository.dart';
import 'package:eightx_friends/src/model/decay.dart';
import 'package:eightx_friends/src/env.dart';
import 'package:eightx_friends/src/model/models.dart';
import 'package:eightx_friends/src/state/app_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P0: boot -> seed -> focus -> log -> re-ignite -> nudge reorder', (
    tester,
  ) async {
    expect(Env.isConfigured, isTrue, reason: 'run with --dart-define-from-file');
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
    );

    final s = AppState(SupabaseGraphRepository());
    await s.boot();
    expect(s.bootError, isNull, reason: 'boot must not error');
    debugPrint(
      'BOOT people=${s.people.length} rels=${s.relationships.length} '
      'events=${s.events.length}',
    );
    expect(s.people.length, greaterThan(20));
    expect(s.relationships.length, greaterThan(30));

    // The graph must be mostly ALIVE, with a few clearly-neglected people.
    final decayed = s.people.where((p) => s.decay.decayOf(p.id) > 0.9).length;
    final alive = s.people.where((p) => s.decay.decayOf(p.id) < 0.4).length;
    debugPrint('GRAPH alive=$alive neglected=$decayed of ${s.people.length}');
    expect(alive, greaterThan(8), reason: 'graph must read as alive');
    expect(decayed, greaterThan(2), reason: 'need visible neglect for the story');

    final before = s.nudges;
    debugPrint(
      'NUDGE before: '
      '${before.map((n) => "${n.person.name} ${n.days.round()}d c${n.person.closeness}").join(" | ")}',
    );
    expect(before, isNotEmpty);
    final target = before.first.person;

    // focus -> WE MET UP must pre-select that person.
    s.focusPerson(target.id);
    s.setMode(AppMode.log);
    expect(
      s.selectedPersonIds,
      contains(target.id),
      reason: 'WE MET UP must pre-select the focused person',
    );

    final decayBefore = s.decay.decayOf(target.id);
    await s.logMeetUp(
      occurredOn: DateTime.now(),
      personIds: [target.id],
      place: 'stage',
    );
    final decayAfter = s.decay.decayOf(target.id);
    debugPrint(
      'RE-IGNITE ${target.name}: '
      '${decayBefore.toStringAsFixed(3)} -> ${decayAfter.toStringAsFixed(3)}',
    );
    expect(decayAfter, lessThan(decayBefore));
    expect(decayAfter, lessThan(0.05), reason: 'met today == fresh');

    final after = s.nudges;
    debugPrint(
      'NUDGE after:  '
      '${after.map((n) => "${n.person.name} ${n.days.round()}d").join(" | ")}',
    );
    expect(
      after.map((n) => n.person.id),
      isNot(contains(target.id)),
      reason: 'the person you just saw must drop off the nudge list',
    );

    // The time scrubber must decay the whole graph.
    s.setTimeOffsetDays(0);
    final aliveNow = s.relationships
        .where((r) => s.decay.linkDecayOf(r) < 0.5)
        .length;
    s.setTimeOffsetDays(400);
    final alive400 = s.relationships
        .where((r) => s.decay.linkDecayOf(r) < 0.5)
        .length;
    s.setTimeOffsetDays(0);
    debugPrint('SCRUB alive links today=$aliveNow at-400d=$alive400');
    expect(alive400, lessThan(aliveNow));

    // The group assembler must produce exactly five.
    s.assembleGroupFrom(null);
    debugPrint('GROUP ${s.group.map((p) => p.name).join(", ")}');
    expect(s.group.length, kGroupSize);

    s.dispose();
  }, timeout: const Timeout(Duration(minutes: 4)));
}
