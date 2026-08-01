import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'name_sheet.dart' show KeyboardInset, SheetField;
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

  /// Friends whose graph we have asked for. A friend can legitimately share
  /// zero people, so ghost presence alone cannot tell us "already pulled in".
  final _pulled = <String>{};
  final _pulling = <String>{};
  bool _redeeming = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pull(AppState state, String profileId) async {
    if (_pulling.contains(profileId)) return;
    setState(() => _pulling.add(profileId));
    await state.mergeFriendGraph(profileId);
    if (!mounted) return;
    setState(() {
      _pulling.remove(profileId);
      _pulled.add(profileId);
    });
  }

  Future<void> _redeem(AppState state) async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 6 || _redeeming) return;
    setState(() => _redeeming = true);
    FocusManager.instance.primaryFocus?.unfocus();
    await state.redeemInviteCode(code);
    if (!mounted) return;
    _code.clear();
    setState(() => _redeeming = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final friends = state.friends;
    final ghosts = state.ghosts;
    final anon = ghosts.where((g) => !g.isNamed).length;
    final shared = friends.where((f) => _pulled.contains(f.profileId)).length;
    final canRedeem = _code.text.trim().length >= 6 && !_redeeming;

    return KeyboardInset(
      child: SheetScaffold(
        label: 'HOW FAR YOUR GRAPH REACHES',
        title: 'How far your graph reaches',
        subtitle: friends.isEmpty
            ? 'Nobody you know is on 8x yet. Swap codes below and your graphs '
                  'start touching.'
            : '$shared of ${friends.length} friends on 8x have shared their '
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
            for (final f in friends)
              _FriendRow(
                friend: f,
                ghosts: ghosts,
                merged: _pulled.contains(f.profileId),
                busy: _pulling.contains(f.profileId),
                onPull: () => _pull(state, f.profileId),
              ),
            if (friends.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.gapS),
                child: Text('NO FRIENDS LINKED YET', style: Tokens.monoLabel),
              ),
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
              onSubmitted: (_) => _redeem(state),
            ),
            const SizedBox(height: Tokens.gapS),
            SheetButton(
              label: _redeeming ? 'REDEEMING…' : 'REDEEM',
              onTap: canRedeem ? () => _redeem(state) : null,
            ),
          ],
        ),
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
  const _FriendRow({
    required this.friend,
    required this.ghosts,
    required this.merged,
    required this.busy,
    required this.onPull,
  });

  final FriendSummary friend;
  final List<Ghost> ghosts;
  final bool merged;
  final bool busy;
  final VoidCallback onPull;

  @override
  Widget build(BuildContext context) {
    final mine = ghosts.where((g) => g.ownerProfileId == friend.profileId);
    final named = [for (final g in mine) ?g.name];
    final anon = (friend.peopleCount - named.length).clamp(0, 1 << 30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetRow(
          title: friend.displayName,
          meta: '${friend.peopleCount} people · reaches ${friend.reach}',
          dot: Tokens.cyan,
          onTap: merged || busy ? null : onPull,
          trailing: GestureDetector(
            onTap: merged || busy ? null : onPull,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: _pillPadding,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Tokens.borderColorStrong,
                  width: Tokens.hairline,
                ),
                borderRadius: BorderRadius.circular(Tokens.radiusButton),
              ),
              child: Text(
                busy
                    ? 'PULLING…'
                    : merged
                    ? 'MERGED'
                    : 'PULL IN',
                style: merged || busy
                    ? Tokens.monoLabel
                    : Tokens.monoLabelBright,
              ),
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
