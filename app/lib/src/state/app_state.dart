/// The single source of truth. One [ChangeNotifier] above one [Stack] — there
/// is no [Navigator] in this app; a mode change is a change of forces.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/repository.dart';
import '../model/decay.dart';
import '../model/models.dart';
import '../theme/tokens.dart';

/// Longest look back the time scrubber allows.
const double kMaxTimeOffsetDays = 540;

/// Per-mode camera targets from the design: `{zoom, panY}`. `panX` is always 0.
/// Belongs in `Tokens` once the orchestrator folds it in.
const kCameraByMode = <AppMode, (double, double)>{
  AppMode.boot: (0.5, 0),
  AppMode.name: (0.5, 0),
  AppMode.home: (0.78, 0),
  AppMode.focus: (1.42, 172),
  AppMode.nudge: (0.5, 205),
  AppMode.group: (1.0, 172),
  AppMode.log: (0.9, 88),
  AppMode.add: (0.9, 86),
  AppMode.time: (0.66, 116),
  AppMode.reach: (0.44, 250),
  AppMode.invites: (0.62, 200),
  AppMode.propose: (0.98, 150),
  AppMode.pay: (0.5, 240),
};

class AppState extends ChangeNotifier {
  AppState(this._repo);

  final GraphRepository _repo;

  // --- lifecycle ------------------------------------------------------------

  bool _isBooting = true;
  String? _bootError;
  bool _needsName = false;

  bool get isBooting => _isBooting;
  String? get bootError => _bootError;
  bool get needsName => _needsName;

  Future<void> boot() async {
    _isBooting = true;
    _bootError = null;
    notifyListeners();
    try {
      _profile = await _repo.signInAndEnsureProfile();
      if (await _repo.isEmpty()) {
        await _repo.seedFixture();
      }
      await _loadGraph();
      final name = _profile?.displayName;
      _needsName = name == null || name.trim().isEmpty;
      _mode = _needsName ? AppMode.name : AppMode.home;
      _isBooting = false;
      notifyListeners();
      unawaited(_loadSocial());
      _invitationSub = _repo.watchInvitations().listen((v) {
        _invitations = v;
        notifyListeners();
      }, onError: (_) {});
    } catch (e) {
      _bootError = '$e';
      _isBooting = false;
      notifyListeners();
    }
  }

  // --- data -----------------------------------------------------------------

  Profile? _profile;
  List<Person> _people = const [];
  List<Relationship> _relationships = const [];
  List<Event> _events = const [];
  List<Ghost> _ghosts = const [];
  List<Invitation> _invitations = const [];
  List<FriendSummary> _friends = const [];

  Profile? get profile => _profile;
  List<Person> get people => _people;
  List<Relationship> get relationships => _relationships;
  List<Event> get events => _events;
  List<Ghost> get ghosts => _ghosts;
  List<Invitation> get invitations => _invitations;
  List<FriendSummary> get friends => _friends;

  Person? get me {
    for (final p in _people) {
      if (p.isMe) return p;
    }
    return null;
  }

  Person? personById(String id) {
    for (final p in _people) {
      if (p.id == id) return p;
    }
    return null;
  }

  late DecayModel _decay = _buildDecay();
  DecayModel get decay => _decay;

  DecayModel _buildDecay() => DecayModel(
    now: now,
    people: _people,
    relationships: _relationships,
    events: _events,
    perPersonHorizon: Tokens.perPersonHorizon,
  );

  void _rebuildDecay() {
    _decay = _buildDecay();
    _group = null;
  }

  Future<void> _loadGraph() async {
    final snap = await _repo.loadGraph();
    _profile = snap.profile;
    _people = snap.people;
    _relationships = snap.relationships;
    _events = snap.events;
    _rebuildDecay();
  }

  Future<void> _loadSocial() async {
    try {
      _friends = await _repo.friendSummaries();
      _invitations = await _repo.loadInvitations();
      notifyListeners();
    } catch (_) {}
  }

  // --- mode machine ---------------------------------------------------------

  AppMode _mode = AppMode.boot;
  GraphLayout _layout = GraphLayout.web;

  AppMode get mode => _mode;
  GraphLayout get layout => _layout;

  static const _selectionModes = {
    AppMode.log,
    AppMode.add,
    AppMode.group,
    AppMode.propose,
  };

  void setMode(AppMode m) {
    if (_mode == m) return;

    _mode = m;
    // Pre-seed on "who is focused", not "which mode we came from": WE MET UP
    // has to work whether focus was entered by tapping the node or by the
    // nudge list jumping straight into log.
    if (_selectionModes.contains(m) && _focusedPersonId != null) {
      _selectedPersonIds
        ..clear()
        ..add(_focusedPersonId!);
    }
    if (m == AppMode.group) {
      assembleGroupFrom(
        _focusedPersonId == null ? null : personById(_focusedPersonId!),
      );
      return;
    }
    notifyListeners();
  }

  void goHome() {
    _mode = AppMode.home;
    _focusedPersonId = null;
    _selectedPersonIds.clear();
    notifyListeners();
  }

  void setLayout(GraphLayout l) {
    if (_layout == l) return;
    _layout = l;
    notifyListeners();
  }

  // --- selection ------------------------------------------------------------

  String? _focusedPersonId;
  final Set<String> _selectedPersonIds = {};

  String? get focusedPersonId => _focusedPersonId;
  Set<String> get selectedPersonIds => _selectedPersonIds;

  void focusPerson(String? id) {
    _focusedPersonId = id;
    if (id != null) {
      if (_mode == AppMode.home || _mode == AppMode.focus) {
        _mode = AppMode.focus;
      }
    } else if (_mode == AppMode.focus) {
      _mode = AppMode.home;
    }
    notifyListeners();
  }

  void toggleSelected(String id) {
    if (!_selectedPersonIds.remove(id)) _selectedPersonIds.add(id);
    notifyListeners();
  }

  void clearSelection() {
    _selectedPersonIds.clear();
    notifyListeners();
  }

  // --- time scrubber --------------------------------------------------------

  double _timeOffsetDays = 0;
  double get timeOffsetDays => _timeOffsetDays;

  DateTime get now =>
      DateTime.now().subtract(Duration(days: _timeOffsetDays.round()));

  void setTimeOffsetDays(double d) {
    final v = d.clamp(0.0, kMaxTimeOffsetDays);
    if (v == _timeOffsetDays) return;
    _timeOffsetDays = v;
    _rebuildDecay();
    notifyListeners();
  }

  // --- derived --------------------------------------------------------------

  List<Nudge> get nudges => topNudges(_decay, count: 3);

  List<Person>? _group;
  List<Person> get group => _group ??= assembleGroup(_decay);

  void assembleGroupFrom(Person? seed) {
    _group = assembleGroup(_decay, seed: seed);
    notifyListeners();
  }

  int get pendingInvitationCount =>
      _invitations.where((i) => i.isPending).length;

  bool get isSubscriber => _profile?.isSubscriber ?? false;

  // --- camera ---------------------------------------------------------------

  double get cameraZoom => kCameraByMode[_mode]!.$1;

  Offset get cameraTarget => Offset(0, kCameraByMode[_mode]!.$2);

  // --- toast ----------------------------------------------------------------

  String? _toast;
  Timer? _toastTimer;

  String? get toast => _toast;

  void showToast(String message) {
    _toastTimer?.cancel();
    _toast = message;
    notifyListeners();
    _toastTimer = Timer(Tokens.toastDuration, () {
      _toast = null;
      notifyListeners();
    });
  }

  // --- actions --------------------------------------------------------------

  Future<void> setDisplayName(String name) async {
    try {
      _profile = await _repo.setDisplayName(name.trim());
      _needsName = false;
      _mode = AppMode.home;
      notifyListeners();
    } catch (_) {
      showToast('Could not save that name.');
    }
  }

  Future<void> addPerson({
    required String name,
    String? context,
    int closeness = 1,
    required List<String> knownByPersonIds,
  }) async {
    try {
      await _repo.addPerson(
        name: name.trim(),
        context: context,
        closeness: closeness,
        knownByPersonIds: knownByPersonIds,
      );
      await _loadGraph();
      _selectedPersonIds.clear();
      _mode = AppMode.home;
      notifyListeners();
      final n = knownByPersonIds.length;
      showToast('${name.trim()} is in the graph with $n ties.');
    } catch (_) {
      showToast('Could not add them.');
    }
  }

  Future<void> logMeetUp({
    required DateTime occurredOn,
    required List<String> personIds,
    String? place,
  }) async {
    try {
      await _repo.logEvent(
        occurredOn: occurredOn,
        personIds: personIds,
        place: place,
      );
      await _loadGraph();
      final names = [for (final id in personIds) ?personById(id)?.name];
      _selectedPersonIds.clear();
      _focusedPersonId = null;
      _mode = AppMode.home;
      notifyListeners();
      if (names.isNotEmpty) {
        showToast(
          names.length == 1
              ? '${names.first} is lit up again.'
              : '${_joinNames(names)} are lit up again.',
        );
      }
    } catch (_) {
      showToast('Could not log that.');
    }
  }

  Future<void> redeemInviteCode(String code) async {
    try {
      await _repo.redeemInviteCode(code.trim());
      await _loadSocial();
    } catch (_) {
      showToast('That code did not work.');
    }
  }

  /// Pulls a friend's graph in as anonymous ghosts.
  Future<void> mergeFriendGraph(String friendProfileId) async {
    try {
      _ghosts = [
        ..._ghosts.where((g) => g.ownerProfileId != friendProfileId),
        ...await _repo.sharedPeople(friendProfileId),
      ];
      notifyListeners();
    } catch (_) {
      showToast('Could not merge that graph.');
    }
  }

  List<String>? _interruptedRecipients;
  String? _interruptedPlace;
  DateTime? _interruptedFor;

  Future<void> propose({
    required List<String> recipientProfileIds,
    String? place,
    DateTime? proposedFor,
  }) async {
    if (!isSubscriber) {
      _interruptedRecipients = List.of(recipientProfileIds);
      _interruptedPlace = place;
      _interruptedFor = proposedFor;
      _mode = AppMode.pay;
      notifyListeners();
      showToast('Proposing is part of 8x Live.');
      return;
    }
    try {
      await _repo.propose(
        recipientProfileIds: recipientProfileIds,
        place: place,
        proposedFor: proposedFor,
      );
      _invitations = await _repo.loadInvitations();
      final names = [
        for (final id in recipientProfileIds)
          ?_friends
              .where((f) => f.profileId == id)
              .map((f) => f.displayName)
              .firstOrNull,
      ];
      _selectedPersonIds.clear();
      _mode = AppMode.home;
      notifyListeners();
      showToast('Invitation on its way to ${_joinNames(names)}.');
    } catch (_) {
      showToast('Could not send that invitation.');
    }
  }

  Future<void> acceptInvitation(String id) async {
    try {
      await _repo.acceptInvitation(id);
      _invitations = await _repo.loadInvitations();
      notifyListeners();
      final place = _invitations
          .where((i) => i.id == id)
          .map((i) => i.place)
          .firstOrNull;
      showToast(place == null ? 'You’re in.' : 'You’re in. $place.');
    } catch (_) {
      showToast('Could not answer that.');
    }
  }

  Future<void> goLive() async {
    try {
      _profile = await _repo.setSubscriber(true);
      notifyListeners();
      showToast('You’re live. Your graph can reach back now.');
      final pending = _interruptedRecipients;
      if (pending != null) {
        _interruptedRecipients = null;
        _mode = AppMode.propose;
        notifyListeners();
        await propose(
          recipientProfileIds: pending,
          place: _interruptedPlace,
          proposedFor: _interruptedFor,
        );
      } else {
        _mode = AppMode.home;
        notifyListeners();
      }
    } catch (_) {
      showToast('Could not go live.');
    }
  }

  Future<void> reseed() async {
    try {
      await _repo.reseed();
      await _loadGraph();
      _selectedPersonIds.clear();
      _focusedPersonId = null;
      _timeOffsetDays = 0;
      _rebuildDecay();
      _mode = AppMode.home;
      notifyListeners();
      showToast('Graph reseeded.');
    } catch (_) {
      showToast('Could not reseed.');
    }
  }

  static String _joinNames(List<String> names) => switch (names.length) {
    0 => 'nobody',
    1 => names.first,
    _ => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
  };

  StreamSubscription<List<Invitation>>? _invitationSub;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _invitationSub?.cancel();
    _repo.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState super.notifier,
    required super.child,
  });

  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
