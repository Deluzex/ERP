import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/models/sale_model.dart';
import 'package:frontend/features/sales/screens/proforma_invoices_screen.dart';
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
          body: ProformaInvoicesScreen(),
        ),
      ),
    );
  }

  group('Proforma Invoices Screen Action Menu & PDF Tests', () {
    testWidgets('Positive: Proforma row action uses single Icons.edit_note instead of 3 raw icon buttons', (tester) async {
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

      // Verify raw icon buttons are not rendered in the table row
      expect(find.byIcon(Icons.picture_as_pdf), findsNothing);
      expect(find.byIcon(Icons.add_card), findsNothing);
      expect(find.byIcon(Icons.shopping_cart_checkout), findsNothing);
    });

    testWidgets('Positive: Tapping Icons.edit_note opens PopupMenu with View Details, Record Advance Payment, Convert to Sales Order', (tester) async {
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
      expect(find.text('Record Advance Payment'), findsOneWidget);
      expect(find.text('Convert to Sales Order'), findsOneWidget);
    });

    testWidgets('Positive: Tapping View Details in popup menu opens SalesPdfGeneratorDialog', (tester) async {
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

      final viewDetailsItem = find.text('View Details');
      await tester.tap(viewDetailsItem);
      await tester.pumpAndSettle();

      expect(find.byType(SalesPdfGeneratorDialog), findsOneWidget);
    });

    testWidgets('Positive: Tapping proforma invoice number opens SalesPdfGeneratorDialog directly', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final firstProforma = db.proformaInvoices.first;
      final proformaNumberFinder = find.text(firstProforma.invoiceNumber);
      expect(proformaNumberFinder, findsOneWidget);

      await tester.tap(proformaNumberFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SalesPdfGeneratorDialog), findsOneWidget);
    });

    testWidgets('Negative/Boundary: Converted proforma invoice does NOT show "Convert to Sales Order" in PopupMenu', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Mark first proforma invoice as converted
      final firstIdx = db.sales.indexWhere((s) => s.documentType == SalesDocumentType.proformaInvoice);
      expect(firstIdx, isNot(-1));
      db.sales[firstIdx] = db.sales[firstIdx].copyWith(
        proformaStatus: ProformaStatus.converted,
        salesOrderNumber: 'DLZ/SO/2026/0001',
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final firstEditNote = find.byIcon(Icons.edit_note).first;
      await tester.tap(firstEditNote);
      await tester.pumpAndSettle();

      // View Details is present
      expect(find.text('View Details'), findsOneWidget);
      // "Convert to Sales Order" MUST NOT be present
      expect(find.text('Convert to Sales Order'), findsNothing);
    });
  });
}

