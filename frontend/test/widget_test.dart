import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/app.dart';

void main() {
  testWidgets('ERP App launch smoke test renders authentication gateway', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ErpApplication(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign In to Workspace'), findsOneWidget);
  });
}
