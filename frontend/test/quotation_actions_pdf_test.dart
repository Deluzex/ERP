import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/models/sale_model.dart';
import 'package:frontend/features/sales/screens/quotations_screen.dart';
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
          body: QuotationsScreen(),
        ),
      ),
    );
  }

  group('Quotations Screen Action Menu & PDF Viewer Tests', () {
    testWidgets('Positive: Quotation popup menu uses Icons.edit_note and does NOT contain "Create Revision" or "Duplicate Quote"', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify Icons.more_vert is replaced with Icons.edit_note
      expect(find.byIcon(Icons.more_vert), findsNothing);
      final moreButton = find.byIcon(Icons.edit_note).first;
      expect(moreButton, findsOneWidget);

      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      // Verify View Details exists
      expect(find.text('View Details'), findsOneWidget);

      // Verify Create Revision and Duplicate Quote are NOT present
      expect(find.text('Create Revision'), findsNothing);
      expect(find.text('Duplicate Quote'), findsNothing);
    });

    testWidgets('Positive: Tapping quotation invoice number opens PDF Preview dialog directly', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find first quotation number link
      final firstQuote = db.quotations.first;
      final quoteNumberText = find.text(firstQuote.invoiceNumber);
      expect(quoteNumberText, findsOneWidget);

      await tester.tap(quoteNumberText);
      await tester.pumpAndSettle();

      // Verify SalesPdfGeneratorDialog / PDF dialog is opened
      expect(find.byType(SalesPdfGeneratorDialog), findsOneWidget);
    });

    testWidgets('Positive: Tapping View Details in popup menu opens PDF Preview dialog directly', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final moreButton = find.byIcon(Icons.edit_note).first;
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      final viewDetailsItem = find.text('View Details');
      await tester.tap(viewDetailsItem);
      await tester.pumpAndSettle();

      // Verify PDF dialog is opened instead of the old record details panel
      expect(find.byType(SalesPdfGeneratorDialog), findsOneWidget);
    });

    testWidgets('Positive: Standalone PDF icon is commented out from table row action column', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Standalone PDF icon in table actions should not be found
      expect(find.byIcon(Icons.picture_as_pdf), findsNothing);
    });

    testWidgets('Negative/Boundary: Quotation with SENT or DRAFT status does NOT show "Convert to Proforma" in PopupMenu', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Ensure first quote is in SENT status
      final firstIdx = db.sales.indexWhere((s) => s.documentType == SalesDocumentType.quotation);
      expect(firstIdx, isNot(-1));
      db.sales[firstIdx] = db.sales[firstIdx].copyWith(
        quotationStatus: QuotationStatus.sent,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final firstEditNote = find.byIcon(Icons.edit_note).first;
      await tester.tap(firstEditNote);
      await tester.pumpAndSettle();

      // Sent quote should have Accept and Reject, but NOT Convert to Proforma
      expect(find.text('Accept Quote'), findsOneWidget);
      expect(find.text('Reject Quote'), findsOneWidget);
      expect(find.text('Convert to Proforma'), findsNothing);
    });

    testWidgets('Positive: Quotation with ACCEPTED status DOES show "Convert to Proforma" in PopupMenu', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Set first quote to ACCEPTED status
      final firstIdx = db.sales.indexWhere((s) => s.documentType == SalesDocumentType.quotation);
      expect(firstIdx, isNot(-1));
      db.sales[firstIdx] = db.sales[firstIdx].copyWith(
        quotationStatus: QuotationStatus.accepted,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final firstEditNote = find.byIcon(Icons.edit_note).first;
      await tester.tap(firstEditNote);
      await tester.pumpAndSettle();

      // Accepted quote MUST show Convert to Proforma
      expect(find.text('Convert to Proforma'), findsOneWidget);
    });

    testWidgets('Negative/Boundary: Quotation with CONVERTED status does NOT show "Convert to Proforma" in PopupMenu', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Set first quote to CONVERTED status
      final firstIdx = db.sales.indexWhere((s) => s.documentType == SalesDocumentType.quotation);
      expect(firstIdx, isNot(-1));
      db.sales[firstIdx] = db.sales[firstIdx].copyWith(
        quotationStatus: QuotationStatus.converted,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final firstEditNote = find.byIcon(Icons.edit_note).first;
      await tester.tap(firstEditNote);
      await tester.pumpAndSettle();

      // Converted quote should NOT show Convert to Proforma
      expect(find.text('Convert to Proforma'), findsNothing);
    });
  });
}
