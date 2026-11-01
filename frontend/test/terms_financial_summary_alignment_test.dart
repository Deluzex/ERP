import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/sales/screens/create_quotation_screen.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabaseService db;

  setUp(() {
    db = MockDatabaseService();
  });

  group('Terms & Conditions & Financial Summary Alignment Tests', () {
    testWidgets('Positive: CreateQuotationScreen renders Terms & Conditions without Internal Sales Notes on desktop', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CreateQuotationScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Terms & Conditions field is present
      expect(find.text('Terms & Conditions (Printed on PDF)'), findsOneWidget);

      // Verify Internal Sales Notes is removed / commented out
      expect(find.text('Internal Sales Notes'), findsNothing);

      // Verify Financial Summary is present
      expect(find.text('Financial Summary'), findsOneWidget);

      // Verify layout heights are well balanced and aligned
      final termsFinder = find.widgetWithText(TextFormField, 'Terms & Conditions (Printed on PDF)');
      final financialSummaryFinder = find.text('Financial Summary');

      expect(termsFinder, findsOneWidget);
      expect(financialSummaryFinder, findsOneWidget);

      final termsSize = tester.getSize(termsFinder);
      // Terms box with 8 lines provides ~180-240px matching financial summary
      expect(termsSize.height, greaterThan(150));
    });

    testWidgets('Negative: Internal Sales Notes is strictly absent from the screen', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CreateQuotationScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Internal Sales Notes'), findsNothing);
    });

    testWidgets('Edge case: Narrow mobile viewport renders without flex overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CreateQuotationScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms & Conditions (Printed on PDF)'), findsOneWidget);
      expect(find.text('Internal Sales Notes'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
