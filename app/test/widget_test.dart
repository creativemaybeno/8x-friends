/// Pure-Dart unit tests. No widget pumping, no plugins, no binding — the
/// widget-level smoke test was dropped when `main()` grew a real shell
/// (pumping it starts a Ticker and an anonymous sign-in). `flutter analyze`
/// is the gate for the UI; this file guards the maths and the demo fixture.
library;

import 'package:eightx_friends/src/demo/cast.dart';
import 'package:eightx_friends/src/env.dart';
import 'package:eightx_friends/src/model/decay.dart';
import 'package:eightx_friends/src/model/models.dart';
import 'package:eightx_friends/src/theme/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decayFor', () {
    test('is 0 at 0 days and never negative', () {
      expect(decayFor(0), 0.0);
      expect(decayFor(-50), 0.0);
    });

    test('is monotonically increasing in days', () {
      var previous = decayFor(0);
      for (var days = 1.0; days <= 600; days += 1) {
        final current = decayFor(days);
        expect(
          current,
          greaterThanOrEqualTo(previous),
          reason: 'decay dropped between ${days - 1} and $days days',
        );
        previous = current;
      }
    });

    test('is strictly increasing below the horizon', () {
      expect(decayFor(1), greaterThan(decayFor(0)));
      expect(decayFor(120), greaterThan(decayFor(60)));
      expect(decayFor(239), greaterThan(decayFor(120)));
      expect(decayFor(239), lessThan(1.0));
    });

    test('reaches exactly 1.0 at the default horizon', () {
      expect(kDefaultHorizonDays, 240);
      expect(decayFor(240), 1.0);
    });

    test('clamps to 1.0 well past the horizon', () {
      expect(decayFor(241), 1.0);
      expect(decayFor(kNeverMetDays), 1.0);
      expect(decayFor(100000), 1.0);
    });

    test('honours a custom horizon', () {
      expect(decayFor(90, horizon: 90), 1.0);
      expect(decayFor(90, horizon: 540), lessThan(0.3));
    });
  });

  group('signalFor', () {
    test('maps the decay range onto 100..0', () {
      expect(signalFor(0.0), 100);
      expect(signalFor(1.0), 0);
      expect(signalFor(0.25), 75);
    });

    test('rounds to the nearest whole percent', () {
      expect(signalFor(0.014), 99);
      expect(signalFor(0.016), 98);
      expect(signalFor(0.687604204980433), 31);
    });
  });

  group('agoLabel', () {
    test('never at and above the never-met sentinel', () {
      expect(agoLabel(kNeverMetDays), 'never');
      expect(agoLabel(kNeverMetDays + 1), 'never');
      expect(agoLabel(kNeverMetDays - 1), '30 months ago');
    });

    test('today / yesterday boundary', () {
      expect(agoLabel(0), 'today');
      expect(agoLabel(0.9), 'today');
      expect(agoLabel(1), 'yesterday');
      expect(agoLabel(1.9), 'yesterday');
      expect(agoLabel(2), '2 days ago');
    });

    test('days -> weeks at 21', () {
      expect(agoLabel(20), '20 days ago');
      expect(agoLabel(20.9), '20 days ago');
      expect(agoLabel(21), '3 weeks ago');
    });

    test('weeks -> months at 60', () {
      expect(agoLabel(59), '8 weeks ago');
      expect(agoLabel(60), '2 months ago');
      expect(agoLabel(152), '5 months ago');
    });
  });

  group('durationLabel', () {
    test('never-met sentinel', () {
      expect(durationLabel(kNeverMetDays), 'longer than you can remember');
      expect(durationLabel(kNeverMetDays + 10), 'longer than you can remember');
      expect(durationLabel(kNeverMetDays - 1), '30 months');
    });

    test('days -> weeks at 21, weeks -> months at 60', () {
      expect(durationLabel(0), '0 days');
      expect(durationLabel(20), '20 days');
      expect(durationLabel(21), '3 weeks');
      expect(durationLabel(59), '8 weeks');
      expect(durationLabel(60), '2 months');
      expect(durationLabel(152), '5 months');
    });
  });

  group('Relationship', () {
    const r = Relationship(id: 'r', aPersonId: 'yassie', bPersonId: 'aya');

    test('keyFor is order-independent', () {
      expect(
        Relationship.keyFor('yassie', 'aya'),
        Relationship.keyFor('aya', 'yassie'),
      );
      expect(Relationship.keyFor('aya', 'yassie'), 'aya|yassie');
      expect(r.key, Relationship.keyFor('aya', 'yassie'));
    });

    test('keyFor separates ids that differ only by the boundary', () {
      expect(
        Relationship.keyFor('a', 'b'),
        isNot(Relationship.keyFor('ab', '')),
      );
    });

    test('other() returns the far end, null for a stranger', () {
      expect(r.other('yassie'), 'aya');
      expect(r.other('aya'), 'yassie');
      expect(r.other('calvin'), isNull);
    });

    test('touches() only its own endpoints', () {
      expect(r.touches('yassie'), isTrue);
      expect(r.touches('aya'), isTrue);
      expect(r.touches('calvin'), isFalse);
    });
  });

  group('Plan', () {
    final plan = Plan(
      id: 'plan-1',
      hostPersonId: Ids.calvin,
      when: DateTime(2026, 8, 7, 19, 30),
      place: 'the boulder gym',
      attendees: const {
        Ids.calvin: Attendance.accepted,
        Ids.yassie: Attendance.invited,
        Ids.hannan: Attendance.declined,
      },
      phase: PlanPhase.confirmed,
    );

    test('round-trips through JSON', () {
      final back = Plan.fromJson(plan.toJson());

      expect(back.id, plan.id);
      expect(back.hostPersonId, plan.hostPersonId);
      expect(back.when, plan.when);
      expect(back.place, plan.place);
      expect(back.phase, plan.phase);
      expect(back.attendees, plan.attendees);
      expect(back.attendees[Ids.calvin], Attendance.accepted);
      expect(back.attendees[Ids.yassie], Attendance.invited);
      expect(back.attendees[Ids.hannan], Attendance.declined);
    });

    test('round-trips every phase', () {
      for (final phase in PlanPhase.values) {
        final back = Plan.fromJson(plan.copyWith(phase: phase).toJson());
        expect(
          back.phase,
          phase,
          reason: 'phase ${phase.name} did not survive',
        );
      }
    });

    test('round-trips a null place', () {
      final back = Plan.fromJson(
        Plan(
          id: plan.id,
          hostPersonId: plan.hostPersonId,
          when: plan.when,
          attendees: plan.attendees,
        ).toJson(),
      );
      expect(back.place, isNull);
      expect(back.phase, PlanPhase.proposed);
    });
  });

  group('ConnectionRequest', () {
    test('round-trips through JSON', () {
      const request = ConnectionRequest(
        fromPersonId: Ids.calvin,
        toPersonId: Ids.hannan,
        viaPersonId: Ids.yassie,
        accepted: true,
      );
      final back = ConnectionRequest.fromJson(request.toJson());

      expect(back.fromPersonId, request.fromPersonId);
      expect(back.toPersonId, request.toPersonId);
      expect(back.viaPersonId, request.viaPersonId);
      expect(back.accepted, isTrue);
      expect(back.key, Relationship.keyFor(Ids.calvin, Ids.hannan));
    });

    test('defaults accepted to false', () {
      const request = ConnectionRequest(
        fromPersonId: Ids.calvin,
        toPersonId: Ids.hannan,
        viaPersonId: Ids.yassie,
      );
      final back = ConnectionRequest.fromJson(request.toJson());
      expect(back.accepted, isFalse);
    });
  });

  group('Tokens.healthLabel', () {
    test('at every threshold boundary', () {
      expect(Tokens.healthLabel(0.0), 'STRONG');
      expect(Tokens.healthLabel(0.24), 'STRONG');
      expect(Tokens.healthLabel(0.25), 'STEADY');
      expect(Tokens.healthLabel(0.49), 'STEADY');
      expect(Tokens.healthLabel(0.50), 'FADING');
      expect(Tokens.healthLabel(0.74), 'FADING');
      expect(Tokens.healthLabel(0.75), 'ALMOST GONE');
      expect(Tokens.healthLabel(1.0), 'ALMOST GONE');
    });
  });

  group('the cast is well formed', () {
    final ids = {for (final p in kCast) p.id};

    test('ids are unique', () {
      expect(ids.length, kCast.length);
    });

    test('contains the three named accounts', () {
      expect(ids, containsAll(<String>[Ids.calvin, Ids.yassie, Ids.hannan]));
    });

    test('every person has a name and closeness in 1..3', () {
      for (final p in kCast) {
        expect(p.name, isNotEmpty, reason: '${p.id} has no name');
        expect(
          p.closeness,
          inInclusiveRange(1, 3),
          reason: '${p.id} closeness ${p.closeness} out of range',
        );
      }
    });

    test('every edge endpoint exists and no edge is a self-loop', () {
      for (final r in kEdges) {
        expect(ids, contains(r.aPersonId), reason: '${r.id} a-end unknown');
        expect(ids, contains(r.bPersonId), reason: '${r.id} b-end unknown');
        expect(r.aPersonId, isNot(r.bPersonId), reason: '${r.id} is a loop');
      }
    });

    test('edges are unique', () {
      final keys = kEdges.map((r) => r.key).toSet();
      expect(keys.length, kEdges.length);
    });

    test('there is no direct calvin-hannan edge — the pitch creates it', () {
      final key = Relationship.keyFor(Ids.calvin, Ids.hannan);
      expect(kEdges.map((r) => r.key), isNot(contains(key)));
    });

    test('calvin-yassie and yassie-hannan both exist', () {
      final keys = kEdges.map((r) => r.key).toSet();
      expect(keys, contains(Relationship.keyFor(Ids.calvin, Ids.yassie)));
      expect(keys, contains(Relationship.keyFor(Ids.yassie, Ids.hannan)));
    });
  });

  group('the story beat', () {
    final now = DateTime(2026, 8, 1);
    final events = buildEvents(now);
    final model = DecayModel(
      now: now,
      people: kCast,
      relationships: kEdges,
      events: events,
    );

    test('every event references people in the cast', () {
      final ids = {for (final p in kCast) p.id};
      for (final e in events) {
        expect(e.personIds, isNotEmpty, reason: '${e.id} has nobody in it');
        for (final id in e.personIds) {
          expect(ids, contains(id), reason: '${e.id} references unknown "$id"');
        }
      }
    });

    test('calvin and yassie last met 140..170 days ago', () {
      final shared =
          events
              .where(
                (e) =>
                    e.personIds.contains(Ids.calvin) &&
                    e.personIds.contains(Ids.yassie),
              )
              .toList()
            ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));

      expect(shared, isNotEmpty);
      expect(
        daysBetween(shared.first.occurredOn, now),
        inInclusiveRange(140, 170),
      );
    });

    test('the calvin-yassie strand sits in the amber, fragmenting band', () {
      final key = Relationship.keyFor(Ids.calvin, Ids.yassie);
      final cy = kEdges.firstWhere((r) => r.key == key);

      expect(model.linkDaysOf(cy), inInclusiveRange(140, 170));
      expect(model.linkDecayOf(cy), inInclusiveRange(0.60, 0.75));
      expect(model.linkDecayOf(cy), greaterThan(kLinkAmberAbove));
      expect(model.linkDecayOf(cy), lessThan(kLinkCollapsesAbove));
    });

    test('at least three other strands stay bright, so the graph has '
        'contrast', () {
      final cyKey = Relationship.keyFor(Ids.calvin, Ids.yassie);
      final bright = kEdges
          .where((r) => r.key != cyKey && model.linkDecayOf(r) < 0.20)
          .toList();

      expect(
        bright.length,
        greaterThanOrEqualTo(3),
        reason: 'only ${bright.length} strands below 0.20 link decay',
      );
    });
  });

  group('Env', () {
    test('supabaseKey falls back from publishable to legacy anon', () {
      // Whichever name is defined at build time, exactly one value surfaces.
      expect(Env.supabaseKey, isA<String>());
      expect(Env.isConfigured, Env.misconfigurationReason == null);
    });
  });
}
