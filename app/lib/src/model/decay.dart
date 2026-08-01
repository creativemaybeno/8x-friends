/// Decay, signal, nudge ranking and the group assembler.
///
/// Constants are locked by `specs/04-decay-and-ranking.md`. Do not re-derive
/// them. Decay is **never stored** — it is a pure function of dates and an
/// instant, because the time scrubber recomputes it for arbitrary past days.
library;

import 'dart:math' as math;

import 'models.dart';

/// Global decay horizon in days. Tunable 90..540.
const double kDefaultHorizonDays = 240;

/// Days assumed when two people have never met.
const double kNeverMetDays = 900;

const double kDecayExponent = 0.82;

/// `decay = min(1, (max(0, days) / horizon) ^ 0.82)` — 0 fresh, 1 dead.
double decayFor(double days, {double horizon = kDefaultHorizonDays}) {
  final d = math.max(0.0, days) / horizon;
  return math.min(1.0, math.pow(d, kDecayExponent).toDouble());
}

/// `signal = round((1 - decay) * 100)`, shown as a percentage.
int signalFor(double decay) => ((1 - decay) * 100).round();

/// Whole days between two dates, floor at 0.
double daysBetween(DateTime from, DateTime to) =>
    to.difference(from).inSeconds / 86400.0;

/// Spring rest length grows with decay — neglected people physically drift
/// away. This line is the product.
double springRestLength(double decay) => 52 + decay * 74;

/// Spring stiffness falls with decay.
double springStiffness(double decay) => 0.055 * (1 - decay * 0.72);

// ---------------------------------------------------------------------------
// Visual thresholds. Referenced by the painter; kept here so the maths and the
// thresholds that read it live together.
// ---------------------------------------------------------------------------

const double kLinkFragmentsAbove = 0.22;
const double kNodeBreathesBelow = 0.42;
const double kRingAmberAbove = 0.60;
const double kLinkAmberAbove = 0.62;
const double kLinkCollapsesAbove = 0.92;

// ---------------------------------------------------------------------------
// Graph-wide computation
// ---------------------------------------------------------------------------

/// A snapshot of the graph's decay state at one instant.
class DecayModel {
  DecayModel({
    required this.now,
    required this.people,
    required this.relationships,
    required this.events,
    this.horizon = kDefaultHorizonDays,
    this.perPersonHorizon = false,
  }) {
    _compute();
  }

  /// The instant decay is evaluated at. The time scrubber moves this.
  final DateTime now;
  final List<Person> people;
  final List<Relationship> relationships;
  final List<Event> events;
  final double horizon;
  final bool perPersonHorizon;

  /// personId -> days since that person was last met.
  final Map<String, double> personDays = {};

  /// Relationship.key -> days since both endpoints were at the same meet-up.
  final Map<String, double> linkDays = {};

  /// personId -> effective horizon (global, or per-person when enabled).
  final Map<String, double> personHorizon = {};

  /// personId -> all meet-up dates, ascending. Used for per-person horizons.
  final Map<String, List<DateTime>> _meets = {};

  void _compute() {
    for (final p in people) {
      _meets[p.id] = <DateTime>[];
    }

    final pairLast = <String, DateTime>{};

    for (final e in events) {
      if (e.occurredOn.isAfter(now)) continue; // invisible to the scrubber
      for (final id in e.personIds) {
        _meets[id]?.add(e.occurredOn);
      }
      // Every pair present at the same event refreshes their link.
      for (var i = 0; i < e.personIds.length; i++) {
        for (var j = i + 1; j < e.personIds.length; j++) {
          final a = e.personIds[i], b = e.personIds[j];
          final (x, y) = a.compareTo(b) < 0 ? (a, b) : (b, a);
          final k = '$x|$y';
          final prev = pairLast[k];
          if (prev == null || e.occurredOn.isAfter(prev)) {
            pairLast[k] = e.occurredOn;
          }
        }
      }
    }

    for (final entry in _meets.entries) {
      entry.value.sort();
      final last = entry.value.isEmpty ? null : entry.value.last;
      personDays[entry.key] = last == null
          ? kNeverMetDays
          : math.max(0.0, daysBetween(last, now));
    }

    for (final r in relationships) {
      final last = pairLast[r.key];
      linkDays[r.key] = last == null
          ? kNeverMetDays
          : math.max(0.0, daysBetween(last, now));
    }

    _computeHorizons();
  }

  void _computeHorizons() {
    if (!perPersonHorizon) {
      for (final p in people) {
        personHorizon[p.id] = horizon;
      }
      return;
    }

    // Pass 1: anyone with >= 3 meet-ups gets median gap * 3, clamped 90..540.
    final direct = <String, double>{};
    for (final p in people) {
      final dates = _meets[p.id] ?? const <DateTime>[];
      if (dates.length < 3) continue;
      final gaps = <double>[
        for (var i = 1; i < dates.length; i++)
          daysBetween(dates[i - 1], dates[i]),
      ]..sort();
      final mid = gaps.length ~/ 2;
      final median = gaps.length.isOdd
          ? gaps[mid]
          : (gaps[mid - 1] + gaps[mid]) / 2;
      direct[p.id] = median.clamp(30.0, 180.0) * 3; // -> 90..540
    }

    // Pass 2: everyone else inherits the mean horizon of linked neighbours
    // that have one; failing that, the global horizon.
    for (final p in people) {
      final own = direct[p.id];
      if (own != null) {
        personHorizon[p.id] = own;
        continue;
      }
      final neighbourHorizons = <double>[
        for (final r in relationships)
          if (r.touches(p.id)) ?direct[r.other(p.id)],
      ];
      personHorizon[p.id] = neighbourHorizons.isEmpty
          ? horizon
          : neighbourHorizons.reduce((a, b) => a + b) /
                neighbourHorizons.length;
    }
  }

  double horizonOf(String personId) => personHorizon[personId] ?? horizon;

  double daysOf(String personId) => personDays[personId] ?? kNeverMetDays;

  double decayOf(String personId) =>
      decayFor(daysOf(personId), horizon: horizonOf(personId));

  int signalOf(String personId) => signalFor(decayOf(personId));

  double linkDaysOf(Relationship r) => linkDays[r.key] ?? kNeverMetDays;

  double linkDecayOf(Relationship r) {
    final h = (horizonOf(r.aPersonId) + horizonOf(r.bPersonId)) / 2;
    return decayFor(linkDaysOf(r), horizon: h);
  }

  /// Number of recorded meet-ups involving [personId] on or before [now].
  int meetCount(String personId) => _meets[personId]?.length ?? 0;

  /// Most recent meet-up date, or null.
  DateTime? lastMet(String personId) {
    final m = _meets[personId];
    return (m == null || m.isEmpty) ? null : m.last;
  }
}

// ---------------------------------------------------------------------------
// Nudge ranking
// ---------------------------------------------------------------------------

class Nudge {
  const Nudge({required this.person, required this.days, required this.score});
  final Person person;
  final double days;
  final double score;
}

/// Top [count] people to reach out to. The person whose id is [meId] — you —
/// is excluded.
///
/// `score = daysSince * (0.55 + closeness * 0.22)`
List<Nudge> topNudges(DecayModel model, {int count = 3, String meId = ''}) {
  final ranked = <Nudge>[
    for (final p in model.people)
      if (p.id != meId)
        Nudge(
          person: p,
          days: model.daysOf(p.id),
          score: model.daysOf(p.id) * (0.55 + p.closeness * 0.22),
        ),
  ]..sort((a, b) => b.score.compareTo(a.score));
  return ranked.take(count).toList();
}

// ---------------------------------------------------------------------------
// Group assembler
// ---------------------------------------------------------------------------

/// A group is the anchor plus four others. Five, plus you. Hardcoded.
const int kGroupSize = 5;

/// Assembles a group of [kGroupSize] around [seed], or around the weakest
/// person when [seed] is null. The person whose id is [meId] — you — is never
/// a candidate.
List<Person> assembleGroup(DecayModel model, {Person? seed, String meId = ''}) {
  final candidates = [
    for (final p in model.people)
      if (p.id != meId) p,
  ];
  if (candidates.isEmpty) return const [];

  final anchor =
      seed ??
      (candidates.toList()..sort(
            (a, b) => model.decayOf(b.id).compareTo(model.decayOf(a.id)),
          ))
          .first;

  final neighbours = <String, Set<String>>{};
  for (final p in candidates) {
    neighbours[p.id] = {};
  }
  for (final r in model.relationships) {
    neighbours[r.aPersonId]?.add(r.bPersonId);
    neighbours[r.bPersonId]?.add(r.aPersonId);
  }

  final anchorNeighbours = neighbours[anchor.id] ?? const <String>{};

  double scoreOf(Person p) {
    final mutual = (neighbours[p.id] ?? const <String>{})
        .intersection(anchorNeighbours)
        .length;
    final linked = anchorNeighbours.contains(p.id);
    final different = p.context != null && p.context != anchor.context;
    return mutual * 2 +
        (linked ? 3 : 0) +
        (different ? 1.6 : 0) +
        math.min(3.0, model.daysOf(p.id) / 90);
  }

  final rest = [
    for (final p in candidates)
      if (p.id != anchor.id) p,
  ]..sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));

  return [anchor, ...rest.take(kGroupSize - 1)];
}

// ---------------------------------------------------------------------------
// Human labels
// ---------------------------------------------------------------------------

/// `never / today / yesterday / N days ago / N weeks ago / N months ago`
String agoLabel(double days) {
  if (days >= kNeverMetDays) return 'never';
  final d = days.floor();
  if (d <= 0) return 'today';
  if (d == 1) return 'yesterday';
  if (d < 21) return '$d days ago';
  if (d < 60) return '${(d / 7).round()} weeks ago';
  return '${(d / 30).round()} months ago';
}

/// `longer than you can remember / N days / N weeks / N months`
String durationLabel(double days) {
  if (days >= kNeverMetDays) return 'longer than you can remember';
  final d = days.floor();
  if (d < 21) return '$d days';
  if (d < 60) return '${(d / 7).round()} weeks';
  return '${(d / 30).round()} months';
}
