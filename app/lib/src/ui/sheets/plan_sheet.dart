/// The upcoming plan: when it is, who is in, and who is still deciding.
library;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'invitation_sheet.dart' show humanWhen;
import 'sheet_scaffold.dart';

const _weekdays = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// `19:00` — the machine voice writes time in twenty-four hours.
String _hhmm(DateTime when) =>
    '${when.hour.toString().padLeft(2, '0')}:'
    '${when.minute.toString().padLeft(2, '0')}';

/// `Saturday 19:00`.
String _dayTime(DateTime when) =>
    '${_weekdays[(when.weekday - 1) % 7]} ${_hhmm(when)}';

/// Host first, then everyone who is in, then everyone still deciding.
int _rank(String id, Plan plan) {
  if (id == plan.hostPersonId) return 0;
  return switch (plan.attendees[id]) {
    Attendance.accepted => 1,
    Attendance.invited => 2,
    _ => 3,
  };
}

/// The plan behind a lime node in the graph.
class PlanSheet extends StatelessWidget {
  const PlanSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final plan = state.plan;

    if (plan == null) {
      return SheetScaffold(
        label: 'planned meetup',
        title: 'Nothing planned yet.',
        read: 'Tap someone in the graph and plan something with them.',
        actions: [
          SheetAction(
            label: 'Close',
            kind: SheetActionKind.ghost,
            onTap: state.goHome,
          ),
        ],
      );
    }

    final ids = plan.attendeeIds;
    ids.sort((a, b) {
      final byRank = _rank(a, plan).compareTo(_rank(b, plan));
      if (byRank != 0) return byRank;
      return (state.personById(a)?.name ?? a).compareTo(
        state.personById(b)?.name ?? b,
      );
    });

    final where = plan.place;
    final iAmHost = state.isMe(plan.hostPersonId);

    return SheetScaffold(
      label: 'planned meetup',
      labelMark: Tokens.lime,
      labelRight: '${plan.acceptedIds.length} going',
      title: where == null
          ? humanWhen(plan.when, now: state.now)
          : '$where — ${_dayTime(plan.when)}',
      rows: [
        for (final id in ids)
          SheetRow(
            initial: state.personById(id)?.initial ?? '?',
            title: state.isMe(id)
                ? 'You'
                : (state.personById(id)?.name ?? 'Someone'),
            sub: id == plan.hostPersonId ? 'host' : null,
            meta: switch (plan.attendees[id]) {
              Attendance.accepted => 'in',
              Attendance.declined => 'out',
              _ => 'waiting',
            },
            metaColor: switch (plan.attendees[id]) {
              Attendance.accepted => Tokens.limeDeep,
              Attendance.declined => Tokens.clay,
              _ => Tokens.mut,
            },
          ),
      ],
      note:
          'No reminder will be sent. The morning after you will be asked '
          'once whether it happened.',
      actions: [
        SheetAction(
          label: 'Bring someone',
          onTap: () => state.setMode(AppMode.circle),
        ),
        SheetAction(
          label: 'Close',
          kind: SheetActionKind.ghost,
          onTap: state.goHome,
        ),
        if (iAmHost)
          SheetAction(
            label: 'Cancel plan',
            kind: SheetActionKind.ghost,
            onTap: state.cancelPlan,
          ),
      ],
    );
  }
}
