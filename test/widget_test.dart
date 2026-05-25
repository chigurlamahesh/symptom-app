import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_symptom_app/main.dart';

void main() {
  testWidgets('App launches and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HealthSymptomApp());
    // Splash screen should show the app name text
    expect(find.text('AI Health'), findsOneWidget);
  });
}
