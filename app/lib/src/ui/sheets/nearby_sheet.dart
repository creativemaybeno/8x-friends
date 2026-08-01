/// The permission that guards the nearby view. Screen S22.
///
/// Asked once, in plain words, with the limits stated before the yes — not a
/// system prompt with a product decision hidden behind it.
library;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

class NearbySheet extends StatelessWidget {
  const NearbySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return SheetScaffold(
      label: 'nearby view',
      labelMark: Tokens.mut,
      labelColor: Tokens.ink2,
      labelRight: 'needs permission',
      title: 'Who could you see tonight?',
      read:
          'The nearby view sorts your people by rough distance, for the plan '
          'you make on a free evening.',
      rows: const [
        SheetRow(title: 'Precision', meta: 'nearby / city / far'),
        SheetRow(title: 'Updates', meta: 'when they open the app'),
        SheetRow(title: 'Live location', meta: 'never', dimmed: true),
        SheetRow(title: 'History kept', meta: 'none', dimmed: true),
      ],
      note:
          'You appear to your connections at the same coarseness. Turn it off '
          'any time and the view disappears for both sides.',
      actions: [
        SheetAction(
          label: 'Allow',
          onTap: () {
            state.grantLocation();
            state.setView(GraphView.distance);
            state.goHome();
          },
        ),
        SheetAction(
          label: 'Not now',
          kind: SheetActionKind.ghost,
          onTap: state.goHome,
        ),
      ],
    );
  }
}
