/// The one [ChangeNotifier] the demo runs on: graph, plan, wire and clock.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../demo/cast.dart';
import '../demo/channel.dart';
import '../demo/director.dart';
import '../model/decay.dart';
import '../model/models.dart';
import '../notify/notifications.dart';
import '../theme/tokens.dart';

/// A consented edge arrives at *neutral*, not warm: permission makes a
/// connection, only meeting builds it. 77 days against the default 30-day
/// cadence (horizon 180) lands decay at ~0.5.
const int _newEdgeSeedDays = 77;

/// Phases whose attendees still wear a plan ring in the graph.
const Set<PlanPhase> _ringPhases = {
  PlanPhase.proposed,
  PlanPhase.confirmed,
  PlanPhase.past,
};

/// Modes that only make sense while a plan exists.
const Set<AppMode> _planModes = {
  AppMode.invitation,
  AppMode.proposeTime,
  AppMode.circle,
  AppMode.planDetail,
  AppMode.confirm,
};

class AppState extends ChangeNotifier {
  AppState() {
    _channel = DemoChannel(onEvent: _onRemote);
    _seedEvents = buildEvents(_bootNow);
    _refreshGraph();
  }

  // --- lifecycle ------------------------------------------------------------

  final DateTime _bootNow = DateTime.now();
  late final DemoChannel _channel;
  final Director _director = Director();

  bool _isBooting = true;
  bool _disposed = false;

  bool get isBooting => _isBooting;

  /// Builds the graph and hands control to the identity sheet. Identity is not
  /// persisted — the demo picks a side on every launch — so this never touches
  /// disk and never blocks on the network.
  Future<void> boot() async {
    _seedEvents = buildEvents(_bootNow);
    _refreshGraph();
    _isBooting = false;
    _mode = _who == null ? AppMode.identity : AppMode.home;
    _notify();
  }

  // --- identity -------------------------------------------------------------

  Who? _who;

  Who? get who => _who;

  String get meId => _who?.personId ?? '';

  Person? get me => meId.isEmpty ? null : personById(meId);

  Future<void> chooseWho(Who w) async {
    _who = w;
    _mode = AppMode.home;
    _focusedPersonId = null;
    _refreshGraph();
    _notify();
    try {
      await _channel.join(w.personId);
    } catch (_) {
      // A dead socket is not an error: the demo still runs solo.
    }
    _notify();
  }

  bool get channelConnected => _channel.isConnected;

  // --- data -----------------------------------------------------------------

  late List<Event> _seedEvents;
  final List<Event> _liveEvents = [];
  final List<Relationship> _liveEdges = [];

  late List<Event> _events;
  late List<Relationship> _relationships;
  late DecayModel _decay;

  List<Person> get people => kCast;
  List<Relationship> get relationships => _relationships;
  List<Event> get events => _events;
  DecayModel get decay => _decay;

  Person? personById(String id) {
    for (final p in kCast) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool isMe(String id) => meId.isNotEmpty && id == meId;

  /// The demo clock. [advanceToMorningAfter] moves it.
  DateTime get now => DateTime.now().add(_clockOffset);

  Duration _clockOffset = Duration.zero;

  /// How far the demo clock has been pushed. Travels over the wire so both
  /// phones age the same graph.
  Duration get clockOffset => _clockOffset;

  void _refreshGraph() {
    _events = [..._seedEvents, ..._liveEvents];
    _relationships = [...kEdges, ..._liveEdges];
    _decay = DecayModel(
      now: now,
      people: kCast,
      relationships: _relationships,
      events: _events,
      perPersonHorizon: Tokens.perPersonHorizon,
    );
  }

  // --- graph view -----------------------------------------------------------

  GraphView _view = GraphView.health;
  bool _locationGranted = false;

  GraphView get view => _view;
  bool get locationGranted => _locationGranted;

  void setView(GraphView v) {
    if (_view == v) return;
    _view = v;
    _notify();
  }

  void grantLocation() {
    if (_locationGranted) return;
    _locationGranted = true;
    _notify();
  }

  // --- mode -----------------------------------------------------------------

  AppMode _mode = AppMode.boot;
  String? _focusedPersonId;

  AppMode get mode => _mode;
  String? get focusedPersonId => _focusedPersonId;

  void setMode(AppMode m) {
    if (_mode == m) return;
    _mode = m;
    _notify();
  }

  void goHome() {
    _mode = _who == null ? AppMode.identity : AppMode.home;
    _focusedPersonId = null;
    _notify();
  }

  void focusPerson(String? id) {
    _focusedPersonId = id;
    if (_mode != AppMode.boot && _mode != AppMode.identity) {
      if (id == null) {
        if (_mode == AppMode.focus || _mode == AppMode.connect) {
          _mode = AppMode.home;
        }
      } else {
        _mode = AppMode.focus;
      }
    }
    _notify();
  }

  (double, double) get _camera =>
      Tokens.cameraByMode[_mode] ?? const (0.8, 0.0);

  double get cameraZoom => _view == GraphView.distance
      ? _camera.$1 * Tokens.distanceZoomFactor
      : _camera.$1;

  Offset get cameraTarget => Offset(0, _camera.$2);

  // --- relationship helpers -------------------------------------------------

  Set<String> _neighboursOf(String personId) {
    final out = <String>{};
    if (personId.isEmpty) return out;
    for (final r in _relationships) {
      final other = r.other(personId);
      if (other != null) out.add(other);
    }
    return out;
  }

  bool isDirectlyConnected(String personId) {
    if (meId.isEmpty || personId == meId) return false;
    for (final r in _relationships) {
      if (r.other(meId) == personId) return true;
    }
    return false;
  }

  Person? mutualFor(String personId) {
    if (meId.isEmpty || personId == meId) return null;
    final mine = _neighboursOf(meId);
    final theirs = _neighboursOf(personId);
    for (final p in kCast) {
      if (p.id == meId || p.id == personId) continue;
      if (mine.contains(p.id) && theirs.contains(p.id)) return p;
    }
    return null;
  }

  List<Person> get indirectPeople {
    if (meId.isEmpty) return const [];
    final mine = _neighboursOf(meId);
    return [
      for (final p in kCast)
        if (p.id != meId && !mine.contains(p.id))
          if (_neighboursOf(p.id).any(mine.contains)) p,
    ];
  }

  List<Person> get directPeople {
    if (meId.isEmpty) return const [];
    final mine = _neighboursOf(meId);
    return [
      for (final p in kCast)
        if (mine.contains(p.id)) p,
    ];
  }

  /// My direct edge to [personId], if we have one.
  Relationship? edgeWith(String personId) {
    if (meId.isEmpty) return null;
    for (final r in _relationships) {
      if (r.other(meId) == personId) return r;
    }
    return null;
  }

  /// How faded my tie to [personId] is. 0 fresh, 1 gone. Falls back to the
  /// neutral 0.5 an indirect connection reads at.
  double decayWith(String personId) {
    final r = edgeWith(personId);
    return r == null ? 0.5 : _decay.linkDecayOf(r);
  }

  /// Days since [personId] and I were last in the same room.
  double daysWith(String personId) {
    final r = edgeWith(personId);
    return r == null ? kNeverMetDays : _decay.linkDaysOf(r);
  }

  /// Everyone I have a direct edge to.
  int get circleCount => directPeople.length;

  /// How many of those ties are in trouble. The second half of the caption
  /// line under the graph.
  int get driftingCount {
    if (meId.isEmpty) return 0;
    var n = 0;
    for (final r in _relationships) {
      if (r.touches(meId) && _decay.linkDecayOf(r) > 0.55) n++;
    }
    return n;
  }

  /// The people I could reach through a mutual, most-connected first.
  List<Person> get reachablePeople => indirectPeople;

  // --- the plan -------------------------------------------------------------

  Plan? _plan;

  Plan? get plan => _plan;

  bool get hasIncomingInvitation {
    final p = _plan;
    if (p == null || meId.isEmpty) return false;
    return p.attendees[meId] == Attendance.invited;
  }

  Attendance? attendanceOf(String personId) => _plan?.attendees[personId];

  Set<String> get planIds {
    final p = _plan;
    if (p == null || !_ringPhases.contains(p.phase)) return const {};
    return p.attendees.keys.toSet();
  }

  Set<String> get pendingIds {
    final p = _plan;
    if (p == null || !_ringPhases.contains(p.phase)) return const {};
    return p.pendingIds.toSet();
  }

  /// Who wears the lime plan dot: everyone who has said yes.
  Set<String> get markIds {
    final p = _plan;
    if (p == null || !_ringPhases.contains(p.phase)) return const {};
    return p.acceptedIds.toSet();
  }

  /// What the ring around the planned group is called.
  String get clusterLabel {
    final p = _plan;
    if (p == null) return 'planned';
    if (p.phase == PlanPhase.past) return 'last night';
    if (p.phase == PlanPhase.renewed) return 'renewed';
    return p.pendingIds.isEmpty ? 'planned' : 'draft plan';
  }

  /// The outstanding connection request, as an unordered pair. Drawn as a
  /// fine dotted tether — a consent question, not an edge.
  (String, String)? get requestPair {
    for (final r in _requests) {
      if (!r.accepted && (r.fromPersonId == meId || r.toPersonId == meId)) {
        return (r.fromPersonId, r.toPersonId);
      }
    }
    return null;
  }

  /// People I am not connected to who must still be on my graph.
  ///
  /// The graph is my circle plus whoever the story has put in front of me:
  /// someone I am focused on, everyone in the plan (**including after it has
  /// renewed** — Calvin has to be able to reach Hannan afterwards), whoever a
  /// connection request is with, and whoever I just connected to.
  Set<String> get spotlightIds {
    final out = <String>{};
    final f = _focusedPersonId;
    if (f != null) out.add(f);
    final p = _plan;
    if (p != null && p.phase != PlanPhase.cancelled) {
      out.addAll(p.attendees.keys);
    }
    final req = requestPair;
    if (req != null) {
      out
        ..add(req.$1)
        ..add(req.$2);
    }
    for (final r in _liveEdges) {
      out
        ..add(r.aPersonId)
        ..add(r.bPersonId);
    }
    out.remove(meId);
    return out;
  }

  /// The edge that just came into existence, so the graph can label it `new`.
  (String, String)? get freshEdgePair {
    if (_liveEdges.isEmpty) return null;
    final r = _liveEdges.last;
    return (r.aPersonId, r.bPersonId);
  }

  void proposePlan({
    required String withPersonId,
    required DateTime when,
    String? place,
  }) {
    if (meId.isEmpty || withPersonId == meId) return;
    final next = Plan(
      id: 'plan-${DateTime.now().millisecondsSinceEpoch}',
      hostPersonId: meId,
      when: when,
      place: place,
      attendees: {meId: Attendance.accepted, withPersonId: Attendance.invited},
    );
    _plan = next;
    _mode = AppMode.home;
    _focusedPersonId = null;
    _sendPlan(next);
    showToast('Invitation on its way to ${_nameOf(withPersonId)}.');
  }

  void acceptPlan() {
    final p = _plan;
    if (p == null || meId.isEmpty) return;
    if (!p.attendees.containsKey(meId)) return;
    final attendees = {...p.attendees, meId: Attendance.accepted};
    final next = p.copyWith(
      attendees: attendees,
      phase: _phaseAfter(p, attendees),
    );
    _plan = next;
    _clearBanner();
    _sendPlan(next);
    _mode = AppMode.circle;
    _notify();
  }

  void proposeAlternateTime(DateTime when) {
    final p = _plan;
    if (p == null) return;
    final attendees = {...p.attendees};
    if (meId.isNotEmpty && attendees.containsKey(meId)) {
      attendees[meId] = Attendance.accepted;
    }
    final next = p.copyWith(
      when: when,
      attendees: attendees,
      phase: _phaseAfter(p, attendees),
    );
    _plan = next;
    _clearBanner();
    _sendPlan(next);
    _mode = AppMode.home;
    _focusedPersonId = null;
    showToast('Your suggestion is on its way.');
  }

  void addToPlan(String personId) {
    final p = _plan;
    if (p == null || personId == meId) return;
    if (p.attendees.containsKey(personId)) return;
    final attendees = {...p.attendees, personId: Attendance.invited};
    final next = p.copyWith(
      attendees: attendees,
      phase: _phaseAfter(p, attendees),
    );
    _plan = next;
    _sendPlan(next);
    _notify();
    _director.scheduleAccept(personId, () => _autoAcceptPlan(personId));
  }

  void _autoAcceptPlan(String personId) {
    final p = _plan;
    if (p == null) return;
    if (p.attendees[personId] != Attendance.invited) return;
    final attendees = {...p.attendees, personId: Attendance.accepted};
    final next = p.copyWith(
      attendees: attendees,
      phase: _phaseAfter(p, attendees),
    );
    _plan = next;
    _sendPlan(next);
    showToast('${_nameOf(personId)} is in.');
  }

  void cancelPlan() {
    final p = _plan;
    if (p == null) return;
    _sendPlan(p.copyWith(phase: PlanPhase.cancelled));
    _plan = null;
    _director.cancelAll();
    if (_planModes.contains(_mode)) _mode = AppMode.home;
    _focusedPersonId = null;
    showToast('Plan called off.');
  }

  void reschedulePlan(DateTime when) {
    final p = _plan;
    if (p == null) return;
    final next = p.copyWith(when: when);
    _plan = next;
    _sendPlan(next);
    showToast('Moved. Everyone sees the new time.');
  }

  PlanPhase _phaseAfter(Plan p, Map<String, Attendance> attendees) {
    if (p.phase == PlanPhase.past ||
        p.phase == PlanPhase.renewed ||
        p.phase == PlanPhase.cancelled) {
      return p.phase;
    }
    final everyoneIn = attendees.values.every((a) => a == Attendance.accepted);
    return everyoneIn ? PlanPhase.confirmed : PlanPhase.proposed;
  }

  // --- confirmation ---------------------------------------------------------

  bool get awaitingConfirmation => _plan?.phase == PlanPhase.past;

  void confirmMeetupHappened() {
    final p = _plan;
    if (p == null) return;
    final next = p.copyWith(phase: PlanPhase.renewed);
    _plan = next;
    _applyRenewal(next);
    _sendPlan(next);
    _mode = AppMode.home;
    _focusedPersonId = null;
    _notify();
  }

  void declineMeetupHappened() {
    final p = _plan;
    if (p == null) return;
    _sendPlan(p.copyWith(phase: PlanPhase.cancelled));
    _plan = null;
    if (_planModes.contains(_mode)) _mode = AppMode.home;
    _focusedPersonId = null;
    showToast('Noted. Nothing changed in your graph.');
  }

  void _applyRenewal(Plan p) {
    final attendees = p.acceptedIds.toList();
    if (attendees.length >= 2) {
      _liveEvents.add(
        Event(
          id: 'met-${DateTime.now().millisecondsSinceEpoch}',
          occurredOn: now,
          place: p.place,
          personIds: attendees,
        ),
      );
      _refreshGraph();
    }
    _pulse(pairKeysAmong(attendees).toSet());
    _renewedTimer?.cancel();
    _renewedMessage = 'Connection renewed';
    _renewedTimer = Timer(Tokens.renewedDwell, () {
      _renewedMessage = null;
      _notify();
    });
  }

  void logMeetup({required List<String> personIds, required DateTime on}) {
    final ids = <String>{
      if (meId.isNotEmpty) meId,
      ...personIds.where((id) => id.isNotEmpty),
    }.toList();
    if (ids.length < 2) {
      showToast('Pick at least one person.');
      return;
    }
    _liveEvents.add(
      Event(
        id: 'log-${DateTime.now().millisecondsSinceEpoch}',
        occurredOn: on,
        personIds: ids,
      ),
    );
    _refreshGraph();
    _pulse(pairKeysAmong(ids).toSet());
    _mode = AppMode.home;
    _focusedPersonId = null;
    final names = [
      for (final id in ids)
        if (id != meId) _nameOf(id),
    ];
    showToast(
      names.length == 1
          ? '${names.first} is lit up again.'
          : '${_joinNames(names)} are lit up again.',
    );
  }

  // --- consent-based connection ---------------------------------------------

  final List<ConnectionRequest> _requests = [];

  List<ConnectionRequest> get connectionRequests =>
      List<ConnectionRequest>.unmodifiable(_requests);

  bool isConnectionPending(String personId) {
    if (meId.isEmpty) return false;
    final key = Relationship.keyFor(meId, personId);
    return _requests.any((r) => !r.accepted && r.key == key);
  }

  void requestConnection(String personId) {
    if (meId.isEmpty) {
      _refuseConnection('Pick who you are first.');
      return;
    }
    if (personId == meId) {
      _refuseConnection('That one is you.');
      return;
    }
    if (isDirectlyConnected(personId)) {
      _refuseConnection('You and ${_nameOf(personId)} are already connected.');
      return;
    }
    if (isConnectionPending(personId)) {
      _refuseConnection('${_nameOf(personId)} already has your request.');
      return;
    }
    final via = mutualFor(personId);
    final request = ConnectionRequest(
      fromPersonId: meId,
      toPersonId: personId,
      viaPersonId: via?.id ?? '',
    );
    _requests.add(request);
    _send('connection', {'request': request.toJson()});
    _mode = AppMode.home;
    _focusedPersonId = null;
    showToast('Request sent to ${_nameOf(personId)}.');
    _director.scheduleConnectionAccept(
      personId,
      () => _autoAcceptConnection(personId),
    );
  }

  /// A refusal still has to move: a sheet that sits there reads as broken.
  void _refuseConnection(String message) {
    _mode = _who == null ? AppMode.identity : AppMode.home;
    _focusedPersonId = null;
    showToast(message);
  }

  void _autoAcceptConnection(String personId) {
    if (meId.isEmpty) return;
    final key = Relationship.keyFor(meId, personId);
    final i = _requests.indexWhere((r) => r.key == key);
    if (i < 0 || _requests[i].accepted) return;
    final accepted = _requests[i].copyWith(accepted: true);
    _requests[i] = accepted;
    _addLiveEdge(accepted.fromPersonId, accepted.toPersonId);
    _send('connection', {'request': accepted.toJson()});
    _alert(
      '${_nameOf(personId)} accepted',
      'You have a direct connection. It starts neutral — meet to build it.',
      AppMode.home,
    );
  }

  void _addLiveEdge(String a, String b) {
    if (a.isEmpty || b.isEmpty || a == b) return;
    final key = Relationship.keyFor(a, b);
    if (_relationships.any((r) => r.key == key)) return;
    _liveEdges.add(
      Relationship(
        id: 'live-$key',
        aPersonId: a,
        bPersonId: b,
        cadenceDays: 30,
        seedDaysSince: _newEdgeSeedDays,
      ),
    );
    _liveEvents.add(
      Event(
        id: 'neutral-$key',
        occurredOn: now.subtract(const Duration(days: _newEdgeSeedDays)),
        personIds: [a, b],
      ),
    );
    _refreshGraph();
    _pulse({key});
  }

  // --- celebration / renew animation ----------------------------------------

  Set<String> _renewingKeys = const {};
  String? _renewedMessage;
  Timer? _renewTimer;
  Timer? _renewedTimer;

  Set<String> get renewingKeys => _renewingKeys;
  String? get renewedMessage => _renewedMessage;

  void _pulse(Set<String> keys) {
    if (keys.isEmpty) return;
    _renewTimer?.cancel();
    _renewingKeys = keys;
    _renewTimer = Timer(Tokens.renewAnimation, () {
      _renewingKeys = const {};
      _notify();
    });
  }

  // --- notification banner --------------------------------------------------

  AppNotification? _banner;
  Timer? _bannerTimer;

  AppNotification? get banner => _banner;

  void dismissBanner() {
    if (_banner == null) return;
    _clearBanner();
    _notify();
  }

  void tapBanner() {
    final b = _banner;
    _clearBanner();
    if (b != null) _mode = b.mode;
    _notify();
  }

  void _clearBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _banner = null;
  }

  void _showBanner(AppNotification n) {
    _bannerTimer?.cancel();
    _banner = n;
    _bannerTimer = Timer(Tokens.bannerDwell, () {
      _banner = null;
      _notify();
    });
  }

  void _alert(String title, String body, AppMode mode) {
    unawaited(Notifications.show(title, body));
    _showBanner(AppNotification(title: title, body: body, mode: mode));
    _notify();
  }

  // --- toast ----------------------------------------------------------------

  String? _toast;
  Timer? _toastTimer;

  String? get toast => _toast;

  void showToast(String message) {
    _toastTimer?.cancel();
    _toast = message;
    _notify();
    _toastTimer = Timer(Tokens.toastDuration, () {
      _toast = null;
      _notify();
    });
  }

  // --- demo controls --------------------------------------------------------

  bool _demoPanelOpen = false;

  bool get demoPanelOpen => _demoPanelOpen;

  void toggleDemoPanel() {
    _demoPanelOpen = !_demoPanelOpen;
    _notify();
  }

  void advanceToMorningAfter() {
    final p = _plan;
    if (p == null) {
      showToast('There is no plan to advance yet.');
      return;
    }
    final morning = DateTime(
      p.when.year,
      p.when.month,
      p.when.day,
      9,
    ).add(const Duration(days: 1));
    _clockOffset = morning.difference(DateTime.now());
    final next = p.copyWith(phase: PlanPhase.past);
    _plan = next;
    _demoPanelOpen = false;
    _refreshGraph();
    _send('clock', {'ms': _clockOffset.inMilliseconds});
    _sendPlan(next);
    _askDidItHappen(next);
    _notify();
  }

  void _askDidItHappen(Plan p) {
    final names = _joinNames([
      for (final id in p.acceptedIds)
        if (id != meId) _nameOf(id),
    ]);
    final place = p.place;
    _alert(
      place == null ? 'Did you meet up?' : 'Did you make it to $place?',
      '${_humanWhen(p.when)}, with $names.',
      AppMode.confirm,
    );
  }

  void resetDemo() {
    _send('reset', const {});
    _applyReset();
    showToast('Back to the start.');
  }

  void _applyReset() {
    _director.cancelAll();
    _renewTimer?.cancel();
    _renewedTimer?.cancel();
    _clearBanner();
    _plan = null;
    _requests.clear();
    _liveEdges.clear();
    _liveEvents.clear();
    _clockOffset = Duration.zero;
    _renewingKeys = const {};
    _renewedMessage = null;
    _focusedPersonId = null;
    _demoPanelOpen = false;
    _locationGranted = false;
    _view = GraphView.health;
    _refreshGraph();
    _mode = _who == null ? AppMode.identity : AppMode.home;
    _notify();
  }

  void nudgeDirector() {
    _director.flush();
    _notify();
  }

  // --- the wire -------------------------------------------------------------

  void _send(String type, Map<String, dynamic> payload) {
    try {
      _channel.send(type, payload);
    } catch (_) {
      // Offline is a supported state.
    }
  }

  void _sendPlan(Plan p) => _send('plan', {'plan': p.toJson()});

  void _onRemote(String type, Map<String, dynamic> payload) {
    try {
      switch (type) {
        case 'plan':
          final rawPlan = payload['plan'];
          if (rawPlan is Map) {
            _applyRemotePlan(Plan.fromJson(Map<String, dynamic>.from(rawPlan)));
          }
        case 'connection':
          final rawRequest = payload['request'];
          if (rawRequest is Map) {
            _applyRemoteRequest(
              ConnectionRequest.fromJson(Map<String, dynamic>.from(rawRequest)),
            );
          }
        case 'clock':
          final ms = payload['ms'];
          if (ms is num) {
            _clockOffset = Duration(milliseconds: ms.toInt());
            _refreshGraph();
            _notify();
          }
        case 'reset':
          _applyReset();
      }
    } catch (_) {
      // A malformed message must never reach the stage.
    }
  }

  void _applyRemotePlan(Plan incoming) {
    final prev = _plan;

    if (incoming.phase == PlanPhase.cancelled) {
      if (prev == null) return;
      _plan = null;
      _director.cancelAll();
      if (_planModes.contains(_mode)) _mode = AppMode.home;
      showToast('The plan was called off.');
      return;
    }

    final isNew = prev == null || prev.id != incoming.id;
    final changed =
        prev == null ||
        prev.id != incoming.id ||
        prev.when != incoming.when ||
        prev.place != incoming.place ||
        prev.phase != incoming.phase ||
        !_sameAttendance(prev.attendees, incoming.attendees);
    if (!changed) return;

    _plan = incoming;

    if (isNew && incoming.attendees[meId] == Attendance.invited) {
      final where = incoming.place == null ? '' : ' at ${incoming.place}';
      _alert(
        '${_nameOf(incoming.hostPersonId)} wants to see you',
        '${_humanWhen(incoming.when)}$where. Tap to answer.',
        AppMode.invitation,
      );
      _notify();
      return;
    }

    if (incoming.phase == PlanPhase.past && prev?.phase != PlanPhase.past) {
      _refreshGraph();
      _askDidItHappen(incoming);
      _notify();
      return;
    }

    if (incoming.phase == PlanPhase.renewed &&
        prev?.phase != PlanPhase.renewed) {
      _applyRenewal(incoming);
      _notify();
      return;
    }

    if (prev != null && prev.when != incoming.when) {
      _alert(
        '${_nameOf(_otherSideOf(incoming))} suggested another time',
        '${_humanWhen(incoming.when)} · tap to see the plan',
        AppMode.planDetail,
      );
      _notify();
      return;
    }

    if (prev != null) {
      final added = [
        for (final id in incoming.attendees.keys)
          if (!prev.attendees.containsKey(id) && id != meId) _nameOf(id),
      ];
      if (added.isNotEmpty) {
        // Calvin learns Hannan was added by watching his own graph gather.
        final by = _nameOf(_otherSideOf(incoming));
        final where = incoming.place == null ? '' : ' at ${incoming.place}';
        _alert(
          '$by added ${_joinNames(added)}',
          'Deciding now. ${_humanWhen(incoming.when)}$where.',
          AppMode.planDetail,
        );
        return;
      }
      final accepted = [
        for (final e in incoming.attendees.entries)
          if (e.value == Attendance.accepted &&
              e.key != meId &&
              prev.attendees[e.key] != Attendance.accepted)
            _nameOf(e.key),
      ];
      if (accepted.isNotEmpty) {
        showToast(
          accepted.length == 1
              ? '${accepted.first} is in.'
              : '${_joinNames(accepted)} are in.',
        );
        return;
      }
    }

    _notify();
  }

  void _applyRemoteRequest(ConnectionRequest incoming) {
    final i = _requests.indexWhere((r) => r.key == incoming.key);
    if (i >= 0) {
      if (_requests[i].accepted == incoming.accepted) return;
      _requests[i] = incoming;
    } else {
      _requests.add(incoming);
    }
    if (incoming.accepted) {
      _addLiveEdge(incoming.fromPersonId, incoming.toPersonId);
      if (incoming.toPersonId == meId || incoming.fromPersonId == meId) {
        final other = incoming.fromPersonId == meId
            ? incoming.toPersonId
            : incoming.fromPersonId;
        _alert(
          '${_nameOf(other)} accepted',
          'You have a direct connection. It starts neutral — meet to build it.',
          AppMode.home,
        );
        return;
      }
      showToast(
        '${_nameOf(incoming.fromPersonId)} and '
        '${_nameOf(incoming.toPersonId)} are connected.',
      );
      return;
    }
    _notify();
  }

  bool _sameAttendance(Map<String, Attendance> a, Map<String, Attendance> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  /// The attendee on the other end of a two-person plan, for banner copy.
  String _otherSideOf(Plan p) {
    for (final id in p.attendeeIds) {
      if (id != meId) return id;
    }
    return p.hostPersonId;
  }

  // --- copy helpers ---------------------------------------------------------

  String _nameOf(String id) => personById(id)?.name ?? 'Someone';

  static String _joinNames(List<String> names) => switch (names.length) {
    0 => 'nobody',
    1 => names.first,
    _ => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
  };

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _humanWhen(DateTime when) {
    final n = now;
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(when.year, when.month, when.day);
    final delta = day.difference(today).inDays;
    final clock = _clockLabel(when);
    if (delta == 0) {
      return when.hour >= 17 ? 'Tonight, $clock' : 'Today, $clock';
    }
    if (delta == 1) return 'Tomorrow, $clock';
    if (delta == -1) return 'Yesterday, $clock';
    return '${_weekdays[(when.weekday - 1) % 7]}, $clock';
  }

  static String _clockLabel(DateTime when) {
    final suffix = when.hour < 12 ? 'AM' : 'PM';
    final h = when.hour % 12 == 0 ? 12 : when.hour % 12;
    final m = when.minute == 0
        ? ''
        : ':${when.minute.toString().padLeft(2, '0')}';
    return '$h$m $suffix';
  }

  // --- plumbing -------------------------------------------------------------

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _toastTimer?.cancel();
    _bannerTimer?.cancel();
    _renewTimer?.cancel();
    _renewedTimer?.cancel();
    try {
      _director.dispose();
    } catch (_) {
      // Nothing here may take the demo down.
    }
    try {
      _channel.dispose();
    } catch (_) {
      // Nothing here may take the demo down.
    }
    super.dispose();
  }
}

/// Inherited access to the one [AppState].
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState super.notifier,
    required super.child,
  });

  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
