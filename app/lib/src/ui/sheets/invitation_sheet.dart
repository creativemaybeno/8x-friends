/// The invitation as it lands on the other phone: who, when, and one tap yes.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

/// Geometry only this sheet needs.
const double _hostAvatarSize = 56.0;
const double _guestAvatarSize = 26.0;
const double _statGap = 10.0;
const double _nameGap = 3.0;
const EdgeInsets _guestPadding = EdgeInsets.fromLTRB(4, 4, Tokens.gapS, 4);

/// Below this, "it has been N days" is not the story worth telling.
const double _recentDays = 7.0;

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

/// One warm line about the gap this invitation is trying to close.
String _subtitleFor(String hostName, double days) => days < _recentDays
    ? 'You saw each other recently. $hostName wants another.'
    : 'It has been ${durationLabel(days)} since you two were in the '
          'same room.';

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

    final key = Relationship.keyFor(state.meId, host.id);
    final days = state.decay.linkDays[key] ?? state.decay.daysOf(host.id);
    final others = <Person>[
      for (final id in plan.attendeeIds)
        if (id != state.meId && id != host.id) ?state.personById(id),
    ];

    return SheetScaffold(
      label: 'INVITATION',
      title: '${host.name} wants to see you',
      subtitle: _subtitleFor(host.name, days),
      accent: Tokens.violet,
      onClose: state.goHome,
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(
              label: 'ACCEPT',
              accent: Tokens.violet,
              onTap: state.acceptPlan,
            ),
          ),
          const SizedBox(width: _statGap),
          Expanded(
            child: SheetGhostButton(
              label: 'ANOTHER TIME',
              onTap: () => state.setMode(AppMode.proposeTime),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(person: host, size: _hostAvatarSize),
              const SizedBox(width: Tokens.gapM),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.name,
                      style: Tokens.personNameLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: _nameGap),
                    Text(Contexts.label(host.context), style: Tokens.monoLabel),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.gapM),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SheetStat(
                  caption: 'WHEN',
                  value: humanWhen(plan.when, now: state.now),
                  accent: Tokens.violet,
                ),
              ),
              const SizedBox(width: _statGap),
              Expanded(
                child: SheetStat(caption: 'WHERE', value: plan.place ?? '—'),
              ),
            ],
          ),
          const SizedBox(height: _statGap),
          SheetStat(
            caption: 'LAST TOGETHER',
            value: agoLabel(days),
            accent: Tokens.healthColor(decayFor(days)),
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: Tokens.gapM),
            Text('ALSO COMING', style: Tokens.monoLabelDim),
            const SizedBox(height: Tokens.gapS),
            Wrap(
              spacing: Tokens.gapS,
              runSpacing: Tokens.gapS,
              children: [
                for (final p in others)
                  _Guest(
                    person: p,
                    pending: state.attendanceOf(p.id) == Attendance.invited,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Someone else who is coming. Dimmed until they say yes.
class _Guest extends StatelessWidget {
  const _Guest({required this.person, required this.pending});

  final Person person;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _guestPadding,
      decoration: BoxDecoration(
        border: Border.all(color: Tokens.borderColor, width: Tokens.hairline),
        borderRadius: BorderRadius.circular(Tokens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(person: person, size: _guestAvatarSize, dimmed: pending),
          const SizedBox(width: Tokens.gapXs),
          Text(person.name, style: Tokens.personName),
          if (pending) ...[
            const SizedBox(width: Tokens.gapXs),
            Text('WAITING', style: Tokens.monoLabelDim),
          ],
        ],
      ),
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
      label: 'INVITATION',
      title: 'Nothing waiting',
      subtitle: 'That invitation is no longer on the table.',
      accent: Tokens.violet,
      onClose: state.goHome,
      footer: SheetButton(
        label: 'BACK TO THE GRAPH',
        accent: Tokens.violet,
        onTap: state.goHome,
      ),
      child: Text('NO OPEN INVITATION', style: Tokens.monoLabelDim),
    );
  }
}
