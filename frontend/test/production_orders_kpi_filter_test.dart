import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/production_model.dart';

void main() {
  group('Production Orders KPI Strip vs Table Filtering (AI-TDD)', () {
    late List<ProductionOrder> mockDatabaseOrders;

    setUp(() {
      mockDatabaseOrders = [
        // Batch 1: Completed on 29 Oct 2026
        ProductionOrder(
          id: 'po-1',
          productionNumber: 'PRD-2026-0087',
          productionDate: DateTime(2026, 10, 29, 10, 0),
          finishedProductId: 'fp-1',
          finishedProductName: 'Aarix Axis Wall Light',
          finishedProductCode: 'DLX-WL-001',
          unit: 'PCS',
          plannedQuantity: 20.0,
          actualQuantityProduced: 20.0,
          status: ProductionStatus.completed,
          rawMaterialsUsed: [],
          totalProductionCost: 16000.0,
          createdAt: DateTime(2026, 10, 29, 10, 0),
        ),
        // Batch 2: Planned (Waiting Approval) on 29 Oct 2026
        ProductionOrder(
          id: 'po-2',
          productionNumber: 'PRD-2026-0058',
          productionDate: DateTime(2026, 10, 29, 9, 30),
          finishedProductId: 'fp-2',
          finishedProductName: 'Crystal Chandelier Pendant',
          finishedProductCode: 'FP-SL2-8903',
          unit: 'PCS',
          plannedQuantity: 500.0,
          actualQuantityProduced: 0.0,
          status: ProductionStatus.planned,
          rawMaterialsUsed: [],
          totalProductionCost: 0.0,
          createdAt: DateTime(2026, 10, 29, 9, 30),
        ),
        // Batch 3: Planned (Waiting Approval) on 28 Oct 2026 (Different date)
        ProductionOrder(
          id: 'po-3',
          productionNumber: 'PRD-2026-0040',
          productionDate: DateTime(2026, 10, 28, 14, 0),
          finishedProductId: 'fp-3',
          finishedProductName: 'Recessed Spotlight',
          finishedProductCode: 'FP-SL1-8903',
          unit: 'PCS',
          plannedQuantity: 15.0,
          actualQuantityProduced: 0.0,
          status: ProductionStatus.planned,
          rawMaterialsUsed: [],
          totalProductionCost: 0.0,
          createdAt: DateTime(2026, 10, 28, 14, 0),
        ),
        // Batch 4: In Progress on 27 Oct 2026
        ProductionOrder(
          id: 'po-4',
          productionNumber: 'PRD-2026-0030',
          productionDate: DateTime(2026, 10, 27, 11, 0),
          finishedProductId: 'fp-1',
          finishedProductName: 'Aarix Axis Wall Light',
          finishedProductCode: 'DLX-WL-001',
          unit: 'PCS',
          plannedQuantity: 30.0,
          actualQuantityProduced: 10.0,
          status: ProductionStatus.inProgress,
          rawMaterialsUsed: [],
          totalProductionCost: 8000.0,
          createdAt: DateTime(2026, 10, 27, 11, 0),
        ),
        // Batch 5: Deleted order (should be excluded from both)
        ProductionOrder(
          id: 'po-5',
          productionNumber: 'PRD-2026-0020',
          productionDate: DateTime(2026, 10, 25, 9, 0),
          finishedProductId: 'fp-4',
          finishedProductName: 'Wall Sconce',
          finishedProductCode: 'DLX-WS-002',
          unit: 'PCS',
          plannedQuantity: 10.0,
          actualQuantityProduced: 0.0,
          status: ProductionStatus.cancelled,
          isDeleted: true,
          rawMaterialsUsed: [],
          totalProductionCost: 0.0,
          createdAt: DateTime(2026, 10, 25, 9, 0),
        ),
      ];
    });

    Map<String, int> computeKpiMetrics(List<ProductionOrder> allOrders) {
      return {
        'total': allOrders.length,
        'waiting': allOrders.where((o) => o.status == ProductionStatus.planned).length,
        'inProgress': allOrders.where((o) => o.status == ProductionStatus.inProgress).length,
        'completed': allOrders.where((o) => o.status == ProductionStatus.completed).length,
      };
    }

    test('Positive case: Overall KPI strip reflects non-deleted totals accurately', () {
      final allOrders = mockDatabaseOrders.where((o) => !o.isDeleted).toList();
      final kpi = computeKpiMetrics(allOrders);

      expect(kpi['total'], 4); // 5 minus 1 deleted
      expect(kpi['waiting'], 2);
      expect(kpi['inProgress'], 1);
      expect(kpi['completed'], 1);
    });

    test('Table date filter isolates table rows without altering KPI strip', () {
      final allOrders = mockDatabaseOrders.where((o) => !o.isDeleted).toList();
      final initialKpi = computeKpiMetrics(allOrders);

      // User filters table to 29 Oct 2026
      final filterDate = DateTime(2026, 10, 29);
      final filteredTableOrders = allOrders.where((o) {
        return o.productionDate.year == filterDate.year &&
            o.productionDate.month == filterDate.month &&
            o.productionDate.day == filterDate.day;
      }).toList();

      // Table is filtered from 4 to 2 items
      expect(filteredTableOrders.length, 2);
      expect(filteredTableOrders.map((o) => o.productionNumber), containsAll(['PRD-2026-0087', 'PRD-2026-0058']));

      // KPI strip remains bound to allOrders and does NOT shrink
      final kpiAfterFilter = computeKpiMetrics(allOrders);
      expect(kpiAfterFilter, equals(initialKpi));
      expect(kpiAfterFilter['total'], 4);
      expect(kpiAfterFilter['waiting'], 2);
    });

    test('Table status filter narrows table records but preserves KPI overview', () {
      final allOrders = mockDatabaseOrders.where((o) => !o.isDeleted).toList();
      final initialKpi = computeKpiMetrics(allOrders);

      // User filters table by 'COMPLETED'
      final filteredByStatus = allOrders.where((o) => o.status == ProductionStatus.completed).toList();

      expect(filteredByStatus.length, 1);
      expect(filteredByStatus.first.productionNumber, 'PRD-2026-0087');

      // KPI cards remain consistent with all recorded orders
      expect(computeKpiMetrics(allOrders), equals(initialKpi));
    });

    test('Search filter on table has zero effect on the KPI cards summary', () {
      final allOrders = mockDatabaseOrders.where((o) => !o.isDeleted).toList();
      final initialKpi = computeKpiMetrics(allOrders);

      // User searches for a non-existent batch
      const query = 'XYZ-NONEXISTENT';
      final searchResults = allOrders.where((o) => o.productionNumber.contains(query)).toList();

      expect(searchResults, isEmpty);

      // Even when table is empty, the top KPI grid continues showing overall metrics
      final kpi = computeKpiMetrics(allOrders);
      expect(kpi, equals(initialKpi));
      expect(kpi['total'], 4);
    });
  });
}
