import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/models/finished_product_model.dart';
import 'package:frontend/core/models/purchase_model.dart';
import 'package:frontend/core/models/sale_model.dart';
import 'package:frontend/core/models/stock_movement_model.dart';
import 'package:frontend/features/sales/screens/create_sale_screen.dart';
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
          body: CreateSaleScreen(),
        ),
      ),
    );
  }

  group('Direct Sale Creation & Stock Deduction Tests (Offline Resilience)', () {
    test('Positive: createDirectSaleAsync gracefully falls back to local and deducts finished product stock', () async {
      final initialFp = db.finishedProducts.first;
      final initialStock = initialFp.currentStock;
      const soldQty = 2.0;
      final rate = initialFp.customerSellingPrice > 0 ? initialFp.customerSellingPrice : 10000.0;

      final testSale = Sale(
        id: 'TEST-SALE-001',
        invoiceNumber: 'INV-TEST-999',
        documentType: SalesDocumentType.invoice,
        partyType: PartyType.customer,
        partyId: db.customers.first.id,
        partyName: db.customers.first.name,
        saleDate: DateTime.now(),
        items: [
          SaleLineItem(
            finishedProductId: initialFp.id,
            finishedProductName: initialFp.name,
            finishedProductCode: initialFp.itemCode,
            quantity: soldQty,
            unit: initialFp.unit,
            rate: rate,
            lineTotal: rate * soldQty,
            gstPercent: 18,
          ),
        ],
        subtotalAmount: rate * soldQty,
        discountAmount: 0,
        taxableAmount: rate * soldQty,
        cgstAmount: (rate * soldQty) * 0.09,
        sgstAmount: (rate * soldQty) * 0.09,
        igstAmount: 0,
        gstAmount: (rate * soldQty) * 0.18,
        totalAmount: (rate * soldQty) * 1.18,
        paidAmount: 0,
        pendingAmount: (rate * soldQty) * 1.18,
        paymentMode: PaymentMode.bankTransfer,
        status: SaleStatus.active,
        createdAt: DateTime.now(),
      );

      // Call createDirectSaleAsync - even if remote API throws/fails, it should succeed via fallback
      final result = await db.createDirectSaleAsync(testSale);

      expect(result.id, equals(testSale.id));
      expect(db.salesInvoices.any((s) => s.id == testSale.id), isTrue);

      // Stock must be deducted
      final updatedFp = db.finishedProducts.firstWhere((fp) => fp.id == initialFp.id);
      expect(updatedFp.currentStock, equals(initialStock - soldQty));

      // StockMovement transaction must be recorded
      final movement = db.stockMovements.firstWhere((m) => m.referenceNumber == testSale.invoiceNumber);
      expect(movement.transactionType, equals(StockMovementType.sale));
      expect(movement.stockOut, equals(soldQty));
    });

    testWidgets('Positive: Tapping Create Invoice & Dispatch creates invoice and navigates without error toast', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap "Add Product" to open item dialog
      final addProductButton = find.text('Add Product').first;
      await tester.tap(addProductButton);
      await tester.pumpAndSettle();

      // Tap "Add to Order" inside dialog
      final addToOrderButton = find.text('Add to Order');
      expect(addToOrderButton, findsOneWidget);
      await tester.tap(addToOrderButton);
      await tester.pumpAndSettle();

      // Find the Create Invoice & Dispatch button
      final createButton = find.text('Create Invoice & Dispatch');
      expect(createButton, findsOneWidget);

      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Expect no error snackbar
      expect(find.textContaining('Failed to create sale'), findsNothing);
      expect(find.textContaining('Invoice Created! Finished Product stock deducted'), findsOneWidget);
    });
  });
}
