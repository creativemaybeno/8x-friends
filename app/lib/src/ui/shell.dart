/// The whole app: one [Stack] over the graph. No [Navigator], no routes.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../env.dart';
import '../graph/graph_view.dart';
import '../model/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'sheets/add_sheet.dart';
import 'sheets/focus_sheet.dart';
import 'sheets/group_sheet.dart';
import 'sheets/invites_sheet.dart';
import 'sheets/log_sheet.dart';
import 'sheets/name_sheet.dart';
import 'sheets/nudge_sheet.dart';
import 'sheets/pay_sheet.dart';
import 'sheets/propose_sheet.dart';
import 'sheets/reach_sheet.dart';
import 'sheets/time_sheet.dart';

// Local design constants — fold into tokens.dart.
const _chromeTop = 14.0;
const _sheetOffscreen = 1.12;
const _badgeDot = 5.0;
const _navGap = 2.0;
const _pillPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 5);
const _segmentPadding = EdgeInsets.symmetric(horizontal: 9, vertical: 5);
const _toastPadding = EdgeInsets.symmetric(horizontal: 15, vertical: 9);
const _toastMaxWidth = 330.0;

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Widget? _lastSheet;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final sheet = _sheetFor(state);
    if (sheet != null) _lastSheet = sheet;

    return ColoredBox(
      color: Tokens.void_,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const GraphView(),
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
            child: SafeArea(top: false, child: _Nav(state: state)),
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
            bottom: Tokens.navHeight + Tokens.gapXl,
            child: _Toast(message: state.toast),
          ),
          _BootOverlay(state: state),
        ],
      ),
    );
  }

  Widget? _sheetFor(AppState state) {
    if (state.needsName) return const NameSheet();
    return switch (state.mode) {
      AppMode.focus => const FocusSheet(),
      AppMode.log => const LogSheet(),
      AppMode.add => const AddSheet(),
      AppMode.nudge => const NudgeSheet(),
      AppMode.group => const GroupSheet(),
      AppMode.time => const TimeSheet(),
      AppMode.reach => const ReachSheet(),
      AppMode.invites => const InvitesSheet(),
      AppMode.propose => const ProposeSheet(),
      AppMode.pay => const PaySheet(),
      AppMode.name => const NameSheet(),
      AppMode.home || AppMode.boot => null,
    };
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final people = state.people.length;
    final anon = state.ghosts.where((g) => !g.isNamed).length;
    final reach = people + state.ghosts.length;
    final pending = state.pendingInvitationCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onLongPress: state.reseed,
              behavior: HitTestBehavior.opaque,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('8x', style: Tokens.wordmark),
                  const SizedBox(width: Tokens.gapXs),
                  Text('friends', style: Tokens.monoLabel),
                ],
              ),
            ),
            const Spacer(),
            if (pending > 0)
              GestureDetector(
                onTap: () => state.setMode(AppMode.invites),
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
                  child: Text(
                    pending == 1
                        ? '1 INVITATION WAITING'
                        : '$pending INVITATIONS WAITING',
                    style: Tokens.monoLabelBright,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Tokens.gapS),
        _LayoutSwitcher(state: state),
        const SizedBox(height: Tokens.gapXs),
        Text(switch (state.layout) {
          GraphLayout.web => 'FREE FORCE LAYOUT',
          GraphLayout.orbit => 'RADIUS = TIME SINCE YOU MET',
          GraphLayout.strata => 'ISLANDS = SHARED CONTEXT',
        }, style: Tokens.monoTiny),
        const SizedBox(height: 2),
        Text(
          '$people PEOPLE · $anon ANON · $reach IN REACH',
          style: Tokens.monoTiny,
        ),
      ],
    );
  }
}

class _LayoutSwitcher extends StatelessWidget {
  const _LayoutSwitcher({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (layout, label) in const [
          (GraphLayout.web, 'WEB'),
          (GraphLayout.orbit, 'ORBIT'),
          (GraphLayout.strata, 'STRATA'),
        ])
          GestureDetector(
            onTap: () => state.setLayout(layout),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(right: Tokens.gapXs),
              padding: _segmentPadding,
              decoration: BoxDecoration(
                color: state.layout == layout
                    ? Tokens.borderColor
                    : Colors.transparent,
                border: Border.all(
                  color: state.layout == layout
                      ? Tokens.borderColorStrong
                      : Colors.transparent,
                  width: Tokens.hairline,
                ),
                borderRadius: BorderRadius.circular(Tokens.radiusButton),
              ),
              child: Text(
                label,
                style: state.layout == layout
                    ? Tokens.monoLabelBright
                    : Tokens.monoLabel,
              ),
            ),
          ),
      ],
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.state});

  final AppState state;

  static const _tabs = <(String, AppMode)>[
    ('GRAPH', AppMode.home),
    ('LOG', AppMode.log),
    ('PULL', AppMode.nudge),
    ('GROUP', AppMode.group),
    ('REACH', AppMode.reach),
    ('TIME', AppMode.time),
  ];

  @override
  Widget build(BuildContext context) {
    final mode = state.mode;
    return SizedBox(
      height: Tokens.navHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.gapS),
        child: Row(
          children: [
            for (final (label, tabMode) in _tabs)
              Expanded(
                child: _NavTab(
                  label: label,
                  active: tabMode == AppMode.home
                      ? (mode == AppMode.home || mode == AppMode.focus)
                      : mode == tabMode,
                  amber: tabMode == AppMode.nudge,
                  badge: tabMode == AppMode.nudge && state.nudges.isNotEmpty,
                  onTap: () => tabMode == AppMode.home
                      ? state.goHome()
                      : state.setMode(tabMode),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.active,
    required this.amber,
    required this.badge,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool amber;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = amber ? Tokens.amber : Tokens.cyan;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: _navGap),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Tokens.borderColor : Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.radiusButton),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: active ? 1 : 0.5,
              child: Text(
                label,
                style: Tokens.monoNav.copyWith(
                  color: amber || active ? color : Tokens.meta,
                ),
              ),
            ),
            if (badge)
              Positioned(
                top: -_badgeDot,
                right: -_badgeDot,
                child: Container(
                  width: _badgeDot,
                  height: _badgeDot,
                  decoration: const BoxDecoration(
                    color: Tokens.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
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

  @override
  void didUpdateWidget(_Toast old) {
    super.didUpdateWidget(old);
    if (widget.message != old.message && widget.message != null) {
      setState(() => _visible = true);
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
                widget.message ?? '',
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
    final error = state.bootError ?? Env.misconfigurationReason;
    final showing = state.isBooting || error != null;
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
                    error ?? 'assembling your graph',
                    textAlign: TextAlign.center,
                    style: error == null
                        ? Tokens.monoLabel
                        : Tokens.monoLabel.copyWith(color: Tokens.amber),
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
