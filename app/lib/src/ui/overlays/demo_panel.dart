/// The stage controls: a small, clearly labelled panel of demo-only actions.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';

// Local one-off geometry. Colours and text styles come from Tokens.
const double _panelWidth = 248.0;
const double _rowHeight = 44.0;
const double _headerHeight = 46.0;
const double _statusHeight = 32.0;
const double _statusDot = 6.0;
const double _closedSlide = 0.10;

/// How far above the bottom edge the panel floats so the `DEMO` chip in the
/// shell stays visible and tappable underneath it.
const double _chipClearance = 34.0;

/// The demo-state controls the pitch calls for, kept deliberately quiet.
///
/// It is labelled `DEMO CONTROLS` on purpose: the jury should read it as part
/// of the presentation, never as part of the product. Visible only while
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusCard),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: Tokens.sheetBlur,
          sigmaY: Tokens.sheetBlur,
        ),
        child: Container(
          width: _panelWidth,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Tokens.sheetTop, Tokens.sheetBottom],
            ),
            border: Border.all(
              color: Tokens.borderColorStrong,
              width: Tokens.hairline,
            ),
            borderRadius: BorderRadius.circular(Tokens.radiusCard),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(onClose: state.toggleDemoPanel),
              _DemoRow(
                label: 'ADVANCE TO THE MORNING AFTER',
                onTap: state.advanceToMorningAfter,
              ),
              _DemoRow(
                label: 'RUN THE NEXT BEAT NOW',
                onTap: state.nudgeDirector,
              ),
              _DemoRow(label: 'RESET THE DEMO', onTap: state.resetDemo),
              _Status(connected: state.channelConnected),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: Tokens.gapM),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Tokens.borderColor, width: Tokens.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DEMO CONTROLS', style: Tokens.monoLabel),
                const SizedBox(height: 2),
                Text('STAGE ONLY', style: Tokens.monoTiny),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: Tokens.gapS),
              child: Text('CLOSE', style: Tokens.monoLabelDim),
            ),
          ),
        ],
      ),
    );
  }
}

/// One 44 px control. Machine voice, hairline underneath, nothing else.
class _DemoRow extends StatelessWidget {
  const _DemoRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _rowHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.gapM),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Tokens.borderColor,
              width: Tokens.hairline,
            ),
          ),
        ),
        child: Text(
          label,
          style: Tokens.monoLabelBright,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Whether the two phones can still hear each other.
class _Status extends StatelessWidget {
  const _Status({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final colour = connected ? Tokens.green : Tokens.faint;
    return Container(
      height: _statusHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: Tokens.gapM),
      child: Row(
        children: [
          Container(
            width: _statusDot,
            height: _statusDot,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          const SizedBox(width: Tokens.gapS),
          Text(
            connected ? 'CHANNEL CONNECTED' : 'CHANNEL OFFLINE',
            style: Tokens.monoLabelDim.copyWith(color: colour),
          ),
        ],
      ),
    );
  }
}
