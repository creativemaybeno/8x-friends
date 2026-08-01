/// The force simulation. Plain Dart — no widgets, no Random.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../model/decay.dart';
import '../model/models.dart';
import '../theme/tokens.dart';

// Local geometry the design does not name. Fold into Tokens if wanted.
const double _maxSpeed = 26.0;
const double _spiralAngleStep = 2.39996; // golden angle
const double _spiralRadiusStep = 26.0;
const double _minSeparation = 2.0;
const double _fixedStep = 1 / 60;
const int _maxStepsPerFrame = 3;

/// Someone I am not connected to reads as a neutral, half-faded tie.
const double _indirectDecay = 0.5;

/// Attractor strengths. The design lerps positions over 340 offline
/// iterations; here the same targets are springs, so the numbers differ but
/// the ordering does not.
const double _kOrbit = 0.11;
const double _kNear = 0.11;
const double _kFocus = 0.13;
const double _kFocusRing = 0.055;
const double _kFocusOther = 0.05;
const double _kCluster = 0.10;
const double _kClusterOther = 0.05;

/// Focus and cluster anchors, straight from the design's layout physics.
const Offset _focusAnchor = Offset(0, -26);
const double _focusRingRadius = 112;
const double _focusOtherRadius = 300;
const Offset _clusterAnchor = Offset(0, -54);
const Offset _clusterOtherAnchor = Offset(0, -44);
const double _clusterOtherRadius = 150;

/// Someone who has not accepted yet hovers just outside the cluster, and
/// settles into it the moment they do.
const double _pendingClusterFactor = 1.22;

/// Ring order around me: contexts become arcs, so clusters read.
const List<String> _ringOrder = [
  Contexts.family,
  Contexts.uni,
  Contexts.work,
  Contexts.climb,
  Contexts.hood,
];

/// Phase per distance band, so the three rings do not line up.
const List<double> _bandPhase = [0.3, 0.62, 0.14];

/// What a node is *to me*. Drives radius, fill and whether it is named.
enum NodeKind { me, direct, indirect }

class SimNode {
  SimNode({
    required this.id,
    required this.pos,
    required this.radius,
    required this.phase,
    required this.kind,
    this.context,
    this.closeness = 1,
    this.distanceKm = 0,
  }) : vel = Offset.zero;

  final String id;
  Offset pos;
  Offset vel;
  double radius;
  final double phase;
  NodeKind kind;
  bool pinned = false;
  String? context;
  int closeness;

  /// Their own approximate kilometres from home. Read by the nearby view.
  double distanceKm;

  /// Where this node sits on the orbit ring and on its distance band.
  double orbitAngle = 0;
  double nearAngle = 0;

  /// The slot it holds in the focus halo or the plan cluster, if it has one.
  double? slotAngle;

  /// In the active plan — clusters with the other attendees.
  bool inPlan = false;

  /// In the plan, but has not accepted yet.
  bool pending = false;

  bool get isMe => kind == NodeKind.me;
}

class SimLink {
  SimLink(this.aId, this.bId, this.decay);
  final String aId;
  final String bId;
  double decay;
}

class Simulation {
  /// Which reading of the graph is on screen. A view is not a different graph,
  /// it is the same simulation with one swapped home force. Setting this never
  /// touches a position.
  GraphView view = GraphView.health;

  /// Ids in the active plan; they cluster together. Set every frame.
  Set<String> planIds = const {};

  /// Ids in the plan that have not accepted.
  Set<String> pendingIds = const {};

  /// The node the focus layout is built around, if any.
  String? focusId;

  final Map<String, SimNode> _nodes = {};
  final List<SimLink> _links = [];
  final Map<String, double> _decay = {};
  final Map<String, Set<String>> _adj = {};
  String? _meId;
  double _t = 0;
  double _acc = 0;

  /// Monotonic spawn counter. Never `_nodes.length` — removing then adding a
  /// node would reuse a spiral index and stack two nodes on one point.
  int _spawns = 0;

  /// Seconds since the simulation started. Drives every breathing animation.
  double get time => _t;

  Iterable<SimNode> get nodes => _nodes.values;
  Iterable<SimLink> get links => _links;

  SimNode? nodeById(String id) => _nodes[id];

  /// How faded *my* tie to [id] is. Indirect people read neutral.
  double decayOf(String id) => _decay[id] ?? _indirectDecay;

  bool isNeighbour(String a, String b) => _adj[a]?.contains(b) ?? false;

  /// Centre of the plan cluster, for the camera to frame. Falls back to the
  /// me node, then to the origin, so a caller never reads a NaN.
  Offset get planCentroid {
    var sx = 0.0;
    var sy = 0.0;
    var n = 0;
    for (final id in planIds) {
      final node = _nodes[id];
      if (node == null) continue;
      if (!node.pos.dx.isFinite || !node.pos.dy.isFinite) continue;
      sx += node.pos.dx;
      sy += node.pos.dy;
      n++;
    }
    if (n == 0) {
      final me = _nodes[_meId];
      return me == null ? Offset.zero : me.pos;
    }
    return Offset(sx / n, sy / n);
  }

  /// Adds and removes nodes without disturbing the ones already on screen.
  void sync(
    List<Person> people,
    List<Relationship> rels,
    DecayModel decay,
    String meId,
  ) {
    _meId = meId.isEmpty ? null : meId;
    final seen = <String>{};

    // A node's brightness is *my* relationship with that person, not how
    // active they are. Built once per sync, never inside the loop below.
    final myEdges = <String, Relationship>{};
    for (final r in rels) {
      final otherId = r.other(meId);
      if (otherId != null) myEdges[otherId] = r;
    }

    for (final p in people) {
      seen.add(p.id);
      final myEdge = myEdges[p.id];
      final kind = p.id == meId
          ? NodeKind.me
          : myEdge != null
          ? NodeKind.direct
          : NodeKind.indirect;
      _decay[p.id] = switch (kind) {
        NodeKind.me => 0.0, // you are always fully present
        NodeKind.direct => decay.linkDecayOf(myEdge!),
        NodeKind.indirect => _indirectDecay,
      };
      final radius = switch (kind) {
        NodeKind.me => Tokens.nodeRadiusMe,
        NodeKind.direct => Tokens.nodeRadius(p.closeness),
        NodeKind.indirect =>
          planIds.contains(p.id)
              ? Tokens.nodeRadiusIndirectInPlan
              : Tokens.nodeRadiusIndirect,
      };
      final existing = _nodes[p.id];
      if (existing == null) {
        _nodes[p.id] = SimNode(
          id: p.id,
          pos: kind == NodeKind.me ? Offset.zero : _initialPos(_spawns++),
          radius: radius,
          phase: _phaseOf(p.id),
          kind: kind,
          context: p.context,
          closeness: p.closeness,
          distanceKm: p.distanceKm,
        );
      } else {
        existing
          ..radius = radius
          ..kind = kind
          ..context = p.context
          ..closeness = p.closeness
          ..distanceKm = p.distanceKm;
      }
    }

    _nodes.removeWhere((id, _) => !seen.contains(id));
    _decay.removeWhere((id, _) => !seen.contains(id));

    // An edge between two people I do not know is noise: the graph is my
    // circle and the ties inside it.
    _links.clear();
    _adj.clear();
    for (final r in rels) {
      final a = _nodes[r.aPersonId];
      final b = _nodes[r.bPersonId];
      if (a == null || b == null) continue;
      if (_meId != null &&
          a.kind == NodeKind.indirect &&
          b.kind == NodeKind.indirect) {
        continue;
      }
      _links.add(SimLink(a.id, b.id, decay.linkDecayOf(r)));
      (_adj[a.id] ??= <String>{}).add(b.id);
      (_adj[b.id] ??= <String>{}).add(a.id);
    }

    _assignRings();
    _refreshSlots();
  }

  void tick(double dt) {
    // The caller may set [planIds] before or after [sync]; refreshing here
    // means a frame never simulates against a stale plan.
    _refreshSlots();
    _t += dt;
    _acc += dt;
    var steps = 0;
    while (_acc >= _fixedStep && steps < _maxStepsPerFrame) {
      _step();
      _acc -= _fixedStep;
      steps++;
    }
    if (steps == _maxStepsPerFrame) _acc = 0;
  }

  SimNode? hitTest(Offset world, {double slop = 12}) {
    SimNode? best;
    var bestD = double.infinity;
    for (final n in _nodes.values) {
      final d = (n.pos - world).distance;
      if (d <= n.radius + slop && d < bestD) {
        best = n;
        bestD = d;
      }
    }
    return best;
  }

  // --- internals ------------------------------------------------------------

  /// Fixed angular slots: contexts in ring order around me, and one ordered
  /// sweep per distance band. Deterministic, so the layout never shuffles.
  void _assignRings() {
    final direct = <SimNode>[
      for (final n in _nodes.values)
        if (n.kind == NodeKind.direct) n,
    ]..sort(_byRing);
    for (var i = 0; i < direct.length; i++) {
      direct[i].orbitAngle = -math.pi / 2 + i / direct.length * 2 * math.pi;
    }

    for (var b = 0; b < Tokens.bandRings.length; b++) {
      final band = <SimNode>[
        for (final n in _nodes.values)
          if (!n.isMe && Tokens.distanceBand(_km(n)) == b) n,
      ]..sort((x, y) => _nearRank(x.id).compareTo(_nearRank(y.id)));
      for (var i = 0; i < band.length; i++) {
        band[i].nearAngle = (_bandPhase[b] + i / band.length) * 2 * math.pi;
      }
    }
  }

  /// The plan cluster and the focus halo both hand out numbered slots.
  void _refreshSlots() {
    for (final n in _nodes.values) {
      n.inPlan = planIds.contains(n.id);
      n.pending = n.inPlan && pendingIds.contains(n.id);
      n.slotAngle = null;
    }

    if (planIds.length >= 2) {
      final ids = planIds.toList()..sort();
      for (var i = 0; i < ids.length; i++) {
        _nodes[ids[i]]?.slotAngle = -math.pi / 2 + i / ids.length * 2 * math.pi;
      }
      return;
    }

    final f = focusId;
    if (f == null || !_nodes.containsKey(f)) return;
    final ring = <String>{...?_adj[f], ?_meId}..remove(f);
    final ids = ring.toList()..sort();
    for (var i = 0; i < ids.length; i++) {
      _nodes[ids[i]]?.slotAngle = i / ids.length * 2 * math.pi + 0.45;
    }
  }

  void _step() {
    final list = _nodes.values.toList(growable: false);

    // One non-finite value would poison every force below it forever and the
    // canvas would silently draw nothing. Re-seed the node instead.
    for (var i = 0; i < list.length; i++) {
      final n = list[i];
      if (!n.pos.dx.isFinite || !n.pos.dy.isFinite) {
        n.pos = _initialPos(i);
        n.vel = Offset.zero;
      } else if (!n.vel.dx.isFinite || !n.vel.dy.isFinite) {
        n.vel = Offset.zero;
      }
    }

    for (var i = 0; i < list.length; i++) {
      final a = list[i];
      for (var j = i + 1; j < list.length; j++) {
        final b = list[j];
        var dx = b.pos.dx - a.pos.dx;
        var dy = b.pos.dy - a.pos.dy;
        var d2 = dx * dx + dy * dy;
        if (d2 < _minSeparation * _minSeparation) {
          dx = math.cos(a.phase + b.phase);
          dy = math.sin(a.phase + b.phase);
          d2 = _minSeparation * _minSeparation;
        }
        var f = Tokens.repulsion / d2;
        if (f > Tokens.repulsionClamp) f = Tokens.repulsionClamp;
        final d = math.sqrt(d2);
        final push = Offset(dx / d * f, dy / d * f);
        a.vel -= push;
        b.vel += push;
      }
    }

    for (final l in _links) {
      final a = _nodes[l.aId];
      final b = _nodes[l.bId];
      if (a == null || b == null) continue;
      final delta = b.pos - a.pos;
      final d = delta.distance;
      if (d < 0.001) continue;
      final f = (d - springRestLength(l.decay)) * springStiffness(l.decay);
      final pull = delta / d * f;
      a.vel += pull;
      b.vel -= pull;
    }

    final me = _nodes[_meId];
    final centre = me == null ? Offset.zero : me.pos;
    final clustered = planIds.length >= 2;
    final focus = focusId;
    final focusNode = focus == null ? null : _nodes[focus];

    for (final n in list) {
      if (n.pinned) {
        // A held node still collects force from the loops above. Without this
        // it launches across the screen the instant the finger lifts.
        n.vel = Offset.zero;
        continue;
      }
      final slot = n.slotAngle;
      if (clustered) {
        if (n.inPlan && slot != null) {
          final rad =
              Tokens.planClusterRadius *
              (n.pending ? _pendingClusterFactor : 1.0);
          _attract(n, _ringPoint(_clusterAnchor, rad, slot), _kCluster);
        } else {
          _pullR(n, _clusterOtherAnchor, _clusterOtherRadius, _kClusterOther);
        }
      } else if (focusNode != null) {
        if (n.id == focus) {
          _attract(n, _focusAnchor, _kFocus);
        } else if (slot != null) {
          _attract(
            n,
            _ringPoint(_focusAnchor, _focusRingRadius, slot),
            _kFocusRing,
          );
        } else {
          _pullR(n, _focusAnchor, _focusOtherRadius, _kFocusOther);
        }
      } else if (n.isMe) {
        n.vel -= n.pos * Tokens.meCentring;
      } else if (view == GraphView.distance) {
        _attract(n, _ringPoint(centre, _bandRadius(n), n.nearAngle), _kNear);
      } else if (n.kind == NodeKind.direct) {
        // Faded people literally sit further out. That is the product.
        _attract(n, _ringPoint(centre, _orbitRadius(n), n.orbitAngle), _kOrbit);
      } else {
        n.vel -= n.pos * Tokens.globalCentring;
      }

      n.vel *= Tokens.damping;
      final speed = n.vel.distance;
      if (speed > _maxSpeed) n.vel = n.vel / speed * _maxSpeed;
      n.pos += n.vel;
    }
  }

  void _attract(SimNode n, Offset target, double k) {
    final rel = n.pos - target;
    if (!rel.dx.isFinite || !rel.dy.isFinite) return;
    n.vel -= rel * k;
  }

  /// Radial pull toward a ring of radius [target] around [centre].
  void _pullR(SimNode n, Offset centre, double target, double k) {
    final rel = n.pos - centre;
    final r = rel.distance;
    if (r < 0.001) {
      n.vel += Offset(math.cos(n.phase), math.sin(n.phase)) * k * target;
      return;
    }
    n.vel -= rel / r * ((r - target) * k);
  }

  double _orbitRadius(SimNode n) {
    final dec = (_decay[n.id] ?? _indirectDecay).clamp(0.0, 1.0);
    final jitter = (n.id.length > 1 ? (n.id.codeUnitAt(1) % 9) - 4 : 0) * 2.5;
    return Tokens.orbitRadiusBase + dec * Tokens.orbitRadiusDecay + jitter;
  }

  double _bandRadius(SimNode n) =>
      Tokens.bandRings[Tokens.distanceBand(_km(n))];

  static Offset _ringPoint(Offset centre, double radius, double angle) =>
      centre + Offset(math.cos(angle) * radius, math.sin(angle) * radius);

  static int _byRing(SimNode a, SimNode b) {
    final ka = _ringIndex(a.context);
    final kb = _ringIndex(b.context);
    return ka != kb ? ka.compareTo(kb) : a.id.compareTo(b.id);
  }

  static int _ringIndex(String? context) {
    final i = _ringOrder.indexOf(context ?? '');
    return i < 0 ? _ringOrder.length : i;
  }

  static int _nearRank(String id) =>
      id.isEmpty ? 0 : (id.codeUnitAt(0) * 7 + id.length * 13) % 97;

  static double _km(SimNode n) =>
      n.distanceKm.isFinite ? math.max(0.0, n.distanceKm) : 0.0;

  Offset _initialPos(int index) {
    final a = index * _spiralAngleStep;
    final r = _spiralRadiusStep * math.sqrt(index + 1);
    return Offset(math.cos(a) * r, math.sin(a) * r);
  }

  double _phaseOf(String id) {
    var h = 0x811c9dc5;
    for (final c in id.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return (h % 628) / 100.0;
  }
}
