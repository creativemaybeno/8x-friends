/// The ultra-fast path: who, when, optionally where.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

const _whenChips = <(String, int)>[
  ('Today', 0),
  ('Yesterday', 1),
  ('3 days', 3),
  ('Last week', 7),
];

class LogSheet extends StatefulWidget {
  const LogSheet({super.key});

  @override
  State<LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<LogSheet> {
  final _place = TextEditingController();
  int _daysBack = 0;

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  String _toast(List<Person> people) {
    if (people.length == 1) return '${people.first.name} is lit up again.';
    final names = people.map((p) => p.name).toList();
    final last = names.removeLast();
    return '${names.join(', ')} and $last are lit up again.';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final decay = state.decay;
    final selected = state.selectedPersonIds;

    final people = <Person>[
      for (final p in state.people)
        if (!p.isMe) p,
    ]..sort((a, b) => decay.daysOf(a.id).compareTo(decay.daysOf(b.id)));

    final chosen = <Person>[
      for (final p in people)
        if (selected.contains(p.id)) p,
    ];

    return SheetScaffold(
      label: 'TAP EVERYONE WHO WAS THERE',
      title: chosen.isEmpty
          ? 'Nobody selected yet'
          : chosen.map((p) => p.name).join(', '),
      onClose: state.goHome,
      footer: SheetButton(
        label: chosen.isEmpty
            ? 'PICK PEOPLE ON THE GRAPH'
            : chosen.length == 1
            ? 'LOG 1 PERSON'
            : 'LOG ${chosen.length} PEOPLE',
        onTap: chosen.isEmpty
            ? null
            : () async {
                final message = _toast(chosen);
                final when = state.now.subtract(Duration(days: _daysBack));
                final place = _place.text.trim();
                await state.logMeetUp(
                  occurredOn: DateTime(when.year, when.month, when.day),
                  personIds: chosen.map((p) => p.id).toList(),
                  place: place.isEmpty ? null : place,
                );
                state.clearSelection();
                state.showToast(message);
                state.goHome();
              },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final (label, days) in _whenChips) ...[
                SheetChip(
                  label: label,
                  selected: _daysBack == days,
                  onTap: () => setState(() => _daysBack = days),
                ),
                const SizedBox(width: Tokens.gapXs),
              ],
            ],
          ),
          const SizedBox(height: Tokens.gapM),
          TextField(
            controller: _place,
            style: Tokens.input,
            cursorColor: Tokens.cyan,
            decoration: InputDecoration(
              hintText: 'Where?',
              hintStyle: Tokens.input.copyWith(color: Tokens.faint),
              filled: true,
              fillColor: Tokens.borderColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Tokens.radiusButton),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: Tokens.gapM),
          for (final p in people)
            SheetRow(
              title: p.name,
              meta: agoLabel(decay.daysOf(p.id)),
              dot: Tokens.contextColor(p.context),
              selected: selected.contains(p.id),
              onTap: () => state.toggleSelected(p.id),
            ),
          const SizedBox(height: Tokens.gapS),
          GestureDetector(
            onTap: () => state.setMode(AppMode.add),
            behavior: HitTestBehavior.opaque,
            child: Text('+ SOMEONE NEW WAS THERE', style: Tokens.monoLabel),
          ),
        ],
      ),
    );
  }
}
