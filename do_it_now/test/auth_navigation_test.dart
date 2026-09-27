import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:do_it_now/main.dart';

void main() {
  testWidgets('external sign-out clears a pushed protected route', (
    tester,
  ) async {
    final sessionIds = StreamController<String?>.broadcast();
    addTearDown(sessionIds.close);

    await tester.pumpWidget(
      AuthNavigationScope(
        sessionIds: sessionIds.stream,
        initialSessionId: 'account-a',
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Text('Protected profile')),
                ),
              ),
              child: const Text('Open profile'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
    expect(find.text('Protected profile'), findsOneWidget);

    sessionIds.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Protected profile'), findsNothing);
    expect(find.text('Open profile'), findsOneWidget);
  });
}
