import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Asks before unsaved work is lost. Pops true to discard and false to stay.
class DiscardChangesDialog extends StatelessWidget {
  const DiscardChangesDialog({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Discard unsaved changes?'),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Stay'),
      ),
      FilledButton(
        style: AppButtonStyles.danger,
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Discard'),
      ),
    ],
  );
}
