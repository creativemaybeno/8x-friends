/// The Supabase-backed implementation of [GraphRepository].
library;

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/models.dart';
import 'auth.dart' as auth;
import 'repository.dart';
import 'seed.dart' as seed;

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class SupabaseGraphRepository implements GraphRepository {
  SupabaseGraphRepository([SupabaseClient? client])
    : _c = client ?? Supabase.instance.client;

  final SupabaseClient _c;

  String? _profileId;
  final Map<String, String> _friendNames = {};

  StreamController<List<Invitation>>? _invitationController;
  RealtimeChannel? _channel;
  Timer? _poll;

  String get _uid {
    final id = _profileId ?? _c.auth.currentUser?.id;
    if (id == null) throw Exception('Not signed in yet.');
    return id;
  }

  Future<T> _guard<T>(String what, Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      throw Exception('$what: ${e.message}');
    } on AuthException catch (e) {
      throw Exception('$what: ${e.message}');
    }
  }

  // --- lifecycle ------------------------------------------------------------

  @override
  Future<Profile> signInAndEnsureProfile() async {
    final profile = await auth.signInAndEnsureProfile(_c);
    _profileId = profile.id;
    return profile;
  }

  @override
  Future<GraphSnapshot> loadGraph() =>
      _guard('Could not load your graph', () async {
        final id = _uid;
        final results = await Future.wait<dynamic>([
          _c.from('profiles').select().eq('id', id).single(),
          _c.from('people').select().eq('owner_id', id),
          _c.from('relationships').select().eq('owner_id', id),
          _c.from('events').select().eq('owner_id', id).order('occurred_on'),
          _c.from('event_people').select(),
        ]);

        final profile = Profile.fromMap(results[0] as Map<String, dynamic>);
        final people = [
          for (final m in results[1] as List)
            Person.fromMap(m as Map<String, dynamic>),
        ];
        final relationships = [
          for (final m in results[2] as List)
            Relationship.fromMap(m as Map<String, dynamic>),
        ];

        final byEvent = <String, List<String>>{};
        for (final m in results[4] as List) {
          final row = m as Map<String, dynamic>;
          (byEvent[row['event_id'] as String] ??= []).add(
            row['person_id'] as String,
          );
        }

        final events = [
          for (final m in results[3] as List)
            Event.fromMap(
              m as Map<String, dynamic>,
              byEvent[m['id'] as String] ?? const [],
            ),
        ];

        return GraphSnapshot(
          profile: profile,
          people: people,
          relationships: relationships,
          events: events,
        );
      });

  @override
  Future<bool> isEmpty() => _guard('Could not read your graph', () async {
    final rows = await _c
        .from('people')
        .select('id')
        .eq('owner_id', _uid)
        .limit(1);
    return (rows as List).isEmpty;
  });

  @override
  Future<void> seedFixture() => seed.seedFixture(_c, _uid);

  @override
  Future<void> reseed() async {
    final id = _uid;
    await _guard('Could not clear your graph', () async {
      await _c.from('events').delete().eq('owner_id', id);
      await _c.from('relationships').delete().eq('owner_id', id);
      await _c.from('people').delete().eq('owner_id', id);
    });
    await seed.seedFixture(_c, id);
  }

  // --- profile --------------------------------------------------------------

  @override
  Future<Profile> setDisplayName(String name) =>
      _guard('Could not save your name', () async {
        final row = await _c
            .from('profiles')
            .update({'display_name': name})
            .eq('id', _uid)
            .select()
            .single();
        await _c
            .from('people')
            .update({'name': name})
            .eq('owner_id', _uid)
            .eq('is_me', true);
        return Profile.fromMap(row);
      });

  @override
  Future<Profile> setSubscriber(bool value) =>
      _guard('Could not update your subscription', () async {
        final row = await _c
            .from('profiles')
            .update({'is_subscriber': value})
            .eq('id', _uid)
            .select()
            .single();
        return Profile.fromMap(row);
      });

  // --- writes ---------------------------------------------------------------

  @override
  Future<Person> addPerson({
    required String name,
    String? context,
    int closeness = 1,
    required List<String> knownByPersonIds,
  }) => _guard('Could not add that person', () async {
    final id = _uid;
    final row = await _c
        .from('people')
        .insert({
          'owner_id': id,
          'name': name,
          'context': ?context,
          'closeness': closeness,
        })
        .select()
        .single();
    final person = Person.fromMap(row);

    final rels = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final other in knownByPersonIds) {
      if (other == person.id) continue;
      final (a, b) = person.id.compareTo(other) < 0
          ? (person.id, other)
          : (other, person.id);
      if (!seen.add('$a|$b')) continue;
      rels.add({'owner_id': id, 'a_person_id': a, 'b_person_id': b});
    }
    if (rels.isNotEmpty) await _c.from('relationships').insert(rels);

    return person;
  });

  @override
  Future<Event> logEvent({
    required DateTime occurredOn,
    required List<String> personIds,
    String? place,
  }) => _guard('Could not log that meet-up', () async {
    final row = await _c
        .from('events')
        .insert({
          'owner_id': _uid,
          'occurred_on': _date(occurredOn),
          if (place != null && place.isNotEmpty) 'place': place,
        })
        .select()
        .single();
    final id = row['id'] as String;
    final ids = personIds.toSet().toList();
    if (ids.isNotEmpty) {
      await _c.from('event_people').insert([
        for (final p in ids) {'event_id': id, 'person_id': p},
      ]);
    }
    return Event.fromMap(row, ids);
  });

  // --- the social layer -----------------------------------------------------

  @override
  Future<String> redeemInviteCode(String code) =>
      _guard('Could not use that code', () async {
        final result = await _c.rpc<dynamic>(
          'redeem_invite_code',
          params: {'code': code},
        );
        return result as String;
      });

  @override
  Future<List<FriendSummary>> friendSummaries() =>
      _guard('Could not load your friends', () async {
        final rows = await _c.rpc<dynamic>('friend_graph_summary');
        final summaries = [
          for (final m in rows as List)
            FriendSummary.fromMap(m as Map<String, dynamic>),
        ];
        _friendNames
          ..clear()
          ..addEntries(
            summaries.map((s) => MapEntry(s.profileId, s.displayName)),
          );
        return summaries;
      });

  @override
  Future<List<Ghost>> sharedPeople(String friendProfileId) =>
      _guard('Could not load that graph', () async {
        final summaries = await friendSummaries();
        final count = summaries
            .where((s) => s.profileId == friendProfileId)
            .fold<int>(0, (_, s) => s.peopleCount);

        final rows = await _c.rpc<dynamic>(
          'shared_people',
          params: {'friend': friendProfileId},
        );
        final named = [
          for (final m in rows as List)
            Ghost(
              id: (m as Map<String, dynamic>)['profile_id'] as String,
              ownerProfileId: friendProfileId,
              name: (m['display_name'] as String?) ?? 'SOMEONE',
            ),
        ];

        // The count is all the server ever gives us. Everyone else is nameless.
        final nameless = [
          for (var i = 0; i < count - named.length; i++)
            Ghost(
              id: 'ghost:$friendProfileId:$i',
              ownerProfileId: friendProfileId,
            ),
        ];
        return [...named, ...nameless];
      });

  @override
  Future<Invitation> propose({
    required List<String> recipientProfileIds,
    String? place,
    DateTime? proposedFor,
  }) => _guard('Could not send that invitation', () async {
    final row = await _c
        .from('invitations')
        .insert({
          'sender_profile_id': _uid,
          if (place != null && place.isNotEmpty) 'place': place,
          if (proposedFor != null) 'proposed_for': _date(proposedFor),
        })
        .select()
        .single();
    final id = row['id'] as String;
    if (recipientProfileIds.isNotEmpty) {
      await _c.from('invitation_recipients').insert([
        for (final p in recipientProfileIds.toSet())
          {'invitation_id': id, 'recipient_profile_id': p},
      ]);
    }
    return Invitation(
      id: id,
      senderProfileId: _uid,
      senderName: 'YOU',
      recipientProfileIds: recipientProfileIds,
      place: place,
      proposedFor: proposedFor,
      state: (row['state'] as String?) ?? 'pending',
    );
  });

  @override
  Future<List<Invitation>> loadInvitations() =>
      _guard('Could not load invitations', () async {
        final id = _uid;
        final rows = await _c
            .from('invitations')
            .select(
              'id, sender_profile_id, place, proposed_for, state, created_at, '
              'invitation_recipients(recipient_profile_id, response)',
            )
            .order('created_at', ascending: false);

        if (_friendNames.isEmpty) {
          await friendSummaries();
        }

        return [
          for (final m in rows as List)
            _invitationFrom(m as Map<String, dynamic>, id),
        ];
      });

  Invitation _invitationFrom(Map<String, dynamic> m, String meId) {
    final recipients = (m['invitation_recipients'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    Map<String, dynamic>? mine;
    for (final r in recipients) {
      if (r['recipient_profile_id'] == meId) mine = r;
    }
    final sender = m['sender_profile_id'] as String;
    return Invitation(
      id: m['id'] as String,
      senderProfileId: sender,
      // Other profiles are not selectable under RLS; this is the only name we
      // are entitled to.
      senderName: sender == meId ? 'YOU' : (_friendNames[sender] ?? 'SOMEONE'),
      recipientProfileIds: [
        for (final r in recipients) r['recipient_profile_id'] as String,
      ],
      place: m['place'] as String?,
      proposedFor: switch (m['proposed_for']) {
        final String s => DateTime.parse(s),
        _ => null,
      },
      state: (m['state'] as String?) ?? 'pending',
      myResponse: (mine?['response'] as String?) ?? 'pending',
    );
  }

  @override
  Future<void> acceptInvitation(String invitationId) => _guard(
    'Could not accept that invitation',
    () async {
      await _c.rpc<dynamic>('accept_invitation', params: {'inv': invitationId});
    },
  );

  @override
  Stream<List<Invitation>> watchInvitations() {
    final existing = _invitationController;
    if (existing != null) return existing.stream;

    final controller = StreamController<List<Invitation>>.broadcast();
    _invitationController = controller;

    var inFlight = false;
    Future<void> refresh() async {
      if (inFlight || controller.isClosed) return;
      inFlight = true;
      try {
        final invitations = await loadInvitations();
        if (!controller.isClosed) controller.add(invitations);
      } catch (_) {
        // A dropped poll must never kill the stream on venue Wi-Fi.
      } finally {
        inFlight = false;
      }
    }

    // Realtime when it works, polling when it does not. Both, always.
    _channel =
        _c
            .channel('invitations-${_c.auth.currentUser?.id ?? 'anon'}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'invitations',
              callback: (_) => refresh(),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'invitation_recipients',
              callback: (_) => refresh(),
            )
          ..subscribe();

    _poll = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    refresh();

    return controller.stream;
  }

  @override
  void dispose() {
    _poll?.cancel();
    _poll = null;
    final channel = _channel;
    if (channel != null) {
      _c.removeChannel(channel);
      _channel = null;
    }
    _invitationController?.close();
    _invitationController = null;
  }
}
