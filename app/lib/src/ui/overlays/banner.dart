/// The in-app notification banner: an OS-style card that drops in from the top.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';

/// iOS banner proportions. Geometry only — every colour and text style is a
/// token.
const double _inset = 14.0;
const double _minHeight = 72.0;
const double _padH = 12.0;
const double _padTop = 12.0;
const double _padBottom = 14.0;
const double _iconSize = 34.0;
const double _iconRadius = 10.0;
const double _iconGlyph = 13.0;
const double _timeNudge = 3.0;
const double _titleGap = 3.0;
const double _grabberWidth = 34.0;
const double _grabberHeight = 3.0;
const double _grabberInset = 5.0;
const double _grabberRadius = 2.0;
const double _shadowAlpha = 0.55;
const double _shadowBlur = 26.0;
const double _shadowOffsetY = 10.0;

/// Where the card waits between notifications: fully clear of the notch.
const Offset _hidden = Offset(0, -1.4);

/// Slides down whenever `state.banner` is set, and leaves on a tap, a swipe,
/// or by itself after [Tokens.bannerDwell].
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
  /// The card keeps rendering its last content while it slides back out.
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
        child: IgnorePointer(
          ignoring: live == null,
          child: AnimatedSlide(
            offset: live == null ? _hidden : Offset.zero,
            duration: Tokens.bannerDuration,
            curve: Tokens.bannerCurve,
            child: AnimatedOpacity(
              opacity: live == null ? 0 : 1,
              duration: Tokens.bannerDuration,
              curve: Tokens.bannerCurve,
              child: shown == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.all(_inset),
                      child: _BannerCard(
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
    const radius = BorderRadius.all(Radius.circular(Tokens.radiusCard * 1.4));
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (_) => onDismiss(),
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < 0) onDismiss();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Tokens.void_.withValues(alpha: _shadowAlpha),
              blurRadius: _shadowBlur,
              offset: const Offset(0, _shadowOffsetY),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: Tokens.sheetBlur,
              sigmaY: Tokens.sheetBlur,
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: _minHeight),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Tokens.sheetTop, Tokens.sheetBottom],
                ),
                borderRadius: radius,
                border: Border.all(
                  color: Tokens.borderColor,
                  width: Tokens.hairline,
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _padH,
                      _padTop,
                      _padH,
                      _padBottom,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _AppTile(),
                        const SizedBox(width: Tokens.gapS),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                style: Tokens.bannerTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: _titleGap),
                              Text(
                                notification.body,
                                style: Tokens.bannerBody,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Tokens.gapS),
                        Padding(
                          padding: const EdgeInsets.only(top: _timeNudge),
                          child: Text('NOW', style: Tokens.monoLabelDim),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: _grabberInset,
                    child: Center(child: _Grabber()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 34x34 "app icon" every OS banner leads with.
class _AppTile extends StatelessWidget {
  const _AppTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _iconSize,
      height: _iconSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Tokens.borderColor,
        borderRadius: BorderRadius.circular(_iconRadius),
        border: Border.all(
          color: Tokens.borderColorStrong,
          width: Tokens.hairline,
        ),
      ),
      child: Text(
        '8x',
        style: Tokens.monoLabelBright.copyWith(fontSize: _iconGlyph),
      ),
    );
  }
}

/// The small pull bar that tells a thumb the card can be swiped away.
class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _grabberWidth,
      height: _grabberHeight,
      decoration: BoxDecoration(
        color: Tokens.borderColorStrong,
        borderRadius: BorderRadius.circular(_grabberRadius),
      ),
    );
  }
}
