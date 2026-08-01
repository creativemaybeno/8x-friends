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
import 'sheets/nearby_sheet.dart';
import 'sheets/plan_sheet.dart';
import 'sheets/plan_time_sheet.dart';

// Geometry, straight off the 402x874 design frame. Colours and type come from
// Tokens.
const _chromeInset = 22.0;
const _chromeTop = 6.0;
const _scrimBelowStatus = 56.0;
const _markSize = 28.0;
const _markGap = 11.0;
const _pillDot = 5.0;
const _pillPadding = EdgeInsets.fromLTRB(11, 7, 14, 7);
const _segmentPadding = EdgeInsets.symmetric(horizontal: 26, vertical: 13);
const _trackPadding = EdgeInsets.all(5);
const _captionBottom = 124.0;
const _switcherBottom = 44.0;
const _toastBottom = 180.0;
const _toastPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 15);
const _toastInset = 24.0;
const _toastRise = 0.7;
const _demoRight = 16.0;
const _demoLift = 13.0;
const _sheetOffscreen = 1.12;

/// The design frame keeps 10px under the switcher for the home indicator; a
/// gesture bar wants the rest.
const _indicatorBand = 10.0;

const _weekdays = <String>[
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

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
    final media = MediaQuery.of(context);
    final sheet = _sheetFor(state);
    if (sheet != null) _lastSheet = sheet;
    final open = sheet != null;
    final chromeVisible = !open && !state.isBooting;
    final lift = (media.padding.bottom - _indicatorBand).clamp(0.0, 40.0);

    // Material (not Scaffold) so the graph stays full-bleed edge to edge, and
    // so Text has a DefaultTextStyle ancestor (otherwise: yellow debug text).
    return Material(
      color: Tokens.paper,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const graph.GraphView(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: media.padding.top + _scrimBelowStatus,
            child: const IgnorePointer(child: _TopScrim()),
          ),
          Positioned(
            top: media.padding.top + _chromeTop,
            left: _chromeInset,
            right: _chromeInset,
            child: _Header(state: state),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: _captionBottom + lift,
            child: IgnorePointer(
              child: _Fade(
                visible: chromeVisible,
                child: Text(
                  _captionFor(state),
                  textAlign: TextAlign.center,
                  style: Tokens.hintLine,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: _switcherBottom + lift,
            child: IgnorePointer(
              ignoring: !chromeVisible,
              child: _Fade(
                visible: chromeVisible,
                child: _ViewSwitcher(state: state),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: Offset(0, open ? 0 : _sheetOffscreen),
              duration: Tokens.sheetDuration,
              curve: Tokens.sheetCurve,
              child: _lastSheet ?? const SizedBox.shrink(),
            ),
          ),
          Positioned(
            left: _toastInset,
            right: _toastInset,
            bottom: _toastBottom + lift,
            child: _Toast(message: state.toast),
          ),
          const RenewedOverlay(),
          const NotificationBannerOverlay(),
          // On the caption's line, not the switcher's: the switcher track is
          // ~270 wide and centred, so anything at the switcher's height on the
          // right edge lands on top of it.
          Positioned(
            right: _demoRight,
            bottom: _captionBottom + lift - _demoLift,
            child: IgnorePointer(
              ignoring: !chromeVisible,
              child: _Fade(
                visible: chromeVisible,
                child: _DemoChip(state: state),
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
    AppMode.nearby => const NearbySheet(),
    AppMode.home || AppMode.boot => null,
  };
}

/// Whatever the graph is waiting on, highest stake first. Null when nothing
/// is: the chrome stays empty rather than inventing a badge.
(String, AppMode?)? _alertFor(AppState s) {
  if (s.hasIncomingInvitation) return ('1 invitation', AppMode.invitation);
  if (s.awaitingConfirmation) return ('did you meet up?', AppMode.confirm);
  final pending = s.pendingIds.length;
  if (pending > 0) return ('$pending pending', AppMode.planDetail);
  final request = s.requestPair;
  if (request != null && request.$1 == s.meId) return ('1 request out', null);
  return null;
}

/// What the graph is saying, in one lowercase mono line.
String _captionFor(AppState s) {
  final plan = s.plan;
  if (plan != null) {
    final tail = switch (plan.phase) {
      PlanPhase.proposed => 'waiting',
      PlanPhase.confirmed => 'confirmed',
      _ => null,
    };
    if (tail != null) {
      final when = plan.when;
      final day = _weekdays[(when.weekday - 1) % 7];
      final hh = when.hour.toString().padLeft(2, '0');
      final mm = when.minute.toString().padLeft(2, '0');
      final place = plan.place?.toLowerCase() ?? '';
      return ['$day $hh:$mm', if (place.isNotEmpty) place, tail].join(' · ');
    }
  }
  return switch (s.view) {
    GraphView.health =>
      '${s.circleCount} in your circle · ${s.driftingCount} drifting',
    GraphView.distance => '${s.circleCount} in your circle · nearby view',
  };
}

/// Keeps the header legible where it crosses the graph.
class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Tokens.paper, Tokens.paper.withAlpha(0)],
      ),
    ),
    child: const SizedBox.expand(),
  );
}

/// Cross-fades a chrome layer out while a sheet owns the screen.
class _Fade extends StatelessWidget {
  const _Fade({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: visible ? 1 : 0,
    duration: Tokens.sheetDuration,
    curve: Tokens.sheetCurve,
    child: child,
  );
}

/// Wordmark, who you are, and the one thing waiting on you.
class _Header extends StatelessWidget {
  const _Header({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final who = state.who;
    final alert = _alertFor(state);
    final mode = alert?.$2;

    return Row(
      children: [
        const _Mark(size: _markSize),
        const SizedBox(width: _markGap),
        Expanded(
          child: Text(
            who == null ? '' : who.label.toLowerCase(),
            style: Tokens.ownerLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (alert != null) ...[
          const SizedBox(width: 10),
          _AlertPill(
            label: alert.$1,
            onTap: mode == null ? null : () => state.setMode(mode),
          ),
        ],
      ],
    );
  }
}

/// The lime disc. The only branding in the product.
class _Mark extends StatelessWidget {
  const _Mark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: Tokens.lime, shape: BoxShape.circle),
    child: Text(
      '8xF',
      style: Tokens.wordmarkMark.copyWith(fontSize: size * 0.375),
    ),
  );
}

/// One waiting thing, with a dot that breathes so you look at it.
class _AlertPill extends StatefulWidget {
  const _AlertPill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  State<_AlertPill> createState() => _AlertPillState();
}

class _AlertPillState extends State<_AlertPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  late final Animation<double> _dot;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _dot = _breath.drive(
      Tween<double>(
        begin: Tokens.breatheMin,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: _pillPadding,
        decoration: BoxDecoration(
          color: Tokens.lime,
          borderRadius: BorderRadius.circular(Tokens.radiusChip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _dot,
              child: Container(
                width: _pillDot,
                height: _pillDot,
                decoration: const BoxDecoration(
                  color: Tokens.ink,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.label, style: Tokens.pillLabel),
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
    (GraphView.health, 'Health'),
    (GraphView.distance, 'Nearby'),
  ];

  void _select(GraphView view) {
    // The nearby view is gated on a permission we ask for in words, once.
    if (view == GraphView.distance && !state.locationGranted) {
      state.setMode(AppMode.nearby);
      return;
    }
    state.setView(view);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: _trackPadding,
        decoration: BoxDecoration(
          color: Tokens.card,
          borderRadius: BorderRadius.circular(Tokens.radiusChip),
          boxShadow: [
            const BoxShadow(color: Tokens.hairInk05, spreadRadius: 1),
            BoxShadow(
              color: Tokens.ink.withAlpha(102),
              blurRadius: 30,
              spreadRadius: -14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              _Segment(
                label: _segments[i].$2,
                active: state.view == _segments[i].$1,
                onTap: () => _select(_segments[i].$1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: _segmentPadding,
      decoration: BoxDecoration(
        color: active ? Tokens.lime : Colors.transparent,
        borderRadius: BorderRadius.circular(Tokens.radiusChip),
      ),
      child: Text(
        label,
        style: Tokens.toggleLabel.copyWith(
          color: active ? Tokens.ink : Tokens.ink2,
        ),
      ),
    ),
  );
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: open ? Tokens.ink : Tokens.card,
          borderRadius: BorderRadius.circular(Tokens.radiusChip),
          boxShadow: const [
            BoxShadow(color: Tokens.hairInk05, spreadRadius: 1),
          ],
        ),
        child: Text(
          'demo',
          style: Tokens.footLine.copyWith(
            color: open ? Tokens.paper : Tokens.mut,
          ),
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
      child: AnimatedSlide(
        offset: Offset(0, _visible ? 0 : _toastRise),
        duration: Tokens.sheetDuration,
        curve: Tokens.sheetCurve,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: Tokens.sheetDuration,
          curve: Tokens.sheetCurve,
          child: Container(
            padding: _toastPadding,
            decoration: BoxDecoration(
              color: Tokens.ink,
              borderRadius: BorderRadius.circular(Tokens.radiusChip),
            ),
            child: Text(
              _shown ?? '',
              textAlign: TextAlign.center,
              style: Tokens.toastText,
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
          color: Tokens.paper,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Mark(size: 56),
                const SizedBox(height: Tokens.gapL),
                Text(
                  'assembling your graph',
                  textAlign: TextAlign.center,
                  style: Tokens.hintLine,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
