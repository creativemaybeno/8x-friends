/// The force simulation. Plain Dart — no widgets, no Random.
///
/// A layout is not a different graph, it is the same simulation with one
/// swapped home force. Setting [Simulation.layout] never touches a position.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../model/decay.dart';
import '../model/models.dart';
import '../theme/tokens.dart';

// Local constants the design does not name. Fold into Tokens if wanted.
const double _maxSpeed = 26.0;
const double _spiralAngleStep = 2.39996; // golden angle
const double _spiralRadiusStep = 26.0;
const double _ghostRadius = 5.5;
const double _minSeparation = 2.0;
const double _fixedStep = 1 / 60;
const int _maxStepsPerFrame = 3;

class SimNode {
  SimNode({
    required this.id,
    required this.pos,
    required this.radius,
    required this.phase,
    this.isMe = false,
    this.isGhost = false,
    this.context,
    this.closeness = 1,
  }) : vel = Offset.zero;

  final String id;
  Offset pos;
  Offset vel;
  double radius;
  final double phase;
  bool isMe;
  bool isGhost;
  bool pinned = false;
  String? context;
  int closeness;
}

class SimLink {
  SimLink(this.aId, this.bId, this.decay);
  final String aId;
  final String bId;
  double decay;
}

class Simulation {
  GraphLayout layout = GraphLayout.web;

  final Map<String, SimNode> _nodes = {};
  final List<SimLink> _links = [];
  final Map<String, double> _decay = {};
  String? _meId;
  double _t = 0;
  double _acc = 0;

  /// Seconds since the simulation started. Drives breathing and fragments.
  double get time => _t;

  Iterable<SimNode> get nodes => _nodes.values;
  Iterable<SimLink> get links => _links;

  SimNode? nodeById(String id) => _nodes[id];

  double decayOf(String id) => _decay[id] ?? 1.0;

  /// Adds and removes nodes without disturbing the ones already on screen.
  void sync(
    List<Person> people,
    List<Relationship> rels,
    List<Ghost> ghosts,
    DecayModel decay,
  ) {
    final seen = <String>{};

    for (final p in people) {
      seen.add(p.id);
      _decay[p.id] = decay.decayOf(p.id);
      final radius = Tokens.nodeRadius(p.closeness, isMe: p.isMe);
      final existing = _nodes[p.id];
      if (existing == null) {
        _nodes[p.id] = SimNode(
          id: p.id,
          pos: p.isMe ? Offset.zero : _initialPos(_nodes.length),
          radius: radius,
          phase: _phaseOf(p.id),
          isMe: p.isMe,
          context: p.context,
          closeness: p.closeness,
        );
      } else {
        existing.radius = radius;
        existing.context = p.context;
        existing.closeness = p.closeness;
        existing.isMe = p.isMe;
      }
      if (p.isMe) _meId = p.id;
    }

    for (final g in ghosts) {
      seen.add(g.id);
      _decay[g.id] = 1.0;
      if (_nodes[g.id] == null) {
        _nodes[g.id] = SimNode(
          id: g.id,
          pos: _initialPos(_nodes.length),
          radius: _ghostRadius,
          phase: _phaseOf(g.id),
          isGhost: true,
          closeness: 0,
        );
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
  }

  void tick(double dt) {
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
      if (n.isGhost) continue;
      final d = (n.pos - world).distance;
      if (d <= n.radius + slop && d < bestD) {
        best = n;
        bestD = d;
      }
    }
    return best;
  }

  // --- internals ------------------------------------------------------------

  void _step() {
    final list = _nodes.values.toList(growable: false);

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
        final strength = (a.isGhost || b.isGhost)
            ? Tokens.repulsionGhost
            : Tokens.repulsion;
        var f = strength / d2;
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

    final me = _meId == null ? null : _nodes[_meId];
    final centre = me?.pos ?? Offset.zero;

    for (final n in list) {
      if (n.pinned) continue;
      if (n.isMe) {
        n.vel -= n.pos * Tokens.meCentring;
      } else if (n.isGhost) {
        n.vel -= n.pos * Tokens.globalCentring;
      } else {
        switch (layout) {
          case GraphLayout.web:
            n.vel -= n.pos * Tokens.globalCentring;
          case GraphLayout.orbit:
            _pullR(
              n,
              centre,
              Tokens.orbitRadiusBase + decayOf(n.id) * Tokens.orbitRadiusDecay,
              Tokens.orbitStrength,
            );
          case GraphLayout.strata:
            final anchor = _strataAnchor(n.context);
            if (anchor == null) {
              n.vel -= n.pos * Tokens.globalCentring;
            } else {
              n.vel += (anchor - n.pos) * Tokens.strataStrength;
            }
        }
      }

      n.vel *= Tokens.damping;
      final speed = n.vel.distance;
      if (speed > _maxSpeed) n.vel = n.vel / speed * _maxSpeed;
      n.pos += n.vel;
    }
  }

  void _pullR(SimNode n, Offset centre, double target, double k) {
    final rel = n.pos - centre;
    final r = rel.distance;
    if (r < 0.001) {
      n.vel += Offset(math.cos(n.phase), math.sin(n.phase)) * k * target;
      return;
    }
    n.vel -= rel / r * ((r - target) * k);
  }

  Offset? _strataAnchor(String? context) {
    final i = Contexts.all.indexOf(context ?? '');
    if (i < 0) return null;
    final a = i / Contexts.all.length * 2 * math.pi - math.pi / 2;
    return Offset(
      math.cos(a) * Tokens.strataAnchorRadius,
      math.sin(a) * Tokens.strataAnchorRadius,
    );
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
