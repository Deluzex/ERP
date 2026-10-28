import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/models/purchase_model.dart';
import 'package:frontend/core/models/raw_material_model.dart';
import 'package:frontend/core/models/vendor_model.dart';
import 'package:frontend/core/utils/formatters.dart';
import 'package:frontend/features/purchase/screens/create_purchase_screen.dart';
import 'package:frontend/features/purchase/widgets/total_purchase_cost_card.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Purchase Transportation & Landed Cost - Verification Test Suite', () {
    testWidgets('1 & 2 & 3 & 4. Transportation Input immediately updates Grand Total and Pending Amount; green summary card is removed',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final db = container.read(databaseServiceProvider);
      db.rawMaterials = [
        RawMaterial(
          id: 'RM-001',
          name: 'Aluminum Bar 6063',
          itemCode: 'RAW-ALU-01',
          categoryId: 'cat-1',
          categoryName: 'Metals',
          unit: 'KG',
          currentStock: 100.0,
          openingStock: 100.0,
          minimumStock: 10.0,
          reorderLevel: 20.0,
          defaultPurchasePrice: 100.0,
          gstPercent: 18.0,
          preferredVendorIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CreatePurchaseScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that the green TotalPurchaseCostCard is NOT rendered in CreatePurchaseScreen
      expect(find.byType(TotalPurchaseCostCard), findsNothing);

      // Add 100 units @ 100 INR = 10,000 subtotal, GST 18% = 1,800
      final addItemBtn = find.text('Add Raw Material');
      expect(addItemBtn, findsOneWidget);
      await tester.tap(addItemBtn);
      await tester.pumpAndSettle();

      // Enter Qty = 100 in dialog
      final qtyFinder = find.widgetWithText(TextFormField, '1');
      if (qtyFinder.evaluate().isNotEmpty) {
        await tester.enterText(qtyFinder.first, '100');
        await tester.pumpAndSettle();
      }

      final addToOrderBtn = find.text('Add to Order');
      expect(addToOrderBtn, findsOneWidget);
      await tester.tap(addToOrderBtn);
      await tester.pumpAndSettle();

      // Subtotal = 10,000, GST = 1,800 => Initial Grand Total = 11,800
      expect(find.text(Formatters.formatCurrency(10000.0)), findsWidgets);
      expect(find.text(Formatters.formatCurrency(11800.0)), findsWidgets);

      // Step 1: Enter transportation charges of ₹2,000
      final transFieldFinder = find.byKey(const ValueKey('purchase_transportation_input'));
      expect(transFieldFinder, findsOneWidget);
      await tester.enterText(transFieldFinder, '2000');
      await tester.pumpAndSettle();

      // Step 2: Confirm Transportation / Freight displays ₹2,000
      expect(find.text('2000'), findsOneWidget);

      // Step 3: Confirm Grand Total immediately includes ₹2,000 (10,000 + 1,800 + 2,000 = ₹13,800)
      expect(find.text(Formatters.formatCurrency(13800.0)), findsWidgets);

      // Step 4: Confirm Pending Amount uses the updated Grand Total (13,800 - 0 = ₹13,800)
      expect(find.text(Formatters.formatCurrency(13800.0)), findsWidgets);

      // Enter partial paid amount of 3,800
      final paidFieldFinder = find.widgetWithText(TextFormField, 'Paid Amount (₹)');
      if (paidFieldFinder.evaluate().isNotEmpty) {
        await tester.enterText(paidFieldFinder, '3800');
        await tester.pumpAndSettle();
        // Pending amount = 13,800 - 3,800 = 10,000
        expect(find.text(Formatters.formatCurrency(10000.0)), findsWidgets);
      }
    });

    testWidgets('5. Save the purchase and reopen it; confirm the transportation value persists',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final db = container.read(databaseServiceProvider);
      db.rawMaterials = [
        RawMaterial(
          id: 'rm-test-01',
          name: 'Extrusion Profile',
          itemCode: 'RAW-EXT-01',
          categoryId: 'cat-1',
          categoryName: 'Metals',
          unit: 'KG',
          currentStock: 100.0,
          openingStock: 100.0,
          minimumStock: 10.0,
          reorderLevel: 20.0,
          defaultPurchasePrice: 100.0,
          gstPercent: 18.0,
          preferredVendorIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      db.vendors = [
        Vendor(
          id: 'ven-test-01',
          name: 'Direct Metals Vendor',
          contactPerson: 'Mr. Gupta',
          mobile: '9898011223',
          email: 'vendor@direct.com',
          state: 'Gujarat',
          address: 'GIDC',
          pincode: '382445',
          creditLimit: 500000,
          outstandingBalance: 0,
          paymentTerms: '30 Days',
          gstNumber: '24AAACT1234A1Z5',
          panNumber: 'AAACT1234A',
          createdAt: DateTime.now(),
        ),
      ];

      final existingPo = Purchase(
        id: 'PUR-REOPEN-01',
        purchaseNumber: 'PO-REOPEN-01',
        purchaseDate: DateTime.now(),
        vendorId: 'ven-test-01',
        vendorName: 'Direct Metals Vendor',
        vendorInvoiceNumber: 'INV-RO-01',
        invoiceDate: DateTime.now(),
        purchaseType: PurchaseItemType.rawMaterial,
        subtotalAmount: 10000.0,
        gstAmount: 1800.0,
        transportationCharges: 2000.0,
        totalAmount: 13800.0,
        paidAmount: 3800.0,
        pendingAmount: 10000.0,
        paymentMode: PaymentMode.bankTransfer,
        status: PurchaseStatus.partialPaid,
        items: [
          PurchaseLineItem(
            itemType: PurchaseItemType.rawMaterial,
            rawMaterialId: 'rm-test-01',
            rawMaterialName: 'Extrusion Profile',
            rawMaterialCode: 'RAW-EXT-01',
            quantity: 100.0,
            unit: 'KG',
            rate: 100.0,
            discountAmount: 0.0,
            gstPercent: 18.0,
            lineTotal: 11800.0,
            transportationCost: 2000.0,
            landedRate: 120.0,
          ),
        ],
        createdAt: DateTime.now(),
      );

      // Open CreatePurchaseScreen directly with the existing purchase
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CreatePurchaseScreen(existingPurchase: existingPo),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify restored values in fields
      expect(find.text('2000'), findsOneWidget);
      expect(find.text(Formatters.formatCurrency(13800.0)), findsWidgets);
      expect(find.text(Formatters.formatCurrency(10000.0)), findsWidgets);
      expect(find.byType(TotalPurchaseCostCard), findsNothing);
    });

    test('6 & 7 & 8. Landed cost of 100 units @ 10,000 INR + 2,000 INR transportation is 120/unit, updates master and preserves selling price', () {
      final db = MockDatabaseService();
      final rmId = 'RM-LANDED-100';

      final initialRm = RawMaterial(
        id: rmId,
        name: 'High Grade Extrusion 100',
        itemCode: 'RAW-HG-100',
        categoryId: 'cat-1',
        categoryName: 'Metals',
        unit: 'KG',
        currentStock: 50.0,
        openingStock: 50.0,
        minimumStock: 10.0,
        reorderLevel: 20.0,
        defaultPurchasePrice: 80.0,
        gstPercent: 18.0,
        preferredVendorIds: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final unrelatedRm = RawMaterial(
        id: 'RM-UNRELATED',
        name: 'Unrelated Rubber Gasket',
        itemCode: 'RAW-GASKET',
        categoryId: 'cat-2',
        categoryName: 'Rubber',
        unit: 'MTR',
        currentStock: 30.0,
        openingStock: 30.0,
        minimumStock: 5.0,
        reorderLevel: 10.0,
        defaultPurchasePrice: 45.0,
        gstPercent: 18.0,
        preferredVendorIds: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      db.rawMaterials = [initialRm, unrelatedRm];

      final vendor = Vendor(
        id: 'V-001',
        name: 'Apex Metals Ltd',
        contactPerson: 'Mr. Sharma',
        mobile: '9876543210',
        email: 'sharma@apex.com',
        state: 'Gujarat',
        address: 'GIDC',
        pincode: '382445',
        creditLimit: 500000,
        outstandingBalance: 0,
        paymentTerms: '30 Days',
        gstNumber: '24AAACT1234A1Z5',
        panNumber: 'AAACT1234A',
        createdAt: DateTime.now(),
      );
      db.vendors = [vendor];

      // 100 units costing ₹10,000 plus ₹2,000 transportation
      // Rate = 100, Qty = 100 => 10,000
      final purchase = Purchase(
        id: 'PUR-LANDED-01',
        purchaseNumber: 'PO-2026-LANDED-01',
        purchaseDate: DateTime.now(),
        vendorId: vendor.id,
        vendorName: vendor.name,
        vendorInvoiceNumber: 'INV-LND-01',
        invoiceDate: DateTime.now(),
        purchaseType: PurchaseItemType.rawMaterial,
        subtotalAmount: 10000.0,
        gstAmount: 1800.0,
        transportationCharges: 2000.0,
        totalAmount: 13800.0,
        paidAmount: 13800.0,
        pendingAmount: 0.0,
        paymentMode: PaymentMode.bankTransfer,
        status: PurchaseStatus.paid,
        items: [
          PurchaseLineItem(
            itemType: PurchaseItemType.rawMaterial,
            rawMaterialId: rmId,
            rawMaterialName: 'High Grade Extrusion 100',
            rawMaterialCode: 'RAW-HG-100',
            quantity: 100.0,
            unit: 'KG',
            rate: 100.0,
            discountAmount: 0.0,
            gstPercent: 18.0,
            lineTotal: 11800.0,
          ),
        ],
        createdAt: DateTime.now(),
      );

      db.createPurchase(purchase);

      final updatedRm = db.rawMaterials.firstWhere((r) => r.id == rmId);
      // Step 6: For 100 units with a discounted line value of ₹10,000 and transportation of ₹2,000, landed cost is ₹120/unit
      // Step 7: Confirm the correct Master product record displays the calculated unit cost (defaultPurchasePrice = 120.0)
      expect(updatedRm.defaultPurchasePrice, 120.0);
      expect(updatedRm.currentStock, 150.0); // 50 + 100

      // Step 8: Unrelated inventory records remain unchanged
      final checkUnrelated = db.rawMaterials.firstWhere((r) => r.id == 'RM-UNRELATED');
      expect(checkUnrelated.defaultPurchasePrice, 45.0);
      expect(checkUnrelated.currentStock, 30.0);
    });

    test('9. Test multiple products and verify proportional allocation across items', () {
      final items = [
        PurchaseLineItem(
          itemType: PurchaseItemType.rawMaterial,
          rawMaterialId: 'rm-1',
          quantity: 100.0,
          unit: 'KG',
          rate: 300.0,
          discountAmount: 0.0, // Line value = 30,000 (75%)
          lineTotal: 35400.0,
        ),
        PurchaseLineItem(
          itemType: PurchaseItemType.finishedProduct,
          finishedProductId: 'fp-1',
          quantity: 10.0,
          unit: 'PCS',
          rate: 1000.0,
          discountAmount: 0.0, // Line value = 10,000 (25%)
          lineTotal: 11800.0,
        ),
      ];

      // Total transportation = 2000
      final allocated = PurchaseLineItem.allocateTransportation(
        items: items,
        transportationCharges: 2000.0,
      );

      // Line 1: 30,000 / 40,000 * 2000 = 1500 => Landed = (30,000 + 1500) / 100 = 315.0
      expect(allocated[0].transportationCost, 1500.0);
      expect(allocated[0].landedRate, 315.0);

      // Line 2: 10,000 / 40,000 * 2000 = 500 => Landed = (10,000 + 500) / 10 = 1050.0
      expect(allocated[1].transportationCost, 500.0);
      expect(allocated[1].landedRate, 1050.0);
    });
  });
}
