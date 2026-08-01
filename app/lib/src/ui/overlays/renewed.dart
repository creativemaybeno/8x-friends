/// The calm celebration that lands the moment a real meet-up is confirmed.
library;

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';

/// Geometry and opacity only this celebration needs.
const double _ringBox = 132.0;
const double _coreRadius = 20.0;
const double _ringSpan = 42.0;
const int _ringCount = 3;
const double _ringStagger = 0.18;
const double _ringStroke = 1.4;
const double _ringAlpha = 0.5;
const double _coreFillAlpha = 0.10;
const double _coreStrokeAlpha = 0.75;
const double _dotRadius = 4.0;
const double _dotSpread = 15.0;
const double _linkStroke = 2.2;
const double _linkAlphaFrom = 0.25;
const double _scaleFrom = 0.86;
const double _scrimAlpha = 0.78;
const double _scrimRadius = 0.95;
const double _glowAlpha = 0.13;
const double _glowRadius = 0.55;
const double _captionMaxWidth = 300.0;

/// Full-screen, non-interactive. Visible while `state.renewedMessage` is set:
/// one green ring opening out of a renewed link, the headline, and the people
/// it belongs to. No confetti — the product is calm.
class RenewedOverlay extends StatefulWidget {
  const RenewedOverlay({super.key});

  @override
  State<RenewedOverlay> createState() => _RenewedOverlayState();
}

class _RenewedOverlayState extends State<RenewedOverlay> {
  /// Held after the state clears so the overlay fades out instead of blinking.
  String? _message;
  String _names = '';
  bool _visible = false;

  /// Bumped on every appearance so the entrance tween runs again.
  int _cycle = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final live = state.renewedMessage;
    if (live != null) {
      if (!_visible) _cycle++;
      _message = live;
      _names = _namesOf(state);
    }
    _visible = live != null;
    final message = _message;

    return IgnorePointer(
      child: SizedBox.expand(
        child: AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: Tokens.sheetDuration,
          curve: Tokens.sheetCurve,
          child: message == null
              ? const SizedBox.shrink()
              : Stack(
                  children: [
                    const Positioned.fill(child: _Glow()),
                    Center(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(_cycle),
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: Tokens.renewAnimation,
                        curve: Tokens.sheetCurve,
                        builder: (context, t, child) => Transform.scale(
                          scale: Tokens.lerp(_scaleFrom, 1, t),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: _ringBox,
                                height: _ringBox,
                                child: CustomPaint(
                                  painter: _RenewRingPainter(t),
                                ),
                              ),
                              const SizedBox(height: Tokens.gapL),
                              child!,
                            ],
                          ),
                        ),
                        child: _Caption(message: message, names: _names),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// `Calvin, Yassie and Hannan` — everyone the meet-up renewed.
  String _namesOf(AppState state) {
    final plan = state.plan;
    if (plan == null) return '';
    final names = <String>[];
    for (final id in plan.acceptedIds) {
      final person = state.personById(id);
      if (person != null) names.add(person.name);
    }
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    final head = names.sublist(0, names.length - 1).join(', ');
    return '$head and ${names.last}';
  }
}

/// A soft green light in the middle of the graph, over a gentle vignette so
/// the words stay readable against a busy network.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        radius: _scrimRadius,
        colors: [
          Tokens.void_.withValues(alpha: _scrimAlpha),
          Tokens.void_.withValues(alpha: 0),
        ],
      ),
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: _glowRadius,
          colors: [
            Tokens.green.withValues(alpha: _glowAlpha),
            Tokens.green.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

class _Caption extends StatelessWidget {
  const _Caption({required this.message, required this.names});

  final String message;
  final String names;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: _captionMaxWidth),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.toUpperCase(),
          textAlign: TextAlign.center,
          style: Tokens.renewedTitle,
        ),
        if (names.isNotEmpty) ...[
          const SizedBox(height: Tokens.gapS),
          Text(names, textAlign: TextAlign.center, style: Tokens.sheetProse),
        ],
      ],
    ),
  );
}

/// One link, two people, and rings opening out of them.
class _RenewRingPainter extends CustomPainter {
  const _RenewRingPainter(this.t);

  /// 0 to 1 across [Tokens.renewAnimation].
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (!t.isFinite) return;
    final centre = size.center(Offset.zero);
    final span = (1 - (_ringCount - 1) * _ringStagger).clamp(0.01, 1.0);

    for (var i = 0; i < _ringCount; i++) {
      final p = ((t - i * _ringStagger) / span).clamp(0.0, 1.0);
      final alpha = (1 - p) * _ringAlpha;
      if (p <= 0 || alpha <= 0.01) continue;
      canvas.drawCircle(
        centre,
        _coreRadius + p * _ringSpan,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ringStroke
          ..color = Tokens.green.withValues(alpha: alpha),
      );
    }

    canvas.drawCircle(
      centre,
      _coreRadius,
      Paint()..color = Tokens.green.withValues(alpha: _coreFillAlpha * t),
    );
    canvas.drawCircle(
      centre,
      _coreRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = Tokens.selectionRingStroke
        ..color = Tokens.green.withValues(alpha: _coreStrokeAlpha * t),
    );

    final left = centre - const Offset(_dotSpread, 0);
    final right = centre + const Offset(_dotSpread, 0);
    final linkAlpha = (_linkAlphaFrom + (1 - _linkAlphaFrom) * t).clamp(
      0.0,
      1.0,
    );
    final ink = Paint()
      ..color = Tokens.green.withValues(alpha: linkAlpha)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(left, right, ink..strokeWidth = _linkStroke);
    canvas.drawCircle(left, _dotRadius, ink);
    canvas.drawCircle(right, _dotRadius, ink);
  }

  @override
  bool shouldRepaint(covariant _RenewRingPainter oldDelegate) =>
      oldDelegate.t != t;
}
