/// One painter for the whole graph. Never a widget per node.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart' hide Simulation;

import '../model/decay.dart';
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
const double _inviteStroke = 1.1;
const double _inviteRate = 3.4;
const double _ghostStrokeWidth = 0.9;
const int _maxFragmentSegments = 48;

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
    required this.invitedIds,
    required this.ghostOpacity,
  });

  final Simulation sim;
  final DecayModel decay;
  final Offset camera;
  final double zoom;
  final Set<String> highlighted;
  final double dimOthers;
  final String? focusedId;
  final double t;
  final Set<String> invitedIds;
  final double ghostOpacity;

  static final Map<String, TextPainter> _labels = {};

  double _dimOf(String id) =>
      highlighted.isEmpty || highlighted.contains(id) ? 1.0 : dimOthers;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.translate(-camera.dx, -camera.dy);

    for (final l in sim.links) {
      _paintLink(canvas, l);
    }
    for (final n in sim.nodes) {
      _paintNode(canvas, n);
    }
    for (final n in sim.nodes) {
      _paintLabel(canvas, n);
    }

    canvas.restore();
  }

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

  // --- nodes ----------------------------------------------------------------

  void _paintNode(Canvas canvas, SimNode n) {
    if (!_finite(n.pos)) return;
    if (n.isGhost) {
      canvas.drawCircle(
        n.pos,
        n.radius,
        Paint()..color = Tokens.sink.withValues(alpha: ghostOpacity),
      );
      canvas.drawCircle(
        n.pos,
        n.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ghostStrokeWidth
          ..color = Tokens.faint.withValues(alpha: ghostOpacity),
      );
      return;
    }

    final d = sim.decayOf(n.id);
    final dim = _dimOf(n.id);
    if (dim <= 0.005) return;

    var r = n.radius;
    if (!n.isMe && d < kNodeBreathesBelow) {
      r *=
          1 +
          Tokens.breathingAmplitude *
              math.sin(t * Tokens.breathingRate + n.phase) *
              (1 - d / kNodeBreathesBelow);
    }

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

    // invitation halo
    if (invitedIds.contains(n.id)) {
      canvas.drawCircle(
        n.pos,
        r + Tokens.inviteHaloOffset,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _inviteStroke
          ..color = Tokens.cyan.withValues(
            alpha: (0.55 + 0.45 * math.sin(t * _inviteRate + n.phase)).clamp(
              0.0,
              1.0,
            ),
          ),
      );
    }
  }

  // --- labels ---------------------------------------------------------------

  void _paintLabel(Canvas canvas, SimNode n) {
    if (!_finite(n.pos)) return;
    final name = _nameOf(n.id);
    if (name == null || name.isEmpty) return;

    final show =
        zoom > _labelZoomThreshold ||
        n.closeness >= _labelCloseness ||
        n.isMe ||
        n.id == focusedId ||
        highlighted.contains(n.id);
    if (!show) return;

    final dim = _dimOf(n.id);
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

  String? _nameOf(String id) => _names[id];

  late final Map<String, String> _names = {
    for (final p in decay.people) p.id: p.name,
  };

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}
