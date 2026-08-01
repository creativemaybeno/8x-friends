import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

// Local design constants — fold into tokens.dart.
const _actionPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 7);

class InvitesSheet extends StatelessWidget {
  const InvitesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final myId = state.profile?.id;
    final invitations = [...state.invitations]
      ..sort((a, b) => (b.isPending ? 1 : 0) - (a.isPending ? 1 : 0));

    return SheetScaffold(
      label: 'SIGNALS FROM YOUR GRAPH',
      title: 'Signals from your graph',
      onClose: state.goHome,
      footer: Text(
        'Answering is always free. Starting something is the part that '
        'needs 8x Live.',
        style: Tokens.sheetProse,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in invitations)
            SheetRow(
              title: i.senderProfileId == myId ? 'You proposed' : i.senderName,
              meta: [
                i.place ?? 'somewhere',
                ?_dateLabel(i.proposedFor),
                i.senderProfileId == myId
                    ? 'WAITING FOR THEM'
                    : switch (i.myResponse) {
                        'pending' => 'AWAITING YOU',
                        'accepted' => 'ACCEPTED',
                        _ => 'DECLINED',
                      },
              ].join(' · '),
              dot: Tokens.cyan,
              trailing: i.isPending && i.senderProfileId != myId
                  ? GestureDetector(
                      onTap: () => state.acceptInvitation(i.id),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: _actionPadding,
                        decoration: BoxDecoration(
                          color: Tokens.cyan,
                          borderRadius: BorderRadius.circular(
                            Tokens.radiusButton,
                          ),
                        ),
                        child: Text(
                          'I’M IN',
                          style: Tokens.monoLabel.copyWith(
                            color: Tokens.onAccent,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          if (invitations.isEmpty) ...[
            Text('NOTHING WAITING', style: Tokens.monoLabel),
            const SizedBox(height: Tokens.gapXs),
            Text(
              'Quiet in here. When someone in your graph starts something, '
              'it lands right here.',
              style: Tokens.sheetProse,
            ),
          ],
        ],
      ),
    );
  }

  String? _dateLabel(DateTime? d) => d == null ? null : '${d.day}/${d.month}';
}
