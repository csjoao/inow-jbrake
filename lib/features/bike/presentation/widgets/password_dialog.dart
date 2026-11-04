import 'package:flutter/material.dart';

/// Pede a senha de 6 dígitos da bike. Retorna `null` se cancelar.
Future<String?> showPasswordDialog(
  BuildContext context, {
  required String initial,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Senha da bike'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(hintText: '000000'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isNotEmpty) Navigator.pop(ctx, v);
          },
          child: const Text('Conectar'),
        ),
      ],
    ),
  );
}
