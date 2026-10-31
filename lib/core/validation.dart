// Input rules shared by forms and services.
//
// firestore.rules enforces its own copy of these checks on the server, so
// update both when changing a rule here.

import 'limits.dart';

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final RegExp _accountUidPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// Firebase Auth's minimum password length.
const int minPasswordLength = 6;

bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

bool isValidAccountUid(String value) =>
    _accountUidPattern.hasMatch(value.trim());

const String invalidListNameMessage =
    'Enter a group name of 1 to $maxListNameLength characters.';

bool isValidListName(String value) {
  final cleaned = value.trim();
  return cleaned.isNotEmpty && cleaned.length <= maxListNameLength;
}
