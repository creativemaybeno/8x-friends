/// The whole app: one [Stack] over the graph. No [Navigator], no routes.
library;

import 'dart:async';

import 'package:flutter/material.dart';

// `models.dart` owns the `GraphView` *enum*; this file owns the `GraphView`
// *widget*. Prefix the widget so both names can live here.
import '../graph/graph_view.dart' as graph;
import '../model/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'overlays/banner.dart';
import 'overlays/demo_panel.dart';
import 'overlays/renewed.dart';
import 'sheets/circle_sheet.dart';
import 'sheets/confirm_sheet.dart';
import 'sheets/connect_sheet.dart';
import 'sheets/focus_sheet.dart';
import 'sheets/identity_sheet.dart';
import 'sheets/invitation_sheet.dart';
import 'sheets/log_sheet.dart';
import 'sheets/plan_sheet.dart';
import 'sheets/plan_time_sheet.dart';

// Local one-off geometry. Colours and text styles come from Tokens.
const _chromeTop = 14.0;
const _sheetOffscreen = 1.12;
const _alertDot = 5.0;
const _captionGap = 3.0;
const _pillPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 5);
const _segmentPadding = EdgeInsets.symmetric(horizontal: 11, vertical: 6);
const _toastPadding = EdgeInsets.symmetric(horizontal: 15, vertical: 9);
const _toastMaxWidth = 330.0;
const _toastBottom = 80.0;

/// The single surface. Everything the jury sees is a layer of this stack.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  /// Retained so a dismissed sheet still has something to slide out with.
  Widget? _lastSheet;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final sheet = _sheetFor(state);
    if (sheet != null) _lastSheet = sheet;
    final demoVisible = sheet == null && !state.isBooting;

    // Material (not Scaffold) so the graph stays full-bleed edge to edge, and
    // so Text has a DefaultTextStyle ancestor (otherwise: yellow debug text).
    return Material(
      color: Tokens.void_,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const graph.GraphView(),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.gapM,
                _chromeTop,
                Tokens.gapM,
                0,
              ),
              child: _TopChrome(state: state),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: Offset(0, sheet == null ? _sheetOffscreen : 0),
              duration: Tokens.sheetDuration,
              curve: Tokens.sheetCurve,
              child: _lastSheet ?? const SizedBox.shrink(),
            ),
          ),
          Positioned(
            left: Tokens.gapM,
            right: Tokens.gapM,
            bottom: _toastBottom,
            child: _Toast(message: state.toast),
          ),
          const RenewedOverlay(),
          const NotificationBannerOverlay(),
          Positioned(
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  0,
                  Tokens.gapM,
                  Tokens.gapM,
                ),
                child: IgnorePointer(
                  ignoring: !demoVisible,
                  child: AnimatedOpacity(
                    opacity: demoVisible ? 1 : 0,
                    duration: Tokens.sheetDuration,
                    curve: Tokens.sheetCurve,
                    child: _DemoChip(state: state),
                  ),
                ),
              ),
            ),
          ),
          const DemoPanel(),
          _BootOverlay(state: state),
        ],
      ),
    );
  }

  Widget? _sheetFor(AppState s) => switch (s.mode) {
    AppMode.identity => const IdentitySheet(),
    AppMode.focus => const FocusSheet(),
    AppMode.planTime => const PlanTimeSheet(),
    AppMode.invitation => const InvitationSheet(),
    AppMode.proposeTime => const ProposeTimeSheet(),
    AppMode.circle => const CircleSheet(),
    AppMode.planDetail => const PlanSheet(),
    AppMode.connect => const ConnectSheet(),
    AppMode.confirm => const ConfirmSheet(),
    AppMode.log => const LogSheet(),
    AppMode.home || AppMode.boot => null,
  };
}

/// Wordmark, the one alert, the view switcher and what the graph is saying.
class _TopChrome extends StatelessWidget {
  const _TopChrome({required this.state});

  final AppState state;

  /// Whatever the graph is asking of you right now, highest stake first. The
  /// confirm sheet's other door is the notification banner, which dismisses
  /// itself after [Tokens.bannerDwell] — this pill keeps it open all demo.
  (String, Color, AppMode)? _pill() {
    if (state.awaitingConfirmation) {
      return ('DID YOU MEET UP?', Tokens.green, AppMode.confirm);
    }
    if (state.hasIncomingInvitation) {
      return ('1 INVITATION WAITING', Tokens.violet, AppMode.invitation);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final who = state.who;
    final pill = _pill();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('8x', style: Tokens.wordmark),
                const SizedBox(width: Tokens.gapXs),
                Text('friends', style: Tokens.monoLabel),
              ],
            ),
            const Spacer(),
            if (pill != null)
              Flexible(
                child: _ActionPill(
                  label: pill.$1,
                  accent: pill.$2,
                  onTap: () => state.setMode(pill.$3),
                ),
              ),
          ],
        ),
        if (who != null) ...[
          const SizedBox(height: Tokens.gapS),
          _ViewSwitcher(state: state),
          const SizedBox(height: Tokens.gapXs),
          Text(switch (state.view) {
            GraphView.health =>
              'RELATIONSHIP HEALTH · ${state.people.length} PEOPLE',
            GraphView.distance =>
              'APPROXIMATE DISTANCE · UPDATED WHEN THEY OPEN THE APP',
          }, style: Tokens.monoTiny),
          const SizedBox(height: _captionGap),
          Text('YOU ARE ${who.label.toUpperCase()}', style: Tokens.monoTiny),
        ],
      ],
    );
  }
}

/// The only thing allowed to interrupt the wordmark.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: _pillPadding,
        decoration: BoxDecoration(
          color: Tokens.borderColor,
          border: Border.all(
            color: Tokens.borderColorStrong,
            width: Tokens.hairline,
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusChip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _alertDot,
              height: _alertDot,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: Tokens.gapXs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tokens.monoLabelBright,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two readings of the same graph. Nothing else changes.
class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.state});

  final AppState state;

  static const _segments = <(GraphView, String)>[
    (GraphView.health, 'HEALTH'),
    (GraphView.distance, 'NEARBY'),
  ];

  void _select(GraphView view) {
    if (view == GraphView.distance && !state.locationGranted) {
      state.grantLocation();
      state.showToast('Approximate distance only. Never live location.');
    }
    state.setView(view);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (view, label) in _segments)
          GestureDetector(
            onTap: () => _select(view),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(right: Tokens.gapXs),
              padding: _segmentPadding,
              decoration: BoxDecoration(
                color: state.view == view
                    ? Tokens.borderColor
                    : Colors.transparent,
                border: Border.all(
                  color: state.view == view
                      ? Tokens.borderColorStrong
                      : Colors.transparent,
                  width: Tokens.hairline,
                ),
                borderRadius: BorderRadius.circular(Tokens.radiusButton),
              ),
              child: Text(
                label,
                style: state.view == view
                    ? Tokens.monoLabelBright
                    : Tokens.monoLabel,
              ),
            ),
          ),
      ],
    );
  }
}

/// Deliberately visible, deliberately small: the stage controls.
class _DemoChip extends StatelessWidget {
  const _DemoChip({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final open = state.demoPanelOpen;
    return GestureDetector(
      onTap: state.toggleDemoPanel,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: _pillPadding,
        decoration: BoxDecoration(
          color: open ? Tokens.borderColorStrong : Tokens.borderColor,
          border: Border.all(
            color: Tokens.borderColorStrong,
            width: Tokens.hairline,
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusChip),
        ),
        child: Text(
          'DEMO',
          style: open ? Tokens.monoLabelBright : Tokens.monoLabel,
        ),
      ),
    );
  }
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message});

  final String? message;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> {
  Timer? _timer;
  bool _visible = false;
  String? _shown;

  @override
  void didUpdateWidget(_Toast old) {
    super.didUpdateWidget(old);
    if (widget.message != old.message && widget.message != null) {
      setState(() {
        _visible = true;
        _shown = widget.message;
      });
      _timer?.cancel();
      _timer = Timer(Tokens.toastDuration, () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: Tokens.sheetDuration,
        curve: Tokens.sheetCurve,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _toastMaxWidth),
            child: Container(
              padding: _toastPadding,
              decoration: BoxDecoration(
                color: Tokens.sheetTop,
                border: Border.all(
                  color: Tokens.borderColorStrong,
                  width: Tokens.hairline,
                ),
                borderRadius: BorderRadius.circular(Tokens.radiusButton),
              ),
              child: Text(
                _shown ?? '',
                textAlign: TextAlign.center,
                style: Tokens.sheetProse,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootOverlay extends StatelessWidget {
  const _BootOverlay({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final showing = state.isBooting;
    return IgnorePointer(
      ignoring: !showing,
      child: AnimatedOpacity(
        opacity: showing ? 1 : 0,
        duration: Tokens.bootDuration,
        curve: Tokens.sheetCurve,
        child: ColoredBox(
          color: Tokens.void_,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.gapXl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('8x', style: Tokens.personNameLarge),
                  const SizedBox(height: Tokens.gapS),
                  Text(
                    'assembling your graph',
                    textAlign: TextAlign.center,
                    style: Tokens.monoLabel,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
