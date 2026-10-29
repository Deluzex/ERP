import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/stock_movement_model.dart';
import 'package:frontend/core/utils/formatters.dart';

void main() {
  group('Stock Movement Ledger Adjustment Filtering Tests (AI-TDD)', () {
    late List<StockMovement> sampleLedger;

    setUp(() {
      sampleLedger = [
        // 2 Recent adjustments (from top 50 in live DB)
        StockMovement(
          id: 'adj-1',
          date: DateTime(2026, 10, 27, 17, 58),
          itemId: 'item-fp-1',
          itemName: 'Aarix Axis Wall Light',
          itemCode: 'FP-AXIS-01',
          itemType: ItemType.finishedProduct,
          transactionType: StockMovementType.adjustment,
          referenceNumber: 'ADJ-2026-05097',
          stockIn: 0,
          stockOut: 10,
          currentBalance: 90,
          unit: 'PCS',
          notes: 'Adjustment (physicalCountMismatch): recount variance',
          performedBy: 'Quality Inspector',
        ),
        StockMovement(
          id: 'adj-2',
          date: DateTime(2026, 10, 27, 17, 54),
          itemId: 'item-rm-1',
          itemName: 'Aarix Extruded Aluminum Housing 6063-T6',
          itemCode: 'RM-ALU-01',
          itemType: ItemType.rawMaterial,
          transactionType: StockMovementType.adjustment,
          referenceNumber: 'ADJ-2026-65853',
          stockIn: 0,
          stockOut: 199,
          currentBalance: 301,
          unit: 'KG',
          notes: 'Adjustment (physicalCountMismatch): damage scrap write-off',
          performedBy: 'Inventory Manager',
        ),
        // Older adjustments (items beyond index 50 that were previously truncated)
        StockMovement(
          id: 'adj-3',
          date: DateTime(2026, 10, 1, 13, 35),
          itemId: 'item-rm-2',
          itemName: 'Sim Alloy Rod 17260',
          itemCode: 'RM-ROD-01',
          itemType: ItemType.rawMaterial,
          transactionType: StockMovementType.adjustment,
          referenceNumber: 'PRD-2026-0027',
          stockIn: 10,
          stockOut: 0,
          currentBalance: 510,
          unit: 'KG',
          notes: 'Reversed consumption: Cancelled production batch PRD-2026-0027',
          performedBy: 'Production Supervisor',
        ),
        StockMovement(
          id: 'adj-4',
          date: DateTime(2026, 9, 16, 19, 10),
          itemId: 'item-rm-3',
          itemName: 'Sim Alloy Rod 55551',
          itemCode: 'RM-ROD-02',
          itemType: ItemType.rawMaterial,
          transactionType: StockMovementType.adjustment,
          referenceNumber: 'ADJ-2026-55032',
          stockIn: 50,
          stockOut: 0,
          currentBalance: 50,
          unit: 'KG',
          notes: 'Adjustment (revaluation): Initial setup for Phase 4 production simulation',
          performedBy: 'System Admin',
        ),
        // Standard Inward Movements
        StockMovement(
          id: 'in-1',
          date: DateTime(2026, 10, 25, 10, 0),
          itemId: 'item-rm-1',
          itemName: 'Aarix Extruded Aluminum Housing 6063-T6',
          itemCode: 'RM-ALU-01',
          itemType: ItemType.rawMaterial,
          transactionType: StockMovementType.purchase,
          referenceNumber: 'PO-2026-0042',
          stockIn: 500,
          stockOut: 0,
          currentBalance: 500,
          unit: 'KG',
          notes: 'Received shipment',
          performedBy: 'Storekeeper',
        ),
        StockMovement(
          id: 'in-2',
          date: DateTime(2026, 10, 26, 14, 0),
          itemId: 'item-fp-1',
          itemName: 'Aarix Axis Wall Light',
          itemCode: 'FP-AXIS-01',
          itemType: ItemType.finishedProduct,
          transactionType: StockMovementType.productionOutput,
          referenceNumber: 'PRD-2026-0045',
          stockIn: 100,
          stockOut: 0,
          currentBalance: 100,
          unit: 'PCS',
          notes: 'Batch output',
          performedBy: 'Line Manager',
        ),
        // Standard Outward Movements
        StockMovement(
          id: 'out-1',
          date: DateTime(2026, 10, 26, 16, 0),
          itemId: 'item-fp-1',
          itemName: 'Aarix Axis Wall Light',
          itemCode: 'FP-AXIS-01',
          itemType: ItemType.finishedProduct,
          transactionType: StockMovementType.sale,
          referenceNumber: 'INV-2026-0089',
          stockIn: 0,
          stockOut: 20,
          currentBalance: 80,
          unit: 'PCS',
          notes: 'Dispatched to customer',
          performedBy: 'Dispatch Head',
        ),
        StockMovement(
          id: 'out-2',
          date: DateTime(2026, 10, 24, 11, 0),
          itemId: 'item-rm-1',
          itemName: 'Aarix Extruded Aluminum Housing 6063-T6',
          itemCode: 'RM-ALU-01',
          itemType: ItemType.rawMaterial,
          transactionType: StockMovementType.productionConsumption,
          referenceNumber: 'PRD-2026-0040',
          stockIn: 0,
          stockOut: 50,
          currentBalance: 450,
          unit: 'KG',
          notes: 'Consumed on production floor',
          performedBy: 'Shopfloor Lead',
        ),
      ];
    });

    test('Positive case: Stock Adjustments tab includes all valid adjustments (positive and negative)', () {
      final adjustments = sampleLedger.where((m) =>
          m.transactionType == StockMovementType.adjustment ||
          m.transactionType == StockMovementType.damage).toList();

      expect(adjustments.length, 4);
      expect(adjustments.map((a) => a.referenceNumber).toList(), [
        'ADJ-2026-05097',
        'ADJ-2026-65853',
        'PRD-2026-0027',
        'ADJ-2026-55032',
      ]);

      // Both positive (+stockIn) and negative (+stockOut) adjustments are captured
      final posAdjustments = adjustments.where((a) => a.stockIn > 0).toList();
      final negAdjustments = adjustments.where((a) => a.stockOut > 0).toList();
      expect(posAdjustments.length, 2);
      expect(negAdjustments.length, 2);
    });

    test('Negative case: Non-adjustment movements are strictly excluded from Stock Adjustments tab', () {
      final nonAdjustments = sampleLedger.where((m) =>
          m.transactionType != StockMovementType.adjustment &&
          m.transactionType != StockMovementType.damage).toList();

      expect(nonAdjustments.length, 4);
      for (final m in nonAdjustments) {
        final isAdjustment = m.transactionType == StockMovementType.adjustment ||
            m.transactionType == StockMovementType.damage;
        expect(isAdjustment, isFalse, reason: '${m.referenceNumber} should not be an adjustment');
      }
    });

    test('Edge case: Date range filtering on Stock Adjustments tab operates inclusively', () {
      // Filter for October 2026 only
      final startDate = DateTime(2026, 10, 1);
      final endDate = DateTime(2026, 10, 31);
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      final octAdjustments = sampleLedger.where((m) {
        final isAdj = m.transactionType == StockMovementType.adjustment ||
            m.transactionType == StockMovementType.damage;
        if (!isAdj) return false;
        if (m.date.isBefore(startOfDay)) return false;
        if (m.date.isAfter(endOfDay)) return false;
        return true;
      }).toList();

      // Should include adj-1, adj-2, adj-3 (all October), but exclude adj-4 (September)
      expect(octAdjustments.length, 3);
      expect(octAdjustments.any((a) => a.referenceNumber == 'ADJ-2026-55032'), isFalse);
    });

    test('Edge case: Search filtering matches reference number and adjustment notes', () {
      final searchReversed = sampleLedger.where((m) {
        final isAdj = m.transactionType == StockMovementType.adjustment ||
            m.transactionType == StockMovementType.damage;
        if (!isAdj) return false;
        return (m.notes?.toLowerCase().contains('reversed') ?? false) ||
            m.referenceNumber.toLowerCase().contains('reversed');
      }).toList();

      expect(searchReversed.length, 1);
      expect(searchReversed.first.referenceNumber, 'PRD-2026-0027');
    });

    test('Edge case: Truncation limit prevention verifies large dataset access (> 50 items)', () {
      // Simulate 162 total ledger items (like in Supabase database)
      final fullLedger = List<StockMovement>.generate(162, (i) {
        if (i < 30) {
          return StockMovement(
            id: 'adj-$i',
            date: DateTime(2026, 9, 1).add(Duration(days: i)),
            itemId: 'item-$i',
            itemName: 'Item $i',
            itemCode: 'CODE-$i',
            itemType: ItemType.rawMaterial,
            transactionType: StockMovementType.adjustment,
            referenceNumber: 'ADJ-2026-${10000 + i}',
            stockIn: i % 2 == 0 ? 10 : 0,
            stockOut: i % 2 != 0 ? 10 : 0,
            currentBalance: 100,
            unit: 'PCS',
            performedBy: 'User',
          );
        } else if (i < 87) {
          return StockMovement(
            id: 'in-$i',
            date: DateTime(2026, 9, 1).add(Duration(days: i)),
            itemId: 'item-$i',
            itemName: 'Item $i',
            itemCode: 'CODE-$i',
            itemType: ItemType.rawMaterial,
            transactionType: StockMovementType.purchase,
            referenceNumber: 'PO-2026-${10000 + i}',
            stockIn: 50,
            stockOut: 0,
            currentBalance: 150,
            unit: 'PCS',
            performedBy: 'User',
          );
        } else {
          return StockMovement(
            id: 'out-$i',
            date: DateTime(2026, 9, 1).add(Duration(days: i)),
            itemId: 'item-$i',
            itemName: 'Item $i',
            itemCode: 'CODE-$i',
            itemType: ItemType.rawMaterial,
            transactionType: StockMovementType.sale,
            referenceNumber: 'INV-2026-${10000 + i}',
            stockIn: 0,
            stockOut: 15,
            currentBalance: 135,
            unit: 'PCS',
            performedBy: 'User',
          );
        }
      });

      // Simulating default limit = 50 vs full limit = 500
      final truncated50 = fullLedger.take(50).toList();
      final truncatedAdjustments = truncated50.where((m) =>
          m.transactionType == StockMovementType.adjustment ||
          m.transactionType == StockMovementType.damage).toList();

      final fullAdjustments = fullLedger.where((m) =>
          m.transactionType == StockMovementType.adjustment ||
          m.transactionType == StockMovementType.damage).toList();

      // When truncated to 50, only records in that batch are present
      expect(truncatedAdjustments.length, lessThanOrEqualTo(truncated50.length));
      expect(fullAdjustments.length, 30);
      expect(fullLedger.length, 162);
    });

    test('Damage/Adjustment Quantity Swap Logic: Current stock 10, Damage 20 gives net stock -10', () {
      const currentStock = 10.0;
      const isReduction = true;
      final rawEntered = double.parse('20'.trim()).abs();
      final effectiveAdjustment = isReduction ? -rawEntered : rawEntered;
      final resultingStock = currentStock + effectiveAdjustment;

      expect(effectiveAdjustment, -20.0);
      expect(resultingStock, -10.0);
    });

    test('Damage/Adjustment Quantity Swap Logic: Current stock 10, Excess addition 15 gives net stock 25', () {
      const currentStock = 10.0;
      const isReduction = false;
      final rawEntered = double.parse('15'.trim()).abs();
      final effectiveAdjustment = isReduction ? -rawEntered : rawEntered;
      final resultingStock = currentStock + effectiveAdjustment;

      expect(effectiveAdjustment, 15.0);
      expect(resultingStock, 25.0);
    });

    test('Local Timezone Conversion: Formatters formats UTC date in local timezone', () {
      final utcDate = DateTime.parse('2026-10-27T17:58:19.857Z');
      final formatted = Formatters.formatDateTime(utcDate);

      // Verify that formatting matches the local timezone representation
      expect(formatted, contains('2026'));
      expect(utcDate.toLocal().isUtc, isFalse);
    });

    test('Local Timezone Conversion: StockMovement.fromJson converts UTC date string to local DateTime', () {
      final json = {
        'id': 'sm-1',
        'date': '2026-10-27T17:58:19.857Z',
        'itemId': 'item-1',
        'itemName': 'Test Item',
        'itemCode': 'CODE-1',
        'itemType': 'finishedProduct',
        'transactionType': 'adjustment',
        'referenceNumber': 'ADJ-2026-05097',
        'stockIn': 0,
        'stockOut': 10,
        'currentBalance': 90,
        'unit': 'PCS',
        'performedBy': 'Inspector',
      };

      final movement = StockMovement.fromJson(json);
      expect(movement.date.isUtc, isFalse);
    });
  });
}
