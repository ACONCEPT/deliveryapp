import 'package:flutter_test/flutter_test.dart';

import 'package:delivery_app/main.dart';

void main() {
  testWidgets('DeliveryApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DeliveryApp());

    // Verify that the login screen loads
    expect(find.text('Delivery App'), findsOneWidget);
  });
}
