// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:novalib/main.dart';

void main() {
  testWidgets('NovaLib app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the login page loads
    expect(find.text('Welcome to NovaLib'), findsOneWidget);
    expect(find.text('Enter your Student ID to begin'), findsOneWidget);
    
    // Verify that login elements are present
    expect(find.text('Student ID'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.text('Scan Student ID'), findsOneWidget);
  });
}
