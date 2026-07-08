import 'package:flutter/material.dart';

import '../theme.dart';

/// Dialog con un campo di testo. Ritorna null se annullato.
Future<String?> promptText(
  BuildContext context, {
  required String heading,
  required String hint,
  String initial = '',
  String confirm = 'OK',
  String cancel = 'Annulla',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Palette.panel,
      title: Text(heading, style: display(size: 18)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: mono(size: 15),
        cursorColor: Palette.brass,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: mono(size: 14, color: Palette.muted),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Palette.brassDim)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Palette.brass)),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(cancel, style: mono(size: 14, color: Palette.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(confirm, style: mono(size: 14, color: Palette.brass)),
        ),
      ],
    ),
  );
}
