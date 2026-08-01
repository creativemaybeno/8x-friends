import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'propose_sheet.dart' show proposeDraft;
import 'sheet_scaffold.dart';

class PaySheet extends StatelessWidget {
  const PaySheet({super.key});

  static const _free = [
    'Your whole graph',
    'Logging meet-ups',
    'Reach & comparisons',
    'Merging friends’ graphs',
    'Answering invitations',
  ];

  static const _live = [
    'Everything free, plus',
    'Propose a meet-up',
    'Assemble & ping a group',
    'Nudge a fading link',
    'See who answered',
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    Future<void> goLive() async {
      await state.goLive();
      if (proposeDraft.isEmpty) return;
      await state.propose(
        recipientProfileIds: proposeDraft.recipients.toList(),
        place: proposeDraft.place,
        proposedFor: proposeDraft.dateFrom(state.now),
      );
      proposeDraft.clear();
    }

    return SheetScaffold(
      label: '8X LIVE',
      title: 'Your graph is yours for free. Reaching into it is the paid part.',
      onClose: state.goHome,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetButton(label: 'GO LIVE — €4 / MONTH', onTap: goLive),
          const SizedBox(height: Tokens.gapS),
          Center(
            child: Text(
              'Your graph never leaves your phone. Only the invitation does.',
              textAlign: TextAlign.center,
              style: Tokens.monoTiny,
            ),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Column(caption: 'OFFLINE · FREE', lines: _free),
          const SizedBox(width: Tokens.gapM),
          _Column(caption: 'LIVE · €4 / MONTH', lines: _live, accent: true),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.caption,
    required this.lines,
    this.accent = false,
  });

  final String caption;
  final List<String> lines;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: accent ? Tokens.monoLabelBright : Tokens.monoLabel,
          ),
          const SizedBox(height: Tokens.gapS),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.gapXs),
              child: Text(line, style: Tokens.sheetProse),
            ),
        ],
      ),
    );
  }
}
