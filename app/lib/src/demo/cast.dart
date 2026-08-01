/// The whole demo fixture: the cast, the edges between them, their meet-ups.
library;

import '../model/models.dart';

/// Stable ids used by both phones and by the broadcast protocol.
abstract final class Ids {
  static const calvin = 'calvin';
  static const yassie = 'yassie';
  static const hannan = 'hannan';
}

// Short aliases so the fixture below stays inside 80 columns.
const _calvin = Ids.calvin;
const _yassie = Ids.yassie;
const _hannan = Ids.hannan;
const _mira = 'mira';
const _aya = 'aya';
const _kojo = 'kojo';
const _liv = 'liv';
const _omar = 'omar';
const _noor = 'noor';
const _jun = 'jun';
const _sena = 'sena';
const _dario = 'dario';
const _lena = 'lena';
const _freya = 'freya';
const _ines = 'ines';
const _rui = 'rui';

/// The shared global cast. Identical on both phones.
///
/// `distanceKm` is measured from Calvin and is deliberately shared by both
/// devices — one fixture, one graph, no per-device geometry.
const List<Person> kCast = [
  Person(
    id: _calvin,
    name: 'Calvin',
    context: Contexts.climb,
    closeness: 3,
    city: 'Berlin',
    distanceKm: 0.0,
  ),
  Person(
    id: _yassie,
    name: 'Yassie',
    context: Contexts.uni,
    closeness: 3,
    city: 'Berlin',
    distanceKm: 3.1,
  ),
  Person(
    id: _hannan,
    name: 'Hannan',
    context: Contexts.hood,
    closeness: 2,
    city: 'Berlin',
    distanceKm: 6.4,
  ),
  Person(
    id: _mira,
    name: 'Mira',
    context: Contexts.family,
    closeness: 3,
    city: 'Berlin',
    distanceKm: 1.2,
  ),
  Person(
    id: _aya,
    name: 'Aya',
    context: Contexts.hood,
    closeness: 2,
    city: 'Berlin',
    distanceKm: 0.8,
  ),
  Person(
    id: _kojo,
    name: 'Kojo',
    context: Contexts.climb,
    closeness: 3,
    city: 'Berlin',
    distanceKm: 2.4,
  ),
  Person(
    id: _liv,
    name: 'Liv',
    context: Contexts.climb,
    closeness: 2,
    city: 'Berlin',
    distanceKm: 4.6,
  ),
  Person(
    id: _omar,
    name: 'Omar',
    context: Contexts.work,
    closeness: 2,
    city: 'Berlin',
    distanceKm: 7.9,
  ),
  Person(
    id: _noor,
    name: 'Noor',
    context: Contexts.work,
    closeness: 1,
    city: 'Berlin',
    distanceKm: 12.5,
  ),
  Person(
    id: _jun,
    name: 'Jun',
    context: Contexts.work,
    closeness: 1,
    city: 'Berlin',
    distanceKm: 18.3,
  ),
  Person(
    id: _sena,
    name: 'Sena',
    context: Contexts.uni,
    closeness: 2,
    city: 'Potsdam',
    distanceKm: 24.0,
  ),
  Person(
    id: _dario,
    name: 'Dario',
    context: Contexts.climb,
    closeness: 2,
    city: 'Leipzig',
    distanceKm: 148.0,
  ),
  Person(
    id: _lena,
    name: 'Lena',
    context: Contexts.family,
    closeness: 2,
    city: 'Dresden',
    distanceKm: 165.0,
  ),
  Person(
    id: _freya,
    name: 'Freya',
    context: Contexts.uni,
    closeness: 1,
    city: 'Hamburg',
    distanceKm: 255.0,
  ),
  Person(
    id: _ines,
    name: 'Ines',
    context: Contexts.uni,
    closeness: 1,
    city: 'Munich',
    distanceKm: 504.0,
  ),
  // A neighbour who moved away. The far end of both views.
  Person(
    id: _rui,
    name: 'Rui',
    context: Contexts.hood,
    closeness: 1,
    city: 'Zurich',
    distanceKm: 636.0,
  ),
];

/// Direct edges that exist before the demo starts.
///
/// Everyone is connected to Calvin **except Hannan** — that edge is created
/// live in step 7 of the pitch. Hannan's only edge is to Yassie, so Calvin
/// sees him as exactly one indirect connection, through exactly one mutual.
const List<Relationship> kEdges = [
  // Calvin's spokes — fourteen of them, one per person but Hannan.
  Relationship(id: 'r-calvin-yassie', aPersonId: _calvin, bPersonId: _yassie),
  Relationship(id: 'r-calvin-mira', aPersonId: _calvin, bPersonId: _mira),
  Relationship(id: 'r-calvin-aya', aPersonId: _calvin, bPersonId: _aya),
  Relationship(id: 'r-calvin-kojo', aPersonId: _calvin, bPersonId: _kojo),
  Relationship(id: 'r-calvin-liv', aPersonId: _calvin, bPersonId: _liv),
  Relationship(id: 'r-calvin-omar', aPersonId: _calvin, bPersonId: _omar),
  Relationship(id: 'r-calvin-noor', aPersonId: _calvin, bPersonId: _noor),
  Relationship(id: 'r-calvin-jun', aPersonId: _calvin, bPersonId: _jun),
  Relationship(id: 'r-calvin-sena', aPersonId: _calvin, bPersonId: _sena),
  Relationship(id: 'r-calvin-dario', aPersonId: _calvin, bPersonId: _dario),
  Relationship(id: 'r-calvin-lena', aPersonId: _calvin, bPersonId: _lena),
  Relationship(id: 'r-calvin-freya', aPersonId: _calvin, bPersonId: _freya),
  Relationship(id: 'r-calvin-ines', aPersonId: _calvin, bPersonId: _ines),
  Relationship(id: 'r-calvin-rui', aPersonId: _calvin, bPersonId: _rui),

  // Yassie's own side of the graph. Hannan hangs off her alone.
  Relationship(id: 'r-yassie-hannan', aPersonId: _yassie, bPersonId: _hannan),
  Relationship(id: 'r-yassie-sena', aPersonId: _yassie, bPersonId: _sena),
  Relationship(id: 'r-yassie-aya', aPersonId: _yassie, bPersonId: _aya),
  Relationship(id: 'r-yassie-lena', aPersonId: _yassie, bPersonId: _lena),

  // Climbing.
  Relationship(id: 'r-kojo-liv', aPersonId: _kojo, bPersonId: _liv),
  Relationship(id: 'r-kojo-dario', aPersonId: _kojo, bPersonId: _dario),
  Relationship(id: 'r-liv-dario', aPersonId: _liv, bPersonId: _dario),

  // Work.
  Relationship(id: 'r-omar-noor', aPersonId: _omar, bPersonId: _noor),
  Relationship(id: 'r-omar-jun', aPersonId: _omar, bPersonId: _jun),
  Relationship(id: 'r-noor-jun', aPersonId: _noor, bPersonId: _jun),

  // University.
  Relationship(id: 'r-sena-ines', aPersonId: _sena, bPersonId: _ines),
  Relationship(id: 'r-sena-freya', aPersonId: _sena, bPersonId: _freya),
  Relationship(id: 'r-ines-freya', aPersonId: _ines, bPersonId: _freya),

  // Family and the neighbourhood.
  Relationship(id: 'r-mira-lena', aPersonId: _mira, bPersonId: _lena),
  Relationship(id: 'r-mira-aya', aPersonId: _mira, bPersonId: _aya),
  Relationship(id: 'r-aya-rui', aPersonId: _aya, bPersonId: _rui),

  // The two seams that stop the clusters reading as separate islands.
  Relationship(id: 'r-kojo-omar', aPersonId: _kojo, bPersonId: _omar),
  Relationship(id: 'r-kojo-aya', aPersonId: _kojo, bPersonId: _aya),
];

/// Meet-ups, dated relative to [now].
///
/// Every day offset here is tuned against `decay = (days / 240) ^ 0.82`.
/// Two numbers come out of it and both matter:
///
/// * **link decay** — days since both endpoints were at the *same* meet-up.
///   This is what the jury sees: the Calvin-Yassie strand at ~0.69, amber and
///   fragmenting, while five other strands sit under 0.10.
/// * **node decay** — days since that person was at *any* meet-up. It gives
///   the graph its hierarchy: a bright core (~0.02), a mid ring (~0.20-0.52)
///   and a quiet rim (~0.83-0.90).
///
/// The two deliberately diverge for Yassie: her node is bright (she saw
/// Hannan sixteen days ago) while her strand to Calvin is the faded one.
/// The person is fine; the relationship is not. That is the whole product.
///
/// Because of that divergence, any "last together" copy must read the *link*
/// (`DecayModel.linkDaysOf`), never `DecayModel.daysOf`.
List<Event> buildEvents(DateTime now) {
  var index = 0;
  Event at(int days, List<String> who, String place) => Event(
    id: 'e${index++}',
    occurredOn: now.subtract(Duration(days: days)),
    personIds: who,
    place: place,
  );

  return [
    // --- The bright, breathing core. Calvin has been busy. ---
    at(2, const [_calvin, _kojo, _liv], 'the boulder gym'), // decay ~0.02
    at(5, const [_calvin, _mira], 'sunday dinner'), // decay ~0.04
    at(8, const [_calvin, _omar, _kojo], 'lunch by the canal'), // ~0.06
    at(12, const [_calvin, _aya, _mira], 'the courtyard'), // decay ~0.09
    // Yassie is out living her life. Bright node, faded strand to Calvin.
    at(16, const [_yassie, _hannan], 'the saturday market'), // ~0.11
    at(23, const [_calvin, _kojo, _aya], 'intro climbing night'),

    // --- Meet-ups Calvin was not at. These are why node and link differ. ---
    at(34, const [_kojo, _liv, _dario], 'the crag'),
    at(41, const [_mira, _lena, _aya], 'a family birthday'),
    at(47, const [_omar, _noor, _jun], 'friday drinks'),
    at(58, const [_yassie, _aya], 'pottery class'),

    // --- The middle ring: steady, drifting, not yet lost. ---
    at(66, const [_calvin, _noor, _omar], 'the team offsite'), // ~0.35
    at(84, const [_calvin, _dario, _kojo], 'a weekend in leipzig'), // ~0.42
    at(97, const [_calvin, _lena, _mira], 'easter lunch'), // decay ~0.48
    at(108, const [_calvin, _sena], 'coffee near campus'), // decay ~0.52
    at(119, const [_calvin, _jun], 'a leaving party'), // decay ~0.56
    at(131, const [_yassie, _sena, _lena], 'a long dinner'),

    // --- THE STORY BEAT. Calvin and Yassie, 152 days, decay ~0.69: amber,
    // fragmenting, one nudge away from gone. Everything else is scenery. ---
    at(152, const [_calvin, _yassie, _mira, _sena], 'a birthday at the lake'),

    // --- The quiet rim. Real range, so the fading reads as a gradient. ---
    at(190, const [_sena, _ines, _freya], 'a weekend in the mountains'),
    at(203, const [_calvin, _freya], 'a trip to hamburg'), // decay ~0.87
    at(212, const [_calvin, _rui, _aya], 'a farewell dinner'), // ~0.90
    at(228, const [_calvin, _ines, _sena], 'a wedding in munich'), // ~0.96
    // --- Older history. It never moves a link, it only makes the graph
    // look like it has been lived in for years. ---
    at(246, const [_calvin, _jun, _noor, _omar], 'the old office'),
    at(268, const [_yassie, _hannan, _aya], 'a housewarming'),
    at(284, const [_calvin, _liv, _dario, _kojo], 'winter climbing'),
    at(302, const [_calvin, _yassie, _sena, _ines, _freya], 'graduation'),
    at(331, const [_calvin, _mira, _lena, _rui], 'christmas at home'),
    at(358, const [_calvin, _aya, _omar], 'the street festival'),
    at(389, const [_kojo, _liv, _aya], 'a summer crag'),
    at(412, const [_calvin, _noor, _jun], 'a conference'),
    at(448, const [_yassie, _lena, _sena], 'a road trip'),
    at(505, const [_calvin, _freya, _ines, _rui], 'backpacking'),
  ];
}

/// Coarse, deliberately imprecise distance. Never an exact position.
String coarseDistanceLabel(double km) {
  if (km < 5) return 'NEARBY';
  if (km < 25) return 'SAME CITY';
  if (km < 200) return 'A TRIP AWAY';
  return 'FAR AWAY';
}

/// Keys of every direct edge in [kEdges] whose both endpoints are in [ids].
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
