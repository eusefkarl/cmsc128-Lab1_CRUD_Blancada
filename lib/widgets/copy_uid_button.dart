import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copies an account UID, which others need to add this account to a group.
class CopyUidButton extends StatelessWidget {
  const CopyUidButton({super.key, required this.uid});

  final String uid;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      await Clipboard.setData(ClipboardData(text: uid));
      message = 'Account UID copied.';
    } on PlatformException {
      message = 'Could not copy. Select the UID and copy it manually.';
    }
    if (!messenger.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => _copy(context),
    icon: const Icon(Icons.copy),
    label: const Text('Copy UID'),
  );
}
