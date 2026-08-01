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
  ('today', 0),
  ('yesterday', 1),
  ('this week', 4),
];

/// `Tomás` · `Tomás and Bruno` · `Tomás, Bruno and Saga`.
String _joinNames(List<String> names) => switch (names.length) {
  0 => '',
  1 => names.first,
  _ => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
};

class LogSheet extends StatefulWidget {
  const LogSheet({super.key});

  @override
  State<LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<LogSheet> {
  final Set<String> _selected = <String>{};
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

    // The people who have been waiting longest come first.
    final people = [...state.directPeople]
      ..sort((a, b) => state.decayWith(b.id).compareTo(state.decayWith(a.id)));
    final chosen = [
      for (final p in people)
        if (_selected.contains(p.id)) p,
    ];

    return SheetScaffold(
      label: 'log a meetup',
      labelMark: Tokens.lime,
      labelRight: chosen.isEmpty ? 'nobody yet' : '${chosen.length} selected',
      title: chosen.isEmpty
          ? 'Who did you see?'
          : _joinNames([for (final p in chosen) p.name]),
      read: 'Tap the people, then pick the day it happened.',
      chips: [
        for (final (label, days) in _whenChips)
          SheetChip(
            label: label,
            selected: _daysBack == days,
            onTap: () => setState(() => _daysBack = days),
          ),
      ],
      rows: [
        for (final p in people)
          SheetRow(
            initial: p.initial,
            title: p.name,
            sub: agoLabel(state.daysWith(p.id)),
            meta: _selected.contains(p.id) ? 'in' : null,
            metaColor: Tokens.limeDeep,
            selected: _selected.contains(p.id),
            onTap: () => setState(() {
              if (!_selected.remove(p.id)) _selected.add(p.id);
            }),
          ),
      ],
      actions: [
        SheetAction(
          label: 'Log it',
          onTap: chosen.isEmpty
              ? null
              : () => state.logMeetup(
                  personIds: [for (final p in chosen) p.id],
                  on: state.now.subtract(Duration(days: _daysBack)),
                ),
        ),
        SheetAction(
          label: 'Close',
          kind: SheetActionKind.ghost,
          onTap: state.goHome,
        ),
      ],
    );
  }
}
