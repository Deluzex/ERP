import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/sales/screens/deliveries_screen.dart';
import 'package:frontend/features/sales/widgets/sales_pdf_generator.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabaseService db;

  setUp(() {
    db = MockDatabaseService();
    // Ensure there is at least one delivery challan
    if (db.deliveries.isEmpty) {
      final firstSo = db.salesOrders.first;
      db.createDelivery(
        salesOrderId: firstSo.id,
        deliveryItems: [
          firstSo.items.first.copyWith(quantity: 1, lineTotal: firstSo.items.first.rate),
        ],
        vehicleNumber: 'MH-04-KU-8842',
        driverContact: 'Sunil Jadhav',
        trackingNumber: 'TRK-2026-1111',
      );
    }
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => db),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: DeliveriesScreen(),
        ),
      ),
    );
  }

  group('Deliveries Screen Action Menu & PDF Tests', () {
    testWidgets('Positive: Delivery row action uses single Icons.edit_note instead of 5 raw buttons', (tester) async {
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

      // Verify raw inline buttons are not directly rendered in the table row
      expect(find.byTooltip('Edit Courier & Tracking Info'), findsNothing);
      expect(find.byTooltip('Share Challan (WhatsApp/Email)'), findsNothing);
      expect(find.byTooltip('Quick WhatsApp Message'), findsNothing);
      expect(find.byTooltip('Preview Delivery Challan PDF'), findsNothing);
    });

    testWidgets('Positive: Tapping Icons.edit_note opens PopupMenu with all delivery actions', (tester) async {
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
      expect(find.text('Create Invoice'), findsOneWidget);
      expect(find.text('Edit Tracking'), findsOneWidget);
      expect(find.text('Share Challan'), findsOneWidget);
      expect(find.text('WhatsApp Message'), findsOneWidget);
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

    testWidgets('Positive: Tapping challan invoice number opens SalesPdfGeneratorDialog directly', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final firstDlv = db.deliveries.first;
      final challanFinder = find.text(firstDlv.invoiceNumber);
      expect(challanFinder, findsOneWidget);

      await tester.tap(challanFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SalesPdfGeneratorDialog), findsOneWidget);
    });
  });
}
