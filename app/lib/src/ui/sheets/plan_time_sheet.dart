/// Picking a time: the host's preset offer and the guest's counter-offer.
library;

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

const _hourTonight = 20;
const _hourEvening = 19;
const _hourAfternoon = 13;

/// Index of `SATURDAY 7 PM` — the time the host opens on.
const _saturdayPick = 2;

/// Index of `SUNDAY 1 PM` — the time a counter-offer opens on.
const _sundayPick = 3;

/// The optional places a plan can carry. Sentence case: a human wrote them.
const _places = <String>['A bar', 'Dinner', 'A walk', 'Climbing'];

DateTime _dayAt(DateTime now, int daysAhead, int hour) =>
    DateTime(now.year, now.month, now.day + daysAhead, hour);

DateTime _nextWeekdayAt(DateTime now, int weekday, int hour) {
  final ahead = (weekday - now.weekday + 7) % 7;
  final when = _dayAt(now, ahead, hour);
  return when.isAfter(now) ? when : _dayAt(now, ahead + 7, hour);
}

/// The four times both sheets offer, resolved against [now].
///
/// Every returned `DateTime` is strictly after [now].
List<(String, DateTime)> planPresets(DateTime now) {
  final tonight = _dayAt(now, 0, _hourTonight);
  return [
    (
      'TONIGHT 8 PM',
      tonight.isAfter(now) ? tonight : _dayAt(now, 1, _hourTonight),
    ),
    ('TOMORROW 7 PM', _dayAt(now, 1, _hourEvening)),
    ('SATURDAY 7 PM', _nextWeekdayAt(now, DateTime.saturday, _hourEvening)),
    ('SUNDAY 1 PM', _nextWeekdayAt(now, DateTime.sunday, _hourAfternoon)),
  ];
}

Widget _sectionLabel(String label) => Text(label, style: Tokens.monoLabelDim);

Widget _chips(List<Widget> children) =>
    Wrap(spacing: Tokens.gapS, runSpacing: Tokens.gapS, children: children);

/// The host picking when to see someone.
class PlanTimeSheet extends StatefulWidget {
  const PlanTimeSheet({super.key});

  @override
  State<PlanTimeSheet> createState() => _PlanTimeSheetState();
}

class _PlanTimeSheetState extends State<PlanTimeSheet> {
  int _pick = _saturdayPick;
  String? _place;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final presets = planPresets(state.now);
    final withId = state.focusedPersonId;
    final name = withId == null ? null : state.personById(withId)?.name;
    final when = presets[_pick].$2;

    return SheetScaffold(
      label: 'PLAN SOMETHING',
      title: 'When works?',
      subtitle: name == null
          ? 'Pick a time. They can accept or suggest another.'
          : 'Pick a time. $name can accept or suggest another.',
      accent: Tokens.violet,
      onClose: state.goHome,
      footer: SheetButton(
        label: 'SEND INVITATION',
        accent: Tokens.violet,
        onTap: withId == null
            ? null
            : () => state.proposePlan(
                withPersonId: withId,
                when: when,
                place: _place,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('WHEN'),
          const SizedBox(height: Tokens.gapS),
          _chips([
            for (var i = 0; i < presets.length; i++)
              SheetChip(
                label: presets[i].$1,
                selected: i == _pick,
                accent: Tokens.violet,
                onTap: () => setState(() => _pick = i),
              ),
          ]),
          const SizedBox(height: Tokens.gapL),
          _sectionLabel('WHERE · OPTIONAL'),
          const SizedBox(height: Tokens.gapS),
          _chips([
            for (final place in _places)
              SheetChip(
                label: place,
                selected: place == _place,
                accent: Tokens.violet,
                onTap: () =>
                    setState(() => _place = place == _place ? null : place),
              ),
          ]),
        ],
      ),
    );
  }
}

/// The guest offering the host a different time.
class ProposeTimeSheet extends StatefulWidget {
  const ProposeTimeSheet({super.key});

  @override
  State<ProposeTimeSheet> createState() => _ProposeTimeSheetState();
}

class _ProposeTimeSheetState extends State<ProposeTimeSheet> {
  int _pick = _sundayPick;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final presets = planPresets(state.now);
    final plan = state.plan;
    final host = plan == null ? null : state.personById(plan.hostPersonId);
    final when = presets[_pick].$2;

    return SheetScaffold(
      label: 'ANOTHER TIME',
      title: 'Suggest a different time',
      subtitle: host == null || state.isMe(host.id)
          ? 'Everyone in the plan will see the new time.'
          : '${host.name} will see your suggestion.',
      accent: Tokens.violet,
      onClose: state.goHome,
      footer: SheetButton(
        label: 'SEND SUGGESTION',
        accent: Tokens.violet,
        onTap: () => state.proposeAlternateTime(when),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('WHEN INSTEAD'),
          const SizedBox(height: Tokens.gapS),
          _chips([
            for (var i = 0; i < presets.length; i++)
              SheetChip(
                label: presets[i].$1,
                selected: i == _pick,
                accent: Tokens.violet,
                onTap: () => setState(() => _pick = i),
              ),
          ]),
          const SizedBox(height: Tokens.gapM),
          Text(
            'Nothing is cancelled. They can take the new time or keep '
            'the old one.',
            style: Tokens.sheetProse,
          ),
        ],
      ),
    );
  }
}
