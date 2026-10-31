import 'package:firebase_core/firebase_core.dart';

/// Stands in for the real API key in builds that use the local emulators.
const String emulatorApiKey = 'emulator-only-placeholder-key';

/// Options for a build that uses the local emulators.
///
/// Firebase rejects the placeholder key, so a request that misses the emulator
/// cannot reach the real project. Auth also saves sessions per API key, so one
/// saved under the real key is not restored. Restoring it would validate it
/// against production during Firebase.initializeApp, after which the emulator
/// can no longer be connected, and the web plugin ignores that error.
FirebaseOptions emulatorFirebaseOptions(FirebaseOptions options) =>
    options.copyWith(apiKey: emulatorApiKey);
