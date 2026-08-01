/// The assembler: five people, one table.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

class GroupSheet extends StatelessWidget {
  const GroupSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final decay = state.decay;
    final group = state.group;

    final names = group.map((p) => p.name).toList();
    final title = names.isEmpty
        ? 'Nobody to assemble yet'
        : names.length == 1
        ? names.first
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';

    var quietest = 0.0;
    for (final p in group) {
      final d = decay.daysOf(p.id);
      if (d > quietest) quietest = d;
    }

    final ids = group.map((p) => p.id).toSet();
    int knowsCount(Person p) => state.relationships
        .where((r) => r.touches(p.id) && ids.contains(r.other(p.id)))
        .length;

    return SheetScaffold(
      label: 'ASSEMBLED FROM THE GRAPH',
      title: title,
      subtitle: group.isEmpty
          ? null
          : 'Everyone already knows someone else here. The quietest of them '
                'hasn’t seen you in ${durationLabel(quietest)} — one table '
                'fixes five threads.',
      onClose: state.goHome,
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(
              label: 'RESHUFFLE',
              onTap: () => state.assembleGroupFrom(null),
            ),
          ),
          const SizedBox(width: Tokens.gapS),
          Expanded(
            child: SheetButton(
              label: 'LOG THIS',
              onTap: group.isEmpty
                  ? null
                  : () {
                      state.clearSelection();
                      for (final p in group) {
                        state.toggleSelected(p.id);
                      }
                      state.setMode(AppMode.log);
                    },
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in group)
            SheetRow(
              title: p.name,
              meta:
                  'knows ${knowsCount(p)} of them · '
                  '${agoLabel(decay.daysOf(p.id))}',
              dot: Tokens.contextColor(p.context),
              onTap: () => state.assembleGroupFrom(p),
            ),
        ],
      ),
    );
  }
}
