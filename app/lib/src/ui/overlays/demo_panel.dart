/// The stage controls: a small, clearly labelled panel of demo-only actions.
library;

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../sheets/sheet_scaffold.dart';

// Local one-off geometry. Colours and text styles come from Tokens.
const double _panelWidth = 336.0;
const EdgeInsets _panelPadding = EdgeInsets.fromLTRB(22, 24, 22, 22);
const double _statusDot = 6.0;
const double _closedSlide = 0.10;

const double _shadowAlpha = 0.4;
const double _shadowBlur = 40.0;
const double _shadowSpread = -18.0;
const double _shadowY = 18.0;

/// How far above the bottom edge the panel floats so the demo chip in the
/// shell stays visible and tappable underneath it.
const double _chipClearance = 34.0;

const List<String> _weekdays = [
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];

/// The demo-state controls the pitch calls for, kept deliberately quiet.
///
/// It is labelled `demo state` on purpose: the jury should read it as part of
/// the presentation, never as part of the product. Visible only while
/// [AppState.demoPanelOpen].
class DemoPanel extends StatelessWidget {
  const DemoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final open = state.demoPanelOpen;
    return Align(
      alignment: Alignment.bottomRight,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.gapM,
            0,
            Tokens.gapM,
            Tokens.gapM + _chipClearance,
          ),
          child: IgnorePointer(
            ignoring: !open,
            child: AnimatedSlide(
              offset: Offset(0, open ? 0 : _closedSlide),
              duration: Tokens.bannerDuration,
              curve: Tokens.bannerCurve,
              child: AnimatedOpacity(
                opacity: open ? 1 : 0,
                duration: Tokens.bannerDuration,
                curve: Tokens.bannerCurve,
                child: _Panel(state: state),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan;
    final morning = plan == null
        ? null
        : DateTime(
            plan.when.year,
            plan.when.month,
            plan.when.day,
            9,
          ).add(const Duration(days: 1));

    final maxHeight =
        MediaQuery.of(context).size.height * Tokens.sheetMaxHeightFraction;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _panelWidth, maxHeight: maxHeight),
      child: Container(
        padding: _panelPadding,
        decoration: BoxDecoration(
          color: Tokens.card,
          borderRadius: BorderRadius.circular(Tokens.radiusNotif),
          border: Border.all(color: Tokens.hairInk09, width: Tokens.hairline),
          boxShadow: [
            BoxShadow(
              color: Tokens.ink.withValues(alpha: _shadowAlpha),
              blurRadius: _shadowBlur,
              spreadRadius: _shadowSpread,
              offset: const Offset(0, _shadowY),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('demo state', style: Tokens.sheetLabel),
              const SizedBox(height: Tokens.gapM),
              Text('Advance the plan clock', style: Tokens.sheetTitle),
              const SizedBox(height: Tokens.gapS),
              Text(
                'For the live demo only. Jumps to the morning after and fires '
                "the real confirmation notification on every attendee's phone.",
                style: Tokens.sheetRead,
              ),
              const SizedBox(height: Tokens.gapM),
              SheetRow(title: 'Now', meta: _clock(state.now)),
              const SizedBox(height: Tokens.gapXs),
              SheetRow(
                title: 'Planned for',
                meta: plan == null ? 'no plan yet' : _stamp(plan.when),
              ),
              const SizedBox(height: Tokens.gapXs),
              SheetRow(
                title: 'Jump to',
                meta: morning == null ? 'nothing to skip' : _stamp(morning),
              ),
              const SizedBox(height: Tokens.gapM),
              SheetAction(
                label: 'Advance to next morning',
                kind: SheetActionKind.dark,
                onTap: state.advanceToMorningAfter,
              ),
              const SizedBox(height: Tokens.gapS),
              SheetAction(
                label: 'Close',
                kind: SheetActionKind.ghost,
                onTap: state.toggleDemoPanel,
              ),
              const SizedBox(height: Tokens.gapM),
              Row(
                children: [
                  Flexible(
                    child: _Ghost(
                      label: 'run next beat',
                      onTap: state.nudgeDirector,
                    ),
                  ),
                  const SizedBox(width: Tokens.gapM),
                  Flexible(
                    child: _Ghost(label: 'reset', onTap: state.resetDemo),
                  ),
                  const SizedBox(width: Tokens.gapS),
                  _Channel(connected: state.channelConnected),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `09:02` — the demo clock, machine voice.
String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// `sat 19:00`.
String _stamp(DateTime t) => '${_weekdays[(t.weekday - 1) % 7]} ${_clock(t)}';

/// A mono text control, no chrome at all.
class _Ghost extends StatelessWidget {
  const _Ghost({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Text(label, style: Tokens.sheetLabelRight),
  );
}

/// Whether the two phones can still hear each other.
class _Channel extends StatelessWidget {
  const _Channel({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final colour = connected ? Tokens.limeDeep : Tokens.mut;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _statusDot,
          height: _statusDot,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          connected ? 'live' : 'offline',
          style: Tokens.footLine.copyWith(color: colour),
        ),
      ],
    );
  }
}
