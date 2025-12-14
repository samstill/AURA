// Basic widget test for Project Aura
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:project_aura/main.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AuraApp()),
    );

    // Verify the app renders
    expect(find.text('Project Aura'), findsWidgets);
  });
}
