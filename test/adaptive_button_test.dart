import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techpie/widgets/adaptive_button.dart';

void main() {
  testWidgets('Material action button handles taps', (
    WidgetTester tester,
  ) async {
    var tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdaptiveButton(
            label: 'Back up now',
            subtitle: 'Upload encrypted bindings',
            icon: Icons.cloud_upload_outlined,
            role: AdaptiveButtonRole.prominent,
            onPressed: () => tapCount++,
          ),
        ),
      ),
    );

    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.text('Back up now'));
    expect(tapCount, 1);
  });
}
