/// One painter for the whole graph. Never a widget per node.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart' hide Simulation;

import '../model/models.dart';
import '../theme/tokens.dart';
import 'simulation.dart';

/// Health ring track: a full circle, barely there.
const double _trackOpacity = 0.09;
const double _trackAbove = 0.12;
const double _healthOpacity = 0.75;
const double _healthMin = 0.03;

/// Hollow-on-paper: an indirect node is an outline, nothing more.
const double _indirectStroke = 0.30;
const double _indirectStrokeInPlan = 0.55;

/// Pending: the dashed ring and the pending plan tether.
const double _pendingRingOpacity = 0.4;
const double _planLinkOpacityPending = 0.3;
const double _planLinkOpacity = 0.95;

/// The cluster ring.
const double _hullStrokeSettled = 0.8;
const double _hullStrokePending = 0.22;

/// Node labels fade with the tie: 0.5 gone, 0.95 fresh.
const double _labelBase = 0.5;
const double _labelRange = 0.45;
const double _meLabelOpacity = 0.8;

/// The whole link layer steps back in the nearby view.
const double _nearbyLinkOpacity = 0.4;

/// Non-spoke links bow away from me by this fraction of their chord.
const double _bowFactor = 0.34;

/// A dashed path is rebuilt every frame; this caps the work per contour.
const int _maxDashSegments = 420;

/// Where a link tag ("new", "request sent") sits relative to the midpoint.
const Offset _tagOffset = Offset(10, -7);

/// `double.nan.round()` throws, so every canvas maths path is gated on this.
bool _finite(Offset o) => o.dx.isFinite && o.dy.isFinite;

class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.sim,
    required this.camera,
    required this.zoom,
    required this.meId,
    required this.highlighted,
    required this.dimOthers,
    required this.focusedId,
    required this.t,
    required this.planIds,
    required this.pendingIds,
    required this.markIds,
    required this.planLinkKeys,
    required this.renewingKeys,
    required this.requestPair,
    required this.freshEdgePair,
    required this.clusterLabel,
    required this.names,
    required this.view,
  });

  final Simulation sim;
  final Offset camera;
  final double zoom;
  final String meId;
  final Set<String> highlighted;
  final double dimOthers;
  final String? focusedId;
  final double t;

  /// Everyone in the active plan.
  final Set<String> planIds;

  /// The subset of [planIds] that has not accepted yet.
  final Set<String> pendingIds;

  /// Who wears the lime plan dot.
  final Set<String> markIds;

  /// `Relationship.keyFor` pairs drawn as marching plan tethers.
  final Set<String> planLinkKeys;

  /// `Relationship.keyFor` pairs renewing right now.
  final Set<String> renewingKeys;

  /// The outstanding connection request, drawn as a fine dotted tether.
  final (String, String)? requestPair;

  /// The edge that just came into existence, labelled `new`.
  final (String, String)? freshEdgePair;

  final String clusterLabel;
  final Map<String, String> names;
  final GraphView view;

  // Type is resolved once per painter, never once per label.
  static final TextStyle _nameStyle = Tokens.nodeName;
  static final TextStyle _meStyle = Tokens.nodeMe;
  static final TextStyle _bandStyle = Tokens.bandLabel;
  static final TextStyle _hullStyle = Tokens.clusterLabel;
  static final TextStyle _tagStyle = Tokens.edgeTag;

  late final String? _freshKey = freshEdgePair == null
      ? null
      : Relationship.keyFor(freshEdgePair!.$1, freshEdgePair!.$2);

  /// The lime plan dot sits up and to the right of the node. The hit test
  /// needs the same point, so it lives here.
  static Offset planMarkCentre(SimNode n) => Offset(
    n.pos.dx + n.radius + Tokens.planMarkOffset,
    n.pos.dy - n.radius - Tokens.planMarkOffset,
  );

  double _dimOf(String id) =>
      highlighted.isEmpty || highlighted.contains(id) ? 1.0 : dimOthers;

  SimNode? get _meNode => meId.isEmpty ? null : sim.nodeById(meId);

  Offset get _origin {
    final me = _meNode;
    return me == null || !_finite(me.pos) ? Offset.zero : me.pos;
  }

  bool _isRenewed(String id) =>
      meId.isNotEmpty && renewingKeys.contains(Relationship.keyFor(meId, id));

  bool _inRequest(String id) {
    final p = requestPair;
    return p != null && (p.$1 == id || p.$2 == id);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.translate(-camera.dx, -camera.dy);

    _paintGuides(canvas);
    for (final l in sim.links) {
      _paintLink(canvas, l);
    }
    _paintPlanLinks(canvas);
    _paintRequest(canvas);
    _paintHull(canvas);
    for (final n in sim.nodes) {
      _paintNode(canvas, n);
    }
    for (final n in sim.nodes) {
      _paintLabel(canvas, n);
    }

    canvas.restore();
  }

  // --- guide rings ----------------------------------------------------------

  void _paintGuides(Canvas canvas) {
    final centre = _origin;

    if (view == GraphView.distance) {
      for (var i = 0; i < Tokens.bandRings.length; i++) {
        final r = Tokens.bandRings[i];
        _dashCircle(
          canvas,
          centre,
          r,
          Tokens.bandDashLength,
          Tokens.bandGapLength,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = Tokens.hairline
            ..color = Tokens.ink.withValues(alpha: Tokens.bandRingOpacity),
        );
        _text(
          canvas,
          text: Tokens.bandLabels[i],
          style: _bandStyle,
          at: Offset(centre.dx + r * 0.72 + 6, centre.dy - r * 0.72 - 6),
          colour: Tokens.mut,
          alpha: 1.0,
          centred: false,
          haloWidth: Tokens.labelHaloStroke,
        );
      }
      return;
    }

    for (final r in Tokens.haloRings) {
      canvas.drawCircle(
        centre,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Tokens.hairline
          ..color = Tokens.ink.withValues(alpha: Tokens.haloRingOpacity),
      );
    }
  }

  // --- links ----------------------------------------------------------------

  void _paintLink(Canvas canvas, SimLink l) {
    final a = sim.nodeById(l.aId);
    final b = sim.nodeById(l.bId);
    if (a == null || b == null) return;
    if (!_finite(a.pos) || !_finite(b.pos)) return;

    final key = Relationship.keyFor(l.aId, l.bId);
    final renewed = renewingKeys.contains(key);
    final fresh = _freshKey == key;
    final dec = renewed ? Tokens.renewedDecay : l.decay.clamp(0.0, 1.0);
    final lit = math.min(_dimOf(l.aId), _dimOf(l.bId));
    final op = lit * (view == GraphView.distance ? _nearbyLinkOpacity : 1.0);
    final spoke = l.aId == meId || l.bId == meId;

    final colour = fresh || renewed ? Tokens.limeDeep : Tokens.linkColor(dec);
    final width =
        (fresh || renewed ? Tokens.linkWidthFresh : Tokens.linkWidth(dec)) *
        (spoke ? Tokens.linkSpokeFactor : Tokens.linkBowFactor);
    final alpha =
        (op * Tokens.linkOpacity(dec) * (spoke ? 1.0 : Tokens.linkBowOpacity))
            .clamp(0.0, 1.0);
    if (alpha <= 0.01) return;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = colour.withValues(alpha: alpha);
    final dash = Tokens.linkDash(dec);

    // A link touching me is a straight spoke; everything else bows away from
    // my node, so the circle around me stays readable.
    if (spoke) {
      if (dash == null) {
        canvas.drawLine(a.pos, b.pos, stroke);
      } else {
        _dashLine(canvas, a.pos, b.pos, dash.$1, dash.$2, 0, stroke);
      }
    } else {
      final bowMid = (a.pos + b.pos) / 2;
      final v = bowMid - _origin;
      final vl = v.distance;
      final unit = vl < 0.001 ? const Offset(0, -1) : v / vl;
      final c = bowMid + unit * (_bowFactor * (b.pos - a.pos).distance);
      final bow = Path()
        ..moveTo(a.pos.dx, a.pos.dy)
        ..quadraticBezierTo(c.dx, c.dy, b.pos.dx, b.pos.dy);
      canvas.drawPath(
        dash == null ? bow : _dash(bow, dash.$1, dash.$2),
        stroke,
      );
    }

    // A healthy spoke reads as a rail: the stroke plus a hairline companion.
    if (dec < Tokens.railBelow && spoke) {
      final d = b.pos - a.pos;
      final len = d.distance;
      if (len > 0.001) {
        final off = Offset(-d.dy / len, d.dx / len) * Tokens.railOffset;
        canvas.drawLine(
          a.pos + off,
          b.pos + off,
          Paint()
            ..strokeWidth = Tokens.railWidth
            ..strokeCap = StrokeCap.round
            ..color = colour.withValues(
              alpha: (op * Tokens.railOpacity).clamp(0.0, 1.0),
            ),
        );
      }
    }

    final mid = (a.pos + b.pos) / 2;

    if (renewed) {
      canvas.drawCircle(
        mid,
        Tokens.renewPulseRadius,
        Paint()
          ..color = Tokens.limeDeep.withValues(
            alpha: (lit * Tokens.breathe(t, Tokens.breathePeriodPulse)).clamp(
              0.0,
              1.0,
            ),
          ),
      );
    }

    if (fresh) {
      _text(
        canvas,
        text: 'new',
        style: _tagStyle,
        at: mid + _tagOffset,
        colour: Tokens.limeDeep,
        alpha: lit,
        centred: false,
      );
    }
  }

  // --- plan tethers ---------------------------------------------------------

  void _paintPlanLinks(Canvas canvas) {
    if (planLinkKeys.isEmpty) return;
    final phase = t * Tokens.planDashDrift;
    for (final key in planLinkKeys) {
      final ids = key.split('|');
      if (ids.length != 2) continue;
      final a = sim.nodeById(ids[0]);
      final b = sim.nodeById(ids[1]);
      if (a == null || b == null) continue;
      if (!_finite(a.pos) || !_finite(b.pos)) continue;

      final waiting =
          pendingIds.contains(ids[0]) || pendingIds.contains(ids[1]);
      final vis = math.min(_dimOf(ids[0]), _dimOf(ids[1]));
      _dashLine(
        canvas,
        a.pos,
        b.pos,
        Tokens.planLinkDashLength,
        Tokens.planLinkGapLength,
        phase,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = waiting
              ? Tokens.planLinkWidthPending
              : Tokens.planLinkWidth
          ..color = (waiting ? Tokens.ink : Tokens.limeDeep).withValues(
            alpha:
                (vis * (waiting ? _planLinkOpacityPending : _planLinkOpacity))
                    .clamp(0.0, 1.0),
          ),
      );
    }
  }

  void _paintRequest(Canvas canvas) {
    final pair = requestPair;
    if (pair == null) return;
    final a = sim.nodeById(pair.$1);
    final b = sim.nodeById(pair.$2);
    if (a == null || b == null) return;
    if (!_finite(a.pos) || !_finite(b.pos)) return;

    final vis = math.min(_dimOf(pair.$1), _dimOf(pair.$2));
    _dashLine(
      canvas,
      a.pos,
      b.pos,
      Tokens.requestDashLength,
      Tokens.requestGapLength,
      t * Tokens.requestDashDrift,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = Tokens.requestWidth
        ..color = Tokens.limeDeep.withValues(alpha: vis.clamp(0.0, 1.0)),
    );
    _text(
      canvas,
      text: 'request sent',
      style: _tagStyle,
      at: (a.pos + b.pos) / 2 + _tagOffset,
      colour: Tokens.limeDeep,
      alpha: vis,
      centred: false,
    );
  }

  // --- the cluster ring -----------------------------------------------------

  void _paintHull(Canvas canvas) {
    if (planIds.length < 2) return;
    final pts = <Offset>[];
    for (final id in planIds) {
      final n = sim.nodeById(id);
      if (n != null && _finite(n.pos)) pts.add(n.pos);
    }
    if (pts.isEmpty) return;

    var sx = 0.0;
    var sy = 0.0;
    for (final p in pts) {
      sx += p.dx;
      sy += p.dy;
    }
    final c = Offset(sx / pts.length, sy / pts.length);
    var far = 0.0;
    for (final p in pts) {
      far = math.max(far, (p - c).distance);
    }
    final r = far + Tokens.hullPadding;
    if (!r.isFinite || r <= 0) return;

    final pending = pendingIds.isNotEmpty;
    if (!pending) {
      canvas.drawCircle(
        c,
        r,
        Paint()..color = Tokens.lime.withValues(alpha: Tokens.hullFillOpacity),
      );
    }
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Tokens.hullStroke
      ..color = pending
          ? Tokens.ink.withValues(alpha: _hullStrokePending)
          : Tokens.limeDeep.withValues(alpha: _hullStrokeSettled);
    if (pending) {
      _dashCircle(
        canvas,
        c,
        r,
        Tokens.hullDashLength,
        Tokens.hullGapLength,
        ringPaint,
      );
    } else {
      canvas.drawCircle(c, r, ringPaint);
    }
    _text(
      canvas,
      text: clusterLabel,
      style: _hullStyle,
      at: Offset(c.dx, c.dy - r + Tokens.hullLabelDrop),
      colour: pending ? Tokens.mut : Tokens.ink,
      alpha: 1.0,
      haloWidth: pending ? 4.0 : 0.0,
    );
  }

  // --- nodes ----------------------------------------------------------------

  void _paintNode(Canvas canvas, SimNode n) {
    if (!_finite(n.pos) || !n.radius.isFinite || n.radius <= 0) return;
    final vis = _dimOf(n.id);
    if (vis <= 0.01) return;

    final renewed = _isRenewed(n.id);
    final r = n.radius;

    if (n.kind == NodeKind.me) {
      canvas.drawCircle(
        n.pos,
        r + Tokens.meHaloOffset,
        Paint()
          ..color = Tokens.lime.withValues(
            alpha: (Tokens.meHaloOpacity * vis).clamp(0.0, 1.0),
          ),
      );
      canvas.drawCircle(
        n.pos,
        r,
        Paint()..color = Tokens.lime.withValues(alpha: vis),
      );
      canvas.drawCircle(
        n.pos,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Tokens.meStroke
          ..color = Tokens.ink.withValues(alpha: vis),
      );
    } else if (n.kind == NodeKind.indirect) {
      canvas.drawCircle(
        n.pos,
        r,
        Paint()..color = Tokens.paper.withValues(alpha: vis),
      );
      canvas.drawCircle(
        n.pos,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Tokens.meStroke
          ..color = Tokens.ink.withValues(
            alpha:
                (vis *
                        (planIds.contains(n.id)
                            ? _indirectStrokeInPlan
                            : _indirectStroke))
                    .clamp(0.0, 1.0),
          ),
      );
    } else {
      final dec = renewed ? Tokens.renewedDecay : sim.decayOf(n.id);
      canvas.drawCircle(
        n.pos,
        r,
        Paint()
          ..color = (renewed ? Tokens.limeDeep : Tokens.nodeFill(null, dec))
              .withValues(alpha: vis),
      );

      // Health is the *remaining* arc: a dying tie is a short clay stub.
      final rect = Rect.fromCircle(
        center: n.pos,
        radius: r + Tokens.ringOffset,
      );
      if (dec > _trackAbove) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = Tokens.ringStroke
            ..color = Tokens.ink.withValues(
              alpha: (vis * _trackOpacity).clamp(0.0, 1.0),
            ),
        );
      }
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * math.max(_healthMin, 1 - dec),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Tokens.ringStroke
          ..strokeCap = StrokeCap.round
          ..color = (renewed ? Tokens.limeDeep : Tokens.nodeRing(null, dec))
              .withValues(
                alpha: (vis * (renewed ? 1.0 : _healthOpacity)).clamp(0.0, 1.0),
              ),
      );
    }

    if (pendingIds.contains(n.id)) {
      _dashCircle(
        canvas,
        n.pos,
        r + Tokens.pendingRingOffset,
        Tokens.pendingDashLength,
        Tokens.pendingGapLength,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Tokens.pendingRingStroke
          ..color = Tokens.ink.withValues(
            alpha:
                (vis *
                        _pendingRingOpacity *
                        Tokens.breathe(t, Tokens.breathePeriodPending))
                    .clamp(0.0, 1.0),
          ),
      );
    }

    if (markIds.contains(n.id)) {
      final c = planMarkCentre(n);
      if (!_finite(c)) return;
      canvas.drawCircle(
        c,
        Tokens.planMarkRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Tokens.planMarkStroke
          ..color = Tokens.paper.withValues(alpha: vis),
      );
      canvas.drawCircle(
        c,
        Tokens.planMarkRadius,
        Paint()..color = Tokens.lime.withValues(alpha: vis),
      );
    }
  }

  // --- labels ---------------------------------------------------------------

  /// Indirect people stay anonymous until they matter. In focus mode only the
  /// focused node, its neighbours and me are named.
  bool _named(SimNode n) {
    final focus = focusedId;
    if (n.kind == NodeKind.indirect &&
        !planIds.contains(n.id) &&
        n.id != focus &&
        !_inRequest(n.id)) {
      return false;
    }
    if (focus == null) return true;
    return n.kind == NodeKind.me ||
        n.id == focus ||
        sim.isNeighbour(focus, n.id);
  }

  void _paintLabel(Canvas canvas, SimNode n) {
    if (!_finite(n.pos) || !n.radius.isFinite) return;
    final vis = _dimOf(n.id);
    if (vis <= 0.05) return;
    if (!_named(n)) return;

    final at = Offset(n.pos.dx, n.pos.dy + n.radius + Tokens.nodeLabelOffset);

    if (n.kind == NodeKind.me) {
      _text(
        canvas,
        text: 'you',
        style: _meStyle,
        at: at,
        colour: Tokens.ink2,
        alpha: vis * _meLabelOpacity,
        haloWidth: Tokens.labelHaloStroke,
      );
      return;
    }

    final name = names[n.id];
    if (name == null || name.isEmpty) return;
    final dec = _isRenewed(n.id) ? Tokens.renewedDecay : sim.decayOf(n.id);
    final clay = dec > 0.66 && n.kind == NodeKind.direct;
    _text(
      canvas,
      text: name,
      style: _nameStyle,
      at: at,
      colour: clay ? Tokens.clay : Tokens.ink,
      alpha: vis * (_labelBase + (1 - dec) * _labelRange),
      haloWidth: Tokens.labelHaloStroke,
    );
  }

  /// Draws [text] with its baseline at [at]. Every label gets a paper halo
  /// underneath so it stays legible over the links.
  void _text(
    Canvas canvas, {
    required String text,
    required TextStyle style,
    required Offset at,
    required Color colour,
    required double alpha,
    bool centred = true,
    double haloWidth = 0,
  }) {
    if (text.isEmpty || !_finite(at)) return;
    final a = alpha.clamp(0.0, 1.0);
    if (a <= 0.02) return;

    if (haloWidth > 0) {
      _blit(
        canvas,
        text,
        style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = haloWidth
            ..strokeJoin = StrokeJoin.round
            ..color = Tokens.paper.withValues(alpha: a),
        ),
        at,
        centred,
      );
    }
    _blit(
      canvas,
      text,
      style.copyWith(color: colour.withValues(alpha: a)),
      at,
      centred,
    );
  }

  void _blit(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at,
    bool centred,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = tp.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final drop = baseline.isFinite ? baseline : tp.height;
    tp.paint(
      canvas,
      Offset(at.dx - (centred ? tp.width / 2 : 0), at.dy - drop),
    );
  }

  // --- dashes ---------------------------------------------------------------

  /// Chops [src] into `dash / gap` pieces. Only the bowed links need this —
  /// circles and straight runs get the cheaper helpers below.
  Path _dash(Path src, double dash, double gap) {
    final unit = dash + gap;
    if (!(unit > 0.01) || !dash.isFinite) return src;
    final out = Path();
    for (final m in src.computeMetrics()) {
      final len = m.length;
      if (!len.isFinite || len <= 0) continue;
      var s = 0.0;
      var guard = 0;
      while (s < len && guard < _maxDashSegments) {
        final b = math.min(len, s + dash);
        if (b > s) out.addPath(m.extractPath(s, b), Offset.zero);
        s += unit;
        guard++;
      }
    }
    return out;
  }

  void _dashLine(
    Canvas canvas,
    Offset a,
    Offset b,
    double dash,
    double gap,
    double phase,
    Paint paint,
  ) {
    final delta = b - a;
    final len = delta.distance;
    if (!(len > 0.001)) return;
    final unit = dash + gap;
    if (!(unit > 0.01) || !phase.isFinite) return;
    final dir = delta / len;
    var s = -(phase % unit);
    var guard = 0;
    while (s < len && guard < _maxDashSegments) {
      final s0 = math.max(0.0, s);
      final s1 = math.min(len, s + dash);
      if (s1 > s0) canvas.drawLine(a + dir * s0, a + dir * s1, paint);
      s += unit;
      guard++;
    }
  }

  void _dashCircle(
    Canvas canvas,
    Offset centre,
    double radius,
    double dash,
    double gap,
    Paint paint,
  ) {
    if (!_finite(centre) || !radius.isFinite || radius <= 0.5) return;
    final unit = dash + gap;
    if (!(unit > 0.01)) return;
    final count = math.min(
      _maxDashSegments,
      math.max(6, (2 * math.pi * radius / unit).round()),
    );
    final step = 2 * math.pi / count;
    final sweep = step * (dash / unit);
    final rect = Rect.fromCircle(center: centre, radius: radius);
    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect, i * step, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}
