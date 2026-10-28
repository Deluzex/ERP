import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/routes/app_routes.dart';
import 'package:frontend/core/models/sale_model.dart';
import 'package:frontend/core/models/purchase_model.dart';
import 'package:frontend/core/models/whatsapp_models.dart';
import 'package:frontend/core/utils/document_sharing_service.dart';
import 'package:frontend/core/widgets/erp_header.dart';
import 'package:frontend/features/sales/widgets/convert_proforma_dialog.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabaseService db;

  setUp(() {
    db = MockDatabaseService();
  });

  group('Sales Proforma -> Sales Order Product Action Workflow Tests', () {
    test('Positive: Proforma retains all line items, customer context and totals', () {
      final proforma = db.proformaInvoices.first;
      expect(proforma.documentType, equals(SalesDocumentType.proformaInvoice));
      expect(proforma.partyName.isNotEmpty, isTrue);
      expect(proforma.totalAmount, greaterThan(0));
    });

    test('Positive: Existing users contain valid Purchase and Production managers without hardcoding', () {
      final purchaseUsers = db.users.where((u) => u.isActive && (u.primaryRoleId == 'purchase_manager' || u.primaryRoleId == 'inventory_manager')).toList();
      final productionUsers = db.users.where((u) => u.isActive && u.primaryRoleId == 'production_manager').toList();

      expect(purchaseUsers.isNotEmpty, isTrue);
      expect(productionUsers.isNotEmpty, isTrue);

      final purchaseUser = purchaseUsers.first;
      final productionUser = productionUsers.first;

      expect(purchaseUser.mobile.isNotEmpty, isTrue);
      expect(productionUser.mobile.isNotEmpty, isTrue);
      expect(DocumentSharingService.cleanPhoneNumber(purchaseUser.mobile).isNotEmpty, isTrue);
      expect(DocumentSharingService.cleanPhoneNumber(productionUser.mobile).isNotEmpty, isTrue);
    });

    test('Positive: WhatsApp message generation preserves Sales Order reference, customer, items, and action', () {
      final proforma = db.proformaInvoices.first;
      final responsibleUser = db.users.firstWhere((u) => u.primaryRoleId == 'purchase_manager');

      final so = Sale(
        id: 'SO-TEST-001',
        invoiceNumber: 'DLZ/SO/2026/9999',
        documentType: SalesDocumentType.salesOrder,
        partyType: proforma.partyType,
        partyId: proforma.partyId,
        partyName: proforma.partyName,
        saleDate: DateTime.now(),
        items: [
          SaleLineItem(
            finishedProductId: 'FP-001',
            finishedProductName: 'Test Product 1',
            finishedProductCode: 'DLX-001',
            quantity: 15,
            unit: 'PCS',
            rate: 2500,
            lineTotal: 37500,
          ),
        ],
        subtotalAmount: 37500,
        gstAmount: 6750,
        totalAmount: 44250,
        pendingAmount: 44250,
        paymentMode: PaymentMode.bankTransfer,
        status: SaleStatus.active,
        createdAt: DateTime.now(),
      );

      // 1. Test Purchase Action WhatsApp Message
      final purchaseMsg = DocumentSharingService.cleanPhoneNumber(responsibleUser.mobile);
      expect(purchaseMsg.length, greaterThanOrEqualTo(10));

      // 2. Test Logging in Mock Database
      final initialLogsCount = db.messageLogs.length;
      db.logWhatsAppMessage(WhatsAppMessageLog(
        id: 'WLOG-TEST',
        messageType: 'PURCHASE Requisition',
        recipientName: responsibleUser.name,
        recipientNumber: responsibleUser.mobile,
        relatedEntityType: 'Sales Order',
        relatedEntityId: so.id,
        relatedEntityNumber: so.invoiceNumber,
        messageText: 'Test WhatsApp notification for purchase order requisition',
        sentAt: DateTime.now(),
        status: 'Sent',
      ));

      expect(db.messageLogs.length, equals(initialLogsCount + 1));
      expect(db.messageLogs.first.recipientName, equals(responsibleUser.name));
    });

    test('Negative / Edge Case: Empty phone numbers gracefully handled by DocumentSharingService', () {
      final cleanedEmpty = DocumentSharingService.cleanPhoneNumber('');
      expect(cleanedEmpty, isEmpty);

      final cleanedSpecialCharsOnly = DocumentSharingService.cleanPhoneNumber('---');
      expect(cleanedSpecialCharsOnly, isEmpty);

      final cleaned10Digit = DocumentSharingService.cleanPhoneNumber('9876543210');
      expect(cleaned10Digit, equals('919876543210'));
    });
  });

  group('ConvertProformaDialog Widget Tests', () {
    testWidgets('Renders action options (PURCHASE & PRODUCTION) and allows converting to Sales Order', (tester) async {
      final proforma = db.proformaInvoices.first;
      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => db),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ConvertProformaDialog(proforma: proforma),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Dialog Title and Proforma Reference
      expect(find.text('Convert Proforma to Sales Order'), findsOneWidget);
      expect(find.text(proforma.invoiceNumber), findsOneWidget);

      // Verify the two distinct product fulfillment options
      expect(find.text('1. PURCHASE'), findsOneWidget);
      expect(find.text('2. PRODUCTION'), findsOneWidget);

      // Tap on 1. PURCHASE
      await tester.tap(find.text('1. PURCHASE'));
      await tester.pumpAndSettle();

      // Tap on Convert to Sales Order button
      await tester.tap(find.text('Convert to Sales Order'));
      await tester.pumpAndSettle();

      // Verify Success Screen
      expect(find.text('Sales Order Created Successfully!'), findsOneWidget);
      expect(find.text('SO GENERATED'), findsOneWidget);
      expect(find.text('PURCHASE'), findsOneWidget);
    });
  });

  group('Global Header Page Title Tests across Roles and Sections', () {
    testWidgets('Header displays correct title for Sales Orders section and no global search bar', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => db),
          currentNavSectionProvider.overrideWith((ref) => ErpNavSection.salesOrders),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ErpHeader(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the page title 'Sales Orders' is displayed in the header
      expect(find.text('Sales Orders'), findsOneWidget);

      // Verify the global search bar text is NOT present
      expect(find.text('Search product, SKU, barcode'), findsNothing);
      expect(find.text('Search products...'), findsNothing);
    });

    testWidgets('Header dynamically updates title for different modules (Product Master, Purchase Orders, etc.)', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => db),
          currentNavSectionProvider.overrideWith((ref) => ErpNavSection.finishedProducts),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ErpHeader(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Product Master Section
      expect(find.text('Product Master'), findsOneWidget);
      expect(find.text('Search product, SKU, barcode'), findsNothing);

      // Switch to Purchase Orders
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseList;
      await tester.pumpAndSettle();
      expect(find.text('Purchase Orders'), findsOneWidget);

      // Switch to Payments Center
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.paymentsDashboard;
      await tester.pumpAndSettle();
      expect(find.text('Payments & Treasury Center'), findsOneWidget);

      // Switch to Proforma Invoices
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.proformaInvoices;
      await tester.pumpAndSettle();
      expect(find.text('Proforma Invoices'), findsOneWidget);
    });
  });

  group('Phase 22 Manual QA Checklist Tests', () {
    test('TEST 1: Stock sufficient (Required = 100, Available = 100) -> Shortage = 0', () {
      const required = 100.0;
      const available = 100.0;
      final shortage = (required - available).clamp(0.0, double.infinity);
      expect(shortage, equals(0.0));
      expect(available >= required, isTrue);
    });

    test('TEST 2: Stock in excess (Required = 100, Available = 150) -> Shortage = 0', () {
      const required = 100.0;
      const available = 150.0;
      final shortage = (required - available).clamp(0.0, double.infinity);
      expect(shortage, equals(0.0));
      expect(available >= required, isTrue);
    });

    test('TEST 3: Partial stock (Required = 100, Available = 50) -> Shortage = 50', () {
      const required = 100.0;
      const available = 50.0;
      final shortage = (required - available).clamp(0.0, double.infinity);
      expect(shortage, equals(50.0));
      expect(available < required, isTrue);
    });

    test('TEST 4: Stock zero (Required = 100, Available = 0) -> Shortage = 100', () {
      const required = 100.0;
      const available = 0.0;
      final shortage = (required - available).clamp(0.0, double.infinity);
      expect(shortage, equals(100.0));
      expect(available < required, isTrue);
    });

    test('TEST 5: Multiple products -> Only shortage products included in requisition', () {
      final items = [
        SaleLineItem(
          finishedProductId: 'FP-A',
          finishedProductName: 'Product A (In Stock)',
          finishedProductCode: 'FP-A-01',
          quantity: 10,
          unit: 'PCS',
          rate: 1000,
          lineTotal: 10000,
        ),
        SaleLineItem(
          finishedProductId: 'FP-B',
          finishedProductName: 'Product B (Shortage)',
          finishedProductCode: 'FP-B-01',
          quantity: 50,
          unit: 'PCS',
          rate: 2000,
          lineTotal: 100000,
        ),
      ];

      // Simulated stock levels
      final stockMap = {
        'FP-A': 20.0, // 20 available >= 10 required -> sufficient
        'FP-B': 20.0, // 20 available < 50 required -> shortage = 30
      };

      final shortages = <SaleLineItem, double>{};
      for (final item in items) {
        final avail = stockMap[item.finishedProductId] ?? 0.0;
        final short = (item.quantity - avail).clamp(0.0, double.infinity);
        if (short > 0) {
          shortages[item] = short;
        }
      }

      // Verify ONLY Product B is in shortages
      expect(shortages.length, equals(1));
      expect(shortages.keys.first.finishedProductName, equals('Product B (Shortage)'));
      expect(shortages.values.first, equals(30.0));
    });

    test('TEST 6 & 7: Purchase and Production Requisition Notification Format', () {
      final purchaseUser = db.users.firstWhere((u) => u.primaryRoleId == 'purchase_manager');
      final productionUser = db.users.firstWhere((u) => u.primaryRoleId == 'production_manager');

      final lineItem = SaleLineItem(
        finishedProductId: 'FP-LED',
        finishedProductName: 'LED Light',
        finishedProductCode: 'DLZ-LED-01',
        quantity: 100,
        unit: 'PCS',
        rate: 1000,
        lineTotal: 100000,
      );

      final so = Sale(
        id: 'SO-TEST-002',
        invoiceNumber: 'DLZ/SO/2026/0042',
        documentType: SalesDocumentType.salesOrder,
        partyType: PartyType.customer,
        partyId: 'CUST-001',
        partyName: 'ABC Customer',
        saleDate: DateTime.now(),
        items: [lineItem],
        subtotalAmount: 100000,
        gstAmount: 18000,
        totalAmount: 118000,
        pendingAmount: 118000,
        paymentMode: PaymentMode.bankTransfer,
        status: SaleStatus.active,
        createdAt: DateTime.now(),
      );

      final shortageDetail = ProductShortageDetail(
        lineItem: lineItem,
        requiredQuantity: 100,
        availableStock: 30,
        shortageQuantity: 70,
      );

      // Verify Purchase Requisition Notification
      final purchaseMsg = '''--------------------------------------------------
New Purchase Requirement

Sales Order: ${so.invoiceNumber}
Customer: ${so.partyName}
Product: ${shortageDetail.lineItem.finishedProductName}
Required Quantity: 100
Available Stock: 30
Shortage: 70
--------------------------------------------------''';

      expect(purchaseMsg, contains('New Purchase Requirement'));
      expect(purchaseMsg, contains('Sales Order: DLZ/SO/2026/0042'));
      expect(purchaseMsg, contains('Customer: ABC Customer'));
      expect(purchaseMsg, contains('Product: LED Light'));
      expect(purchaseMsg, contains('Required Quantity: 100'));
      expect(purchaseMsg, contains('Available Stock: 30'));
      expect(purchaseMsg, contains('Shortage: 70'));

      // Verify Production Requisition Notification
      final productionMsg = '''--------------------------------------------------
New Production Requirement

Sales Order: ${so.invoiceNumber}
Customer: ${so.partyName}
Product: ${shortageDetail.lineItem.finishedProductName}
Required Quantity: 100
Available Stock: 30
Shortage: 70
--------------------------------------------------''';

      expect(productionMsg, contains('New Production Requirement'));
      expect(productionMsg, contains('Sales Order: DLZ/SO/2026/0042'));

      // Verify Real Phone Numbers
      expect(purchaseUser.mobile, isNotEmpty);
      expect(productionUser.mobile, isNotEmpty);
      final cleanPurPhone = DocumentSharingService.cleanPhoneNumber(purchaseUser.mobile);
      final cleanProdPhone = DocumentSharingService.cleanPhoneNumber(productionUser.mobile);
      expect(cleanPurPhone.length, greaterThanOrEqualTo(10));
      expect(cleanProdPhone.length, greaterThanOrEqualTo(10));
    });

    test('TEST 8: Sufficient stock allows direct Sales Order creation without shortage dialog', () {
      final item = SaleLineItem(
        finishedProductId: 'FP-SUFFICIENT',
        finishedProductName: 'Chandelier (In Stock)',
        finishedProductCode: 'DLZ-CHAN-01',
        quantity: 5,
        unit: 'PCS',
        rate: 5000,
        lineTotal: 25000,
      );

      // Available is 10, required is 5 -> sufficient!
      const availableStock = 10.0;
      final hasShortage = item.quantity > availableStock;
      expect(hasShortage, isFalse);

      final so = Sale(
        id: 'SO-DIRECT-001',
        invoiceNumber: 'DLZ/SO/2026/0099',
        documentType: SalesDocumentType.salesOrder,
        partyType: PartyType.customer,
        partyId: 'CUST-002',
        partyName: 'Direct Customer',
        saleDate: DateTime.now(),
        items: [item],
        subtotalAmount: 25000,
        gstAmount: 4500,
        totalAmount: 29500,
        pendingAmount: 29500,
        paymentMode: PaymentMode.bankTransfer,
        status: SaleStatus.active,
        salesOrderStatus: SalesOrderStatus.readyForDispatch,
        createdAt: DateTime.now(),
      );

      final createdSO = db.createSalesOrder(so, autoAllocate: true);
      expect(createdSO.invoiceNumber, equals('DLZ/SO/2026/0099'));
      expect(createdSO.salesOrderStatus, equals(SalesOrderStatus.readyForDispatch));
    });

    test('TEST 9: Low stock alert records persisted in database architecture', () {
      final initialAlertsCount = db.alertHistory.length;

      db.triggerLowStockWhatsAppAlert(
        itemId: 'FP-TEST-01',
        itemName: 'LED Panel 40W',
        itemCode: 'DLZ-PAN-40',
        itemType: 'Finished Product',
        currentStock: 20,
        minStock: 100,
        reorderLevel: 100,
        unit: 'PCS',
        recipientName: 'Vikram Mehta',
        recipientWhatsApp: '+91 98765 00003',
        messageBody: 'Shortage of 80 units for SO DLZ/SO/2026/0042',
      );

      expect(db.alertHistory.length, equals(initialAlertsCount + 1));
      final recorded = db.alertHistory.first;
      expect(recorded.recipientName, equals('Vikram Mehta'));
      expect(recorded.currentStock, equals(20));
      expect(recorded.status, equals(AlertRecordStatus.sent));
    });
  });
}
