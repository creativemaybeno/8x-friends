/// The morning after: the one question that turns a plan into a renewal.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'invitation_sheet.dart' show humanWhen;
import 'sheet_scaffold.dart';

/// `Yassie` · `Yassie and Hannan` · `Yassie, Hannan and Mira`.
String _joinNames(List<String> names) => switch (names.length) {
  0 => 'your circle',
  1 => names.first,
  _ => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
};

/// `19:00`.
String _hhmm(DateTime when) =>
    '${when.hour.toString().padLeft(2, '0')}:'
    '${when.minute.toString().padLeft(2, '0')}';

/// Asks whether the plan actually happened. Answering yes is what renews every
/// relationship among the people who were there.
class ConfirmSheet extends StatelessWidget {
  const ConfirmSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final plan = state.plan;

    if (plan == null) {
      return SheetScaffold(
        label: 'confirm',
        title: 'Nothing to confirm.',
        read: 'That plan has left your graph.',
        actions: [
          SheetAction(
            label: 'Close',
            kind: SheetActionKind.ghost,
            onTap: state.goHome,
          ),
        ],
      );
    }

    final others = <Person>[
      for (final p in state.people)
        if (!state.isMe(p.id) && plan.attendees[p.id] == Attendance.accepted) p,
    ];
    final indirect = [
      for (final p in others)
        if (!state.isDirectlyConnected(p.id)) p.name,
    ];
    final names = _joinNames([for (final p in others) p.name]);
    final where = plan.place;

    return SheetScaffold(
      label: 'confirm',
      labelMark: Tokens.lime,
      labelRight: _hhmm(plan.when),
      title: 'Did it happen?',
      read: where == null
          ? '${humanWhen(plan.when, now: state.now)}, with $names.'
          : '$where, last night, with $names.',
      rows: [
        for (final p in others)
          if (state.isDirectlyConnected(p.id))
            SheetRow(
              initial: p.initial,
              title: p.name,
              sub: 'direct · ${agoLabel(state.daysWith(p.id))}',
              meta: 'will get stronger',
              metaColor: Tokens.limeDeep,
            )
          else
            SheetRow(
              initial: p.initial,
              initialHollow: true,
              title: p.name,
              sub: 'indirect · no change',
              meta: 'no change',
              dimmed: true,
            ),
      ],
      note: indirect.isEmpty
          ? 'Only relationships you already have get stronger. Sharing a '
                'table does not create one.'
          : 'Only relationships you already have get stronger. Sharing a '
                'table does not make ${_joinNames(indirect)} a connection.',
      actions: [
        SheetAction(label: 'Yes, we met', onTap: state.confirmMeetupHappened),
        SheetAction(
          label: 'Not this time',
          kind: SheetActionKind.ghost,
          onTap: state.declineMeetupHappened,
        ),
      ],
    );
  }
}
