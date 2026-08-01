/// Drop a new node into the graph, then wire it up.
library;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

class AddSheet extends StatefulWidget {
  const AddSheet({super.key});

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  final _name = TextEditingController();
  final _knownBy = <String>{};
  String? _context;
  bool _wiring = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final name = _name.text.trim();
    final people = <Person>[
      for (final p in state.people)
        if (!p.isMe) p,
    ];

    return SheetScaffold(
      label: _wiring
          ? 'NOW TAP WHO ALREADY KNOWS THEM'
          : 'DROP A NEW NODE INTO THE GRAPH',
      title: _wiring ? name : 'Their name',
      subtitle: _wiring
          ? '${_knownBy.length} '
                '${_knownBy.length == 1 ? 'connection' : 'connections'} so far. '
                'Every tap springs a new tie into place.'
          : 'They will appear at the centre, unattached. Then you wire them '
                'into the people they already know.',
      onClose: state.goHome,
      footer: SheetButton(
        label: _wiring ? 'DONE' : 'DROP THE NODE',
        onTap: name.isEmpty
            ? null
            : !_wiring
            ? () => setState(() => _wiring = true)
            : () async {
                final ties = _knownBy.length;
                await state.addPerson(
                  name: name,
                  context: _context,
                  knownByPersonIds: _knownBy.toList(),
                );
                state.showToast('$name is in the graph with $ties ties.');
                state.goHome();
              },
      ),
      child: _wiring
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in people)
                  SheetRow(
                    title: p.name,
                    meta: Contexts.label(p.context),
                    dot: Tokens.contextColor(p.context),
                    selected: _knownBy.contains(p.id),
                    onTap: () => setState(() {
                      if (!_knownBy.remove(p.id)) _knownBy.add(p.id);
                    }),
                  ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _name,
                  autofocus: true,
                  style: Tokens.input,
                  cursorColor: Tokens.cyan,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Their name',
                    hintStyle: Tokens.input.copyWith(color: Tokens.faint),
                    filled: true,
                    fillColor: Tokens.borderColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Tokens.radiusButton),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: Tokens.gapM),
                Wrap(
                  spacing: Tokens.gapXs,
                  runSpacing: Tokens.gapXs,
                  children: [
                    for (final c in Contexts.all)
                      SheetChip(
                        label: Contexts.label(c),
                        selected: _context == c,
                        accent: Tokens.contextColor(c),
                        onTap: () =>
                            setState(() => _context = _context == c ? null : c),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
