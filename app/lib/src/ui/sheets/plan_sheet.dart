/// The upcoming plan: when it is, who is in, and who is still deciding.
library;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'invitation_sheet.dart' show humanWhen;
import 'sheet_scaffold.dart';

/// The attendee avatar sitting left of the row.
const double _avatarSize = 34.0;

/// Someone who has not answered yet is present but not certain.
const double _pendingOpacity = 0.45;

/// Where an attendee stands, in the machine's voice.
String _attendanceLabel(Attendance? a, {required bool isHost}) {
  if (isHost) return 'HOST';
  return switch (a) {
    Attendance.accepted => 'IN',
    Attendance.declined => "CAN'T MAKE IT",
    _ => 'WAITING',
  };
}

/// Host first, then everyone who is in, then everyone still deciding.
int _rank(String id, Plan plan) {
  if (id == plan.hostPersonId) return 0;
  return switch (plan.attendees[id]) {
    Attendance.accepted => 1,
    Attendance.invited => 2,
    _ => 3,
  };
}

/// The plan behind the icon on a graph node.
class PlanSheet extends StatelessWidget {
  const PlanSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final plan = state.plan;

    if (plan == null) {
      return SheetScaffold(
        label: 'UPCOMING',
        title: 'Nothing planned yet',
        subtitle: 'Tap someone in the graph and plan something with them.',
        accent: Tokens.violet,
        onClose: state.goHome,
        child: const SizedBox.shrink(),
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
    final inCount = plan.acceptedIds.length;
    final waitingCount = plan.pendingIds.length;

    return SheetScaffold(
      label: 'UPCOMING',
      title: humanWhen(plan.when, now: state.now),
      subtitle: plan.place ?? 'Somewhere you both like.',
      accent: Tokens.violet,
      onClose: state.goHome,
      footer: Row(
        children: [
          Expanded(
            child: SheetGhostButton(
              label: 'RESCHEDULE',
              accent: Tokens.violet,
              onTap: () => state.setMode(AppMode.proposeTime),
            ),
          ),
          const SizedBox(width: Tokens.gapS),
          Expanded(
            child: SheetGhostButton(
              label: 'CANCEL PLAN',
              accent: Tokens.amber,
              onTap: state.cancelPlan,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final id in ids)
            _AttendeeRow(
              person: state.personById(id),
              id: id,
              attendance: plan.attendees[id],
              isHost: id == plan.hostPersonId,
              isMe: state.isMe(id),
            ),
          const SizedBox(height: Tokens.gapS),
          Text(
            '$inCount IN · $waitingCount WAITING',
            style: Tokens.monoLabelBright.copyWith(color: Tokens.violet),
          ),
        ],
      ),
    );
  }
}

/// One person in the plan, dimmed while they have not answered.
class _AttendeeRow extends StatelessWidget {
  const _AttendeeRow({
    required this.person,
    required this.id,
    required this.attendance,
    required this.isHost,
    required this.isMe,
  });

  final Person? person;
  final String id;
  final Attendance? attendance;
  final bool isHost;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final pending = !isHost && attendance == Attendance.invited;
    final who = person ?? Person(id: id, name: id);
    return Opacity(
      opacity: pending ? _pendingOpacity : 1,
      child: Row(
        children: [
          Avatar(person: who, size: _avatarSize, dimmed: pending),
          const SizedBox(width: Tokens.gapS),
          Expanded(
            child: SheetRow(
              title: isMe ? '${who.name} (you)' : who.name,
              meta: _attendanceLabel(attendance, isHost: isHost),
            ),
          ),
        ],
      ),
    );
  }
}
