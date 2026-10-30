// Product limits shared across the app.
//
// firestore.rules enforces the same values on the server, so update both
// when changing a limit here.

/// Maximum members in one collaborative list, owner included.
const int maxListMembers = 20;

/// How long a deleted task can be restored with Undo.
const Duration undoDeleteWindow = Duration(seconds: 5);
