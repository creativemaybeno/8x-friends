/// The shared bottom-sheet container every mode's sheet sits in.
///
/// Contract file — written by the orchestrator so every sheet agent compiles
/// against the same API. Sheets never own their own chrome.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../theme/tokens.dart';

/// Geometry and opacity that only these primitives need.
const double _ghostFillAlpha = 0.07;
const double _ghostBorderAlpha = 0.45;
const double _disabledOpacity = 0.35;
const double _barHeight = 3.0;
const double _barRadius = 2.0;
const double _avatarFillAlpha = 0.16;
const double _avatarDimmed = 0.4;
const double _avatarInitialScale = 0.38;
const double _avatarInitialHeight = 1.0;

/// A bottom sheet that rises from `translateY(112%)` to 0 and never covers
/// more than about half the graph.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
    this.onClose,
    this.footer,
    required this.child,
    this.accent = Tokens.cyan,
  });

  /// Mono, uppercase — the machine naming the mode. e.g. `LOG A MEET-UP`.
  final String label;

  /// Sans — the app talking to you.
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  /// Pinned below the scrollable body, e.g. the confirm button.
  final Widget? footer;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        MediaQuery.sizeOf(context).height * Tokens.sheetMaxHeightFraction;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(Tokens.radiusSheet),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: Tokens.sheetBlur,
          sigmaY: Tokens.sheetBlur,
        ),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Tokens.sheetTop, Tokens.sheetBottom],
            ),
            border: Border(
              top: BorderSide(
                color: Tokens.borderColor,
                width: Tokens.hairline,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Padding(
                padding: Tokens.sheetPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            label.toUpperCase(),
                            style: Tokens.monoLabelBright.copyWith(
                              color: accent,
                            ),
                          ),
                        ),
                        if (onClose != null)
                          GestureDetector(
                            onTap: onClose,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: Tokens.gapM,
                                bottom: Tokens.gapXs,
                              ),
                              child: Text('CLOSE', style: Tokens.monoLabel),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Tokens.gapS),
                    Text(title, style: Tokens.sheetTitle),
                    if (subtitle != null) ...[
                      const SizedBox(height: Tokens.gapXs),
                      Text(subtitle!, style: Tokens.sheetProse),
                    ],
                    const SizedBox(height: Tokens.gapM),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: child,
                      ),
                    ),
                    if (footer != null) ...[
                      const SizedBox(height: Tokens.gapM),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one primary action button. Filled with [accent], mono-ish sans label.
class SheetButton extends StatelessWidget {
  const SheetButton({
    super.key,
    required this.label,
    this.onTap,
    this.accent = Tokens.cyan,
  });

  final String label;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          height: Tokens.buttonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(Tokens.radiusButton),
          ),
          child: Text(label, style: Tokens.buttonLabel),
        ),
      ),
    );
  }
}

/// The quieter second action: outline only, same height as [SheetButton].
///
/// Use it beside a [SheetButton] when the sheet offers a real alternative
/// ("another time", "not now") rather than a way out.
class SheetGhostButton extends StatelessWidget {
  const SheetGhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.accent = Tokens.cyan,
  });

  final String label;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : _disabledOpacity,
        child: Container(
          height: Tokens.buttonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: _ghostFillAlpha),
            border: Border.all(
              color: accent.withValues(alpha: _ghostBorderAlpha),
              width: Tokens.hairline,
            ),
            borderRadius: BorderRadius.circular(Tokens.radiusButton),
          ),
          child: Text(label, style: Tokens.buttonLabel.copyWith(color: accent)),
        ),
      ),
    );
  }
}

/// A pill. Used for when-chips, context chips, filters.
class SheetChip extends StatelessWidget {
  const SheetChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.accent = Tokens.cyan,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.gapM,
          vertical: Tokens.gapS,
        ),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          border: Border.all(
            color: selected ? accent : Tokens.borderColorStrong,
            width: Tokens.hairline,
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusChip),
        ),
        child: Text(
          label.toUpperCase(),
          style: selected
              ? Tokens.monoLabel.copyWith(color: Tokens.onAccent)
              : Tokens.monoLabel,
        ),
      ),
    );
  }
}

/// One selectable person row: name, mono meta line, selection tick.
class SheetRow extends StatelessWidget {
  const SheetRow({
    super.key,
    required this.title,
    this.meta,
    this.selected = false,
    this.onTap,
    this.dot,
    this.trailing,
  });

  final String title;
  final String? meta;
  final bool selected;
  final VoidCallback? onTap;

  /// Context colour dot on the left.
  final Color? dot;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: Tokens.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.gapS),
        margin: const EdgeInsets.only(bottom: Tokens.gapXs),
        decoration: BoxDecoration(
          color: selected ? Tokens.borderColor : Colors.transparent,
          border: Border.all(
            color: selected ? Tokens.borderColorStrong : Colors.transparent,
            width: Tokens.hairline,
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusCard),
        ),
        child: Row(
          children: [
            if (dot != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: Tokens.gapS),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Tokens.personName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta != null) ...[
                    const SizedBox(height: 2),
                    Text(meta!.toUpperCase(), style: Tokens.monoTiny),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// One fact in a bordered card: mono caption, sans value.
///
/// Sits happily inside an `Expanded` next to its siblings — the value is kept
/// to a single line so a row of stats never changes height.
class SheetStat extends StatelessWidget {
  const SheetStat({
    super.key,
    required this.caption,
    required this.value,
    this.accent,
  });

  /// Machine voice — uppercased here, so pass it however reads best.
  final String caption;

  /// Human voice. Short: a date, a duration, a word.
  final String value;

  /// Tints the value and the border when this stat is the one that matters.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tint = accent;
    return Container(
      padding: const EdgeInsets.all(Tokens.gapS),
      decoration: BoxDecoration(
        border: Border.all(
          color: tint == null
              ? Tokens.borderColor
              : tint.withValues(alpha: _ghostBorderAlpha),
          width: Tokens.hairline,
        ),
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption.toUpperCase(), style: Tokens.monoLabelDim),
          const SizedBox(height: Tokens.gapXs),
          Text(
            value,
            style: tint == null
                ? Tokens.statValue
                : Tokens.statValue.copyWith(color: tint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// How a relationship is doing, read as a percentage and a 3 px bar.
///
/// [decay] is 0 (just met) to 1 (gone). The bar shows what is left of the
/// relationship, tinted by [Tokens.healthColor].
class HealthBar extends StatelessWidget {
  const HealthBar({super.key, required this.decay});

  final double decay;

  @override
  Widget build(BuildContext context) {
    final d = decay.clamp(0.0, 1.0);
    final health = 1 - d;
    final colour = Tokens.healthColor(d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('RELATIONSHIP HEALTH', style: Tokens.monoLabel),
            ),
            Text(
              '${(health * 100).round()}%',
              style: Tokens.monoStat.copyWith(color: colour),
            ),
          ],
        ),
        const SizedBox(height: Tokens.gapXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(_barRadius),
          child: LinearProgressIndicator(
            value: health,
            minHeight: _barHeight,
            backgroundColor: Tokens.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(colour),
          ),
        ),
      ],
    );
  }
}

/// A person as a circle: their initial, in their context colour.
///
/// No photographs anywhere in this product — a name and a colour is all one
/// person is allowed to know about another before they connect. [dimmed] is
/// the pending look: still there, not yet certain.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.person,
    this.size = 40,
    this.dimmed = false,
  });

  final Person person;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colour = Tokens.contextColor(person.context);
    return Opacity(
      opacity: dimmed ? _avatarDimmed : 1,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colour.withValues(alpha: _avatarFillAlpha),
          shape: BoxShape.circle,
          border: Border.all(color: colour, width: Tokens.hairline),
        ),
        child: Text(
          person.initial,
          style: Tokens.personNameLarge.copyWith(
            fontSize: size * _avatarInitialScale,
            height: _avatarInitialHeight,
            color: colour,
          ),
        ),
      ),
    );
  }
}
