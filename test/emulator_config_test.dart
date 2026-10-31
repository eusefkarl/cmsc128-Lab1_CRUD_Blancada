import 'package:do_it_now/core/emulator_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const real = FirebaseOptions(
    apiKey: 'AIzaRealProjectKey',
    appId: '1:350109597967:web:abc',
    messagingSenderId: '350109597967',
    projectId: 'doitnow-c26f9',
    authDomain: 'doitnow-c26f9.firebaseapp.com',
  );

  test('emulator builds replace the real API key', () {
    final options = emulatorFirebaseOptions(real);
    expect(options.apiKey, emulatorApiKey);
    expect(options.apiKey, isNot(real.apiKey));
  });

  test('emulator builds keep the project the emulators run under', () {
    final options = emulatorFirebaseOptions(real);
    expect(options.projectId, real.projectId);
    expect(options.appId, real.appId);
    expect(options.authDomain, real.authDomain);
  });
}
