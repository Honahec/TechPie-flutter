import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techpie/widgets/adaptive_text_input_dialog.dart';

void main() {
  testWidgets('confirmation must match before the dialog submits', (
    WidgetTester tester,
  ) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(
              showAdaptiveTextInputDialog(
                context: context,
                title: 'Password',
                fieldLabel: 'Password',
                confirmationFieldLabel: 'Confirm password',
                mismatchMessage: 'Mismatch',
                confirmLabel: 'OK',
                obscureText: true,
              ).then((value) => result = value),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'secret');
    await tester.enterText(fields.at(1), 'different');
    await tester.pump();
    expect(find.text('Mismatch'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.text('Password'), findsWidgets);
    expect(result, isNull);

    await tester.enterText(fields.at(1), 'secret');
    await tester.pump();
    final submitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'OK'),
    );
    expect(submitButton.onPressed, isNotNull);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(result, 'secret');
  });
}
