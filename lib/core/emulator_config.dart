import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Stands in for the real API key in builds that use the local emulators.
const String emulatorApiKey = 'emulator-only-placeholder-key';

/// Where this build reaches the local emulators. An Android emulator sees its
/// host computer at 10.0.2.2, because 127.0.0.1 is the emulator itself.
String get emulatorHost =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    ? '10.0.2.2'
    : '127.0.0.1';

/// Options for a build that uses the local emulators.
///
/// Firebase rejects the placeholder key, so a request that misses the emulator
/// cannot reach the real project. Auth also saves sessions per API key, so one
/// saved under the real key is not restored. Restoring it would validate it
/// against production during Firebase.initializeApp, after which the emulator
/// can no longer be connected, and the web plugin ignores that error.
FirebaseOptions emulatorFirebaseOptions(FirebaseOptions options) =>
    options.copyWith(apiKey: emulatorApiKey);
