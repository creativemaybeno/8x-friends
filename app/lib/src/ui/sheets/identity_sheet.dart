/// The first sheet of every launch: which of the two demo phones is this one.
library;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import 'sheet_scaffold.dart';

/// Two rows, one choice. No close action — the app cannot start without it.
class IdentitySheet extends StatefulWidget {
  const IdentitySheet({super.key});

  @override
  State<IdentitySheet> createState() => _IdentitySheetState();
}

class _IdentitySheetState extends State<IdentitySheet> {
  /// Set the moment a row is tapped, so the choice reads as made while the
  /// sheet slides away and a second tap cannot land.
  Who? _chosen;

  void _choose(AppState state, Who who) {
    if (_chosen != null) return;
    setState(() => _chosen = who);
    state.chooseWho(who);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return SheetScaffold(
      label: 'this phone',
      title: 'Who is holding this phone?',
      read: 'Two demo accounts, two devices, one shared graph.',
      rows: [
        SheetRow(
          initial: 'C',
          title: 'Calvin',
          sub: '9 in his circle',
          meta: _chosen == Who.calvin ? 'joining' : 'pick',
          selected: _chosen == Who.calvin,
          onTap: () => _choose(state, Who.calvin),
        ),
        SheetRow(
          initial: 'Y',
          title: 'Yassie',
          sub: '8 in hers',
          meta: _chosen == Who.yassie ? 'joining' : 'pick',
          selected: _chosen == Who.yassie,
          onTap: () => _choose(state, Who.yassie),
        ),
      ],
    );
  }
}
