/// The v3 sheet kit.
///
/// One white card that rises from the bottom of the paper. Its blocks always
/// render in the same order and with the same rhythm, so every screen in the
/// product reads as the same object:
///
///     label -> subject -> signal -> title -> read -> chips -> picker
///     -> field -> rows -> note -> child -> actions -> foot
///
/// Contract file — written by the orchestrator so every sheet agent compiles
/// against the same API. Nothing here decides copy. Screens pass strings; this
/// file decides pixels.
library;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../theme/tokens.dart';

/// Vertical gap between sheet blocks.
const double _block = 22;

// ---------------------------------------------------------------------------
// Sub-parts
// ---------------------------------------------------------------------------

/// The person (or thing) a sheet is about: big name, mono meta, optional
/// right-hand statistic.
class SheetSubject {
  const SheetSubject({
    required this.initial,
    required this.name,
    this.meta,
    this.stat,
    this.statLabel,
    this.statColor,
    this.badgeDecay,
    this.hollow = false,
  });

  final String initial;
  final String name;
  final String? meta;
  final String? stat;
  final String? statLabel;
  final Color? statColor;

  /// Drives the badge treatment: a tie in trouble gets a clay outline
  /// instead of a solid ink disc.
  final double? badgeDecay;

  /// A person you are not connected to: outline only, no health.
  final bool hollow;
}

/// The pill-shaped read-only field (`where`, `who is coming`, ...).
class SheetField {
  const SheetField({
    required this.label,
    required this.value,
    this.color,
    this.caret = false,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? color;
  final bool caret;
  final VoidCallback? onTap;
}

/// One day in the day strip.
class SheetDay {
  const SheetDay({required this.weekday, required this.number});

  final String weekday;
  final String number;
}

/// The day + time picker.
class SheetPicker {
  const SheetPicker({
    required this.dayLabel,
    required this.days,
    required this.selected,
    required this.onSelect,
    this.time,
    this.timeHint,
    this.onEarlier,
    this.onLater,
  });

  final String dayLabel;
  final List<SheetDay> days;
  final int selected;
  final ValueChanged<int> onSelect;
  final String? time;
  final String? timeHint;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;
}

// ---------------------------------------------------------------------------
// The scaffold
// ---------------------------------------------------------------------------

class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.label,
    this.labelColor,
    this.labelMark,
    this.labelRight,
    this.subject,
    this.signal,
    this.signalColor,
    this.title,
    this.read,
    this.chips,
    this.picker,
    this.field,
    this.rows,
    this.note,
    this.actions,
    this.foot,
    this.child,
  });

  /// The mono eyebrow: lowercase, always present.
  final String label;
  final Color? labelColor;

  /// The 8px dot before the eyebrow. Null hides it.
  final Color? labelMark;
  final String? labelRight;

  final SheetSubject? subject;

  /// 0..1 — how much of the meter is filled.
  final double? signal;
  final Color? signalColor;

  final String? title;
  final String? read;
  final List<Widget>? chips;
  final SheetPicker? picker;
  final SheetField? field;
  final List<Widget>? rows;
  final String? note;
  final List<Widget>? actions;
  final String? foot;

  /// Anything a screen needs that the vocabulary above does not cover.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final blocks = <Widget>[
      _labelHeader(),
      if (subject != null) ...[
        _Subject(subject: subject!),
        const SizedBox(height: 20),
      ],
      if (signal != null) ...[
        _Signal(value: signal!, color: signalColor ?? Tokens.ink),
        const SizedBox(height: _block),
      ],
      if (title != null) ...[
        Text(title!, style: Tokens.sheetTitle),
        const SizedBox(height: 14),
      ],
      if (read != null) ...[
        Text(read!, style: Tokens.sheetRead),
        const SizedBox(height: _block),
      ],
      if (chips != null && chips!.isNotEmpty) ...[
        Wrap(spacing: 8, runSpacing: 8, children: chips!),
        const SizedBox(height: _block),
      ],
      if (picker != null) _Picker(picker: picker!),
      if (field != null) ...[
        _Field(field: field!),
        const SizedBox(height: _block),
      ],
      if (rows != null && rows!.isNotEmpty) ...[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows!.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              rows![i],
            ],
          ],
        ),
        const SizedBox(height: _block),
      ],
      if (note != null) ...[_Note(text: note!), const SizedBox(height: _block)],
      if (child != null) ...[child!, const SizedBox(height: _block)],
      if (actions != null && actions!.isNotEmpty)
        Row(
          children: [
            for (var i = 0; i < actions!.length; i++) ...[
              if (i > 0) const SizedBox(width: 9),
              Expanded(child: actions![i]),
            ],
          ],
        ),
      if (foot != null) ...[
        const SizedBox(height: 18),
        Center(child: Text(foot!, style: Tokens.footLine)),
      ],
    ];

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: media.size.height * Tokens.sheetMaxHeightFraction,
      ),
      decoration: const BoxDecoration(
        color: Tokens.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Tokens.radiusSheet),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x2314170F),
            blurRadius: 44,
            spreadRadius: -16,
            offset: Offset(0, -14),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          26,
          30,
          26,
          24 + media.padding.bottom.clamp(0.0, 22.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: blocks,
        ),
      ),
    );
  }

  Widget _labelHeader() => Padding(
    padding: const EdgeInsets.only(bottom: _block),
    child: Row(
      children: [
        if (labelMark != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: labelMark, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            label,
            style: Tokens.sheetLabel.copyWith(color: labelColor ?? Tokens.mut),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        if (labelRight != null)
          Text(labelRight!, style: Tokens.sheetLabelRight),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Blocks
// ---------------------------------------------------------------------------

class _Subject extends StatelessWidget {
  const _Subject({required this.subject});

  final SheetSubject subject;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Avatar(
          initial: subject.initial,
          decay: subject.badgeDecay,
          hollow: subject.hollow,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                subject.name,
                style: Tokens.subjectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subject.meta != null) ...[
                const SizedBox(height: 9),
                Text(subject.meta!, style: Tokens.subjectMeta),
              ],
            ],
          ),
        ),
        if (subject.stat != null) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                subject.stat!,
                style: Tokens.subjectStat.copyWith(
                  color: subject.statColor ?? Tokens.ink,
                ),
              ),
              if (subject.statLabel != null) ...[
                const SizedBox(height: 7),
                Text(subject.statLabel!, style: Tokens.subjectStatLabel),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: Container(
      height: 8,
      color: Tokens.hairInk09,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    decoration: BoxDecoration(
      color: Tokens.soft,
      borderRadius: BorderRadius.circular(Tokens.radiusCard),
    ),
    child: Text(text, style: Tokens.noteText),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.field});

  final SheetField field;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      decoration: BoxDecoration(
        color: Tokens.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Text(field.label, style: Tokens.fieldLabel),
          const SizedBox(width: 13),
          Flexible(
            child: Text(
              field.value,
              style: Tokens.fieldValue.copyWith(color: field.color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (field.caret) ...[
            const SizedBox(width: 3),
            Container(
              width: 2,
              height: 19,
              decoration: BoxDecoration(
                color: Tokens.ink,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
    if (field.onTap == null) return body;
    return GestureDetector(onTap: field.onTap, child: body);
  }
}

class _Picker extends StatelessWidget {
  const _Picker({required this.picker});

  final SheetPicker picker;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(picker.dayLabel, style: Tokens.pickerLabel),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < picker.days.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => picker.onSelect(i),
                  child: Container(
                    padding: const EdgeInsets.only(top: 11, bottom: 13),
                    decoration: BoxDecoration(
                      color: i == picker.selected ? Tokens.lime : Tokens.soft,
                      borderRadius: BorderRadius.circular(Tokens.radiusDay),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: 0.55,
                          child: Text(
                            picker.days[i].weekday,
                            style: Tokens.dayWeekday,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(picker.days[i].number, style: Tokens.dayNumber),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: _block),
        if (picker.time != null) ...[
          Text('time', style: Tokens.pickerLabel),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: Tokens.soft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(picker.time!, style: Tokens.timeValue),
                      if (picker.timeHint != null) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            picker.timeHint!,
                            style: Tokens.timeHint,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Stepper(glyph: '−', onTap: picker.onEarlier),
              const SizedBox(width: 8),
              _Stepper(glyph: '+', onTap: picker.onLater),
            ],
          ),
          const SizedBox(height: _block),
        ],
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.glyph, this.onTap});

  final String glyph;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Tokens.hairInk14, width: 1.5),
      ),
      child: Text(
        glyph,
        style: Tokens.sheetRead.copyWith(fontSize: 22, color: Tokens.ink2),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Leaves the screens compose with
// ---------------------------------------------------------------------------

/// A round initial. Solid ink normally; clay outline when the tie is in
/// trouble; grey outline when there is no tie at all.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initial,
    this.decay,
    this.hollow = false,
    this.size = 58,
  });

  /// Convenience for the common `Avatar.of(person)` call.
  factory Avatar.of(Person person, {double size = 58, double? decay}) =>
      Avatar(initial: person.initial, size: size, decay: decay);

  final String initial;
  final double? decay;
  final bool hollow;
  final double size;

  @override
  Widget build(BuildContext context) {
    final small = size <= 44;
    final ailing = !hollow && (decay ?? 0) > 0.5;
    final outlined = hollow || ailing;
    final tint = hollow ? Tokens.mut : (ailing ? Tokens.clay : Tokens.paper);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: outlined ? Colors.transparent : Tokens.ink,
        border: outlined
            ? Border.all(
                color: hollow ? Tokens.hairInk18 : Tokens.clay,
                width: 1.5,
              )
            : null,
      ),
      child: Text(
        initial,
        style: (small ? Tokens.badgeGlyphSmall : Tokens.badgeGlyph).copyWith(
          color: tint,
        ),
      ),
    );
  }
}

enum SheetActionKind { primary, ghost, dark }

/// A full-width action. Three kinds, no more.
class SheetAction extends StatelessWidget {
  const SheetAction({
    super.key,
    required this.label,
    this.onTap,
    this.kind = SheetActionKind.primary,
  });

  final String label;
  final VoidCallback? onTap;
  final SheetActionKind kind;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final (bg, fg, border) = switch (kind) {
      SheetActionKind.primary => (Tokens.lime, Tokens.ink, null),
      SheetActionKind.dark => (Tokens.ink, Tokens.paper, null),
      SheetActionKind.ghost => (
        Colors.transparent,
        Tokens.ink2,
        Border.all(color: Tokens.hairInk14, width: 1.5),
      ),
    };
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 19),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Tokens.actionLabel.copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}

/// Legacy name, mapped onto [SheetAction] so older call sites compile.
class SheetButton extends StatelessWidget {
  const SheetButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SheetAction(label: label, onTap: onTap);
}

/// Legacy name, mapped onto the ghost [SheetAction].
class SheetGhostButton extends StatelessWidget {
  const SheetGhostButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      SheetAction(label: label, onTap: onTap, kind: SheetActionKind.ghost);
}

/// A selectable pill.
class SheetChip extends StatelessWidget {
  const SheetChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
      decoration: BoxDecoration(
        color: selected ? Tokens.lime : Tokens.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Tokens.chipLabel.copyWith(
          color: selected ? Tokens.ink : Tokens.ink2,
        ),
      ),
    ),
  );
}

/// One line in a sheet's list: optional initial, a name, a mono value.
class SheetRow extends StatelessWidget {
  const SheetRow({
    super.key,
    required this.title,
    this.sub,
    this.meta,
    this.metaColor,
    this.initial,
    this.initialHollow = false,
    this.titleColor,
    this.flat = false,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
    this.trailing,
  });

  final String title;

  /// A second, quieter line under [title].
  final String? sub;

  /// The right-hand mono value.
  final String? meta;
  final Color? metaColor;

  /// When set, the row leads with a 36px avatar.
  final String? initial;
  final bool initialHollow;

  final Color? titleColor;

  /// No background — for rows that are pure information.
  final bool flat;

  /// Multi-select state: a lime ring around the row.
  final bool selected;

  /// A person who cannot be chosen.
  final bool dimmed;

  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: flat ? Colors.transparent : Tokens.rowSoft,
        borderRadius: BorderRadius.circular(Tokens.radiusRow),
        border: selected
            ? Border.all(color: Tokens.limeDeep, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          if (initial != null) ...[
            Avatar(initial: initial!, hollow: initialHollow, size: 36),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Tokens.rowLeft.copyWith(color: titleColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sub != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    sub!,
                    style: Tokens.rowSub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (meta != null) ...[
            const SizedBox(width: 12),
            Text(
              meta!,
              style: Tokens.rowRight.copyWith(color: metaColor),
              textAlign: TextAlign.right,
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    final faded = dimmed ? Opacity(opacity: 0.45, child: body) : body;
    if (onTap == null) return faded;
    return GestureDetector(onTap: onTap, child: faded);
  }
}

/// Legacy: a caption over a value.
class SheetStat extends StatelessWidget {
  const SheetStat({super.key, required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(caption, style: Tokens.sheetLabelRight),
      const SizedBox(height: 6),
      Text(value, style: Tokens.rowLeft),
    ],
  );
}

/// Legacy: the relationship-health meter.
class HealthBar extends StatelessWidget {
  const HealthBar({super.key, required this.decay});

  final double decay;

  @override
  Widget build(BuildContext context) =>
      _Signal(value: 1 - decay, color: Tokens.healthColor(decay));
}
