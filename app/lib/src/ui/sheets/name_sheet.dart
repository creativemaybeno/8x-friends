import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

// Local design constants — fold into tokens.dart.
const kFieldPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 13);

/// Lifts a sheet clear of the software keyboard. The shell pins every sheet to
/// `bottom: 0` and does not react to `viewInsets`, so without this the keyboard
/// covers the field the user is typing into.
class KeyboardInset extends StatelessWidget {
  const KeyboardInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 120),
    curve: Curves.easeOut,
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: child,
  );
}

/// The shared text field every sheet of mine uses.
class SheetField extends StatelessWidget {
  const SheetField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLength,
    this.uppercase = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int? maxLength;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: kFieldPadding,
      decoration: BoxDecoration(
        color: Tokens.borderColor,
        border: Border.all(
          color: Tokens.borderColorStrong,
          width: Tokens.hairline,
        ),
        borderRadius: BorderRadius.circular(Tokens.radiusButton),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        maxLength: maxLength,
        cursorColor: Tokens.cyan,
        textCapitalization: uppercase
            ? TextCapitalization.characters
            : TextCapitalization.words,
        style: Tokens.input,
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          border: InputBorder.none,
          hintText: hint,
          hintStyle: Tokens.input.copyWith(color: Tokens.faint),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}

class NameSheet extends StatefulWidget {
  const NameSheet({super.key});

  @override
  State<NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<NameSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState state) async {
    final name = _controller.text.trim();
    if (name.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    // Drop the keyboard first so the graph is not left behind it.
    FocusManager.instance.primaryFocus?.unfocus();
    await state.setDisplayName(name);
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final name = _controller.text.trim();
    final canSubmit = name.isNotEmpty && !_submitting;

    return KeyboardInset(
      child: SheetScaffold(
        label: '8X FRIENDS',
        title: 'what should we call you?',
        footer: SheetButton(
          label: _submitting ? 'SAVING…' : 'CONTINUE',
          onTap: canSubmit ? () => _submit(state) : null,
        ),
        child: SheetField(
          controller: _controller,
          hint: 'Your name',
          autofocus: true,
          maxLength: 40,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(state),
        ),
      ),
    );
  }
}
