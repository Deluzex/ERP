import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/models/sale_model.dart';
import 'package:frontend/features/sales/screens/sales_orders_screen.dart';
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
          body: SalesOrdersScreen(),
        ),
      ),
    );
  }

  group('Sales Orders Screen Action Menu & PDF Tests', () {
    testWidgets('Positive: Sales order row action uses single Icons.edit_note instead of raw icon buttons', (tester) async {
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

      // Verify raw icon buttons are not directly rendered in the table row
      expect(find.byTooltip('Preview Sales Order PDF'), findsNothing);
      expect(find.byTooltip('Dispatch Delivery'), findsNothing);
    });

    testWidgets('Positive: Tapping Icons.edit_note opens PopupMenu with View Details and Dispatch Delivery', (tester) async {
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
      expect(find.text('Dispatch Delivery'), findsOneWidget);
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

    testWidgets('Positive: Tapping sales order invoice number opens SalesPdfGeneratorDialog directly', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final firstSo = db.salesOrders.first;
      final soNumberFinder = find.text(firstSo.invoiceNumber);
      expect(soNumberFinder, findsOneWidget);

      await tester.tap(soNumberFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SalesPdfGeneratorDialog), findsOneWidget);
    });

    testWidgets('Negative/Boundary: Delivered or Completed Sales Order does NOT show "Dispatch Delivery" in PopupMenu', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Mark first sales order as delivered
      final firstIdx = db.sales.indexWhere((s) => s.documentType == SalesDocumentType.salesOrder);
      expect(firstIdx, isNot(-1));
      db.sales[firstIdx] = db.sales[firstIdx].copyWith(
        salesOrderStatus: SalesOrderStatus.delivered,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final firstEditNote = find.byIcon(Icons.edit_note).first;
      await tester.tap(firstEditNote);
      await tester.pumpAndSettle();

      // View Details is present
      expect(find.text('View Details'), findsOneWidget);
      // Dispatch Delivery MUST NOT be present
      expect(find.text('Dispatch Delivery'), findsNothing);
    });

    testWidgets('Positive: When PCS stock data is fetched in master, workflow status displays COMPLETE PRODUCTION and Dispatch Delivery is enabled', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Setup a sales order with an item that has sufficient stock in master finished products
      final targetFpId = db.finishedProducts.first.id;
      final fpStock = db.finishedProducts.first.currentStock;
      expect(fpStock, greaterThan(0));

      final firstIdx = db.sales.indexWhere((s) => s.documentType == SalesDocumentType.salesOrder);
      db.sales[firstIdx] = db.sales[firstIdx].copyWith(
        salesOrderStatus: SalesOrderStatus.productionPending,
        items: [
          SaleLineItem(
            finishedProductId: targetFpId,
            finishedProductName: db.finishedProducts.first.name,
            finishedProductCode: db.finishedProducts.first.itemCode,
            quantity: 5,
            deliveredQuantity: 0,
            reservedQuantity: 0,
            unit: 'PCS',
            rate: 100,
            lineTotal: 500,
          ),
        ],
      );

      // Ensure master has at least 10 PCS in stock (greater than quantity 5)
      final fpIdx = db.finishedProducts.indexWhere((f) => f.id == targetFpId);
      db.finishedProducts[fpIdx] = db.finishedProducts[fpIdx].copyWith(currentStock: 20.0);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Workflow badge should show COMPLETE PRODUCTION
      expect(find.text('COMPLETE PRODUCTION'), findsWidgets);

      // Open Actions menu
      final firstEditNote = find.byIcon(Icons.edit_note).first;
      await tester.tap(firstEditNote);
      await tester.pumpAndSettle();

      // Verify Dispatch Delivery is present and enabled
      final dispatchItem = find.widgetWithText(PopupMenuItem<String>, 'Dispatch Delivery');
      expect(dispatchItem, findsOneWidget);
      final popupWidget = tester.widget<PopupMenuItem<String>>(dispatchItem);
      expect(popupWidget.enabled, isTrue);
    });

    testWidgets('Negative: When PCS stock data is NOT in master, workflow status displays IN PRODUCTION and Dispatch Delivery is disabled', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Setup a sales order with quantity greater than master stock
      final targetFpId = db.finishedProducts.first.id;
      final firstIdx = db.sales.indexWhere((s) => s.documentType == SalesDocumentType.salesOrder);
      
      // Set master stock to 0 PCS
      final fpIdx = db.finishedProducts.indexWhere((f) => f.id == targetFpId);
      db.finishedProducts[fpIdx] = db.finishedProducts[fpIdx].copyWith(currentStock: 0.0);

      db.sales[firstIdx] = db.sales[firstIdx].copyWith(
        salesOrderStatus: SalesOrderStatus.productionPending,
        items: [
          SaleLineItem(
            finishedProductId: targetFpId,
            finishedProductName: db.finishedProducts.first.name,
            finishedProductCode: db.finishedProducts.first.itemCode,
            quantity: 50,
            deliveredQuantity: 0,
            reservedQuantity: 0,
            unit: 'PCS',
            rate: 100,
            lineTotal: 5000,
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Workflow badge should show IN PRODUCTION
      expect(find.text('IN PRODUCTION'), findsWidgets);

      // Open Actions menu
      final firstEditNote = find.byIcon(Icons.edit_note).first;
      await tester.tap(firstEditNote);
      await tester.pumpAndSettle();

      // Verify Dispatch Delivery is disabled
      final dispatchItem = find.widgetWithText(PopupMenuItem<String>, 'Dispatch Delivery');
      expect(dispatchItem, findsOneWidget);
      final popupWidget = tester.widget<PopupMenuItem<String>>(dispatchItem);
      expect(popupWidget.enabled, isFalse);
    });

    testWidgets('Positive: createDelivery deducts physical stock and creates delivery challan', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Target first sales order
      final so = db.salesOrders.first;
      expect(so.items.isNotEmpty, isTrue);

      final firstItem = so.items.first;
      final fp = db.finishedProducts.firstWhere((p) => p.id == firstItem.finishedProductId);
      final initialPhysicalStock = fp.currentStock;

      final dispatchItem = firstItem.copyWith(
        quantity: 1,
        lineTotal: firstItem.rate * 1,
      );

      final deliveryDoc = db.createDelivery(
        salesOrderId: so.id,
        deliveryItems: [dispatchItem],
        vehicleNumber: 'MH-04-KU-8842',
        driverContact: 'Sunil Jadhav',
        trackingNumber: 'TRK-2026-9999',
        notes: 'Test dispatch',
      );

      expect(deliveryDoc, isNotNull);
      expect(deliveryDoc.invoiceNumber, startsWith('DLZ/DLV/2026/'));

      // Verify physical stock was deducted
      final updatedFp = db.finishedProducts.firstWhere((p) => p.id == firstItem.finishedProductId);
      expect(updatedFp.currentStock, equals(initialPhysicalStock - 1));
    });
  });
}
