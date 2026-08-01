/// Core domain types. Plain, immutable-ish data classes — no codegen.
library;

/// The five seeded contexts. `context` is a free `text` column server-side;
/// these are seed data, not a constraint.
abstract final class Contexts {
  static const family = 'family';
  static const climb = 'climb';
  static const work = 'work';
  static const uni = 'uni';
  static const hood = 'hood';

  static const all = [family, climb, work, uni, hood];

  static String label(String? context) => switch (context) {
    family => 'FAMILY',
    climb => 'CLIMBING',
    work => 'WORK',
    uni => 'UNIVERSITY',
    hood => 'NEIGHBOURHOOD',
    _ => 'UNKNOWN',
  };
}

/// Everything the app can be doing. A mode is a set of forces and a sheet —
/// never a route push. There is no [Navigator] in this app.
enum AppMode {
  boot,
  home,
  focus,
  log,
  add,
  nudge,
  group,
  time,
  reach,
  invites,
  propose,
  pay,
  name,
}

/// The three graph layouts. Same simulation, three force configurations.
enum GraphLayout { web, orbit, strata }

class Person {
  const Person({
    required this.id,
    required this.name,
    this.context,
    this.closeness = 1,
    this.birthdayDay,
    this.birthdayMonth,
    this.metVia,
    this.linkedProfileId,
    this.isMe = false,
  });

  final String id;
  final String name;
  final String? context;

  /// 1..3, higher is closer.
  final int closeness;

  final int? birthdayDay;
  final int? birthdayMonth;
  final String? metVia;

  /// Set when this person is also an account holder you are friend-linked to.
  final String? linkedProfileId;
  final bool isMe;

  Person copyWith({String? name, String? context, int? closeness}) => Person(
    id: id,
    name: name ?? this.name,
    context: context ?? this.context,
    closeness: closeness ?? this.closeness,
    birthdayDay: birthdayDay,
    birthdayMonth: birthdayMonth,
    metVia: metVia,
    linkedProfileId: linkedProfileId,
    isMe: isMe,
  );

  static Person fromMap(Map<String, dynamic> m) => Person(
    id: m['id'] as String,
    name: (m['name'] as String?) ?? '',
    context: m['context'] as String?,
    closeness: (m['closeness'] as num?)?.toInt() ?? 1,
    birthdayDay: (m['birthday_day'] as num?)?.toInt(),
    birthdayMonth: (m['birthday_month'] as num?)?.toInt(),
    metVia: m['met_via'] as String?,
    linkedProfileId: m['linked_profile_id'] as String?,
    isMe: (m['is_me'] as bool?) ?? false,
  );
}

/// An undirected edge between two people in *your* graph.
class Relationship {
  const Relationship({
    required this.id,
    required this.aPersonId,
    required this.bPersonId,
  });

  final String id;
  final String aPersonId;
  final String bPersonId;

  /// Stable key independent of endpoint order.
  String get key {
    final (a, b) = aPersonId.compareTo(bPersonId) < 0
        ? (aPersonId, bPersonId)
        : (bPersonId, aPersonId);
    return '$a|$b';
  }

  bool touches(String personId) =>
      personId == aPersonId || personId == bPersonId;

  String? other(String personId) => personId == aPersonId
      ? bPersonId
      : personId == bPersonId
      ? aPersonId
      : null;

  static Relationship fromMap(Map<String, dynamic> m) => Relationship(
    id: m['id'] as String,
    aPersonId: m['a_person_id'] as String,
    bPersonId: m['b_person_id'] as String,
  );
}

/// A meet-up: who, when, optionally where.
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

  static Event fromMap(Map<String, dynamic> m, List<String> personIds) => Event(
    id: m['id'] as String,
    occurredOn: DateTime.parse(m['occurred_on'] as String),
    place: m['place'] as String?,
    personIds: personIds,
  );
}

/// Your own account row.
class Profile {
  const Profile({
    required this.id,
    this.displayName,
    this.inviteCode,
    this.isSubscriber = false,
  });

  final String id;
  final String? displayName;
  final String? inviteCode;
  final bool isSubscriber;

  Profile copyWith({String? displayName, bool? isSubscriber}) => Profile(
    id: id,
    displayName: displayName ?? this.displayName,
    inviteCode: inviteCode,
    isSubscriber: isSubscriber ?? this.isSubscriber,
  );

  static Profile fromMap(Map<String, dynamic> m) => Profile(
    id: m['id'] as String,
    displayName: m['display_name'] as String?,
    inviteCode: m['invite_code'] as String?,
    isSubscriber: (m['is_subscriber'] as bool?) ?? false,
  );
}

/// A friend-linked account, as returned by `friend_graph_summary()`.
class FriendSummary {
  const FriendSummary({
    required this.profileId,
    required this.displayName,
    required this.peopleCount,
    required this.reach,
  });

  final String profileId;
  final String displayName;
  final int peopleCount;
  final int reach;

  static FriendSummary fromMap(Map<String, dynamic> m) => FriendSummary(
    profileId: m['profile_id'] as String,
    displayName: (m['display_name'] as String?) ?? 'SOMEONE',
    peopleCount: (m['people_count'] as num?)?.toInt() ?? 0,
    reach: (m['reach'] as num?)?.toInt() ?? 0,
  );
}

/// A node in a friend's graph that we are *not* entitled to a name for.
/// Generated client-side from a count — no per-ghost row ever leaves the
/// server.
class Ghost {
  const Ghost({required this.id, required this.ownerProfileId, this.name});

  final String id;
  final String ownerProfileId;

  /// Non-null only for a shared connection you are also account-linked to.
  final String? name;

  bool get isNamed => name != null;
}

class Invitation {
  const Invitation({
    required this.id,
    required this.senderProfileId,
    required this.senderName,
    required this.recipientProfileIds,
    this.place,
    this.proposedFor,
    this.state = 'pending',
    this.myResponse = 'pending',
  });

  final String id;
  final String senderProfileId;
  final String senderName;
  final List<String> recipientProfileIds;
  final String? place;
  final DateTime? proposedFor;
  final String state;
  final String myResponse;

  bool get isPending => myResponse == 'pending';
}
