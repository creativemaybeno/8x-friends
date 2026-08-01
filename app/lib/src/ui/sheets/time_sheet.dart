/// Scrub the whole graph through time. The scrub is the interaction.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

/// The scrubber range is the state's range — never a second copy of it.
const double _maxOffsetDays = kMaxTimeOffsetDays;
const double _weekDays = 7;

class TimeSheet extends StatelessWidget {
  const TimeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final offset = state.timeOffsetDays;
    final now = state.now;
    final decay = state.decay;

    final alive = state.relationships
        .where((r) => decay.linkDecayOf(r) <= kLinkCollapsesAbove)
        .length;

    final nearby = state.events
        .where((e) => (e.occurredOn.difference(now).inDays).abs() <= _weekDays)
        .length;

    return SheetScaffold(
      label: 'SCRUB THE GRAPH THROUGH TIME',
      title: offset < 1
          ? 'now'
          : '${now.day}/${now.month}/${now.year} · '
                '${durationLabel(offset)} back',
      subtitle: offset < 1
          ? 'Today. Drag back and watch links thin, fray and fall apart as the '
                'months undo themselves.'
          : '$nearby meet-ups within a week of this point. Links you kept '
                'alive stay bright.',
      onClose: state.goHome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$alive LINKS ALIVE', style: Tokens.monoStat),
          const SizedBox(height: Tokens.gapS),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Tokens.cyan,
              inactiveTrackColor: Tokens.borderColorStrong,
              thumbColor: Tokens.cyanBright,
              overlayColor: Tokens.borderColor,
            ),
            child: Slider(
              value: (_maxOffsetDays - offset).clamp(0.0, _maxOffsetDays),
              max: _maxOffsetDays,
              onChanged: (v) => state.setTimeOffsetDays(
                (_maxOffsetDays - v).clamp(0.0, _maxOffsetDays),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('18 MONTHS AGO', style: Tokens.monoLabel),
              Text('TODAY', style: Tokens.monoLabel),
            ],
          ),
        ],
      ),
    );
  }
}
