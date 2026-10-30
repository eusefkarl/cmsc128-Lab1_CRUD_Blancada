/// Messages for Firebase Auth error codes that read the same on every screen.
///
/// Returns null for codes a screen words for its own context, such as a
/// wrong password at login versus during a profile change.
String? sharedAuthErrorMessage(String code) => switch (code) {
  'invalid-email' => 'Enter a valid email address.',
  'too-many-requests' => 'Too many attempts. Wait a while, then try again.',
  'network-request-failed' =>
    'The request could not reach the server. Check your connection.',
  _ => null,
};
