/// Growing a plan sideways: the guest brings people from their own circle.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

/// `Hannan` · `Hannan and Pilar` · `Hannan, Pilar and Rui`.
String _joinNames(List<String> names) => switch (names.length) {
  0 => 'Whoever you pick',
  1 => names.first,
  _ => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
};

/// Adding people to a plan you have just accepted.
///
/// The host does not get a veto — that is the point of this sheet, and the
/// note says so out loud.
class CircleSheet extends StatefulWidget {
  const CircleSheet({super.key});

  @override
  State<CircleSheet> createState() => _CircleSheetState();
}

class _CircleSheetState extends State<CircleSheet> {
  final Set<String> _selected = <String>{};

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _invite(AppState state, List<String> ids) {
    for (final id in ids) {
      state.addToPlan(id);
    }
    state.goHome();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final plan = state.plan;

    if (plan == null) {
      return SheetScaffold(
        label: 'add from your circle',
        title: 'There is no plan to add to.',
        actions: [
          SheetAction(
            label: 'Close',
            kind: SheetActionKind.ghost,
            onTap: state.goHome,
          ),
        ],
      );
    }

    final host = state.personById(plan.hostPersonId);
    final theirs = host == null || state.isMe(host.id) ? 'you' : host.name;
    final invited = plan.attendees.keys.toSet();

    // Who would most benefit from the evening: the faded ties first, and
    // between two equally faded ones, the closer person.
    final candidates = [
      for (final p in state.directPeople)
        if (!invited.contains(p.id)) p,
    ];
    candidates.sort((a, b) {
      final da = state.decayWith(a.id);
      final db = state.decayWith(b.id);
      if (da != db) return db.compareTo(da);
      final byCloseness = b.closeness.compareTo(a.closeness);
      return byCloseness != 0 ? byCloseness : a.name.compareTo(b.name);
    });
    // A suggestion, not a directory. Five names is a decision; twelve is a
    // list to get lost in — and the sheet must never need scrolling on stage.
    if (candidates.length > 5) candidates.length = 5;

    final chosen = [
      for (final p in candidates)
        if (_selected.contains(p.id)) p,
    ];
    final names = _joinNames([for (final p in chosen) p.name]);

    return SheetScaffold(
      label: 'add from your circle',
      labelMark: Tokens.lime,
      labelRight: chosen.isEmpty ? null : '${chosen.length} selected',
      title: 'Who else should be there?',
      rows: [
        for (final p in candidates)
          SheetRow(
            initial: p.initial,
            title: p.name,
            sub:
                '${Contexts.label(p.context)} · '
                '${agoLabel(state.daysWith(p.id))}',
            meta: _selected.contains(p.id) ? 'selected' : 'add',
            metaColor: _selected.contains(p.id) ? Tokens.limeDeep : null,
            selected: _selected.contains(p.id),
            onTap: () => _toggle(p.id),
          ),
      ],
      note:
          '$names will see the plan and who is going, not anything else '
          'about $theirs.',
      actions: [
        SheetAction(
          label: switch (chosen.length) {
            0 => 'Invite',
            1 => 'Invite ${chosen.first.name}',
            _ => 'Invite ${chosen.length} people',
          },
          onTap: chosen.isEmpty
              ? null
              : () => _invite(state, [for (final p in chosen) p.id]),
        ),
        SheetAction(
          label: 'Back',
          kind: SheetActionKind.ghost,
          onTap: state.goHome,
        ),
      ],
    );
  }
}
