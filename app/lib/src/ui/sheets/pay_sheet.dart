import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'propose_sheet.dart' show proposeDraft;
import 'sheet_scaffold.dart';

class PaySheet extends StatefulWidget {
  const PaySheet({super.key});

  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> {
  bool _busy = false;

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

  Future<void> _goLive(AppState state) async {
    if (_busy) return;
    setState(() => _busy = true);
    // `goLive` awaits the `is_subscriber` write, so the row is committed
    // before any propose is attempted — a local-only flag fails the RLS
    // insert policy on `invitations`.
    await state.goLive();
    if (!mounted) return;
    // If the write failed we are still free; proposing now would bounce us
    // straight back into this paywall.
    if (!state.isSubscriber) {
      setState(() => _busy = false);
      return;
    }
    // Resume the interrupted proposal. Take a copy and clear first so a
    // second tap cannot send it twice.
    final recipients = proposeDraft.recipients.toList();
    final place = proposeDraft.place;
    final when = proposeDraft.dateFrom(state.now);
    proposeDraft.clear();
    if (recipients.isNotEmpty) {
      await state.propose(
        recipientProfileIds: recipients,
        place: place.isEmpty ? null : place,
        proposedFor: when,
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return SheetScaffold(
      label: '8X LIVE',
      title: 'Your graph is yours for free. Reaching into it is the paid part.',
      onClose: state.goHome,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetButton(
            label: _busy ? 'GOING LIVE…' : 'GO LIVE — €4 / MONTH',
            onTap: _busy ? null : () => _goLive(state),
          ),
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
