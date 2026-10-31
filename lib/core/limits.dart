// Product limits shared across the app.
//
// firestore.rules enforces the same values on the server, so update both
// when changing a limit here.

/// Maximum members in one collaborative list, owner included.
const int maxListMembers = 20;

/// Maximum length of a collaborative list's name.
const int maxListNameLength = 100;

/// Maximum length of the display name other accounts can read.
const int maxPublicNameLength = 256;

/// How long a deleted task can be restored with Undo.
const Duration undoDeleteWindow = Duration(seconds: 5);
