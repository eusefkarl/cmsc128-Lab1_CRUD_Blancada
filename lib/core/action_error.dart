/// A message for a failed action that is safe to show to the user.
///
/// Services raise [StateError] and [FormatException] with user-facing text.
/// Anything else is an unexpected failure whose details stay out of the UI.
String actionErrorMessage(Object error) => switch (error) {
  StateError(:final message) => message,
  FormatException(:final message) => message,
  _ => 'Could not complete the request. Try again.',
};
