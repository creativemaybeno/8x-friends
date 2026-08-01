/// The consent step: asking an indirect connection to become a direct one.
library;

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

/// The one screen where the product explains itself.
///
/// A connection request is the only way the graph grows, so this sheet says
/// out loud what is shared and what is not. Nothing happens until the other
/// person says yes.
class ConnectSheet extends StatelessWidget {
  const ConnectSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final person = state.personById(state.focusedPersonId ?? '');

    if (person == null) {
      return SheetScaffold(
        label: 'connection request',
        title: 'Nobody is selected.',
        read: 'Tap someone in the graph first.',
        actions: [
          SheetAction(
            label: 'Close',
            kind: SheetActionKind.ghost,
            onTap: state.goHome,
          ),
        ],
      );
    }

    final mutual = state.mutualFor(person.id);
    final pending = state.isConnectionPending(person.id);

    return SheetScaffold(
      label: 'connection request',
      labelMark: Tokens.mut,
      labelRight: 'needs consent',
      subject: SheetSubject(
        initial: person.initial,
        name: person.name,
        meta: mutual == null
            ? 'not connected'
            : 'through ${mutual.name.toLowerCase()}',
        hollow: true,
      ),
      title: 'Ask ${person.name} to connect?',
      read:
          'They decide. Nothing about your graph is shared while they '
          'think about it.',
      rows: [
        const SheetRow(title: 'They will see', meta: 'your name and initial'),
        SheetRow(
          title: 'They will see',
          meta: mutual == null
              ? 'that you have someone in common'
              : 'that you both know ${mutual.name}',
        ),
        const SheetRow(
          title: 'They will not see',
          meta: 'health, location, people',
          dimmed: true,
        ),
      ],
      note:
          'Sharing a table did not make you friends. Only a request can — '
          'and only meeting builds it.',
      actions: [
        SheetAction(
          label: 'Request connection',
          onTap: pending ? null : () => state.requestConnection(person.id),
        ),
        SheetAction(
          label: 'Close',
          kind: SheetActionKind.ghost,
          onTap: state.goHome,
        ),
      ],
      foot: pending ? 'asked ${person.name.toLowerCase()}. they decide.' : null,
    );
  }
}
