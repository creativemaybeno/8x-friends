/// The invitation as it lands on the other phone: who, when, and one tap yes.
/// Screen S06.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

/// A day is only named by its weekday while it is still this week-ish.
const int _weekdayHorizon = 6;

const _weekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _weekdayShort = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _monthShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A time written the way a person would say it out loud.
///
/// `Tonight, 8 PM` · `Tomorrow, 7 PM` · `Saturday, 7 PM`, and
/// `Sat 12 Aug, 7 PM` once it is further out than a weekday name can place it.
/// Every sheet that has to name the plan's time uses this one function.
///
/// [now] is the demo clock (`AppState.now`), not the wall clock — the demo
/// jumps time forward, and this has to move with it.
String humanWhen(DateTime when, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  // Hours, not days: a daylight-saving jump makes `inDays` lie by one.
  final delta = (day.difference(today).inHours / 24).round();
  final clock = _clockLabel(when);
  if (delta == 0) {
    return when.hour >= 17 ? 'Tonight, $clock' : 'Today, $clock';
  }
  if (delta == 1) return 'Tomorrow, $clock';
  if (delta == -1) return 'Yesterday, $clock';
  final index = (when.weekday - 1) % 7;
  if (delta > 1 && delta <= _weekdayHorizon) {
    return '${_weekdayNames[index]}, $clock';
  }
  return '${_weekdayShort[index]} ${when.day} '
      '${_monthShort[(when.month - 1) % 12]}, $clock';
}

/// `7 PM` · `1:30 PM` · `12 AM`. Twelve-hour, because people speak that way.
String _clockLabel(DateTime when) {
  final suffix = when.hour < 12 ? 'AM' : 'PM';
  final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
  final minute = when.minute == 0
      ? ''
      : ':${when.minute.toString().padLeft(2, '0')}';
  return '$hour$minute $suffix';
}

/// `19:00`. The sheet's own headline is written the way the plan was set.
String _clock24(DateTime when) =>
    '${when.hour.toString().padLeft(2, '0')}:'
    '${when.minute.toString().padLeft(2, '0')}';

/// What Yassie sees when Calvin's invitation arrives: accept, or offer a
/// different time. Nothing else — an invitation is not a negotiation.
class InvitationSheet extends StatelessWidget {
  const InvitationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final plan = state.plan;
    final host = plan == null ? null : state.personById(plan.hostPersonId);
    if (plan == null || host == null) return const _NoInvitation();

    final days = state.daysWith(host.id);
    final never = days >= kNeverMetDays;
    final weekday = _weekdayNames[(plan.when.weekday - 1) % 7];
    final place = plan.place;
    final names = [
      for (final id in plan.attendeeIds)
        if (id != state.meId) state.personById(id)?.name ?? 'Someone',
    ];

    return SheetScaffold(
      label: 'invitation',
      labelColor: Tokens.ink2,
      labelMark: Tokens.lime,
      labelRight: never
          ? 'from ${host.name.toLowerCase()}'
          : '${durationLabel(days)} since you met',
      subject: SheetSubject(
        initial: host.initial,
        name: host.name,
        meta:
            '${Contexts.label(host.context)} · '
            'last together ${agoLabel(days)}',
        badgeDecay: state.decayWith(host.id),
      ),
      title: place == null
          ? '$weekday, ${_clock24(plan.when)}'
          : '$weekday, ${_clock24(plan.when)} — $place',
      read:
          'It has been a while since ${host.name}. One evening would fix '
          'the whole thread.',
      field: SheetField(
        label: 'who is coming',
        value: names.isEmpty ? 'just you' : '${names.join(', ')}, you',
      ),
      actions: [
        SheetAction(label: 'I’m in', onTap: state.acceptPlan),
        SheetAction(
          label: 'Another time',
          kind: SheetActionKind.ghost,
          onTap: () => state.setMode(AppMode.proposeTime),
        ),
      ],
      foot: 'declining is fine — it just goes quiet',
    );
  }
}

/// The plan was cancelled or answered while this sheet was open. Say so
/// plainly rather than showing an empty invitation.
class _NoInvitation extends StatelessWidget {
  const _NoInvitation();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return SheetScaffold(
      label: 'invitation',
      labelColor: Tokens.ink2,
      labelMark: Tokens.mut,
      labelRight: 'nothing waiting',
      title: 'Nothing waiting',
      read: 'That invitation is no longer on the table.',
      actions: [
        SheetAction(
          label: 'Back to the graph',
          kind: SheetActionKind.ghost,
          onTap: state.goHome,
        ),
      ],
    );
  }
}
