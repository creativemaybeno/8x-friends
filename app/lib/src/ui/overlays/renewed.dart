/// The lime card that lands the moment a real meet-up is confirmed.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';

// Geometry from the design (`Phone8x` 2e). Colour and type are tokens.
const double _insetH = 26.0;

/// `top:268` on the design's 874-tall frame.
const double _topFraction = 268 / 874;

const EdgeInsets _padding = EdgeInsets.fromLTRB(30, 34, 30, 30);
const double _eyebrowGap = 20.0;
const double _lineGap = 26.0;
const double _meterGap = 20.0;
const double _meterSpacing = 12.0;
const double _meterHeight = 6.0;

/// The fill is fixed in the design: a renewal always reads as a full bar.
const double _meterFill = 0.96;

const double _scaleFrom = 0.95;
const Duration _entrance = Duration(milliseconds: 500);

const double _shadowAlpha = 0.45;
const double _shadowBlur = 46.0;
const double _shadowSpread = -20.0;
const double _shadowY = 20.0;

/// The old signal, quiet. The new one, full weight.
TextStyle get _meterFrom => Tokens.timeHint.copyWith(
  fontSize: 13,
  color: Tokens.ink.withValues(alpha: 0.5),
);

TextStyle get _meterTo =>
    Tokens.timeHint.copyWith(fontSize: 15, color: Tokens.ink);

/// Non-interactive, so the graph keeps moving underneath. Visible while
/// `state.renewedMessage` is set: one lime card that names what just got
/// stronger and by how much. No confetti — the product is calm.
class RenewedOverlay extends StatefulWidget {
  const RenewedOverlay({super.key});

  @override
  State<RenewedOverlay> createState() => _RenewedOverlayState();
}

class _RenewedOverlayState extends State<RenewedOverlay> {
  /// Held after the state clears so the card fades out instead of blinking.
  String? _line;
  String _sub = '';
  String _from = '';
  String _to = '';
  bool _visible = false;

  /// Bumped on every appearance so the entrance tween runs again.
  int _cycle = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final live = state.renewedMessage;
    if (live != null) {
      if (!_visible) _cycle++;
      _read(state);
    }
    _visible = live != null;
    final line = _line;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: _entrance,
          curve: Tokens.sheetCurve,
          child: line == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.fromLTRB(
                    _insetH,
                    constraints.maxHeight * _topFraction,
                    _insetH,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TweenAnimationBuilder<double>(
                        key: ValueKey(_cycle),
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: _entrance,
                        curve: Tokens.sheetCurve,
                        builder: (context, t, child) => Transform.scale(
                          scale: Tokens.lerp(_scaleFrom, 1, t),
                          child: child,
                        ),
                        child: _RenewedCard(
                          line: line,
                          from: _from,
                          to: _to,
                          sub: _sub,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// Everything the card says, read off the plan that just closed.
  void _read(AppState state) {
    final people = _renewedPeople(state);
    _line = _headline(people);

    final edge = people.isEmpty ? null : state.edgeWith(people.first.id);
    if (edge == null) {
      _from = '';
      _to = '';
      _sub =
          'One evening put every tie you already had back at full signal. '
          'Meeting is the only thing that counts.';
      return;
    }

    final gap = edge.seedDaysSince.toDouble();
    final before = decayFor(gap, horizon: edge.horizonDays);
    _from = '${signalFor(before)}%';
    _to = '${signalFor(state.decayWith(people.first.id))}%';
    _sub = people.length == 1
        ? 'One evening closed a gap of ${durationLabel(gap)}. Your rhythm has '
              'been re-learned from the meet-up — you two are back to meeting '
              '${edge.rhythmLabel}.'
        : 'One evening closed a gap of ${durationLabel(gap)}. Every tie you '
              'already had has been re-learned from the meet-up.';
  }

  /// Who the renewal belongs to: the plan's accepted attendees, minus me,
  /// narrowed to the ones I actually have an edge with.
  List<Person> _renewedPeople(AppState state) {
    final plan = state.plan;
    if (plan == null) return const [];
    final all = <Person>[];
    for (final id in plan.acceptedIds) {
      if (state.isMe(id)) continue;
      final person = state.personById(id);
      if (person != null) all.add(person);
    }
    final direct = [
      for (final p in all)
        if (state.edgeWith(p.id) != null) p,
    ];
    return direct.isEmpty ? all : direct;
  }

  String _headline(List<Person> people) {
    if (people.isEmpty) return 'You are back in rhythm.';
    if (people.length == 1) {
      return 'You and ${people.first.name} are back in rhythm.';
    }
    final names = [for (final p in people) p.name].join(', ');
    return '$names and you are back in rhythm.';
  }
}

class _RenewedCard extends StatelessWidget {
  const _RenewedCard({
    required this.line,
    required this.from,
    required this.to,
    required this.sub,
  });

  final String line;
  final String from;
  final String to;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: Tokens.lime,
        borderRadius: BorderRadius.circular(Tokens.radiusRenewed),
        boxShadow: [
          BoxShadow(
            color: Tokens.ink.withValues(alpha: _shadowAlpha),
            blurRadius: _shadowBlur,
            spreadRadius: _shadowSpread,
            offset: const Offset(0, _shadowY),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('connection renewed', style: Tokens.renewedEyebrow),
          const SizedBox(height: _eyebrowGap),
          Text(line, style: Tokens.renewedLine),
          const SizedBox(height: _lineGap),
          if (to.isNotEmpty) ...[
            Row(
              children: [
                Text(from, style: _meterFrom),
                const SizedBox(width: _meterSpacing),
                const Expanded(child: _Meter()),
                const SizedBox(width: _meterSpacing),
                Text(to, style: _meterTo),
              ],
            ),
            const SizedBox(height: _meterGap),
          ],
          Text(sub, style: Tokens.renewedSub),
        ],
      ),
    );
  }
}

/// Ink on a dark-lime track. The fill is the design's, not the data's.
class _Meter extends StatelessWidget {
  const _Meter();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: Container(
      height: _meterHeight,
      color: Tokens.hairInk18,
      child: const FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _meterFill,
        child: DecoratedBox(decoration: BoxDecoration(color: Tokens.ink)),
      ),
    ),
  );
}
