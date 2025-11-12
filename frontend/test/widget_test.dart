import 'package:flutter_test/flutter_test.dart';

import 'package:delivery_app/main.dart';
import 'package:delivery_app/providers/auth_provider.dart';

void main() {
  testWidgets('DeliveryApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final authProvider = AuthProvider();
    await tester.pumpWidget(DeliveryApp(authProvider: authProvider));

    // Verify that the login screen loads
    expect(find.text('Delivery App'), findsOneWidget);
  });
}
