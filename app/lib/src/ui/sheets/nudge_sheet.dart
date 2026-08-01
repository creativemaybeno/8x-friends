/// The graph pulling at you. The one surface amber belongs on.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

class NudgeSheet extends StatelessWidget {
  const NudgeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final nudges = state.nudges;

    return SheetScaffold(
      label: 'THE GRAPH IS PULLING AT YOU',
      title: nudges.isEmpty
          ? 'Nothing is fading right now.'
          : 'It’s been ${durationLabel(nudges.first.days)} since '
                '${nudges.first.person.name}.',
      accent: Tokens.amber,
      onClose: state.goHome,
      footer: SheetButton(
        label: 'SEE THEM ALL AT ONCE',
        accent: Tokens.amber,
        onTap: nudges.isEmpty
            ? null
            : () {
                state.assembleGroupFrom(nudges.first.person);
                state.setMode(AppMode.group);
              },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final n in nudges)
            SheetRow(
              title: n.person.name,
              meta: Contexts.label(n.person.context),
              dot: Tokens.contextColor(n.person.context),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    n.days >= kNeverMetDays ? '∞' : '${n.days.floor()}d',
                    style: Tokens.monoStat.copyWith(color: Tokens.amber),
                  ),
                  const SizedBox(width: Tokens.gapS),
                  GestureDetector(
                    onTap: () {
                      state.clearSelection();
                      state.toggleSelected(n.person.id);
                      state.setMode(AppMode.log);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.gapS,
                        vertical: Tokens.gapXs,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Tokens.amber,
                          width: Tokens.hairline,
                        ),
                        borderRadius: BorderRadius.circular(Tokens.radiusChip),
                      ),
                      child: Text(
                        'WE MET UP',
                        style: Tokens.monoLabel.copyWith(color: Tokens.amber),
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () => state.focusPerson(n.person.id),
            ),
        ],
      ),
    );
  }
}
