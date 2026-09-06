import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:do_it_now/main.dart';

void main() {
  testWidgets('creates and deletes a task', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    expect(find.text('Task Desk'), findsOneWidget);
    expect(find.text('Map the first user flow'), findsOneWidget);

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Ship CRUD flow',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Details'),
      'Connect the form to the list.',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Ship CRUD flow'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Ship edited CRUD flow',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Ship edited CRUD flow'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Ship CRUD flow'), findsNothing);
  });
}
