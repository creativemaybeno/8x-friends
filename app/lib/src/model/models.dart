/// Core domain types for the demo. Plain data, no codegen, no persistence.
library;

/// The five seeded contexts. Used for node colour and the chip label.
abstract final class Contexts {
  static const family = 'family';
  static const climb = 'climb';
  static const work = 'work';
  static const uni = 'uni';
  static const hood = 'hood';

  static const all = [family, climb, work, uni, hood];

  /// Lowercase: the machine voice never shouts in the paper build.
  static String label(String? context) => switch (context) {
    family => 'family',
    climb => 'climbing',
    work => 'work',
    uni => 'university',
    hood => 'neighbourhood',
    _ => 'circle',
  };
}

/// Which demo account this phone is. Chosen once on first launch.
enum Who { calvin, yassie }

extension WhoX on Who {
  /// The `Person.id` in the shared cast that *is* this account.
  String get personId => switch (this) {
    Who.calvin => 'cal',
    Who.yassie => 'yas',
  };

  String get label => switch (this) {
    Who.calvin => 'Calvin',
    Who.yassie => 'Yassie',
  };
}

/// Everything the app can be doing. A mode is a camera, a set of forces and a
/// sheet — never a route push.
enum AppMode {
  boot,
  identity,
  home,
  focus,
  planTime,
  invitation,
  proposeTime,
  circle,
  planDetail,
  connect,
  confirm,
  log,

  /// The permission that guards the nearby view. Asked once, never assumed.
  nearby,
}

/// The two graph readings.
enum GraphView { health, distance }

/// Where one attendee stands on a plan.
enum Attendance { invited, accepted, declined }

/// Life cycle of the one active plan.
enum PlanPhase {
  /// Sent, waiting on at least one attendee.
  proposed,

  /// Everyone in; the meet-up is upcoming.
  confirmed,

  /// The morning after: we are asking whether it happened.
  past,

  /// Confirmed as happened; relationships renewed.
  renewed,

  /// Called off.
  cancelled,
}

class Person {
  const Person({
    required this.id,
    required this.name,
    this.context,
    this.closeness = 2,
    this.city,
    this.distanceKm = 0,
  });

  final String id;
  final String name;
  final String? context;

  /// 1..3, higher is closer. Drives node radius.
  final int closeness;

  /// Shown in the distance view only.
  final String? city;
  final double distanceKm;

  String get initial => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
}

/// An undirected edge between two people. Order-independent [key].
class Relationship {
  const Relationship({
    required this.id,
    required this.aPersonId,
    required this.bPersonId,
    this.cadenceDays = 30,
    this.seedDaysSince = 30,
    this.via,
  });

  final String id;
  final String aPersonId;
  final String bPersonId;

  /// The median gap between this pair's meet-ups, in days. This is what makes
  /// four months mean something different for a weekly friend than for a
  /// twice-a-year one.
  final int cadenceDays;

  /// Days since they last met, at boot. A logged meet-up overrides it.
  final int seedDaysSince;

  /// How the two of them know each other, in the owner's words.
  final String? via;

  /// `cadence x 6`, clamped to [60, 900]. Past this a tie reads as gone.
  double get horizonDays => (cadenceDays * 6).clamp(60, 900).toDouble();

  /// "about weekly" / "about monthly" — how often this pair normally meets.
  String get rhythmLabel {
    final d = cadenceDays;
    if (d <= 9) return 'about weekly';
    if (d <= 17) return 'every couple of weeks';
    if (d <= 38) return 'about monthly';
    if (d <= 75) return 'every couple of months';
    if (d <= 130) return 'a few times a year';
    return 'once or twice a year';
  }

  static String keyFor(String a, String b) =>
      a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  String get key => keyFor(aPersonId, bPersonId);

  bool touches(String personId) =>
      personId == aPersonId || personId == bPersonId;

  String? other(String personId) => personId == aPersonId
      ? bPersonId
      : personId == bPersonId
      ? aPersonId
      : null;
}

/// A real-world meet-up: who, when, optionally where.
class Event {
  const Event({
    required this.id,
    required this.occurredOn,
    required this.personIds,
    this.place,
  });

  final String id;
  final DateTime occurredOn;
  final String? place;
  final List<String> personIds;
}

/// The one active plan. Serialised over the broadcast channel.
class Plan {
  const Plan({
    required this.id,
    required this.hostPersonId,
    required this.when,
    this.place,
    required this.attendees,
    this.phase = PlanPhase.proposed,
  });

  final String id;
  final String hostPersonId;
  final DateTime when;
  final String? place;

  /// personId -> where they stand. Always contains the host as accepted.
  final Map<String, Attendance> attendees;
  final PlanPhase phase;

  List<String> get attendeeIds => attendees.keys.toList();

  Iterable<String> get acceptedIds => attendees.entries
      .where((e) => e.value == Attendance.accepted)
      .map((e) => e.key);

  Iterable<String> get pendingIds => attendees.entries
      .where((e) => e.value == Attendance.invited)
      .map((e) => e.key);

  bool get everyoneIn =>
      attendees.values.every((a) => a == Attendance.accepted);

  Plan copyWith({
    DateTime? when,
    String? place,
    Map<String, Attendance>? attendees,
    PlanPhase? phase,
  }) => Plan(
    id: id,
    hostPersonId: hostPersonId,
    when: when ?? this.when,
    place: place ?? this.place,
    attendees: attendees ?? this.attendees,
    phase: phase ?? this.phase,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'host': hostPersonId,
    'when': when.toIso8601String(),
    'place': place,
    'attendees': {for (final e in attendees.entries) e.key: e.value.name},
    'phase': phase.name,
  };

  static Plan fromJson(Map<String, dynamic> m) => Plan(
    id: m['id'] as String,
    hostPersonId: m['host'] as String,
    when: DateTime.parse(m['when'] as String),
    place: m['place'] as String?,
    attendees: {
      for (final e in (m['attendees'] as Map).entries)
        e.key as String: Attendance.values.firstWhere(
          (a) => a.name == e.value,
          orElse: () => Attendance.invited,
        ),
    },
    phase: PlanPhase.values.firstWhere(
      (p) => p.name == m['phase'],
      orElse: () => PlanPhase.proposed,
    ),
  );
}

/// A consent-based request to turn an indirect connection into a direct one.
class ConnectionRequest {
  const ConnectionRequest({
    required this.fromPersonId,
    required this.toPersonId,
    required this.viaPersonId,
    this.accepted = false,
  });

  final String fromPersonId;
  final String toPersonId;
  final String viaPersonId;
  final bool accepted;

  String get key => Relationship.keyFor(fromPersonId, toPersonId);

  ConnectionRequest copyWith({bool? accepted}) => ConnectionRequest(
    fromPersonId: fromPersonId,
    toPersonId: toPersonId,
    viaPersonId: viaPersonId,
    accepted: accepted ?? this.accepted,
  );

  Map<String, dynamic> toJson() => {
    'from': fromPersonId,
    'to': toPersonId,
    'via': viaPersonId,
    'accepted': accepted,
  };

  static ConnectionRequest fromJson(Map<String, dynamic> m) =>
      ConnectionRequest(
        fromPersonId: m['from'] as String,
        toPersonId: m['to'] as String,
        viaPersonId: m['via'] as String,
        accepted: (m['accepted'] as bool?) ?? false,
      );
}

/// What the in-app banner and the OS notification both render.
class AppNotification {
  const AppNotification({
    required this.title,
    required this.body,
    required this.mode,
  });

  final String title;
  final String body;

  /// The mode tapping the banner opens.
  final AppMode mode;
}
