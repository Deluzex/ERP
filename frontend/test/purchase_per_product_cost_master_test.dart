import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/models/purchase_model.dart';
import 'package:frontend/core/models/raw_material_model.dart';
import 'package:frontend/core/models/finished_product_model.dart';
import 'package:frontend/core/utils/formatters.dart';
import 'package:frontend/features/purchase/widgets/total_purchase_cost_card.dart';
import 'package:frontend/features/masters/screens/raw_material_master_screen.dart';
import 'package:frontend/features/masters/screens/product_master_screen.dart';
import 'package:frontend/features/purchase/screens/create_purchase_screen.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Purchase Per Product Cost & Master Module Updates - AI-TDD Test Suite', () {
    testWidgets('1. Positive: TotalPurchaseCostCard renders Total Cost per Product and per-unit landed cost when units provided',
        (WidgetTester tester) async {
      const double testAmount = 11800.0;
      const double testUnits = 10.0;
      const double expectedLanded = 1180.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TotalPurchaseCostCard(
              totalAmount: testAmount,
              totalUnits: testUnits,
              landedCostPerUnit: expectedLanded,
            ),
          ),
        ),
      );

      // Verify Production Page style title
      expect(find.text('Total Cost per Product:'), findsOneWidget);
      expect(find.text('Items + GST + Transportation'), findsOneWidget);
      expect(find.text('Total Purchase Cost'), findsOneWidget);

      // Verify Landed unit cost
      expect(find.text(Formatters.formatCurrency(expectedLanded)), findsOneWidget);
      expect(find.text('${Formatters.formatCurrency(expectedLanded)} / unit'), findsOneWidget);
    });

    testWidgets('2. Edge Case: TotalPurchaseCostCard with 0 or null units falls back to Total Purchase Cost',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TotalPurchaseCostCard(
              totalAmount: 5000.0,
              totalUnits: 0,
            ),
          ),
        ),
      );

      expect(find.text('Total Purchase Cost'), findsOneWidget);
      expect(find.text('Total Cost per Product:'), findsNothing);
      expect(find.text(Formatters.formatCurrency(5000.0)), findsOneWidget);
    });

    test('3. Master Module Sync: Creating purchase with transportation updates raw material master purchase cost', () {
      final db = MockDatabaseService();
      final rmId = 'RM-TEST-001';
      final initialRm = RawMaterial(
        id: rmId,
        name: 'Test Extrusion Profile',
        itemCode: 'RAW-TEST-001',
        categoryId: 'cat-1',
        categoryName: 'Metals',
        unit: 'MTR',
        currentStock: 10.0,
        openingStock: 10.0,
        minimumStock: 5.0,
        reorderLevel: 8.0,
        defaultPurchasePrice: 200.0,
        gstPercent: 18.0,
        preferredVendorIds: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      db.rawMaterials = [initialRm];

      // Create purchase with 10 units @ 1000 INR each + 500 INR transportation
      // Landed cost = (10000 + 500) / 10 = 1050.0
      final purchase = Purchase(
        id: 'PUR-TEST-1',
        purchaseNumber: 'PO-TEST-1',
        purchaseDate: DateTime.now(),
        vendorId: 'V-001',
        vendorName: 'Apex Vendor',
        vendorInvoiceNumber: 'INV-001',
        invoiceDate: DateTime.now(),
        purchaseType: PurchaseItemType.rawMaterial,
        subtotalAmount: 10000.0,
        gstAmount: 1800.0,
        transportationCharges: 500.0,
        totalAmount: 12300.0,
        paidAmount: 12300.0,
        pendingAmount: 0.0,
        paymentMode: PaymentMode.bankTransfer,
        status: PurchaseStatus.paid,
        items: [
          PurchaseLineItem(
            itemType: PurchaseItemType.rawMaterial,
            rawMaterialId: rmId,
            rawMaterialName: 'Test Extrusion Profile',
            rawMaterialCode: 'RAW-TEST-001',
            quantity: 10.0,
            unit: 'MTR',
            rate: 1000.0,
            discountAmount: 0.0,
            gstPercent: 18.0,
            lineTotal: 11800.0,
          ),
        ],
        createdAt: DateTime.now(),
      );

      db.createPurchase(purchase);

      final updatedRm = db.rawMaterials.firstWhere((r) => r.id == rmId);
      // Stock updated: 10 + 10 = 20
      expect(updatedRm.currentStock, 20.0);
      // Master purchase price directly updated to landed cost including transportation: 1050.0
      expect(updatedRm.defaultPurchasePrice, 1050.0);
    });

    test('4. Master Module Sync: Creating purchase with transportation updates finished product master cost price', () {
      final db = MockDatabaseService();
      final fpId = 'FP-TEST-001';
      final initialFp = FinishedProduct(
        id: fpId,
        name: 'Test Modern Chandelier',
        itemCode: 'FP-CH-001',
        categoryId: 'cat-2',
        categoryName: 'Lighting',
        unit: 'PCS',
        currentStock: 5.0,
        openingStock: 5.0,
        minimumStock: 2.0,
        costPrice: 500.0,
        dealerSellingPrice: 800.0,
        customerSellingPrice: 1200.0,
        gstPercent: 18.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      db.finishedProducts = [initialFp];

      // Create finished goods purchase with 20 units @ 400 INR each + 400 INR transportation
      // Landed cost = (8000 + 400) / 20 = 420.0
      final purchase = Purchase(
        id: 'PUR-TEST-FP',
        purchaseNumber: 'PO-TEST-FP',
        purchaseDate: DateTime.now(),
        vendorId: 'V-002',
        vendorName: 'Direct Goods Supplier',
        vendorInvoiceNumber: 'INV-FP-002',
        invoiceDate: DateTime.now(),
        purchaseType: PurchaseItemType.finishedProduct,
        subtotalAmount: 8000.0,
        gstAmount: 1440.0,
        transportationCharges: 400.0,
        totalAmount: 9840.0,
        paidAmount: 9840.0,
        pendingAmount: 0.0,
        paymentMode: PaymentMode.bankTransfer,
        status: PurchaseStatus.paid,
        items: [
          PurchaseLineItem(
            itemType: PurchaseItemType.finishedProduct,
            finishedProductId: fpId,
            finishedProductName: 'Test Modern Chandelier',
            finishedProductCode: 'FP-CH-001',
            quantity: 20.0,
            unit: 'PCS',
            rate: 400.0,
            discountAmount: 0.0,
            gstPercent: 18.0,
            lineTotal: 9440.0,
          ),
        ],
        createdAt: DateTime.now(),
      );

      db.createPurchase(purchase);

      final updatedFp = db.finishedProducts.firstWhere((f) => f.id == fpId);
      // Stock updated: 5 + 20 = 25
      expect(updatedFp.currentStock, 25.0);
      // Master cost price directly updated to landed cost including transportation: 420.0
      expect(updatedFp.costPrice, 420.0);
    });

    testWidgets('5. Master Module UI: Raw Material Master and Product Master display Purchase Cost / Price columns',
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
          id: 'RM-TEST-1',
          name: 'Profile 6063',
          itemCode: 'RAW-6063',
          categoryId: 'cat-1',
          categoryName: 'Metals',
          unit: 'MTR',
          currentStock: 10.0,
          openingStock: 10.0,
          minimumStock: 5.0,
          reorderLevel: 8.0,
          defaultPurchasePrice: 200.0,
          gstPercent: 18.0,
          preferredVendorIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      db.finishedProducts = [
        FinishedProduct(
          id: 'FP-TEST-1',
          name: 'Pendant 01',
          itemCode: 'FP-01',
          categoryId: 'cat-2',
          categoryName: 'Lighting',
          unit: 'PCS',
          currentStock: 5.0,
          openingStock: 5.0,
          minimumStock: 2.0,
          costPrice: 500.0,
          dealerSellingPrice: 800.0,
          customerSellingPrice: 1200.0,
          gstPercent: 18.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // 1. Verify Raw Material Master column header
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: RawMaterialMasterScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PURCHASE COST (₹)'), findsOneWidget);

      // 2. Verify Product Master column header
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ProductMasterScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PURCHASE / COST PRICE (₹)'), findsOneWidget);
    });

    testWidgets('6. Direct Auto-Calculation: CreatePurchaseScreen auto-populates transportation charge from item in master',
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
          id: 'RM-AUTO-1',
          name: 'Steel Bar Grade A',
          itemCode: 'RAW-STEEL-01',
          categoryId: 'cat-1',
          categoryName: 'Metals',
          unit: 'KG',
          currentStock: 50.0,
          openingStock: 50.0,
          minimumStock: 10.0,
          reorderLevel: 20.0,
          defaultPurchasePrice: 100.0,
          transportationCharge: 15.0,
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

      // Tap "Add Item" button
      final addItemBtn = find.text('Add Raw Material');
      expect(addItemBtn, findsOneWidget);
      await tester.tap(addItemBtn);
      await tester.pumpAndSettle();

      // Tap "Add to Order" button in dialog
      final addToOrderBtn = find.text('Add to Order');
      expect(addToOrderBtn, findsOneWidget);
      await tester.tap(addToOrderBtn);
      await tester.pumpAndSettle();

      // Transportation should now be auto-filled from 1 unit * 15.0 = 15
      expect(find.text('15'), findsWidgets);
      // Grand Total = 100 + 18 (GST) + 15 (Trans) = ₹133
      expect(find.text(Formatters.formatCurrency(133.0)), findsWidgets);
      expect(find.byType(TotalPurchaseCostCard), findsNothing);
    });
  });
}
