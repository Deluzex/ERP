import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/purchase_model.dart';
import 'package:frontend/core/api/purchases_api_service.dart';

void main() {
  group('Purchase Model & API Binding Test Suite (Phase 3)', () {
    test('PurchaseLineItem.fromJson parses backend raw material line correctly', () {
      final json = {
        'id': 'item-101',
        'purchaseId': 'pur-101',
        'itemType': 'rawMaterial',
        'rawMaterialId': 'rm-uuid-1',
        'rawMaterialName': 'Aluminum Ingot 6063',
        'rawMaterialCode': 'RM-AL-6063',
        'quantity': 25.5,
        'unit': 'kg',
        'rate': 220.0,
        'discountAmount': 100.0,
        'gstPercent': 18.0,
        'taxableAmount': 5510.0,
        'cgstAmount': 495.9,
        'sgstAmount': 495.9,
        'igstAmount': 0.0,
        'lineTotal': 6501.8,
      };

      final item = PurchaseLineItem.fromJson(json);

      expect(item.itemType, PurchaseItemType.rawMaterial);
      expect(item.rawMaterialId, 'rm-uuid-1');
      expect(item.displayName, 'Aluminum Ingot 6063');
      expect(item.displayCode, 'RM-AL-6063');
      expect(item.quantity, 25.5);
      expect(item.rate, 220.0);
      expect(item.discountAmount, 100.0);
      expect(item.gstPercent, 18.0);
      expect(item.taxableAmount, 5510.0);
      expect(item.cgstAmount, 495.9);
      expect(item.sgstAmount, 495.9);
      expect(item.igstAmount, 0.0);
      expect(item.lineTotal, 6501.8);
    });

    test('PurchaseLineItem.toJson serializes to match NestJS PurchaseLineItemDto', () {
      final item = PurchaseLineItem(
        itemType: PurchaseItemType.finishedProduct,
        finishedProductId: 'fp-uuid-1',
        finishedProductName: 'Slim Profile Handle 128mm',
        finishedProductCode: 'FP-SPH-128',
        quantity: 100.0,
        unit: 'PCS',
        rate: 85.0,
        discountAmount: 0.0,
        gstPercent: 18.0,
        lineTotal: 10030.0,
      );

      final json = item.toJson();

      expect(json['itemType'], 'finishedProduct');
      expect(json['finishedProductId'], 'fp-uuid-1');
      expect(json['finishedProductName'], 'Slim Profile Handle 128mm');
      expect(json['quantity'], 100.0);
      expect(json['unit'], 'PCS');
      expect(json['rate'], 85.0);
      expect(json['lineTotal'], 10030.0);
    });

    test('Purchase.fromJson parses complete backend purchase with items', () {
      final json = {
        'id': 'pur-2026-001',
        'purchaseNumber': 'PO-2026-0001',
        'purchaseDate': '2026-09-16T10:00:00.000Z',
        'vendorId': 'ven-uuid-1',
        'vendorName': 'Apex Metals Corp',
        'vendorInvoiceNumber': 'INV-9901',
        'invoiceDate': '2026-09-16T10:00:00.000Z',
        'purchaseType': 'rawMaterial',
        'subtotalAmount': '10000.00',
        'discountAmount': '0.00',
        'taxableAmount': '10000.00',
        'cgstAmount': '900.00',
        'sgstAmount': '900.00',
        'igstAmount': '0.00',
        'gstAmount': '1800.00',
        'totalAmount': '11800.00',
        'paidAmount': '5000.00',
        'pendingAmount': '6800.00',
        'paymentMode': 'bankTransfer',
        'status': 'partialPaid',
        'notes': 'Urgent raw material procurement',
        'createdAt': '2026-09-16T10:00:00.000Z',
        'items': [
          {
            'itemType': 'rawMaterial',
            'rawMaterialId': 'rm-uuid-1',
            'quantity': 50.0,
            'unit': 'kg',
            'rate': 200.0,
            'lineTotal': 11800.0,
          }
        ],
      };

      final p = Purchase.fromJson(json);

      expect(p.id, 'pur-2026-001');
      expect(p.purchaseNumber, 'PO-2026-0001');
      expect(p.vendorName, 'Apex Metals Corp');
      expect(p.vendorInvoiceNumber, 'INV-9901');
      expect(p.purchaseType, PurchaseItemType.rawMaterial);
      expect(p.status, PurchaseStatus.partialPaid);
      expect(p.statusLabel, 'Partially Paid');
      expect(p.totalAmount, 11800.00);
      expect(p.paidAmount, 5000.00);
      expect(p.pendingAmount, 6800.00);
      expect(p.items.length, 1);
      expect(p.items[0].quantity, 50.0);
    });

    test('Purchase.toJson serializes correctly for POST /api/v1/purchases', () {
      final p = Purchase(
        id: 'temp-id',
        purchaseNumber: 'PO-2026-0099',
        purchaseDate: DateTime.parse('2026-09-16T12:00:00.000Z'),
        vendorId: 'ven-456',
        vendorName: 'Zenith Hardware',
        vendorInvoiceNumber: 'INV-4567',
        invoiceDate: DateTime.parse('2026-09-16T12:00:00.000Z'),
        purchaseType: PurchaseItemType.finishedProduct,
        items: [
          PurchaseLineItem(
            itemType: PurchaseItemType.finishedProduct,
            finishedProductId: 'fp-789',
            finishedProductName: 'Cabinet Knob',
            quantity: 200.0,
            unit: 'PCS',
            rate: 45.0,
            lineTotal: 10620.0,
          ),
        ],
        totalAmount: 10620.0,
        paidAmount: 10620.0,
        pendingAmount: 0.0,
        paymentMode: PaymentMode.upi,
        status: PurchaseStatus.paid,
        createdAt: DateTime.now(),
      );

      final json = p.toJson();

      expect(json['vendorId'], 'ven-456');
      expect(json['vendorName'], 'Zenith Hardware');
      expect(json['vendorInvoiceNumber'], 'INV-4567');
      expect(json['purchaseType'], 'finishedProduct');
      expect(json['status'], 'paid');
      expect(json['paymentMode'], 'upi');
      expect(json['totalAmount'], 10620.0);
      expect(json['paidAmount'], 10620.0);
      expect(json['pendingAmount'], 0.0);
      expect(json['items'], isA<List>());
      expect((json['items'] as List).length, 1);
    });

    test('Purchase & PurchaseLineItem serialize and parse transportation fields with backward compatibility', () {
      final json = {
        'id': 'pur-2026-002',
        'purchaseNumber': 'PO-2026-0002',
        'purchaseDate': '2026-10-16T00:00:00.000Z',
        'vendorId': 'ven-uuid-1',
        'vendorName': 'Apex Metals Corp',
        'vendorInvoiceNumber': 'INV-9902',
        'invoiceDate': '2026-10-16T00:00:00.000Z',
        'purchaseType': 'rawMaterial',
        'subtotalAmount': '40000.00',
        'discountAmount': '0.00',
        'taxableAmount': '40000.00',
        'cgstAmount': '3600.00',
        'sgstAmount': '3600.00',
        'igstAmount': '0.00',
        'gstAmount': '7200.00',
        'transportationCharges': 2000.0,
        'totalAmount': '49200.00',
        'paidAmount': '0.00',
        'pendingAmount': '49200.00',
        'paymentMode': 'credit',
        'status': 'saved',
        'items': [
          {
            'itemType': 'rawMaterial',
            'rawMaterialId': 'rm-uuid-1',
            'quantity': 100.0,
            'unit': 'MTR',
            'rate': 300.0,
            'lineTotal': 35400.0,
            'transportationCost': 1500.0,
            'landedRate': 315.0,
          },
          {
            'itemType': 'finishedProduct',
            'finishedProductId': 'fp-uuid-1',
            'quantity': 10.0,
            'unit': 'PCS',
            'rate': 1000.0,
            'lineTotal': 11800.0,
            'transportationCost': 500.0,
            'landedRate': 1050.0,
          },
        ],
      };

      final p = Purchase.fromJson(json);

      expect(p.transportationCharges, 2000.0);
      expect(p.items.length, 2);
      expect(p.items[0].transportationCost, 1500.0);
      expect(p.items[0].landedRate, 315.0);
      expect(p.items[1].transportationCost, 500.0);
      expect(p.items[1].landedRate, 1050.0);

      // Verify toJson serialization
      final serialized = p.toJson();
      expect(serialized['transportationCharges'], 2000.0);
      expect((serialized['items'] as List)[0]['transportationCost'], 1500.0);
      expect((serialized['items'] as List)[0]['landedRate'], 315.0);

      // Historical purchase without transportation charges defaults to 0.0
      final historical = Purchase.fromJson({
        'id': 'hist-1',
        'purchaseNumber': 'PO-HIST-1',
        'totalAmount': 5000.0,
        'paidAmount': 5000.0,
        'pendingAmount': 0.0,
        'status': 'paid',
        'items': [
          {
            'itemType': 'rawMaterial',
            'quantity': 10.0,
            'rate': 500.0,
            'lineTotal': 5000.0,
          }
        ],
      });
      expect(historical.transportationCharges, 0.0);
      expect(historical.items[0].transportationCost, 0.0);
      expect(historical.items[0].landedRate, 500.0);
    });

    test('PurchaseLineItem.allocateTransportation accurately calculates prorated landed cost and resolves paisa delta', () {
      final items = [
        PurchaseLineItem(
          itemType: PurchaseItemType.rawMaterial,
          rawMaterialId: 'rm-1',
          quantity: 100.0,
          unit: 'MTR',
          rate: 300.0,
          discountAmount: 0.0,
          lineTotal: 35400.0,
        ),
        PurchaseLineItem(
          itemType: PurchaseItemType.finishedProduct,
          finishedProductId: 'fp-1',
          quantity: 10.0,
          unit: 'PCS',
          rate: 1000.0,
          discountAmount: 0.0,
          lineTotal: 11800.0,
        ),
      ];

      final allocated = PurchaseLineItem.allocateTransportation(
        items: items,
        transportationCharges: 2000.0,
      );

      expect(allocated.length, 2);
      // Item 1: 30,000 / 40,000 * 2000 = 1500.00
      expect(allocated[0].transportationCost, 1500.0);
      expect(allocated[0].landedRate, 315.0); // (30000 + 1500) / 100

      // Item 2: 10,000 / 40,000 * 2000 = 500.00
      expect(allocated[1].transportationCost, 500.0);
      expect(allocated[1].landedRate, 1050.0); // (10000 + 500) / 10

      // Sum equals total transportation
      expect(allocated[0].transportationCost + allocated[1].transportationCost, 2000.0);

      // Edge case: Odd paisa split (e.g. 1000 charges split over 3 items with values 1000, 1000, 1000)
      final oddItems = [
        PurchaseLineItem(quantity: 1.0, unit: 'PCS', rate: 1000.0, lineTotal: 1000.0),
        PurchaseLineItem(quantity: 1.0, unit: 'PCS', rate: 1000.0, lineTotal: 1000.0),
        PurchaseLineItem(quantity: 1.0, unit: 'PCS', rate: 1000.0, lineTotal: 1000.0),
      ];
      final oddAllocated = PurchaseLineItem.allocateTransportation(
        items: oddItems,
        transportationCharges: 100.0,
      );
      final sumAllocated = oddAllocated.fold<double>(0.0, (s, i) => s + i.transportationCost);
      expect(double.parse(sumAllocated.toStringAsFixed(2)), 100.0);

      // Edge case: Zero transportation
      final zeroAllocated = PurchaseLineItem.allocateTransportation(
        items: items,
        transportationCharges: 0.0,
      );
      expect(zeroAllocated[0].transportationCost, 0.0);
      expect(zeroAllocated[0].landedRate, 300.0);

      // Edge case: Zero subtotal (rate = 0 or 100% discount)
      final freeItems = [
        PurchaseLineItem(quantity: 10.0, unit: 'PCS', rate: 0.0, lineTotal: 0.0),
        PurchaseLineItem(quantity: 10.0, unit: 'PCS', rate: 0.0, lineTotal: 0.0),
      ];
      final freeAllocated = PurchaseLineItem.allocateTransportation(
        items: freeItems,
        transportationCharges: 500.0,
      );
      expect(freeAllocated[0].transportationCost + freeAllocated[1].transportationCost, 500.0);
      expect(freeAllocated[0].landedRate, 25.0); // 250 / 10
    });

    test('PurchasesApiService instantiates without error', () {
      final api = PurchasesApiService();
      expect(api, isNotNull);
    });
  });
}
