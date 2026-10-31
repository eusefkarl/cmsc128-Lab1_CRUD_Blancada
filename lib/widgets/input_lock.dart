import 'package:flutter/material.dart';

/// Blocks input to a text field while an action runs.
///
/// Use this rather than toggling the field's readOnly or enabled. On web, either
/// toggle sends TextInput.updateConfig while the field's input connection is
/// open, and Flutter's engine throws a null check error if it has already
/// released the field's DOM element, which happens in accessibility mode.
class InputLock extends StatelessWidget {
  const InputLock({super.key, required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: locked,
    child: AbsorbPointer(absorbing: locked, child: child),
  );
}
