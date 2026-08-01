/// One painter for the whole graph. Never a widget per node.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart' hide Simulation;

import '../model/decay.dart';
import '../model/models.dart';
import '../theme/tokens.dart';
import 'simulation.dart';

// Local constants the design does not name. Fold into Tokens if wanted.
const double _haloStroke = 6.0;
const double _haloAlpha = 0.30;
const double _coreStrokeAlpha = 0.45;
const double _ringAlpha = 0.9;
const double _labelAlpha = 0.92;
const double _labelZoomThreshold = 0.86;
const double _labelCloseness = 3;
const double _linkGlowWidth = 4.5;
const double _linkGlowAlpha = 0.14;
const double _linkBaseAlpha = 0.9;
const double _linkDecayAlpha = 0.62;
const double _fragmentFillBase = 0.98;
const double _fragmentFillDecay = 0.72;
const double _fragmentFillMin = 0.14;
const double _selectionAlpha = 0.9;
const int _maxFragmentSegments = 48;

// Plan / pending.
const double _pendingNodeOpacity = 0.45;
const double _pendingRingRate = 0.55; // radians per second
const double _pendingDashDrift = 13.0; // world px per second
const double _planRingAlpha = 0.85;
const double _planRingGlowAlpha = 0.14;
const double _planRingGlowStroke = 5.0;
const double _planLinkAlpha = 0.82;
const double _planLinkGlowAlpha = 0.16;
const double _planLinkWidth = 1.5;
const int _maxDashSegments = 96;
const int _minDashArcs = 8;

// Plan icon.
const double _iconGlowOffset = 3.4;
const double _iconGlowAlpha = 0.16;
const double _iconEdgeOffset = 1.2;
const double _iconEdgeStroke = 1.7;
const double _iconEdgeAlpha = 0.9;
const double _iconStemAlpha = 0.5;
const double _glyphWidth = 9.4;
const double _glyphHeight = 8.6;
const double _glyphRadius = 2.0;
const double _glyphStroke = 1.2;
const double _glyphDrop = 0.7;
const double _glyphHeaderInset = 1.0;
const double _glyphHeaderDrop = 2.5;
const double _glyphTickX = 2.3;
const double _glyphTickRise = 2.1;
const double _glyphTickDrop = 0.3;

// Renew pulse.
const double _renewPulseRate = 4.0;
const double _renewGlowWidth = 3.2;
const double _renewGlowAlpha = 0.2;
const double _renewRingRate = 0.62; // cycles per second
const double _renewRingSpan = 42.0;
const double _renewRingAlpha = 0.55;
const double _renewRingStroke = 2.0;

// Distance guides.
const double _distanceClampRadius = 620.0;
const double _guideLabelGap = 5.0;
const List<(double, String)> _guides = [
  (5.0, 'NEARBY'),
  (25.0, 'SAME CITY'),
  (200.0, 'A TRIP AWAY'),
];

/// `double.nan.round()` throws, so every canvas maths path is gated on this.
bool _finite(Offset o) => o.dx.isFinite && o.dy.isFinite;

class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.sim,
    required this.decay,
    required this.camera,
    required this.zoom,
    required this.highlighted,
    required this.dimOthers,
    required this.focusedId,
    required this.t,
    required this.planIds,
    required this.pendingIds,
    required this.planLinkKeys,
    required this.renewingKeys,
    required this.names,
    required this.view,
  });

  final Simulation sim;
  final DecayModel decay;
  final Offset camera;
  final double zoom;
  final Set<String> highlighted;
  final double dimOthers;
  final String? focusedId;
  final double t;

  /// Everyone in the active plan — they get a ring.
  final Set<String> planIds;

  /// The subset of [planIds] that has not accepted yet.
  final Set<String> pendingIds;

  /// `Relationship.keyFor` pairs drawn as dashed plan connections.
  final Set<String> planLinkKeys;

  /// `Relationship.keyFor` pairs pulsing green right now.
  final Set<String> renewingKeys;

  final Map<String, String> names;
  final GraphView view;

  /// The plan icon sits directly above the node. The hit test needs the same
  /// point, so it lives here and uses the resting radius, not the breathing
  /// one.
  static Offset planIconCentre(SimNode n) =>
      n.pos - Offset(0, n.radius + Tokens.planIconOffset);

  static final Map<String, TextPainter> _labels = {};
  static final Map<String, TextPainter> _guideLabels = {};

  double _dimOf(String id) =>
      highlighted.isEmpty || highlighted.contains(id) ? 1.0 : dimOthers;

  SimNode? get _meNode {
    for (final n in sim.nodes) {
      if (n.isMe) return n;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.translate(-camera.dx, -camera.dy);

    if (view == GraphView.distance) _paintDistanceGuides(canvas);

    for (final l in sim.links) {
      _paintLink(canvas, l);
    }
    for (final k in planLinkKeys) {
      _paintPlanLink(canvas, k);
    }
    for (final k in renewingKeys) {
      _paintRenewLink(canvas, k);
    }
    for (final n in sim.nodes) {
      _paintNode(canvas, n);
    }

    final renewEnds = <String>{};
    for (final k in renewingKeys) {
      renewEnds.addAll(k.split('|'));
    }
    for (final id in renewEnds) {
      _paintRenewRings(canvas, id);
    }

    for (final n in sim.nodes) {
      if (planIds.contains(n.id) && !pendingIds.contains(n.id)) {
        _paintPlanIcon(canvas, n);
      }
    }
    for (final n in sim.nodes) {
      _paintLabel(canvas, n);
    }

    canvas.restore();
  }

  // --- distance guides ------------------------------------------------------

  double _guideRadius(double km) => math.min(
    _distanceClampRadius,
    Tokens.distanceRadiusBase + km * Tokens.distanceRadiusPerKm,
  );

  void _paintDistanceGuides(Canvas canvas) {
    final me = _meNode;
    if (me == null || !_finite(me.pos)) return;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Tokens.hairline
      ..color = Tokens.borderColor;

    for (final (km, label) in _guides) {
      final r = _guideRadius(km);
      if (!r.isFinite || r <= 0) continue;
      canvas.drawCircle(me.pos, r, ring);

      final tp = _guideLabelFor(label);
      tp.paint(
        canvas,
        Offset(
          me.pos.dx - tp.width / 2,
          me.pos.dy - r - tp.height - _guideLabelGap,
        ),
      );
    }
  }

  TextPainter _guideLabelFor(String label) => _guideLabels.putIfAbsent(
    label,
    () => TextPainter(
      text: TextSpan(text: label, style: Tokens.monoTiny),
      textDirection: TextDirection.ltr,
    )..layout(),
  );

  // --- links ----------------------------------------------------------------

  void _paintLink(Canvas canvas, SimLink l) {
    final a = sim.nodeById(l.aId);
    final b = sim.nodeById(l.bId);
    if (a == null || b == null) return;
    if (!_finite(a.pos) || !_finite(b.pos)) return;

    final d = l.decay;
    final vis = math.min(_dimOf(l.aId), _dimOf(l.bId));
    final alpha =
        (vis * (_linkBaseAlpha - d * _linkDecayAlpha) * Tokens.linkOpacity(d))
            .clamp(0.0, 1.0);
    if (alpha <= 0.01) return;

    final colour = Tokens.linkColor(d).withValues(alpha: alpha);
    final width = Tokens.linkWidth(d);

    final glow = Paint()
      ..color = Tokens.linkColor(
        d,
      ).withValues(alpha: alpha * (1 - d) * _linkGlowAlpha)
      ..strokeWidth = width * _linkGlowWidth
      ..strokeCap = StrokeCap.round;
    final stroke = Paint()
      ..color = colour
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    if (d <= kLinkFragmentsAbove) {
      canvas.drawLine(a.pos, b.pos, glow);
      canvas.drawLine(a.pos, b.pos, stroke);
      return;
    }

    final delta = b.pos - a.pos;
    final len = delta.distance;
    if (!(len > 0.001)) return; // false for NaN too
    final dir = delta / len;
    final perp = Offset(-dir.dy, dir.dx);
    final segs = math.min(
      _maxFragmentSegments,
      math.max(3, (len / Tokens.fragmentSegmentLength).round()),
    );
    final fill = math.max(
      _fragmentFillMin,
      _fragmentFillBase - d * _fragmentFillDecay,
    );
    final ampT = (d - kLinkFragmentsAbove) / (1 - kLinkFragmentsAbove);
    final amp = ampT * ampT * Tokens.fragmentAmplitude;

    for (var i = 0; i < segs; i++) {
      final s0 = i / segs;
      final s1 = math.min(1.0, (i + fill) / segs);
      final mid = (s0 + s1) / 2;
      final o = amp * math.sin(math.pi * mid) * math.sin(t + i);
      final p0 = a.pos + dir * (len * s0) + perp * o;
      final p1 = a.pos + dir * (len * s1) + perp * o;
      canvas.drawLine(p0, p1, glow);
      canvas.drawLine(p0, p1, stroke);
    }
  }

  // --- plan links -----------------------------------------------------------

  void _paintPlanLink(Canvas canvas, String key) {
    final ids = key.split('|');
    if (ids.length != 2) return;
    final a = sim.nodeById(ids[0]);
    final b = sim.nodeById(ids[1]);
    if (a == null || b == null) return;
    if (!_finite(a.pos) || !_finite(b.pos)) return;

    final vis = math.min(_dimOf(ids[0]), _dimOf(ids[1]));
    if (vis <= 0.01) return;

    final waiting = pendingIds.contains(ids[0]) || pendingIds.contains(ids[1]);
    final colour = waiting ? Tokens.dim : Tokens.violet;
    final phase = waiting ? t * _pendingDashDrift : 0.0;

    if (!waiting) {
      _dashedLine(
        canvas,
        a.pos,
        b.pos,
        Paint()
          ..color = colour.withValues(alpha: vis * _planLinkGlowAlpha)
          ..strokeWidth = _planLinkWidth * _linkGlowWidth
          ..strokeCap = StrokeCap.round,
        phase,
      );
    }

    _dashedLine(
      canvas,
      a.pos,
      b.pos,
      Paint()
        ..color = colour.withValues(alpha: vis * _planLinkAlpha)
        ..strokeWidth = _planLinkWidth
        ..strokeCap = StrokeCap.round,
      phase,
    );
  }

  void _dashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint,
    double phase,
  ) {
    final delta = b - a;
    final len = delta.distance;
    if (!(len > 0.001)) return; // false for NaN too
    if (!phase.isFinite) return;
    final dir = delta / len;
    final unit = Tokens.pendingDashLength + Tokens.pendingGapLength;
    var s = -(phase % unit);
    var guard = 0;
    while (s < len && guard < _maxDashSegments) {
      final s0 = math.max(0.0, s);
      final s1 = math.min(len, s + Tokens.pendingDashLength);
      if (s1 > s0) canvas.drawLine(a + dir * s0, a + dir * s1, paint);
      s += unit;
      guard++;
    }
  }

  void _dashedCircle(
    Canvas canvas,
    Offset centre,
    double radius,
    Paint paint,
    double phase,
  ) {
    if (!_finite(centre) || !radius.isFinite || radius <= 0.5) return;
    if (!phase.isFinite) return;
    final unit = Tokens.pendingDashLength + Tokens.pendingGapLength;
    final count = math.max(
      _minDashArcs,
      math.min(_maxDashSegments, (2 * math.pi * radius / unit).round()),
    );
    final step = 2 * math.pi / count;
    final sweep = step * (Tokens.pendingDashLength / unit);
    final rect = Rect.fromCircle(center: centre, radius: radius);
    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect, phase + i * step, sweep, false, paint);
    }
  }

  // --- renew pulse ----------------------------------------------------------

  double get _renewAlpha =>
      (0.55 + 0.45 * math.sin(t * _renewPulseRate)).clamp(0.0, 1.0);

  void _paintRenewLink(Canvas canvas, String key) {
    final ids = key.split('|');
    if (ids.length != 2) return;
    final a = sim.nodeById(ids[0]);
    final b = sim.nodeById(ids[1]);
    if (a == null || b == null) return;
    if (!_finite(a.pos) || !_finite(b.pos)) return;

    final alpha = _renewAlpha;
    canvas.drawLine(
      a.pos,
      b.pos,
      Paint()
        ..color = Tokens.green.withValues(alpha: alpha * _renewGlowAlpha)
        ..strokeWidth = Tokens.renewPulseWidth * _renewGlowWidth
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a.pos,
      b.pos,
      Paint()
        ..color = Tokens.green.withValues(alpha: alpha)
        ..strokeWidth = Tokens.renewPulseWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Two staggered rings expanding out of every renewed endpoint.
  void _paintRenewRings(Canvas canvas, String id) {
    final n = sim.nodeById(id);
    if (n == null || !_finite(n.pos) || !n.radius.isFinite) return;

    final base = t * _renewRingRate;
    for (var i = 0; i < 2; i++) {
      final p = (base + i * 0.5) % 1.0;
      final r = n.radius + Tokens.selectionRingOffset + p * _renewRingSpan;
      if (!r.isFinite) continue;
      final alpha = ((1 - p) * _renewRingAlpha).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;
      canvas.drawCircle(
        n.pos,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _renewRingStroke
          ..color = Tokens.green.withValues(alpha: alpha),
      );
    }
  }

  // --- nodes ----------------------------------------------------------------

  void _paintNode(Canvas canvas, SimNode n) {
    if (!_finite(n.pos)) return;

    // The simulation holds the decay of *my* relationship with this person,
    // not their general activity. That is what a node's brightness means.
    final d = sim.decayOf(n.id);
    final waiting = pendingIds.contains(n.id);
    final modeDim = _dimOf(n.id);
    if (modeDim <= 0.005) return;

    // Uncertainty is legible at a glance: a pending body sits at 45%.
    final dim = waiting ? modeDim * _pendingNodeOpacity : modeDim;

    var r = n.radius;
    if (!n.isMe && d < kNodeBreathesBelow) {
      r *=
          1 +
          Tokens.breathingAmplitude *
              math.sin(t * Tokens.breathingRate + n.phase) *
              (1 - d / kNodeBreathesBelow);
    }
    if (!r.isFinite || r <= 0) return;

    // halo
    final haloPulse = 0.7 + 0.3 * math.sin(t * Tokens.breathingRate + n.phase);
    canvas.drawCircle(
      n.pos,
      r + Tokens.haloOffset,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _haloStroke
        ..color = Tokens.nodeRing(
          n.context,
          d,
        ).withValues(alpha: (1 - d) * _haloAlpha * haloPulse * dim),
    );

    // decay ring — a countdown arc.
    if (!n.isMe) {
      final ringR = r + Tokens.ringOffset;
      final rect = Rect.fromCircle(center: n.pos, radius: ringR);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * (1 - d),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Tokens.ringStroke
          ..strokeCap = StrokeCap.round
          ..color = Tokens.nodeRing(
            n.context,
            d,
          ).withValues(alpha: _ringAlpha * dim),
      );
    }

    // core
    canvas.drawCircle(
      n.pos,
      r,
      Paint()..color = Tokens.nodeFill(n.context, d).withValues(alpha: dim),
    );
    if (!n.isMe) {
      canvas.drawCircle(
        n.pos,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Tokens.hairline
          ..color = Tokens.nodeRing(
            n.context,
            d,
          ).withValues(alpha: _coreStrokeAlpha * dim),
      );
    }

    // selection ring
    if (highlighted.contains(n.id) || n.id == focusedId) {
      canvas.drawCircle(
        n.pos,
        r + Tokens.selectionRingOffset,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Tokens.selectionRingStroke
          ..color = Tokens.cyanBright.withValues(alpha: _selectionAlpha),
      );
    }

    // plan ring — solid violet once in, dashed and turning while waiting.
    // The ring is the pending affordance, so it keeps the mode dim rather than
    // the 45% body fade; otherwise it would disappear at phone size.
    if (planIds.contains(n.id)) {
      _paintPlanRing(canvas, n, r, modeDim, waiting);
    }
  }

  void _paintPlanRing(
    Canvas canvas,
    SimNode n,
    double r,
    double dim,
    bool waiting,
  ) {
    final ringR = r + Tokens.planRingOffset;
    if (!ringR.isFinite || ringR <= 0) return;

    if (waiting) {
      _dashedCircle(
        canvas,
        n.pos,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Tokens.planRingStroke
          ..strokeCap = StrokeCap.round
          ..color = Tokens.dim.withValues(alpha: dim),
        t * _pendingRingRate + n.phase,
      );
      return;
    }

    canvas.drawCircle(
      n.pos,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _planRingGlowStroke
        ..color = Tokens.violet.withValues(alpha: dim * _planRingGlowAlpha),
    );
    canvas.drawCircle(
      n.pos,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = Tokens.planRingStroke
        ..color = Tokens.violet.withValues(alpha: dim * _planRingAlpha),
    );
  }

  // --- plan icon ------------------------------------------------------------

  void _paintPlanIcon(Canvas canvas, SimNode n) {
    if (!_finite(n.pos) || !n.radius.isFinite) return;
    final centre = planIconCentre(n);
    if (!_finite(centre)) return;

    final dim = _dimOf(n.id);
    if (dim <= 0.02) return;

    // A hairline stem so the icon reads as belonging to this node.
    canvas.drawLine(
      n.pos - Offset(0, n.radius),
      centre + const Offset(0, Tokens.planIconRadius),
      Paint()
        ..strokeWidth = Tokens.hairline
        ..color = Tokens.violet.withValues(alpha: dim * _iconStemAlpha),
    );

    canvas.drawCircle(
      centre,
      Tokens.planIconRadius + _iconGlowOffset,
      Paint()..color = Tokens.violet.withValues(alpha: dim * _iconGlowAlpha),
    );
    canvas.drawCircle(
      centre,
      Tokens.planIconRadius + _iconEdgeOffset,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _iconEdgeStroke
        ..color = Tokens.void_.withValues(alpha: dim * _iconEdgeAlpha),
    );
    canvas.drawCircle(
      centre,
      Tokens.planIconRadius,
      Paint()..color = Tokens.violet.withValues(alpha: dim),
    );

    _paintCalendarGlyph(canvas, centre, Tokens.void_.withValues(alpha: dim));
  }

  /// A calendar drawn with primitives: a rounded body, a header rule and the
  /// two ring ticks. No icon font — this has to stay crisp at any zoom.
  void _paintCalendarGlyph(Canvas canvas, Offset centre, Color ink) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _glyphStroke
      ..strokeCap = StrokeCap.round
      ..color = ink;

    final body = Rect.fromCenter(
      center: centre + const Offset(0, _glyphDrop),
      width: _glyphWidth,
      height: _glyphHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(_glyphRadius)),
      pen,
    );
    canvas.drawLine(
      Offset(body.left + _glyphHeaderInset, body.top + _glyphHeaderDrop),
      Offset(body.right - _glyphHeaderInset, body.top + _glyphHeaderDrop),
      pen,
    );
    for (final sign in const [-1.0, 1.0]) {
      final x = centre.dx + sign * _glyphTickX;
      canvas.drawLine(
        Offset(x, body.top - _glyphTickRise),
        Offset(x, body.top + _glyphTickDrop),
        pen,
      );
    }
  }

  // --- labels ---------------------------------------------------------------

  void _paintLabel(Canvas canvas, SimNode n) {
    if (!_finite(n.pos) || !n.radius.isFinite) return;
    final name = names[n.id];
    if (name == null || name.isEmpty) return;

    final show =
        zoom > _labelZoomThreshold ||
        n.closeness >= _labelCloseness ||
        n.isMe ||
        n.id == focusedId ||
        planIds.contains(n.id) ||
        highlighted.contains(n.id);
    if (!show) return;

    var dim = _dimOf(n.id);
    if (pendingIds.contains(n.id)) dim *= _pendingNodeOpacity;
    if (dim <= 0.05) return;

    final alpha = dim * _labelAlpha;
    final key = '$name|${(alpha * 10).round()}';
    final tp = _labels.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: name,
          style: Tokens.nodeLabel.copyWith(
            color: Tokens.nodeLabel.color?.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );

    tp.paint(
      canvas,
      Offset(
        n.pos.dx - tp.width / 2,
        n.pos.dy + n.radius + Tokens.nodeLabelOffset,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}
