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

/// Someone 600 km away would otherwise leave the frame at any usable zoom.
const double _maxDistanceRadius = 620.0;

/// Gathering a plan must never launch a node across the screen. Capping the
/// cluster force turns a slingshot into a walk: the group closes in about a
/// second and the rest of the graph keeps simulating undisturbed.
const double _planClusterClamp = 1.6;

/// Someone who has not accepted yet hovers just outside the cluster, and
/// settles into it the moment they do.
const double _pendingClusterFactor = 1.22;

class SimNode {
  SimNode({
    required this.id,
    required this.pos,
    required this.radius,
    required this.phase,
    this.isMe = false,
    this.context,
    this.closeness = 1,
    this.distanceKm = 0,
  }) : vel = Offset.zero;

  final String id;
  Offset pos;
  Offset vel;
  double radius;
  final double phase;
  bool isMe;
  bool pinned = false;
  String? context;
  int closeness;

  /// Approximate kilometres from me. Read by the distance view only.
  double distanceKm;

  /// In the active plan — clusters with the other attendees.
  bool inPlan = false;

  /// In the plan, but has not accepted yet.
  bool pending = false;
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

  /// Extra link pairs to draw dashed (plan links). Key = Relationship.keyFor.
  Set<String> planLinkKeys = const {};

  final Map<String, SimNode> _nodes = {};
  final List<SimLink> _links = [];
  final Map<String, double> _decay = {};
  String? _meId;
  double _t = 0;
  double _acc = 0;

  /// Monotonic spawn counter. Never `_nodes.length` — removing then adding a
  /// node would reuse a spiral index and stack two nodes on one point.
  int _spawns = 0;

  /// Seconds since the simulation started. Drives breathing and fragments.
  double get time => _t;

  Iterable<SimNode> get nodes => _nodes.values;
  Iterable<SimLink> get links => _links;

  SimNode? nodeById(String id) => _nodes[id];

  double decayOf(String id) => _decay[id] ?? 1.0;

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
    // active they are: a direct edge to me wins over their own last meet-up.
    // Built once per sync, never inside the loop below.
    final myEdges = <String, Relationship>{};
    for (final r in rels) {
      final otherId = r.other(meId);
      if (otherId != null) myEdges[otherId] = r;
    }

    // The distance view rings people around whoever holds the phone, but the
    // fixture measures `distanceKm` from Calvin. Everyone sits on one axis out
    // of Berlin, so the difference along that axis is a fair one-dimensional
    // approximation — honest for a demo, not a real geodesic.
    var meKm = 0.0;
    for (final p in people) {
      if (p.id == meId) meKm = p.distanceKm;
    }

    for (final p in people) {
      seen.add(p.id);
      final isMe = p.id == meId;
      final myEdge = myEdges[p.id];
      _decay[p.id] = isMe
          ? 0.0 // you are always fully present
          : myEdge != null
          ? decay.linkDecayOf(myEdge)
          : decay.decayOf(p.id);
      final distanceKm = (p.distanceKm - meKm).abs();
      final radius = Tokens.nodeRadius(p.closeness, isMe: isMe);
      final existing = _nodes[p.id];
      if (existing == null) {
        _nodes[p.id] = SimNode(
          id: p.id,
          pos: isMe ? Offset.zero : _initialPos(_spawns++),
          radius: radius,
          phase: _phaseOf(p.id),
          isMe: isMe,
          context: p.context,
          closeness: p.closeness,
          distanceKm: distanceKm,
        );
      } else {
        existing.radius = radius;
        existing.context = p.context;
        existing.closeness = p.closeness;
        existing.isMe = isMe;
        existing.distanceKm = distanceKm;
      }
    }

    _nodes.removeWhere((id, _) => !seen.contains(id));
    _decay.removeWhere((id, _) => !seen.contains(id));

    _links
      ..clear()
      ..addAll([
        for (final r in rels)
          if (_nodes.containsKey(r.aPersonId) &&
              _nodes.containsKey(r.bPersonId))
            SimLink(r.aPersonId, r.bPersonId, decay.linkDecayOf(r)),
      ]);

    _applyPlanFlags();
  }

  void tick(double dt) {
    // The caller may set [planIds] before or after [sync]; refreshing here
    // means a frame never simulates against a stale plan.
    _applyPlanFlags();
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

  void _applyPlanFlags() {
    for (final n in _nodes.values) {
      n.inPlan = planIds.contains(n.id);
      n.pending = n.inPlan && pendingIds.contains(n.id);
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
    final centre = me?.pos ?? Offset.zero;
    final hasPlan = planIds.isNotEmpty;
    final cluster = hasPlan ? planCentroid : Offset.zero;

    for (final n in list) {
      if (n.pinned) {
        // A held node still collects force from the loops above. Without this
        // it launches across the screen the instant the finger lifts.
        n.vel = Offset.zero;
        continue;
      }
      if (n.isMe) {
        n.vel -= n.pos * Tokens.meCentring;
      } else {
        switch (view) {
          case GraphView.health:
            n.vel -= n.pos * Tokens.globalCentring;
          case GraphView.distance:
            _pullR(n, centre, _distanceRadius(n), Tokens.distanceStrength);
        }
      }

      // The plan is an extra force, never a replacement: the attendees gather
      // while everyone else keeps living in the same graph.
      if (hasPlan && n.inPlan) _pullCluster(n, cluster);

      n.vel *= Tokens.damping;
      final speed = n.vel.distance;
      if (speed > _maxSpeed) n.vel = n.vel / speed * _maxSpeed;
      n.pos += n.vel;
    }
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

  /// The gathering force. A ring, not a point — attendees close in but keep
  /// their own space, and the pull is capped so the cluster settles rather
  /// than snaps.
  void _pullCluster(SimNode n, Offset centre) {
    final target = n.pending
        ? Tokens.planClusterRadius * _pendingClusterFactor
        : Tokens.planClusterRadius;
    final rel = n.pos - centre;
    final r = rel.distance;
    if (r < 0.001) {
      n.vel +=
          Offset(math.cos(n.phase), math.sin(n.phase)) *
          Tokens.planClusterStrength *
          target;
      return;
    }
    final f = ((r - target) * Tokens.planClusterStrength).clamp(
      -_planClusterClamp,
      _planClusterClamp,
    );
    n.vel -= rel / r * f;
  }

  double _distanceRadius(SimNode n) {
    final km = n.distanceKm.isFinite ? math.max(0.0, n.distanceKm) : 0.0;
    final r = Tokens.distanceRadiusBase + km * Tokens.distanceRadiusPerKm;
    return math.min(_maxDistanceRadius, r);
  }

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
