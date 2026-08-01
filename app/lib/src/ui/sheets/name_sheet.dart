import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

// Local design constants — fold into tokens.dart.
const kFieldPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 13);

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final name = _controller.text.trim();
    void submit() {
      if (name.isEmpty) return;
      state.setDisplayName(name);
    }

    return SheetScaffold(
      label: '8X FRIENDS',
      title: 'what should we call you?',
      footer: SheetButton(
        label: 'CONTINUE',
        onTap: name.isEmpty ? null : submit,
      ),
      child: SheetField(
        controller: _controller,
        hint: 'Your name',
        autofocus: true,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => submit(),
      ),
    );
  }
}
