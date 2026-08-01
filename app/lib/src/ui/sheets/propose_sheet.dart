import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'name_sheet.dart' show KeyboardInset, SheetField;
import 'sheet_scaffold.dart';

/// Survives the sheet being swapped out for the paywall, so `GO LIVE` can
/// resume the interrupted proposal.
class ProposeDraft {
  final recipients = <String>{};
  String place = 'Bar Estrela';
  String? dateLabel;

  bool get isEmpty => recipients.isEmpty;

  /// Never throws: an unknown label just means "no date".
  DateTime? dateFrom(DateTime now) {
    if (dateLabel == null) return null;
    for (final d in proposeDates(now)) {
      if (d.$1 == dateLabel) return d.$2;
    }
    return null;
  }

  void clear() {
    recipients.clear();
    dateLabel = null;
  }
}

final proposeDraft = ProposeDraft();

/// Date chips, in the copy's order.
List<(String, DateTime)> proposeDates(DateTime now) {
  DateTime next(int weekday) =>
      now.add(Duration(days: (weekday - now.weekday) % 7 + 1));
  return [
    ('Tomorrow', now.add(const Duration(days: 1))),
    ('Thursday', next(DateTime.thursday)),
    ('Sunday', next(DateTime.sunday)),
    ('Next week', now.add(const Duration(days: 7))),
  ];
}

class ProposeSheet extends StatefulWidget {
  const ProposeSheet({super.key});

  @override
  State<ProposeSheet> createState() => _ProposeSheetState();
}

class _ProposeSheetState extends State<ProposeSheet> {
  late final _place = TextEditingController(text: proposeDraft.place);

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final friends = state.friends;
    // Drop selections for friends that are no longer in the list — proposing
    // to an id the server does not link us to is an RLS error.
    proposeDraft.recipients.retainWhere(
      (id) => friends.any((f) => f.profileId == id),
    );
    final names = friends
        .where((f) => proposeDraft.recipients.contains(f.profileId))
        .map((f) => f.displayName)
        .toList();

    Future<void> send() async {
      proposeDraft.place = _place.text.trim();
      FocusManager.instance.primaryFocus?.unfocus();
      if (!state.isSubscriber) {
        // Straight to the paywall with the selection INTACT — `GO LIVE`
        // resumes from `proposeDraft`.
        state.setMode(AppMode.pay);
        return;
      }
      final recipients = proposeDraft.recipients.toList();
      await state.propose(
        recipientProfileIds: recipients,
        place: proposeDraft.place.isEmpty ? null : proposeDraft.place,
        proposedFor: proposeDraft.dateFrom(state.now),
      );
      proposeDraft.clear();
    }

    return KeyboardInset(
      child: SheetScaffold(
        label: 'PROPOSE A MEET-UP',
        title: names.isEmpty ? 'nobody yet' : names.join(', '),
        onClose: state.goHome,
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetButton(
              label: 'SEND IT DOWN THE LINKS',
              onTap: proposeDraft.isEmpty ? null : send,
            ),
            const SizedBox(height: Tokens.gapS),
            Center(
              child: Text(
                'THEY ANSWER INSIDE THEIR OWN GRAPH',
                style: Tokens.monoTiny,
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final f in friends)
              SheetRow(
                title: f.displayName,
                meta: '${f.peopleCount} people',
                dot: Tokens.cyan,
                selected: proposeDraft.recipients.contains(f.profileId),
                onTap: () => setState(() {
                  if (!proposeDraft.recipients.remove(f.profileId)) {
                    proposeDraft.recipients.add(f.profileId);
                  }
                }),
              ),
            if (friends.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.gapS),
                child: Text(
                  'Nobody to propose to yet. Swap invite codes in REACH first.',
                  style: Tokens.sheetProse,
                ),
              ),
            const SizedBox(height: Tokens.gapS),
            Wrap(
              spacing: Tokens.gapXs,
              runSpacing: Tokens.gapXs,
              children: [
                for (final (label, _) in proposeDates(state.now))
                  SheetChip(
                    label: label,
                    selected: proposeDraft.dateLabel == label,
                    onTap: () => setState(
                      () => proposeDraft.dateLabel =
                          proposeDraft.dateLabel == label ? null : label,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Tokens.gapS),
            SheetField(controller: _place, hint: 'Where?'),
          ],
        ),
      ),
    );
  }
}
