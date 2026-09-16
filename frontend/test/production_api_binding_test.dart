import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/production_model.dart';
import 'package:frontend/core/api/production_api_service.dart';

void main() {
  group('Production Model & API Binding Test Suite (Phase 4)', () {
    test('ProductionRawMaterialUsage.fromJson parses backend raw material usage correctly', () {
      final json = {
        'rawMaterialId': 'rm-uuid-1',
        'rawMaterialName': 'Aluminum Ingot 6063',
        'rawMaterialCode': 'RM-AL-6063',
        'quantityUsed': 30.5,
        'unit': 'Kg',
        'unitCost': 220.0,
        'totalCost': 6710.0,
      };

      final usage = ProductionRawMaterialUsage.fromJson(json);

      expect(usage.rawMaterialId, 'rm-uuid-1');
      expect(usage.rawMaterialName, 'Aluminum Ingot 6063');
      expect(usage.rawMaterialCode, 'RM-AL-6063');
      expect(usage.quantityUsed, 30.5);
      expect(usage.unit, 'Kg');
      expect(usage.unitCost, 220.0);
      expect(usage.totalCost, 6710.0);
    });

    test('ProductionRawMaterialUsage.toJson serializes correctly', () {
      final usage = ProductionRawMaterialUsage(
        rawMaterialId: 'rm-uuid-2',
        rawMaterialName: 'Zinc Alloy #3',
        rawMaterialCode: 'RM-ZN-003',
        quantityUsed: 15.0,
        unit: 'Kg',
        unitCost: 150.0,
        totalCost: 2250.0,
      );

      final json = usage.toJson();

      expect(json['rawMaterialId'], 'rm-uuid-2');
      expect(json['rawMaterialName'], 'Zinc Alloy #3');
      expect(json['quantityUsed'], 15.0);
      expect(json['totalCost'], 2250.0);
    });

    test('ProductionOrder.fromJson parses backend production order correctly', () {
      final json = {
        'id': 'po-uuid-1',
        'productionNumber': 'PRD-2026-0001',
        'finishedProductId': 'fp-uuid-1',
        'finishedProductName': 'Profile Handle 128mm',
        'finishedProductCode': 'FP-PH-128',
        'unit': 'Pcs',
        'plannedQuantity': 100.0,
        'actualQuantityProduced': 100.0,
        'rawMaterialCost': 6710.0,
        'labourCost': 500.0,
        'otherExpenses': 200.0,
        'totalProductionCost': 7410.0,
        'costPerUnit': 74.1,
        'productionDate': '2026-09-16T12:00:00.000Z',
        'status': 'completed',
        'salesOrderId': 'so-uuid-1',
        'salesOrderNumber': 'SO-2026-001',
        'notes': 'Production run for batch A1',
        'createdAt': '2026-09-16T12:00:00.000Z',
        'isDeleted': false,
        'rawMaterials': [
          {
            'rawMaterialId': 'rm-uuid-1',
            'rawMaterialName': 'Aluminum Ingot 6063',
            'rawMaterialCode': 'RM-AL-6063',
            'quantityUsed': 30.5,
            'unit': 'Kg',
            'unitCost': 220.0,
            'totalCost': 6710.0,
          }
        ],
      };

      final order = ProductionOrder.fromJson(json);

      expect(order.id, 'po-uuid-1');
      expect(order.productionNumber, 'PRD-2026-0001');
      expect(order.finishedProductId, 'fp-uuid-1');
      expect(order.finishedProductName, 'Profile Handle 128mm');
      expect(order.finishedProductCode, 'FP-PH-128');
      expect(order.unit, 'Pcs');
      expect(order.plannedQuantity, 100.0);
      expect(order.actualQuantityProduced, 100.0);
      expect(order.rawMaterialCost, 6710.0);
      expect(order.labourCost, 500.0);
      expect(order.otherExpenses, 200.0);
      expect(order.totalProductionCost, 7410.0);
      expect(order.costPerUnit, 74.1);
      expect(order.status, ProductionStatus.completed);
      expect(order.statusLabel, 'Completed');
      expect(order.salesOrderId, 'so-uuid-1');
      expect(order.notes, 'Production run for batch A1');
      expect(order.rawMaterialsUsed.length, 1);
      expect(order.rawMaterialsUsed.first.rawMaterialName, 'Aluminum Ingot 6063');
    });

    test('ProductionOrder.toJson serializes to match NestJS CreateProductionOrderDto', () {
      final order = ProductionOrder(
        id: 'po-uuid-2',
        productionNumber: 'PRD-2026-0002',
        finishedProductId: 'fp-uuid-1',
        finishedProductName: 'Profile Handle 128mm',
        finishedProductCode: 'FP-PH-128',
        unit: 'Pcs',
        plannedQuantity: 50.0,
        actualQuantityProduced: 50.0,
        rawMaterialsUsed: [
          ProductionRawMaterialUsage(
            rawMaterialId: 'rm-uuid-1',
            rawMaterialName: 'Aluminum Ingot 6063',
            rawMaterialCode: 'RM-AL-6063',
            quantityUsed: 15.0,
            unit: 'Kg',
            unitCost: 220.0,
            totalCost: 3300.0,
          ),
        ],
        rawMaterialCost: 3300.0,
        labourCost: 250.0,
        otherExpenses: 100.0,
        totalProductionCost: 3650.0,
        costPerUnit: 73.0,
        productionDate: DateTime.parse('2026-09-16T10:00:00.000Z'),
        status: ProductionStatus.completed,
        createdAt: DateTime.parse('2026-09-16T10:00:00.000Z'),
      );

      final json = order.toJson();

      expect(json['id'], 'po-uuid-2');
      expect(json['productionNumber'], 'PRD-2026-0002');
      expect(json['finishedProductId'], 'fp-uuid-1');
      expect(json['plannedQuantity'], 50.0);
      expect(json['actualQuantityProduced'], 50.0);
      expect(json['status'], 'completed');
      expect(json['rawMaterials'], isA<List>());
      expect((json['rawMaterials'] as List).length, 1);
    });

    test('ProductionApiService instantiates without error', () {
      final api = ProductionApiService();
      expect(api, isNotNull);
    });
  });
}
