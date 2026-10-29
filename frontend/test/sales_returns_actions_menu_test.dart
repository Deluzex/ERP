import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/sales/screens/sales_returns_screen.dart';
import 'package:frontend/features/sales/widgets/sales_pdf_generator.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabaseService db;

  setUp(() {
    db = MockDatabaseService();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => db),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SalesReturnsScreen(),
        ),
      ),
    );
  }

  group('Sales Returns Table Actions & Columns Tests', () {
    testWidgets('Negative: "Created By" column header and cells are commented out/removed', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // "Created By" header should NOT be present
      expect(find.text('Created By'), findsNothing);
      expect(find.text('CREATED BY'), findsNothing);
    });

    testWidgets('Positive: Action column uses ochre Icons.edit_note popup button instead of Icons.more_vert', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify Icons.edit_note is present in actions column
      final editNoteButtons = find.byIcon(Icons.edit_note);
      expect(editNoteButtons, findsWidgets);

      // Verify Icons.more_vert is not used in the table
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('Positive: Tapping Icons.edit_note opens PopupMenu with View Details option', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final firstEditNote = find.byIcon(Icons.edit_note).first;
      await tester.tap(firstEditNote);
      await tester.pumpAndSettle();

      // Verify menu options
      expect(find.text('View Details'), findsOneWidget);
    });

    testWidgets('Positive: Tapping Return Number opens SalesPdfGeneratorDialog directly', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final firstReturnNo = find.text(db.salesReturns.first.invoiceNumber);
      expect(firstReturnNo, findsOneWidget);

      await tester.tap(firstReturnNo);
      await tester.pumpAndSettle();

      // Should open the Credit Note / Return Receipt PDF generator dialog
      expect(find.byType(SalesPdfGeneratorDialog), findsOneWidget);
      expect(find.text('CREDIT NOTE / RETURN RECEIPT'), findsOneWidget);
    });

    testWidgets('Positive: Create Sales Return dialog renders without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final createReturnBtn = find.text('Create Sales Return');
      expect(createReturnBtn, findsOneWidget);

      await tester.tap(createReturnBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Create Sales Return & Credit Note'), findsOneWidget);
      expect(find.text('Condition'), findsWidgets);
      expect(find.text('Resalable (Restock)'), findsWidgets);
      // Ensure no layout assertion/RenderFlex overflow was thrown
      expect(tester.takeException(), isNull);
    });
  });
}
