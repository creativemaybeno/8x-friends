/// The first sheet of every launch: which of the two demo phones is this one.
library;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

// Local geometry for the two account cards.
const double _avatarSize = 66.0;
const double _cardGap = 12.0;
const EdgeInsets _cardPadding = EdgeInsets.symmetric(
  horizontal: Tokens.gapS,
  vertical: Tokens.gapL,
);
const double _pressedScale = 0.98;
const double _restingOpacity = 1.0;
const double _steppedBackOpacity = 0.32;

/// Two cards, one choice. No close button — the app cannot start without it.
class IdentitySheet extends StatefulWidget {
  const IdentitySheet({super.key});

  @override
  State<IdentitySheet> createState() => _IdentitySheetState();
}

class _IdentitySheetState extends State<IdentitySheet> {
  /// Set the moment a card is tapped, so the choice reads as made while the
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
      label: '8X FRIENDS',
      title: 'Who is holding this phone?',
      subtitle: 'Two demo accounts, two phones, one shared graph.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _AccountCard(
              who: Who.calvin,
              caption: 'ACCOUNT A',
              chosen: _chosen == Who.calvin,
              steppedBack: _chosen == Who.yassie,
              onTap: () => _choose(state, Who.calvin),
            ),
          ),
          const SizedBox(width: _cardGap),
          Expanded(
            child: _AccountCard(
              who: Who.yassie,
              caption: 'ACCOUNT B',
              chosen: _chosen == Who.yassie,
              steppedBack: _chosen == Who.calvin,
              onTap: () => _choose(state, Who.yassie),
            ),
          ),
        ],
      ),
    );
  }
}

/// One big tappable card: initial, name, mono caption.
class _AccountCard extends StatefulWidget {
  const _AccountCard({
    required this.who,
    required this.caption,
    required this.chosen,
    required this.steppedBack,
    required this.onTap,
  });

  final Who who;
  final String caption;

  /// This card is the one that was picked.
  final bool chosen;

  /// The other card was picked; this one recedes.
  final bool steppedBack;
  final VoidCallback onTap;

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final lit = _pressed || widget.chosen;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      behavior: HitTestBehavior.opaque,
      child: Transform.scale(
        scale: _pressed ? _pressedScale : 1.0,
        child: Opacity(
          opacity: widget.steppedBack ? _steppedBackOpacity : _restingOpacity,
          child: Container(
            padding: _cardPadding,
            decoration: BoxDecoration(
              color: lit ? Tokens.borderColor : Colors.transparent,
              border: Border.all(
                color: lit ? Tokens.borderColorStrong : Tokens.borderColor,
                width: Tokens.hairline,
              ),
              borderRadius: BorderRadius.circular(Tokens.radiusCard),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _avatarSize,
                  height: _avatarSize,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Tokens.borderColor,
                  ),
                  foregroundDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: lit ? Tokens.cyan : Tokens.borderColorStrong,
                      width: Tokens.hairline,
                    ),
                  ),
                  child: Text(
                    widget.who.label.substring(0, 1),
                    style: Tokens.personNameLarge.copyWith(
                      color: lit ? Tokens.cyanBright : Tokens.cyan,
                    ),
                  ),
                ),
                const SizedBox(height: Tokens.gapM),
                Text(
                  widget.who.label,
                  style: Tokens.personName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Tokens.gapXs),
                Text(
                  widget.caption,
                  style: lit ? Tokens.monoLabelBright : Tokens.monoLabelDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
