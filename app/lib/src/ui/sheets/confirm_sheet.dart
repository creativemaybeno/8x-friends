/// The morning after: the one question that turns a plan into a renewal.
library;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'invitation_sheet.dart' show humanWhen;
import 'sheet_scaffold.dart';

/// Geometry only this sheet needs.
const double _avatarSize = 34.0;
const double _avatarGap = 12.0;
const double _metaGap = 2.0;

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
        label: 'YESTERDAY',
        title: 'Nothing to confirm.',
        subtitle: 'That plan has left your graph.',
        accent: Tokens.green,
        onClose: state.goHome,
        footer: SheetButton(
          label: 'BACK TO THE GRAPH',
          accent: Tokens.green,
          onTap: state.goHome,
        ),
        child: const SizedBox.shrink(),
      );
    }

    final attendees = _orderedAttendees(state, plan);
    final others = attendees.where((p) => !state.isMe(p.id)).toList();

    return SheetScaffold(
      label: 'YESTERDAY',
      title: 'Did you meet up?',
      subtitle:
          '${humanWhen(plan.when, now: state.now)} with ${_nameList(others)}.',
      accent: Tokens.green,
      onClose: state.goHome,
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(
              label: 'YES, WE MET',
              accent: Tokens.green,
              onTap: state.confirmMeetupHappened,
            ),
          ),
          const SizedBox(width: Tokens.gapS),
          Expanded(
            child: SheetGhostButton(
              label: 'NOT THIS TIME',
              onTap: state.declineMeetupHappened,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHO WAS THERE', style: Tokens.monoLabelDim),
          const SizedBox(height: Tokens.gapS),
          for (final person in attendees)
            _AttendeeRow(
              person: person,
              attendance: state.attendanceOf(person.id) ?? Attendance.invited,
              isHost: person.id == plan.hostPersonId,
              isMe: state.isMe(person.id),
            ),
        ],
      ),
    );
  }
}

/// Everyone on the plan, host first, in the order the plan grew.
List<Person> _orderedAttendees(AppState state, Plan plan) {
  final ids = <String>[
    plan.hostPersonId,
    ...plan.attendeeIds.where((id) => id != plan.hostPersonId),
  ];
  return <Person>[for (final id in ids) ?state.personById(id)];
}

/// `Yassie`, `Yassie and Hannan`, `Yassie, Hannan and Mira`.
String _nameList(List<Person> people) {
  final names = people.map((p) => p.name).toList();
  return switch (names.length) {
    0 => 'your circle',
    1 => names.first,
    _ => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
  };
}

/// One person on the plan. Read-only — this sheet asks, it does not edit.
class _AttendeeRow extends StatelessWidget {
  const _AttendeeRow({
    required this.person,
    required this.attendance,
    required this.isHost,
    required this.isMe,
  });

  final Person person;
  final Attendance attendance;
  final bool isHost;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final came = attendance == Attendance.accepted;
    final role = isHost
        ? 'HOST'
        : switch (attendance) {
            Attendance.accepted => 'IN',
            Attendance.invited => 'WAITING',
            Attendance.declined => 'COULD NOT MAKE IT',
          };
    final meta = [if (isMe) 'YOU', role].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.gapS),
      child: Row(
        children: [
          Avatar(person: person, size: _avatarSize, dimmed: !came),
          const SizedBox(width: _avatarGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: Tokens.personName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: _metaGap),
                Text(meta, style: Tokens.monoLabelDim),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
