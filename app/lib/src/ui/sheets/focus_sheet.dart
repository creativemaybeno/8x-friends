/// The focused person.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

/// Missing from tokens.dart — the 3 px signal bar and its track.
const double _signalBarHeight = 3.0;
const double _signalBarRadius = 2.0;

class FocusSheet extends StatelessWidget {
  const FocusSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final person = state.personById(state.focusedPersonId ?? '');
    if (person == null) return const SizedBox.shrink();

    final decay = state.decay;
    final days = decay.daysOf(person.id);
    final signal = decay.signalOf(person.id);
    final d = decay.decayOf(person.id);

    final known = <Person>[
      for (final r in state.relationships)
        if (r.touches(person.id)) ?state.personById(r.other(person.id) ?? ''),
    ]..removeWhere((p) => p.isMe);

    final other = known.isEmpty ? null : known.first.name;
    final line = d > kRingAmberAbove
        ? 'It’s been a while since ${person.name}. The thread is coming apart '
              '— one message would fix it.'
        : d > kLinkFragmentsAbove && other != null
        ? 'You and ${person.name} are drifting a little. You could bring '
              '$other along.'
        : 'You and ${person.name} are in good rhythm right now.';

    return SheetScaffold(
      label: Contexts.label(person.context),
      title: person.name,
      subtitle: line,
      onClose: state.goHome,
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(
              label: 'WE MET UP',
              onTap: () {
                state.clearSelection();
                state.toggleSelected(person.id);
                state.setMode(AppMode.log);
              },
            ),
          ),
          const SizedBox(width: Tokens.gapS),
          Expanded(
            child: SheetButton(
              label: 'BUILD A GROUP AROUND THEM',
              onTap: () {
                state.assembleGroupFrom(person);
                state.setMode(AppMode.group);
              },
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(person.name, style: Tokens.personNameLarge),
          const SizedBox(height: Tokens.gapM),
          Row(
            children: [
              Expanded(
                child: _Stat(caption: 'LAST TOGETHER', value: agoLabel(days)),
              ),
              const SizedBox(width: Tokens.gapS),
              Expanded(
                child: _Stat(
                  caption: 'BIRTHDAY',
                  value: person.birthdayDay == null
                      ? '—'
                      : '${person.birthdayDay}/${person.birthdayMonth}',
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.gapM),
          Row(
            children: [
              Expanded(child: Text('SIGNAL STRENGTH', style: Tokens.monoLabel)),
              Text('$signal%', style: Tokens.monoStat),
            ],
          ),
          const SizedBox(height: Tokens.gapXs),
          ClipRRect(
            borderRadius: BorderRadius.circular(_signalBarRadius),
            child: LinearProgressIndicator(
              value: signal / 100,
              minHeight: _signalBarHeight,
              backgroundColor: Tokens.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                Tokens.nodeRing(person.context, d),
              ),
            ),
          ),
          const SizedBox(height: Tokens.gapL),
          Text('SHARED HISTORY', style: Tokens.monoLabel),
          const SizedBox(height: Tokens.gapS),
          for (final k in known)
            SheetRow(
              title: 'also knows ${k.name}',
              meta: agoLabel(decay.daysOf(k.id)),
              dot: Tokens.contextColor(k.context),
              onTap: () => state.focusPerson(k.id),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Tokens.gapS),
      decoration: BoxDecoration(
        border: Border.all(color: Tokens.borderColor, width: Tokens.hairline),
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: Tokens.monoLabel),
          const SizedBox(height: Tokens.gapXs),
          Text(value, style: Tokens.personName),
        ],
      ),
    );
  }
}
