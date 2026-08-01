/// The one boundary between the UI and Supabase.
library;

import '../model/models.dart';

/// Everything loaded in one round trip on boot.
class GraphSnapshot {
  const GraphSnapshot({
    required this.profile,
    required this.people,
    required this.relationships,
    required this.events,
  });

  final Profile profile;
  final List<Person> people;
  final List<Relationship> relationships;
  final List<Event> events;

  static const empty = GraphSnapshot(
    profile: Profile(id: ''),
    people: [],
    relationships: [],
    events: [],
  );
}

abstract class GraphRepository {
  /// Anonymous sign-in if needed, then ensure a `profiles` row with an invite
  /// code exists. Returns the profile.
  Future<Profile> signInAndEnsureProfile();

  /// Everything in the signed-in account's graph.
  Future<GraphSnapshot> loadGraph();

  /// True when the account has no `people` rows yet — gate for first-run seed.
  Future<bool> isEmpty();

  /// Writes the deterministic ~25-person fixture graph into this account.
  Future<void> seedFixture();

  /// Deletes every row in this account's graph, then re-seeds. Dev only.
  Future<void> reseed();

  Future<Profile> setDisplayName(String name);

  Future<Profile> setSubscriber(bool value);

  /// Adds a person and links them to [knownBy]. Returns the new person.
  Future<Person> addPerson({
    required String name,
    String? context,
    int closeness,
    required List<String> knownByPersonIds,
  });

  /// Records a meet-up. Returns the new event.
  Future<Event> logEvent({
    required DateTime occurredOn,
    required List<String> personIds,
    String? place,
  });

  // --- P1: the social layer -------------------------------------------------

  /// `redeem_invite_code` — returns the friend's profile id.
  Future<String> redeemInviteCode(String code);

  /// `friend_graph_summary`
  Future<List<FriendSummary>> friendSummaries();

  /// `shared_people`
  Future<List<Ghost>> sharedPeople(String friendProfileId);

  Future<Invitation> propose({
    required List<String> recipientProfileIds,
    String? place,
    DateTime? proposedFor,
  });

  Future<List<Invitation>> loadInvitations();

  /// `accept_invitation`
  Future<void> acceptInvitation(String invitationId);

  /// Realtime + 5 s poll fallback. Fires whenever invitations change.
  Stream<List<Invitation>> watchInvitations();

  void dispose();
}
