/// Picking a time: the host's day + time, and the guest's counter-offer.
/// Screens S03 and S07. No presets — she picks her own day and her own hour.
library;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

/// The strip is always the next seven days, today first.
const int _dayCount = 7;

const _weekdayShort = <String>['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

const _weekdayLong = <String>[
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// Where a plan can be. Tapping the field cycles them.
const _places = <String>['Café Janis', 'the boulder gym', 'the park', 'yours'];

/// The time stepper: half-hour steps, inside a civilised day.
const int _stepMinutes = 30;
const int _earliestMinutes = 8 * 60;
const int _latestMinutes = 23 * 60;

/// 19:00 — what the host opens on.
const int _defaultMinutes = 19 * 60;

/// 12:30 — what a counter-offer opens on.
const int _counterMinutes = 12 * 60 + 30;

List<DateTime> _days(DateTime now) => [
  for (var i = 0; i < _dayCount; i++)
    DateTime(now.year, now.month, now.day + i),
];

List<SheetDay> _strip(List<DateTime> days) => [
  for (final d in days)
    SheetDay(weekday: _weekdayShort[(d.weekday - 1) % 7], number: '${d.day}'),
];

int _clampDay(int i) => i < 0 ? 0 : (i > _dayCount - 1 ? _dayCount - 1 : i);

int _clampMinutes(int m) {
  if (m < _earliestMinutes) return _earliestMinutes;
  if (m > _latestMinutes) return _latestMinutes;
  return m;
}

/// Where [day] sits in the strip. Hours, not days: a daylight-saving jump
/// makes `inDays` lie by one.
int _indexOf(DateTime now, DateTime day) {
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(day.year, day.month, day.day);
  return _clampDay((b.difference(a).inHours / 24).round());
}

/// The coming Saturday, or today when today is Saturday.
int _saturdayIndex(DateTime now) => (DateTime.saturday - now.weekday + 7) % 7;

String _clock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

String _clockOf(DateTime when) => _clock(when.hour * 60 + when.minute);

/// "saturday evening" — the mono hint beside the big time.
String _hint(DateTime day, int minutes) {
  final hour = minutes ~/ 60;
  final part = hour < 11
      ? 'morning'
      : hour < 14
      ? 'lunch'
      : hour < 17
      ? 'afternoon'
      : hour < 21
      ? 'evening'
      : 'night';
  return '${_weekdayLong[(day.weekday - 1) % 7]} $part';
}

DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

String _capital(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// ---------------------------------------------------------------------------
// S03 — the host picks a day and an hour.
// ---------------------------------------------------------------------------

class PlanTimeSheet extends StatefulWidget {
  const PlanTimeSheet({super.key});

  @override
  State<PlanTimeSheet> createState() => _PlanTimeSheetState();
}

class _PlanTimeSheetState extends State<PlanTimeSheet> {
  int? _day;
  int _minutes = _defaultMinutes;
  int _place = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final days = _days(state.now);
    final selected = _day ?? _saturdayIndex(state.now);
    final withId = state.focusedPersonId;
    final person = withId == null ? null : state.personById(withId);
    final place = _places[_place];

    return SheetScaffold(
      label: 'plan something',
      labelColor: Tokens.ink2,
      labelMark: Tokens.lime,
      labelRight: person == null
          ? 'with someone'
          : 'with ${person.name.toLowerCase()}',
      title: 'When suits you?',
      picker: SheetPicker(
        dayLabel: 'day',
        days: _strip(days),
        selected: selected,
        onSelect: (i) => setState(() => _day = i),
        time: _clock(_minutes),
        timeHint: _hint(days[selected], _minutes),
        onEarlier: () =>
            setState(() => _minutes = _clampMinutes(_minutes - _stepMinutes)),
        onLater: () =>
            setState(() => _minutes = _clampMinutes(_minutes + _stepMinutes)),
      ),
      field: SheetField(
        label: 'where',
        value: place,
        onTap: () => setState(() => _place = (_place + 1) % _places.length),
      ),
      actions: [
        SheetAction(
          label: 'Send invitation',
          onTap: withId == null
              ? null
              : () => state.proposePlan(
                  withPersonId: withId,
                  when: _at(days[selected], _minutes),
                  place: place,
                ),
        ),
        SheetAction(
          label: 'Back',
          kind: SheetActionKind.ghost,
          onTap: withId == null
              ? state.goHome
              : () => state.focusPerson(withId),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S07 — the guest offers one other time.
// ---------------------------------------------------------------------------

class ProposeTimeSheet extends StatefulWidget {
  const ProposeTimeSheet({super.key});

  @override
  State<ProposeTimeSheet> createState() => _ProposeTimeSheetState();
}

class _ProposeTimeSheetState extends State<ProposeTimeSheet> {
  int? _day;
  int? _minutes;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final plan = state.plan;
    if (plan == null) return _NoPlan(state: state);

    final days = _days(state.now);
    final proposed = _indexOf(state.now, plan.when);
    final selected = _day ?? _clampDay(proposed + 1);
    final minutes = _minutes ?? _counterMinutes;
    final host = state.personById(plan.hostPersonId);
    final hostName = host?.name ?? 'They';
    final theirDay = _weekdayLong[(plan.when.weekday - 1) % 7];
    final myDay = _weekdayLong[(days[selected].weekday - 1) % 7];

    return SheetScaffold(
      label: 'offer another time',
      labelColor: Tokens.ink2,
      labelMark: Tokens.ink,
      labelRight: 'one counter-offer',
      title: selected == proposed
          ? '${_capital(theirDay)} works — just later?'
          : '${_capital(theirDay)} is tight. ${_capital(myDay)}?',
      read: 'Nothing is cancelled. $hostName sees your time and can take it.',
      picker: SheetPicker(
        dayLabel: 'your day instead',
        days: _strip(days),
        selected: selected,
        onSelect: (i) => setState(() => _day = i),
        time: _clock(minutes),
        timeHint: _hint(days[selected], minutes),
        onEarlier: () =>
            setState(() => _minutes = _clampMinutes(minutes - _stepMinutes)),
        onLater: () =>
            setState(() => _minutes = _clampMinutes(minutes + _stepMinutes)),
      ),
      rows: [
        SheetRow(
          title: hostName,
          initial: host?.initial ?? '?',
          sub:
              'proposed ${_weekdayShort[(plan.when.weekday - 1) % 7]} '
              '${_clockOf(plan.when)}',
          meta: 'waiting',
        ),
        SheetRow(
          title: 'You',
          initial: state.me?.initial ?? '?',
          sub:
              'offering ${_weekdayShort[(days[selected].weekday - 1) % 7]} '
              '${_clock(minutes)}',
          meta: 'offering',
          metaColor: Tokens.limeDeep,
        ),
      ],
      actions: [
        SheetAction(
          label: 'Send offer',
          onTap: () => state.proposeAlternateTime(_at(days[selected], minutes)),
        ),
        SheetAction(
          label: 'Back',
          kind: SheetActionKind.ghost,
          onTap: () => state.setMode(AppMode.invitation),
        ),
      ],
    );
  }
}

/// The plan went away while the counter-offer was open.
class _NoPlan extends StatelessWidget {
  const _NoPlan({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => SheetScaffold(
    label: 'offer another time',
    labelColor: Tokens.ink2,
    labelMark: Tokens.mut,
    title: 'Nothing to move',
    read: 'That plan is no longer on the table.',
    actions: [
      SheetAction(
        label: 'Close',
        kind: SheetActionKind.ghost,
        onTap: state.goHome,
      ),
    ],
  );
}
