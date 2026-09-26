# Do It Now!

A Flutter task-management app with a game HUD-inspired interface. Tasks support due dates, due times, priorities, categories, completion state, sorting, filtering, undo deletion, and Firestore persistence.

## Tech Stack

- **Flutter and Dart**: cross-platform UI and application logic.
- **Firebase Core**: initializes the Firebase project for supported platforms.
- **Firebase Authentication**: email/password accounts and optional Google sign-in.
- **Cloud Firestore**: stores task documents and streams changes in real time.
- **Google Fonts**: provides the Exo 2 typeface used throughout the HUD interface.

Firestore was chosen instead of an in-memory list because tasks must survive browser refreshes and app restarts. Its realtime stream keeps the task list synchronized after create, edit, completion, and delete operations. Authentication and `ownerId` prevent users from accessing another user's tasks.

## Firebase Setup

The project is configured for the Firebase project in `lib/firebase_options.dart` and currently supports Web, Windows, and macOS.

Before running the app:

1. Open the Firebase Console and select the configured project.
2. Create or enable **Cloud Firestore**.
3. Enable **Authentication -> Sign-in method -> Email/Password**. Enable **Google** if Google sign-in is required.
4. Add the deployed app's domain to **Authentication -> Settings -> Authorized domains**.
5. Review the password reset and email change templates under **Authentication -> Templates**.
6. Publish the rules in `firestore.rules`.

From a machine with the Firebase CLI authenticated, deploy the rules with:

```powershell
firebase deploy --only firestore:rules
```

The rules file is intentionally committed. Firestore rules are access-control configuration, not secret credentials. Do not commit Firebase service-account private keys or Admin SDK credentials.

## Run Locally

### Requirements

- Flutter SDK compatible with Dart `^3.13.2`
- A configured Firebase project
- Chrome for Web, or a supported desktop Flutter platform
- Firebase CLI only if deploying rules from the command line

From the project directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

For Windows desktop:

```powershell
flutter run -d windows
```

The app uses Firebase Authentication for login and stores the current UID, email, and display name in the owner's `users/{uid}` Firestore profile document. Firebase Authentication is authoritative for account credentials and profile identity; Firestore mirrors the active values for app data. Passwords are never written to Firestore.

### Profile and password flows

- Display name updates are written to Firebase Authentication and mirrored to Firestore.
- Email changes require the current password and reauthentication. Firebase sends a verification link; the current address stays active until the new address is verified. The app reloads Firebase Authentication and synchronizes the verified email to Firestore on startup, app resume, and when the profile page opens or resumes.
- Firebase Authentication enforces email uniqueness. The profile displays a specific duplicate-email error.
- Direct password changes require the current password, a new password, and confirmation. Passwords are managed only by Firebase Authentication.
- Password recovery uses Firebase's hosted email action handler. Links use single-use, expiring action codes; Firebase applies the new password when the user completes the hosted flow. The app does not receive or store reset codes.
- The reset screen uses neutral feedback so it does not reveal whether an email is registered.

For an email change, check the **new** address, including its spam/junk folder. The old address remains active until the link is opened. If the app confirms the request but no message arrives, check **Authentication -> Templates** in Firebase Console and the project's [email sending limits](https://firebase.google.com/docs/auth/limits). When using the Authentication emulator, no real email is delivered; its verification URL appears in the terminal running `firebase emulators:start`.

To return a completed password reset or email verification to the deployed app, build with its root URL as the continue URL:

```powershell
flutter run -d chrome --dart-define=FIREBASE_AUTH_CONTINUE_URL=https://YOUR_DEPLOYED_APP_DOMAIN/
```

Replace the example with the actual deployed app URL and add that domain to Firebase Authentication's **Authorized domains**. If this setting is omitted, Firebase's default hosted action handler still processes the email action, but it may not return the user to the app afterward. No custom email action handler is currently required.

### Local Firebase emulators

`firebase.json` configures the Authentication and Firestore emulators. Start them with:

```powershell
firebase emulators:start --only auth,firestore --project doitnow-c26f9 --export-on-exit=.firebase-emulator-data
```

Run the app against emulators in a separate terminal:

```powershell
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

The emulator flag is opt-in. Without it, the app uses the Firebase project configured by FlutterFire. To restore saved emulator data after a restart, add `--import=.firebase-emulator-data` to the start command; the export flag writes changes back when the emulators stop.

## Data Model

Each document in the Firestore `tasks` collection contains:

```text
ownerId   string       authenticated Firebase user ID
title     string       required task title
details   string       optional details
createdAt timestamp    creation timestamp
dueDate   timestamp?   optional due date
dueTime   int?         minutes after midnight
priority  string       low, medium, or high
category  string       school, personal, or others
isDone    boolean      completion state
```

## CRUD Data Operations

The app uses `FirestoreTaskRepository` in `lib/services/task_repository.dart` rather than REST endpoints.

### Read tasks in real time

```dart
final stream = FirebaseFirestore.instance
		.collection('tasks')
		.where('ownerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
		.snapshots();
```

The repository maps each document into a `Task` and sorts the stream result for display.

### Create a task

```dart
final task = Task(
	title: 'Review notes',
	details: 'Prepare for the quiz',
	createdAt: DateTime.now(),
	priority: TaskPriority.medium,
	category: TaskCategory.school,
);

await repository.createTask(task);
```

The repository adds the authenticated user's `ownerId` and creates a Firestore document ID.

### Update a task

```dart
task.isDone = true;
task.priority = TaskPriority.high;
await repository.updateTask(task);
```

The same update operation is used for editing fields and marking a task complete.

### Delete a task

```dart
await repository.deleteTask(task);
```

The UI first asks for confirmation, hides the task temporarily, and provides a five-second Undo action before calling this operation.

## UI Features

- Create and edit task title, details, due date, due time, priority, and category.
- Delete confirmation with delayed deletion and Undo.
- Checkbox completion with strikethrough and visual status styling.
- Sort by date added, due date, priority, or tag.
- Filter by priority or category.
- Baby-blue game HUD theme with Exo 2 typography.
- Red high-priority, yellow medium-priority, and green low-priority indicators.

## Screenshots

Add the application screenshots to a `screenshots/` folder in the project root and use the following layout:

### Main Task Dashboard

![Main task dashboard](screenshots/task-dashboard.png)

### Create or Edit Task

![Create or edit task dialog](screenshots/task-form.png)

### Task Priority and Category States

![Task priority and category states](screenshots/task-priority-category.png)

### Sorting and Filtering

![Task sorting and filtering controls](screenshots/task-filters.png)

## Testing

Run all checks with:

```powershell
flutter analyze
flutter test
```

Widget tests use a fake repository, so they do not require network access or a live Firestore database. They cover serialization, task editing, deletion confirmation, Undo, completion updates, filtering, and tag ordering.

Run the Firebase-backed account and Firestore-rules checks in isolated emulators:

```powershell
firebase emulators:exec --only auth,firestore --project doitnow-c26f9 "node --test scripts/account_compliance.test.mjs"
```

These checks create throwaway accounts in the local Authentication emulator, read one-time email action codes from its local endpoint, and verify changes against Authentication and the deployed Firestore rules. They do not use real accounts or production data. The Flutter `integration_test` suite is also available for native targets; Flutter's integration runner does not support Chrome.
