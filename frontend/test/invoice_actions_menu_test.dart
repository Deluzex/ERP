import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/models/sale_model.dart';
import 'package:frontend/features/sales/screens/sales_invoice_list_screen.dart';
import 'package:frontend/features/sales/widgets/sales_pdf_generator.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabaseService db;

  setUp(() {
    db = MockDatabaseService();
    // Ensure there is at least one invoice with pending amount
    if (db.salesInvoices.isEmpty) {
      final firstSo = db.salesOrders.first;
      final dlv = db.createDelivery(
        salesOrderId: firstSo.id,
        deliveryItems: [
          firstSo.items.first.copyWith(quantity: 1, lineTotal: firstSo.items.first.rate),
        ],
        vehicleNumber: 'MH-04-KU-8842',
        driverContact: 'Sunil Jadhav',
      );
      db.createSalesInvoiceFromDelivery(deliveryId: dlv.id, initialPaidAmount: 0);
    }
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => db),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SalesInvoiceListScreen(),
        ),
      ),
    );
  }

  group('Sales Invoice List Action Menu & PDF Tests', () {
    testWidgets('Positive: Invoice row action uses single Icons.edit_note instead of raw buttons', (tester) async {
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

      // Verify raw inline icon buttons are not directly rendered in the table row
      expect(find.byTooltip('Preview Invoice PDF'), findsNothing);
      expect(find.byTooltip('Create Sales Return'), findsNothing);
      expect(find.byTooltip('Record Payment'), findsNothing);
    });

    testWidgets('Positive: Tapping Icons.edit_note opens PopupMenu with invoice actions', (tester) async {
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
      expect(find.text('Record Payment'), findsOneWidget);
      expect(find.text('Create Sales Return'), findsOneWidget);
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

    testWidgets('Positive: Tapping invoice number opens SalesPdfGeneratorDialog directly', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final firstInv = db.salesInvoices.first;
      final invoiceFinder = find.text(firstInv.invoiceNumber);
      expect(invoiceFinder, findsOneWidget);

      await tester.tap(invoiceFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SalesPdfGeneratorDialog), findsOneWidget);
    });
  });
}

