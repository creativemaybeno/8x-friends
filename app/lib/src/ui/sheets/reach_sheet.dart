import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'name_sheet.dart' show SheetField;
import 'sheet_scaffold.dart';

// Local design constants — fold into tokens.dart.
const _tilePadding = EdgeInsets.symmetric(horizontal: 11, vertical: 10);
const _pillPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 6);

class ReachSheet extends StatefulWidget {
  const ReachSheet({super.key});

  @override
  State<ReachSheet> createState() => _ReachSheetState();
}

class _ReachSheetState extends State<ReachSheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final friends = state.friends;
    final ghosts = state.ghosts;
    final anon = ghosts.where((g) => !g.isNamed).length;
    final shared = friends
        .where((f) => ghosts.any((g) => g.ownerProfileId == f.profileId))
        .length;

    return SheetScaffold(
      label: 'HOW FAR YOUR GRAPH REACHES',
      title: 'How far your graph reaches',
      subtitle:
          '$shared of ${friends.length} friends on 8x have shared their '
          'graph. $anon more people are one tap away.',
      onClose: state.goHome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Tile(caption: 'YOUR PEOPLE', value: '${state.people.length}'),
              const SizedBox(width: Tokens.gapXs),
              _Tile(caption: 'ANONYMOUS FoF', value: '$anon'),
              const SizedBox(width: Tokens.gapXs),
              _Tile(
                caption: 'IN REACH',
                value: '${state.people.length + ghosts.length}',
              ),
            ],
          ),
          const SizedBox(height: Tokens.gapM),
          for (final f in friends) _FriendRow(friend: f, ghosts: ghosts),
          const SizedBox(height: Tokens.gapM),
          Text('YOUR INVITE CODE', style: Tokens.monoLabel),
          const SizedBox(height: Tokens.gapXs),
          Text(
            state.profile?.inviteCode ?? '······',
            style: Tokens.personNameLarge,
          ),
          const SizedBox(height: Tokens.gapM),
          SheetField(
            controller: _code,
            hint: 'THEIR CODE',
            maxLength: 6,
            uppercase: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Tokens.gapS),
          SheetButton(
            label: 'REDEEM',
            onTap: _code.text.trim().length < 6
                ? null
                : () => state.redeemInviteCode(_code.text.trim()),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: _tilePadding,
        decoration: BoxDecoration(
          border: Border.all(
            color: Tokens.borderColorStrong,
            width: Tokens.hairline,
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caption, style: Tokens.monoTiny),
            const SizedBox(height: Tokens.gapXs),
            Text(value, style: Tokens.personNameLarge),
          ],
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.ghosts});

  final FriendSummary friend;
  final List<Ghost> ghosts;

  @override
  Widget build(BuildContext context) {
    final mine = ghosts.where((g) => g.ownerProfileId == friend.profileId);
    final named = mine.where((g) => g.isNamed).map((g) => g.name!).toList();
    final merged = mine.isNotEmpty;
    final anon = friend.peopleCount - named.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetRow(
          title: friend.displayName,
          meta: '${friend.peopleCount} people · reaches ${friend.reach}',
          dot: Tokens.cyan,
          trailing: Container(
            padding: _pillPadding,
            decoration: BoxDecoration(
              border: Border.all(
                color: Tokens.borderColorStrong,
                width: Tokens.hairline,
              ),
              borderRadius: BorderRadius.circular(Tokens.radiusButton),
            ),
            child: Text(
              merged ? 'MERGED' : 'PULL IN',
              style: merged ? Tokens.monoLabel : Tokens.monoLabelBright,
            ),
          ),
        ),
        if (merged)
          Padding(
            padding: const EdgeInsets.only(
              left: Tokens.gapS,
              bottom: Tokens.gapS,
            ),
            child: Text(
              named.isEmpty
                  ? '$anon anonymous'
                  : '${named.join(', ')} · $anon anonymous',
              style: Tokens.monoTiny,
            ),
          ),
      ],
    );
  }
}
