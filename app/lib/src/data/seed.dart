/// Deterministic fixture generator. Same input, same graph, every run.
///
/// No `dart:math` `Random` — its sequence is not guaranteed across versions and
/// the demo depends on the shape of this graph.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/models.dart';

/// Small linear congruential generator. Reproducible everywhere.
class _Lcg {
  _Lcg(this._s);
  int _s;

  int _next() => _s = (_s * 1103515245 + 12345) & 0x7fffffff;

  /// The low bits of a power-of-two-modulus LCG have a period as short as 2, so
  /// `_s % max` cycles through a handful of values and any "keep picking until
  /// N distinct" loop never terminates. Take the high bits instead.
  int nextInt(int max) => (_next() >> 15) % max;

  double nextDouble() => _next() / 0x80000000;

  T pick<T>(List<T> items) => items[nextInt(items.length)];
}

int _hash(String s) {
  var h = 0x811c9dc5;
  for (final u in s.codeUnits) {
    h = (h ^ u) & 0xffffffff;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

const _hex = '0123456789abcdef';

/// Deterministic uuid v4-shaped id, unique per owner so two seeded accounts
/// never collide on the shared primary key.
String _uuid(String salt) {
  final r = _Lcg(_hash(salt) | 1);
  final b = StringBuffer();
  for (var i = 0; i < 32; i++) {
    if (i == 8 || i == 12 || i == 16 || i == 20) b.write('-');
    if (i == 12) {
      b.write('4');
    } else if (i == 16) {
      b.write(_hex[8 + r.nextInt(4)]);
    } else {
      b.write(_hex[r.nextInt(16)]);
    }
  }
  return b.toString();
}

class _Seeded {
  _Seeded(this.name, this.context, this.closeness, this.gapDays, this.metVia);
  final String name;
  final String context;
  final int closeness;

  /// When non-null, this person has not been seen for this many days.
  final int? gapDays;
  final String? metVia;

  late String id;
}

// The roster is written out rather than generated: the demo lives or dies on
// this shape. Five contexts, five people each.
final _roster = <_Seeded>[
  _Seeded('Mara', Contexts.family, 3, 447, null),
  _Seeded('Tobias', Contexts.family, 2, null, null),
  _Seeded('Elin', Contexts.family, 3, null, null),
  _Seeded('Jonas', Contexts.family, 1, null, null),
  _Seeded('Greta', Contexts.family, 2, null, null),
  _Seeded('Nils', Contexts.climb, 3, 268, 'the gym'),
  _Seeded('Yara', Contexts.climb, 2, null, 'the gym'),
  _Seeded('Sacha', Contexts.climb, 3, null, 'Nils'),
  _Seeded('Bex', Contexts.climb, 1, null, null),
  _Seeded('Ravi', Contexts.climb, 2, null, 'a bouldering trip'),
  _Seeded('Priya', Contexts.work, 2, 530, 'the old team'),
  _Seeded('Daniel', Contexts.work, 1, null, null),
  _Seeded('Marlene', Contexts.work, 3, null, null),
  _Seeded('Omar', Contexts.work, 2, null, 'a conference'),
  _Seeded('Ines', Contexts.work, 1, null, null),
  _Seeded('Kasper', Contexts.uni, 1, 341, null),
  _Seeded('Leila', Contexts.uni, 3, null, null),
  _Seeded('Fynn', Contexts.uni, 2, null, null),
  _Seeded('Noor', Contexts.uni, 2, null, 'Leila'),
  _Seeded('Theo', Contexts.uni, 1, null, null),
  _Seeded('Ana', Contexts.hood, 2, 221, null),
  _Seeded('Milo', Contexts.hood, 1, null, null),
  _Seeded('Rosa', Contexts.hood, 3, null, 'the building'),
  _Seeded('Hugo', Contexts.hood, 1, null, null),
  _Seeded('Lotte', Contexts.hood, 2, null, 'Rosa'),
];

const _places = [
  'the kitchen table',
  'Bar Kabul',
  'the gym',
  'a long walk',
  'the allotment',
  'the office roof',
  'Sunday lunch',
  'the climbing wall',
  'the corner cafe',
  'the lake',
];

Future<void> seedFixture(SupabaseClient c, String profileId) async {
  try {
    final me = await c
        .from('profiles')
        .select('display_name')
        .eq('id', profileId)
        .maybeSingle();
    final myName = (me?['display_name'] as String?)?.trim();

    final r = _Lcg(20260801);
    final today = DateTime.now();
    DateTime dayAgo(int d) => DateTime(today.year, today.month, today.day - d);

    // --- people -------------------------------------------------------------
    final mePersonId = _uuid('$profileId:me');
    for (var i = 0; i < _roster.length; i++) {
      _roster[i].id = _uuid('$profileId:person:$i');
    }

    // PostgREST rejects a bulk insert whose objects do not all carry the *same*
    // keys ("All object keys must match"), so every row spells out every
    // column — nulls included.
    final peopleRows = <Map<String, dynamic>>[
      {
        'id': mePersonId,
        'owner_id': profileId,
        'name': (myName == null || myName.isEmpty) ? 'YOU' : myName,
        'context': null,
        'closeness': 3,
        'is_me': true,
        'met_via': null,
        'birthday_day': null,
        'birthday_month': null,
      },
      for (var i = 0; i < _roster.length; i++)
        {
          'id': _roster[i].id,
          'owner_id': profileId,
          'name': _roster[i].name,
          'context': _roster[i].context,
          'closeness': _roster[i].closeness,
          'is_me': false,
          'met_via': _roster[i].metVia,
          'birthday_day': i % 4 == 1 ? 2 + (i * 7) % 26 : null,
          'birthday_month': i % 4 == 1 ? 1 + (i * 5) % 12 : null,
        },
    ];

    // --- events -------------------------------------------------------------
    final eventRows = <Map<String, dynamic>>[];
    final attendeeRows = <Map<String, dynamic>>[];
    final metCount = {for (final p in _roster) p.id: 0};

    /// Pair key -> the smallest day offset the two shared a meet-up at.
    final together = <String, int>{};

    void addEvent(int dayOffset, List<_Seeded> attendees, {String? place}) {
      if (attendees.isEmpty) return;
      final id = _uuid('$profileId:event:${eventRows.length}');
      eventRows.add({
        'id': id,
        'owner_id': profileId,
        'occurred_on': dayAgo(dayOffset).toIso8601String().substring(0, 10),
        'place': place,
      });
      // Every meet-up is one you were at, so the me-node's links stay as fresh
      // as the person on the other end of them.
      attendeeRows.add({'event_id': id, 'person_id': mePersonId});
      for (final a in attendees) {
        attendeeRows.add({'event_id': id, 'person_id': a.id});
        metCount[a.id] = metCount[a.id]! + 1;
      }
      for (var i = 0; i < attendees.length; i++) {
        for (var j = i + 1; j < attendees.length; j++) {
          final x = attendees[i].id, y = attendees[j].id;
          final k = x.compareTo(y) < 0 ? '$x|$y' : '$y|$x';
          final prev = together[k];
          if (prev == null || dayOffset < prev) together[k] = dayOffset;
        }
      }
    }

    bool eligible(_Seeded p, int dayOffset) =>
        p.gapDays == null || dayOffset >= p.gapDays!;

    // The gap people get one clean last sighting exactly at their gap.
    for (final p in _roster) {
      final gap = p.gapDays;
      if (gap == null) continue;
      final company = [
        for (final o in _roster)
          if (o.context == p.context && o.id != p.id && eligible(o, gap)) o,
      ];
      addEvent(gap, [
        p,
        ...company.take(1 + r.nextInt(2)),
      ], place: r.pick(_places));
    }

    while (eventRows.length < 79) {
      // Skewed toward recent: the graph should look alive near today.
      final t = r.nextDouble();
      final dayOffset = (t * t * 540).round();
      final context = r.pick(Contexts.all);
      final pool = [
        for (final p in _roster)
          if (p.context == context && eligible(p, dayOffset)) p,
      ];
      if (pool.isEmpty) continue;

      double weight(_Seeded p) {
        var w = p.closeness * p.closeness.toDouble();
        if (p.closeness == 3 && dayOffset < 150) w *= 2.6;
        return w;
      }

      final wanted = 1 + r.nextInt(pool.length.clamp(1, 4));
      final chosen = <_Seeded>[];
      while (chosen.length < wanted) {
        final remaining = [
          for (final p in pool)
            if (!chosen.contains(p)) p,
        ];
        if (remaining.isEmpty) break;
        var total = 0.0;
        for (final p in remaining) {
          total += weight(p);
        }
        var pickPoint = r.nextDouble() * total;
        var taken = remaining.last;
        for (final p in remaining) {
          pickPoint -= weight(p);
          if (pickPoint <= 0) {
            taken = p;
            break;
          }
        }
        chosen.add(taken);
      }

      // One outsider now and then, so STRATA is layered but not sealed.
      if (r.nextDouble() < 0.22 && chosen.length < 5) {
        final outsiders = [
          for (final p in _roster)
            if (p.context != context && eligible(p, dayOffset)) p,
        ];
        if (outsiders.isNotEmpty) chosen.add(r.pick(outsiders));
      }

      addEvent(
        dayOffset,
        chosen,
        place: r.nextDouble() < 0.7 ? r.pick(_places) : null,
      );
    }

    // Nobody should be a stranger unless the fixture meant them to be.
    for (final p in _roster) {
      if (metCount[p.id]! > 0) continue;
      final day = (p.gapDays ?? 300) + r.nextInt(40);
      addEvent(day, [p], place: r.pick(_places));
    }

    // --- relationships ------------------------------------------------------
    // Built after the events so the extra edges follow real co-attendance: a
    // link nobody ever met across renders as already collapsed.
    final pairs = <String>{};
    final relRows = <Map<String, dynamic>>[];
    void link(String x, String y) {
      if (x == y) return;
      final (a, b) = x.compareTo(y) < 0 ? (x, y) : (y, x);
      if (!pairs.add('$a|$b')) return;
      relRows.add({
        'id': _uuid('$profileId:rel:$a:$b'),
        'owner_id': profileId,
        'a_person_id': a,
        'b_person_id': b,
      });
    }

    for (final context in Contexts.all) {
      final group = [
        for (final p in _roster)
          if (p.context == context) p,
      ];
      if (group.length < 5) continue;
      for (var i = 0; i < group.length; i++) {
        link(group[i].id, group[(i + 1) % group.length].id);
      }
      link(group[0].id, group[2].id);
      link(group[1].id, group[4].id);
    }
    final shared = together.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final s in shared) {
      if (relRows.length >= 50) break;
      final parts = s.key.split('|');
      link(parts[0], parts[1]);
    }
    // Deterministic sweep so the fixture can never depend on co-attendance
    // reaching 50 — a demo must not be able to hang here.
    for (var i = 0; i < _roster.length && relRows.length < 50; i++) {
      for (var j = i + 1; j < _roster.length && relRows.length < 50; j++) {
        link(_roster[i].id, _roster[j].id);
      }
    }
    // You know everyone in your own graph: the centre node needs springs.
    for (final p in _roster) {
      link(mePersonId, p.id);
    }

    await c.from('people').insert(peopleRows);
    await c.from('relationships').insert(relRows);
    await c.from('events').insert(eventRows);
    await c.from('event_people').insert(attendeeRows);
  } on PostgrestException catch (e) {
    throw Exception('Could not build your graph: ${e.message}');
  }
}
