/// The in-app push notification: the OS banner, rebuilt in paper.
library;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';

// Geometry from the design (`Phone8x` 2d). Colour and type are tokens.
const double _insetH = 12.0;
const double _insetTop = 6.0;
const EdgeInsets _padding = EdgeInsets.fromLTRB(20, 18, 20, 20);
const double _markSize = 24.0;
const double _markGlyph = 9.0;
const double _markGap = 10.0;
const double _appRowGap = 11.0;
const double _titleGap = 6.0;

/// `p8drop`: the card falls this far while it fades in.
const double _drop = 16.0;

const double _shadowAlpha = 0.4;
const double _shadowBlur = 32.0;
const double _shadowSpread = -14.0;
const double _shadowY = 14.0;

/// Drops in whenever `state.banner` is set, and leaves on a tap, a swipe, or
/// by itself after [Tokens.bannerDwell].
///
/// Must be the last-but-one layer of the shell `Stack` so it covers the
/// sheets — a notification that arrives behind the interface is not a
/// notification.
class NotificationBannerOverlay extends StatefulWidget {
  const NotificationBannerOverlay({super.key});

  @override
  State<NotificationBannerOverlay> createState() =>
      _NotificationBannerOverlayState();
}

class _NotificationBannerOverlayState extends State<NotificationBannerOverlay> {
  /// The card keeps rendering its last content while it fades back out.
  AppNotification? _last;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final live = state.banner;
    if (live != null) _last = live;
    final shown = live ?? _last;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_insetH, _insetTop, _insetH, 0),
          child: IgnorePointer(
            ignoring: live == null,
            child: AnimatedOpacity(
              opacity: live == null ? 0 : 1,
              duration: Tokens.bannerDuration,
              curve: Tokens.bannerCurve,
              child: AnimatedContainer(
                duration: Tokens.bannerDuration,
                curve: Tokens.bannerCurve,
                transform: Matrix4.translationValues(
                  0,
                  live == null ? -_drop : 0,
                  0,
                ),
                child: shown == null
                    ? const SizedBox.shrink()
                    : _BannerCard(
                        notification: shown,
                        onTap: state.tapBanner,
                        onDismiss: state.dismissBanner,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (_) => onDismiss(),
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < 0) onDismiss();
      },
      child: Container(
        padding: _padding,
        decoration: BoxDecoration(
          color: Tokens.card,
          borderRadius: BorderRadius.circular(Tokens.radiusNotif),
          border: Border.all(color: Tokens.hairInk05, width: Tokens.hairline),
          boxShadow: [
            BoxShadow(
              color: Tokens.ink.withValues(alpha: _shadowAlpha),
              blurRadius: _shadowBlur,
              spreadRadius: _shadowSpread,
              offset: const Offset(0, _shadowY),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _AppMark(),
                const SizedBox(width: _markGap),
                Text('friends', style: Tokens.notifApp),
                const Spacer(),
                Text('now', style: Tokens.notifWhen),
              ],
            ),
            const SizedBox(height: _appRowGap),
            Text(
              notification.title,
              style: Tokens.notifTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: _titleGap),
            Text(
              notification.body,
              style: Tokens.notifBody,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// The lime app mark every banner leads with.
class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _markSize,
      height: _markSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Tokens.lime,
        shape: BoxShape.circle,
      ),
      child: Text(
        '8xF',
        style: Tokens.wordmarkMark.copyWith(fontSize: _markGlyph),
      ),
    );
  }
}
