/// The whole demo fixture: the cast, the edges between them, their meet-ups.
///
/// Straight out of the v3 design. Every edge carries its own **cadence** (the
/// median gap between that pair's meet-ups) and how many days it has been.
/// Decay reads `horizon = clamp(cadence * 6, 60, 900)`, so four months means
/// something different for a weekly friend than for a twice-a-year one.
library;

import '../model/models.dart';

/// Stable ids used by both phones and by the broadcast protocol.
abstract final class Ids {
  static const calvin = 'cal';
  static const yassie = 'yas';
  static const hannan = 'han';
}

const _cal = Ids.calvin;
const _yas = Ids.yassie;
const _han = Ids.hannan;
const _mira = 'mira';
const _tomas = 'tomas';
const _dara = 'dara';
const _noor = 'noor';
const _iker = 'iker';
const _sofia = 'sofia';
const _lena = 'lena';
const _kaito = 'kaito';
const _rui = 'rui';
const _pilar = 'pilar';
const _ines = 'ines';
const _jonas = 'jonas';
const _mei = 'mei';
const _bruno = 'bruno';
const _saga = 'saga';
const _otto = 'otto';
const _enzo = 'enzo';
const _ava = 'ava';
const _leo = 'leo';

/// The shared global cast. Identical on both phones.
const List<Person> kCast = [
  Person(
    id: _cal,
    name: 'Calvin',
    context: Contexts.work,
    closeness: 3,
    distanceKm: 0.0,
  ),
  Person(
    id: _yas,
    name: 'Yassie',
    context: Contexts.uni,
    closeness: 3,
    distanceKm: 4.4,
  ),
  Person(
    id: _mira,
    name: 'Mira',
    context: Contexts.work,
    closeness: 2,
    distanceKm: 3.5,
  ),
  Person(
    id: _tomas,
    name: 'Tomás',
    context: Contexts.climb,
    closeness: 2,
    distanceKm: 1.2,
  ),
  Person(
    id: _dara,
    name: 'Dara',
    context: Contexts.uni,
    closeness: 2,
    distanceKm: 380,
  ),
  Person(
    id: _noor,
    name: 'Noor',
    context: Contexts.work,
    closeness: 1,
    distanceKm: 9,
  ),
  Person(
    id: _iker,
    name: 'Iker',
    context: Contexts.climb,
    closeness: 1,
    distanceKm: 14,
  ),
  Person(
    id: _sofia,
    name: 'Sofia',
    context: Contexts.family,
    closeness: 3,
    distanceKm: 2.1,
  ),
  Person(
    id: _lena,
    name: 'Lena',
    context: Contexts.hood,
    closeness: 1,
    distanceKm: 0.6,
  ),
  Person(
    id: _kaito,
    name: 'Kaito',
    context: Contexts.uni,
    closeness: 1,
    distanceKm: 1200,
  ),
  Person(
    id: _han,
    name: 'Hannan',
    context: Contexts.climb,
    closeness: 2,
    distanceKm: 6,
  ),
  Person(
    id: _rui,
    name: 'Rui',
    context: Contexts.work,
    closeness: 2,
    distanceKm: 5,
  ),
  Person(
    id: _pilar,
    name: 'Pilar',
    context: Contexts.family,
    closeness: 3,
    distanceKm: 3,
  ),
  Person(
    id: _ines,
    name: 'Inês',
    context: Contexts.uni,
    closeness: 1,
    distanceKm: 900,
  ),
  Person(
    id: _jonas,
    name: 'Jonas',
    context: Contexts.hood,
    closeness: 1,
    distanceKm: 2,
  ),
  Person(
    id: _mei,
    name: 'Mei',
    context: Contexts.work,
    closeness: 2,
    distanceKm: 700,
  ),
  Person(
    id: _bruno,
    name: 'Bruno',
    context: Contexts.climb,
    closeness: 1,
    distanceKm: 1.8,
  ),
  Person(
    id: _saga,
    name: 'Saga',
    context: Contexts.climb,
    closeness: 1,
    distanceKm: 12,
  ),
  Person(
    id: _otto,
    name: 'Otto',
    context: Contexts.work,
    closeness: 1,
    distanceKm: 6,
  ),
  Person(
    id: _enzo,
    name: 'Enzo',
    context: Contexts.work,
    closeness: 1,
    distanceKm: 210,
  ),
  Person(
    id: _ava,
    name: 'Ava',
    context: Contexts.family,
    closeness: 2,
    distanceKm: 2.6,
  ),
  Person(
    id: _leo,
    name: 'Leo',
    context: Contexts.uni,
    closeness: 1,
    distanceKm: 480,
  ),
];

Relationship _e(String a, String b, int cadence, int days, {String? via}) =>
    Relationship(
      id: 'r-$a-$b',
      aPersonId: a,
      bPersonId: b,
      cadenceDays: cadence,
      seedDaysSince: days,
      via: via,
    );

/// Direct edges that exist before the demo starts.
///
/// Calvin has nine. **Hannan is not one of them** — Hannan hangs off Yassie,
/// so Calvin sees him as exactly one indirect connection through exactly one
/// mutual. That edge is created live in act 5.
final List<Relationship> kEdges = [
  // Calvin's nine. cal-yas is the story: about monthly, four months ago.
  _e(_cal, _yas, 26, 118, via: 'the lisbon studio year'),
  _e(_cal, _mira, 21, 9),
  _e(_cal, _tomas, 14, 4, via: 'bloc fabrik'),
  _e(_cal, _dara, 30, 26),
  _e(_cal, _noor, 45, 52),
  _e(_cal, _iker, 60, 210),
  _e(_cal, _sofia, 21, 12, via: 'sister'),
  _e(_cal, _lena, 90, 70),
  _e(_cal, _kaito, 120, 84),

  // Calvin's people know each other.
  _e(_mira, _tomas, 40, 22),
  _e(_tomas, _dara, 55, 38),
  _e(_noor, _iker, 35, 60),
  _e(_sofia, _lena, 60, 40),
  _e(_lena, _kaito, 90, 120),
  _e(_mira, _sofia, 70, 30),
  _e(_dara, _kaito, 60, 50),

  // Yassie's own side of the graph.
  _e(_yas, _han, 21, 15),
  _e(_yas, _rui, 28, 20),
  _e(_yas, _pilar, 14, 6),
  _e(_yas, _ines, 60, 74),
  _e(_yas, _jonas, 75, 40),
  _e(_yas, _mei, 35, 30),
  _e(_yas, _dara, 100, 165),
  _e(_han, _rui, 45, 33),
  _e(_han, _pilar, 60, 50),
  _e(_rui, _mei, 30, 18),
  _e(_pilar, _ines, 90, 60),
  _e(_jonas, _mei, 120, 95),

  // The rim: people one hop out, so the graph reads as lived-in.
  _e(_tomas, _bruno, 21, 10),
  _e(_tomas, _saga, 30, 19),
  _e(_mira, _otto, 30, 14),
  _e(_mira, _enzo, 60, 44),
  _e(_sofia, _ava, 21, 8),
  _e(_dara, _leo, 45, 33),
];

/// One seeded meet-up per edge, dated `seedDaysSince` before [now].
///
/// That is the whole history: the fixture states how long it has been for
/// every pair, and the decay model reads it back. Live meet-ups (a confirmed
/// plan, a manual log) append on top and reset those links to today.
List<Event> buildEvents(DateTime now) => [
  for (var i = 0; i < kEdges.length; i++)
    Event(
      id: 'seed$i',
      occurredOn: now.subtract(Duration(days: kEdges[i].seedDaysSince)),
      personIds: [kEdges[i].aPersonId, kEdges[i].bPersonId],
    ),
];

/// Coarse, deliberately imprecise distance. Never an exact position.
String coarseDistanceLabel(double km) =>
    km < 2 ? 'nearby' : (km < 30 ? 'same city' : 'far away');

/// Keys of every direct edge whose both endpoints are in [ids].
///
/// Used when a meet-up is confirmed: only relationships that already exist
/// are renewed. Being in the same room does not create a friendship.
List<String> pairKeysAmong(Iterable<String> ids) {
  final present = ids.toSet();
  return [
    for (final r in kEdges)
      if (present.contains(r.aPersonId) && present.contains(r.bPersonId)) r.key,
  ];
}

/// The relationship between two people, if one exists.
Relationship? edgeBetween(String a, String b) {
  final key = Relationship.keyFor(a, b);
  for (final r in kEdges) {
    if (r.key == key) return r;
  }
  return null;
}
