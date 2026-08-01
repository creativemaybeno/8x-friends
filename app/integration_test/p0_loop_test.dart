/// Drives the P0 demo loop on a real device: boot, identity, plan, the
/// morning after, renewal, reset and a manual log.
///
/// ```sh
/// flutter test integration_test/p0_loop_test.dart -d <simulator-id> \
///   --dart-define-from-file=dart_define.json
/// ```
///
/// The graph is a client-side fixture, so this passes with or without a
/// reachable backend; Supabase is only initialised so the broadcast channel
/// has something to join.
library;

import 'package:eightx_friends/src/demo/cast.dart';
import 'package:eightx_friends/src/env.dart';
import 'package:eightx_friends/src/model/models.dart';
import 'package:eightx_friends/src/state/app_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'P0: boot -> plan -> morning after -> renewed -> log',
    (tester) async {
      if (Env.isConfigured) {
        await Supabase.initialize(
          url: Env.supabaseUrl,
          publishableKey: Env.supabaseKey,
        );
      } else {
        debugPrint('BOOT no backend configured: running the loop offline');
      }

      final s = AppState();
      await s.boot();
      expect(s.isBooting, isFalse);
      expect(s.mode, AppMode.identity, reason: 'boot hands over to identity');

      await s.chooseWho(Who.calvin);
      expect(s.meId, Ids.calvin);
      expect(s.mode, AppMode.home);
      debugPrint(
        'BOOT people=${s.people.length} rels=${s.relationships.length} '
        'events=${s.events.length} channel=${s.channelConnected}',
      );
      expect(s.people.length, 16);
      expect(s.relationships.length, greaterThan(25));

      // The graph must read as alive, with a few clearly-neglected strands.
      final alive = s.people.where((p) => s.decay.decayOf(p.id) < 0.4).length;
      final faded = s.relationships
          .where((r) => s.decay.linkDecayOf(r) > 0.6)
          .length;
      debugPrint('GRAPH alive=$alive fadedLinks=$faded of ${s.people.length}');
      expect(alive, greaterThan(8), reason: 'graph must read as alive');
      expect(
        faded,
        greaterThan(2),
        reason: 'need visible neglect for the story',
      );

      // THE story beat: Calvin and Yassie have drifted. Read the *link*, not
      // the node — her node is bright because she still sees Hannan.
      final calvinYassie = s.relationships.firstWhere(
        (r) => r.key == Relationship.keyFor(Ids.calvin, Ids.yassie),
      );
      final strandBefore = s.decay.linkDecayOf(calvinYassie);
      debugPrint('STRAND calvin|yassie ${strandBefore.toStringAsFixed(3)}');
      expect(strandBefore, greaterThan(0.6));
      expect(strandBefore, lessThan(0.85));

      // Focus her, then propose.
      s.focusPerson(Ids.yassie);
      expect(s.mode, AppMode.focus);
      expect(s.isDirectlyConnected(Ids.yassie), isTrue);

      final n = s.now;
      final when = DateTime(
        n.year,
        n.month,
        n.day,
        19,
      ).add(const Duration(days: 3));
      s.setMode(AppMode.planTime);
      s.proposePlan(
        withPersonId: Ids.yassie,
        when: when,
        place: 'the boulder gym',
      );
      expect(s.plan, isNotNull);
      expect(s.plan!.phase, PlanPhase.proposed);
      expect(s.planIds, containsAll(<String>[Ids.calvin, Ids.yassie]));
      expect(s.pendingIds, contains(Ids.yassie));
      expect(
        s.mode,
        AppMode.home,
        reason: 'sending drops you back to the graph',
      );

      // Bring someone along; the director makes them accept.
      final guest = s.directPeople.firstWhere((p) => p.id != Ids.yassie);
      s.addToPlan(guest.id);
      expect(s.attendanceOf(guest.id), Attendance.invited);
      s.nudgeDirector();
      expect(
        s.attendanceOf(guest.id),
        Attendance.accepted,
        reason: 'the scripted beat must land on demand',
      );
      debugPrint(
        'PLAN ${s.planIds.join(", ")} pending=${s.pendingIds.join(", ")}',
      );

      // The morning after.
      s.advanceToMorningAfter();
      expect(s.plan!.phase, PlanPhase.past);
      expect(s.awaitingConfirmation, isTrue);
      expect(s.now.isAfter(when), isTrue, reason: 'the demo clock must move');

      final guestLink = s.relationships.firstWhere(
        (r) => r.key == Relationship.keyFor(Ids.calvin, guest.id),
      );
      final guestBefore = s.decay.linkDecayOf(guestLink);
      s.confirmMeetupHappened();
      final guestAfter = s.decay.linkDecayOf(guestLink);
      debugPrint(
        'RENEW ${guest.name}: '
        '${guestBefore.toStringAsFixed(3)} -> ${guestAfter.toStringAsFixed(3)}',
      );
      expect(s.plan!.phase, PlanPhase.renewed);
      expect(s.renewedMessage, isNotNull, reason: 'the celebration must fire');
      expect(s.renewingKeys, contains(guestLink.key));
      expect(guestAfter, lessThan(guestBefore));
      expect(guestAfter, lessThan(0.05), reason: 'met yesterday == fresh');

      // Consent-based connection: Hannan is one hop away, through Yassie.
      s.resetDemo();
      expect(s.plan, isNull);
      expect(s.connectionRequests, isEmpty);
      expect(s.isDirectlyConnected(Ids.hannan), isFalse);
      expect(s.indirectPeople.map((p) => p.id), contains(Ids.hannan));
      expect(s.mutualFor(Ids.hannan)?.id, Ids.yassie);

      s.requestConnection(Ids.hannan);
      expect(s.isConnectionPending(Ids.hannan), isTrue);
      s.nudgeDirector();
      expect(s.isDirectlyConnected(Ids.hannan), isTrue);
      final newEdge = s.relationships.firstWhere(
        (r) => r.key == Relationship.keyFor(Ids.calvin, Ids.hannan),
      );
      final seeded = s.decay.linkDecayOf(newEdge);
      debugPrint('CONNECT calvin|hannan ${seeded.toStringAsFixed(3)}');
      expect(seeded, greaterThan(0.35), reason: 'a new connection is neutral');
      expect(seeded, lessThan(0.75));

      // Manual re-ignition, straight from the log sheet.
      s.resetDemo();
      expect(
        s.decay.linkDecayOf(calvinYassie),
        closeTo(strandBefore, 0.02),
        reason: 'reset must put the story beat back',
      );
      s.logMeetup(personIds: [Ids.yassie], on: s.now);
      final strandAfter = s.decay.linkDecayOf(calvinYassie);
      debugPrint(
        'LOG calvin|yassie '
        '${strandBefore.toStringAsFixed(3)} -> ${strandAfter.toStringAsFixed(3)}',
      );
      expect(strandAfter, lessThan(strandBefore));
      expect(strandAfter, lessThan(0.05), reason: 'met today == fresh');
      expect(s.renewingKeys, contains(calvinYassie.key));
      expect(s.mode, AppMode.home);

      s.dispose();
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
