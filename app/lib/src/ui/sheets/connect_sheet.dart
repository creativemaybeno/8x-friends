/// The consent step: asking an indirect connection to become a direct one.
library;

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

/// One-off geometry: the portrait at the head of the sheet.
const double _avatarSize = 52.0;

/// The gap between the name and the mono line under it.
const double _nameGap = 5.0;

/// Breathing room around each hairline inside the consent card.
const double _consentGap = 14.0;

/// The one screen where the product explains itself.
///
/// A connection request is the only way the graph grows, so this sheet says
/// out loud what is shared, what is not, and what a new edge is worth. Nothing
/// happens until the other person says yes.
class ConnectSheet extends StatelessWidget {
  const ConnectSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final person = state.personById(state.focusedPersonId ?? '');
    if (person == null) return const SizedBox.shrink();

    final mutual = state.mutualFor(person.id);
    final pending = state.isConnectionPending(person.id);

    final through = mutual == null
        ? 'THROUGH A MUTUAL FRIEND'
        : 'THROUGH ${mutual.name.toUpperCase()}';

    final seen = mutual == null
        ? 'Your name, and that the two of you have a friend in common.'
        : 'Your name, and that you both know ${mutual.name}. That is all.';

    return SheetScaffold(
      label: 'CONNECTION REQUEST',
      title: 'Ask ${person.name} to connect?',
      subtitle: 'They decide. Nothing about you is shared until they accept.',
      onClose: state.goHome,
      footer: SheetButton(
        label: pending ? 'REQUEST SENT' : 'SEND REQUEST',
        onTap: pending ? null : () => state.requestConnection(person.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(person: person, size: _avatarSize, dimmed: true),
              const SizedBox(width: Tokens.gapM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: Tokens.personNameLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: _nameGap),
                    Text(through, style: Tokens.monoLabelBright),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.gapL),
          Container(
            padding: const EdgeInsets.all(Tokens.gapM),
            decoration: BoxDecoration(
              border: Border.all(
                color: Tokens.borderColor,
                width: Tokens.hairline,
              ),
              borderRadius: BorderRadius.circular(Tokens.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConsentLine(
                  caption: 'THEY WILL SEE',
                  body: seen,
                  accent: Tokens.cyan,
                ),
                const _ConsentRule(),
                const _ConsentLine(
                  caption: 'THEY WILL NOT SEE',
                  body:
                      'Your circle, your activity, or where you are. '
                      'Accepting opens one relationship, never your graph.',
                  accent: Tokens.faint,
                ),
                const _ConsentRule(),
                const _ConsentLine(
                  caption: 'MEETING IS WHAT COUNTS',
                  body:
                      'A new connection starts neutral. Time together is '
                      'what makes it strong.',
                  accent: Tokens.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.gapM),
          Text(
            pending
                ? 'WAITING FOR ${person.name.toUpperCase()} TO ANSWER'
                : 'YOU CAN ONLY ASK PEOPLE A FRIEND ALREADY KNOWS',
            style: Tokens.monoLabelDim,
          ),
        ],
      ),
    );
  }
}

/// One promise: a mono caption stating the rule, a sans line explaining it.
class _ConsentLine extends StatelessWidget {
  const _ConsentLine({
    required this.caption,
    required this.body,
    required this.accent,
  });

  final String caption;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: Tokens.monoLabelBright.copyWith(color: accent)),
        const SizedBox(height: Tokens.gapXs),
        Text(body, style: Tokens.sheetProse),
      ],
    );
  }
}

/// The hairline that keeps the three promises from running together.
class _ConsentRule extends StatelessWidget {
  const _ConsentRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Tokens.hairline,
      margin: const EdgeInsets.symmetric(vertical: _consentGap),
      color: Tokens.borderColor,
    );
  }
}
