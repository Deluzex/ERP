import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/models/sale_model.dart';
import 'package:frontend/core/models/user_model.dart';
import 'package:frontend/core/models/purchase_model.dart';
import 'package:frontend/core/utils/validators.dart';
import 'package:frontend/features/sales/screens/deliveries_screen.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  group('Requirement 2: Allow 0% GST in Direct Sales & Rate Validations', () {
    // Custom GST validator matching CreateSaleScreen
    String? validateGst(String? v) {
      final nonNeg = Validators.nonNegativeNumber(v, 'GST must be 0 or greater');
      if (nonNeg != null) return nonNeg;
      final num = double.tryParse(v!.trim());
      if (num != null && num > 100) return 'GST cannot exceed 100%';
      return null;
    }

    test('GST Validator accepts 0% and 0.0%', () {
      expect(validateGst('0'), isNull);
      expect(validateGst('0.0'), isNull);
      expect(validateGst('0.00'), isNull);
    });

    test('GST Validator accepts standard tax rates 5%, 12%, 18%, 28%', () {
      expect(validateGst('5'), isNull);
      expect(validateGst('12'), isNull);
      expect(validateGst('18'), isNull);
      expect(validateGst('28'), isNull);
    });

    test('GST Validator rejects negative numbers', () {
      expect(validateGst('-1'), 'GST must be 0 or greater');
      expect(validateGst('-5.0'), 'GST must be 0 or greater');
    });

    test('GST Validator rejects empty and values over 100%', () {
      expect(validateGst(''), 'This field is required');
      expect(validateGst('   '), 'This field is required');
      expect(validateGst('101'), 'GST cannot exceed 100%');
    });

    test('SaleLineItem.calculateLineTotal computes 0 tax when GST is 0%', () {
      final lineTotal = SaleLineItem.calculateLineTotal(
        quantity: 3.0,
        rate: 1500.0,
        discountAmount: 500.0,
        gstPercent: 0.0,
      );
      // (3 * 1500) - 500 = 4000 taxable. With 0% GST -> total = 4000.0
      expect(lineTotal, 4000.0);
    });

    test('SaleLineItem lineTotal and tax splits with 0% GST', () {
      final item = SaleLineItem(
        finishedProductId: 'fp-101',
        finishedProductName: 'Track Light 0%',
        quantity: 2.0,
        rate: 1000.0,
        discountAmount: 0.0,
        gstPercent: 0.0,
        lineTotal: 2000.0,
        unit: 'pcs',
      );

      expect(item.taxableAmount, 2000.0);
      expect(item.cgstAmount, 0.0);
      expect(item.sgstAmount, 0.0);
      expect(item.igstAmount, 0.0);
      expect(item.lineTotal, 2000.0);
    });

    test('MockDatabaseService creates direct sale with 0% GST and deducts stock', () {
      final db = MockDatabaseService();
      final product = db.finishedProducts.first;
      final initialStock = product.currentStock;

      final sale = Sale(
        id: 'sale-0gst-1',
        invoiceNumber: 'INV-0GST-001',
        documentType: SalesDocumentType.invoice,
        partyType: PartyType.customer,
        partyId: db.customers.first.id,
        partyName: db.customers.first.name,
        saleDate: DateTime.now(),
        items: [
          SaleLineItem(
            finishedProductId: product.id,
            finishedProductName: product.name,
            quantity: 2.0,
            rate: 1000.0,
            discountAmount: 0.0,
            gstPercent: 0.0,
            lineTotal: 2000.0,
            unit: product.unit,
          ),
        ],
        subtotalAmount: 2000.0,
        discountAmount: 0.0,
        taxableAmount: 2000.0,
        gstAmount: 0.0,
        totalAmount: 2000.0,
        paidAmount: 2000.0,
        pendingAmount: 0.0,
        paymentMode: PaymentMode.cash,
        status: SaleStatus.paid,
        createdAt: DateTime.now(),
      );

      final created = db.createDirectSale(sale);
      expect(created.gstAmount, 0.0);
      expect(created.totalAmount, 2000.0);

      // Verify finished product stock was deducted by 2.0
      final updatedProduct = db.finishedProducts.firstWhere((p) => p.id == product.id);
      expect(updatedProduct.currentStock, initialStock - 2.0);
    });

    test('MockDatabaseService rejects zero or negative direct sale total', () {
      final db = MockDatabaseService();
      final product = db.finishedProducts.first;

      final invalidSale = Sale(
        id: 'sale-invalid-total',
        invoiceNumber: 'INV-ZERO-001',
        documentType: SalesDocumentType.invoice,
        partyType: PartyType.customer,
        partyId: db.customers.first.id,
        partyName: db.customers.first.name,
        saleDate: DateTime.now(),
        items: [
          SaleLineItem(
            finishedProductId: product.id,
            finishedProductName: product.name,
            quantity: 1.0,
            rate: 1000.0,
            discountAmount: 1000.0, // 0 total
            gstPercent: 0.0,
            lineTotal: 0.0,
            unit: product.unit,
          ),
        ],
        subtotalAmount: 1000.0,
        discountAmount: 1000.0,
        taxableAmount: 0.0,
        gstAmount: 0.0,
        totalAmount: 0.0, // Zero total
        pendingAmount: 0.0,
        paymentMode: PaymentMode.cash,
        status: SaleStatus.paid,
        createdAt: DateTime.now(),
      );

      expect(() => db.createDirectSale(invalidSale), throwsA(isA<Exception>()));
    });
  });

  group('Requirement 1: Dispatch Challan Single Invoice Lifecycle', () {
    test('Generate Invoice from Dispatch Challan marks challan invoiced and links reference', () {
      final db = MockDatabaseService();

      // Find an uninvoiced delivery
      final delivery = db.deliveries.firstWhere((d) => !d.isInvoiced);
      expect(delivery.isInvoiced, isFalse);
      expect(delivery.status, isNot(SaleStatus.invoiced));

      // Generate invoice from delivery
      final invoice = db.createSalesInvoiceFromDelivery(
        deliveryId: delivery.id,
        discountAmount: 0.0,
        initialPaidAmount: 0.0,
      );

      expect(invoice.documentType, SalesDocumentType.invoice);
      expect(invoice.deliveryReferenceId, delivery.id);

      // Check delivery document is now invoiced
      final updatedDlv = db.deliveries.firstWhere((d) => d.id == delivery.id);
      expect(updatedDlv.status, SaleStatus.invoiced);
      expect(updatedDlv.deliveryStatus, DeliveryStatus.invoiced);
      expect(updatedDlv.isInvoiced, isTrue);
      expect(updatedDlv.linkedInvoiceId, invoice.id);
      expect(updatedDlv.linkedInvoiceNumber, invoice.invoiceNumber);
    });

    test('Duplicate Invoice creation attempt for the same Challan is rejected', () {
      final db = MockDatabaseService();
      final delivery = db.deliveries.firstWhere((d) => !d.isInvoiced);

      // First creation succeeds
      db.createSalesInvoiceFromDelivery(
        deliveryId: delivery.id,
        discountAmount: 0.0,
      );

      // Second attempt must throw duplicate error
      expect(
        () => db.createSalesInvoiceFromDelivery(
          deliveryId: delivery.id,
          discountAmount: 0.0,
        ),
        throwsA(predicate((e) => e.toString().contains('Invoice already generated for this Dispatch Challan'))),
      );
    });

    test('Challan with status invoiced stays invoiced after page refresh simulation', () {
      final db = MockDatabaseService();
      final delivery = db.deliveries.firstWhere((d) => !d.isInvoiced);

      final inv = db.createSalesInvoiceFromDelivery(deliveryId: delivery.id);
      final dlv = db.deliveries.firstWhere((d) => d.id == delivery.id);

      // Simulate JSON serialization and reload
      final dlvJson = {
        'id': dlv.id,
        'invoiceNumber': dlv.invoiceNumber,
        'documentType': 'delivery',
        'deliveryReferenceId': delivery.id,
        'linkedInvoiceId': inv.id,
        'linkedInvoiceNumber': inv.invoiceNumber,
        'status': 'invoiced',
        'deliveryStatus': 'invoiced',
      };

      final reloaded = Sale.fromJson(dlvJson);
      expect(reloaded.isInvoiced, isTrue);
      expect(reloaded.status, SaleStatus.invoiced);
      expect(reloaded.deliveryStatus, DeliveryStatus.invoiced);
      expect(reloaded.linkedInvoiceId, inv.id);
    });

    testWidgets('DeliveriesScreen renders INVOICED badge and View Invoice for invoiced challan', (tester) async {
      final db = MockDatabaseService();
      final delivery = db.deliveries.firstWhere((d) => !d.isInvoiced);

      // Mark this delivery as invoiced
      db.createSalesInvoiceFromDelivery(deliveryId: delivery.id);

      await tester.binding.setSurfaceSize(const Size(1600, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DeliveriesScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // INVOICED badge should be displayed
      expect(find.text('INVOICED'), findsAtLeastNWidgets(1));

      // Open the PopupMenu for actions on the first row
      final actionButton = find.byIcon(Icons.edit_note).first;
      await tester.tap(actionButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Should show 'View Invoice' instead of 'Create Invoice'
      expect(find.text('View Invoice'), findsOneWidget);
      expect(find.text('Create Invoice'), findsNothing);
    });
  });
}
