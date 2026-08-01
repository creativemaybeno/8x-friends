/// Logging a meet-up that already happened: who was there, and roughly when.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

/// The three answers to "when". Anything older is rare enough to leave out —
/// this flow has to be finishable in the time it takes to walk to the tram.
const _whenChips = <(String, int)>[
  ('TODAY', 0),
  ('YESTERDAY', 1),
  ('THIS WEEK', 4),
];

class LogSheet extends StatefulWidget {
  const LogSheet({super.key});

  @override
  State<LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<LogSheet> {
  final Set<String> _selected = {};
  int _daysBack = 0;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    // Arriving from the focus sheet, the person you were just looking at is
    // almost always the person you were just with.
    final state = AppScope.of(context);
    final focused = state.focusedPersonId;
    if (focused != null && state.isDirectlyConnected(focused)) {
      _selected.add(focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final decay = state.decay;
    final people = state.directPeople;
    final chosen = <String>[
      for (final p in people)
        if (_selected.contains(p.id)) p.id,
    ];

    return SheetScaffold(
      label: 'LOG A MEET-UP',
      title: 'Who were you with?',
      subtitle: 'Adding it now keeps the graph honest.',
      onClose: state.goHome,
      footer: SheetButton(
        label: 'THAT HAPPENED',
        onTap: chosen.isEmpty
            ? null
            : () => state.logMeetup(
                personIds: chosen,
                on: state.now.subtract(Duration(days: _daysBack)),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHEN', style: Tokens.monoLabelDim),
          const SizedBox(height: Tokens.gapS),
          Wrap(
            spacing: Tokens.gapXs,
            runSpacing: Tokens.gapXs,
            children: [
              for (final (label, days) in _whenChips)
                SheetChip(
                  label: label,
                  selected: _daysBack == days,
                  onTap: () => setState(() => _daysBack = days),
                ),
            ],
          ),
          const SizedBox(height: Tokens.gapM),
          Row(
            children: [
              Expanded(
                child: Text('WHO WAS THERE', style: Tokens.monoLabelDim),
              ),
              Text(
                chosen.isEmpty ? 'NOBODY YET' : '${chosen.length} SELECTED',
                style: Tokens.monoLabel,
              ),
            ],
          ),
          const SizedBox(height: Tokens.gapS),
          for (final p in people)
            SheetRow(
              title: p.name,
              meta: agoLabel(decay.daysOf(p.id)),
              dot: Tokens.contextColor(p.context),
              selected: _selected.contains(p.id),
              onTap: () => setState(() {
                if (!_selected.remove(p.id)) _selected.add(p.id);
              }),
            ),
        ],
      ),
    );
  }
}
