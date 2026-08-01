/// Growing a plan sideways: the guest brings people from their own circle.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

/// The selection tick that sits at the end of every row.
const double _tickSize = 20.0;
const double _tickGlyph = 13.0;

/// Adding friends to a plan you have just accepted.
///
/// The host does not get a veto — that is the point of this sheet, and the
/// subtitle says so out loud.
class CircleSheet extends StatefulWidget {
  const CircleSheet({super.key});

  @override
  State<CircleSheet> createState() => _CircleSheetState();
}

class _CircleSheetState extends State<CircleSheet> {
  final Set<String> _selected = <String>{};

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _add(AppState state, List<String> ids) {
    for (final id in ids) {
      state.addToPlan(id);
    }
    state.goHome();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final plan = state.plan;
    final host = plan == null ? null : state.personById(plan.hostPersonId);
    final invited = plan?.attendees.keys.toSet() ?? const <String>{};

    final candidates = [
      for (final p in state.directPeople)
        if (!invited.contains(p.id)) p,
    ];
    final chosen = [
      for (final p in candidates)
        if (_selected.contains(p.id)) p.id,
    ];

    return SheetScaffold(
      label: 'YOUR CIRCLE',
      title: 'Bring someone along',
      subtitle: host == null || state.isMe(host.id)
          ? 'Add friends from your circle. Nobody needs to approve.'
          : 'Add friends from your circle. ${host.name} does not need '
                'to approve.',
      accent: Tokens.violet,
      onClose: state.goHome,
      footer: Row(
        children: [
          Expanded(
            child: SheetGhostButton(
              label: 'NOT NOW',
              accent: Tokens.violet,
              onTap: state.goHome,
            ),
          ),
          const SizedBox(width: Tokens.gapS),
          Expanded(
            flex: 2,
            child: SheetButton(
              label: 'ADD TO THE PLAN',
              accent: Tokens.violet,
              onTap: chosen.isEmpty ? null : () => _add(state, chosen),
            ),
          ),
        ],
      ),
      child: candidates.isEmpty
          ? Text(
              'Everyone you have met is already coming.',
              style: Tokens.sheetProse,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in candidates)
                  SheetRow(
                    title: p.name,
                    meta: agoLabel(state.decay.daysOf(p.id)),
                    dot: Tokens.contextColor(p.context),
                    selected: _selected.contains(p.id),
                    onTap: () => _toggle(p.id),
                    trailing: _Tick(selected: _selected.contains(p.id)),
                  ),
              ],
            ),
    );
  }
}

/// A quiet circle that fills violet once the person is coming along.
class _Tick extends StatelessWidget {
  const _Tick({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _tickSize,
      height: _tickSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Tokens.violet : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Tokens.violet : Tokens.borderColorStrong,
          width: Tokens.hairline,
        ),
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: _tickGlyph,
              color: Tokens.onAccent,
            )
          : null,
    );
  }
}
