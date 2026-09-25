import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/architect_model.dart';
import 'package:frontend/core/models/customer_model.dart';
import 'package:frontend/core/models/dealer_model.dart';
import 'package:frontend/core/models/finished_product_model.dart';
import 'package:frontend/core/models/raw_material_model.dart';
import 'package:frontend/core/models/rbac_models.dart';
import 'package:frontend/core/models/vendor_model.dart';
import 'package:frontend/core/api/roles_api_service.dart';

void main() {
  group('Full-Stack Masters & RBAC Integration Test Suite', () {
    test('Vendor model JSON serialization matches NestJS DTO contract', () {
      final vendor = Vendor(
        id: 'VEN-001',
        name: 'Apex Industrial Parts',
        contactPerson: 'Rajesh Sharma',
        mobile: '9876543210',
        email: 'apex@example.com',
        gstNumber: '24AAACH1234F1Z5',
        panNumber: 'AAACH1234F',
        address: 'GIDC, Ahmedabad',
        paymentTerms: 'Net 30 Days',
        creditLimit: 500000.0,
        createdAt: DateTime.now(),
      );

      final json = vendor.toJson();
      expect(json['name'], 'Apex Industrial Parts');
      expect(json['gstNumber'], '24AAACH1234F1Z5');
      expect(json['creditLimit'], 500000.0);

      final fromJson = Vendor.fromJson({
        'id': 'a655c645-5c97-457d-b67a-92abaaaecc8d',
        'name': 'Apex Industrial Parts',
        'contact_person': 'Rajesh Sharma',
        'mobile': '9876543210',
        'email': 'apex@example.com',
        'gst_number': '24AAACH1234F1Z5',
        'pan_number': 'AAACH1234F',
        'address': 'GIDC, Ahmedabad',
        'payment_terms': 'Net 30 Days',
        'credit_limit': '500000.00',
        'outstanding_balance': '0.00',
        'is_deleted': false,
        'created_at': '2026-09-16T10:00:00.000Z',
      });
      expect(fromJson.id, 'a655c645-5c97-457d-b67a-92abaaaecc8d');
      expect(fromJson.contactPerson, 'Rajesh Sharma');
      expect(fromJson.creditLimit, 500000.0);
    });

    test('Customer model JSON serialization & dual architect link matches DTO contract', () {
      final customer = Customer(
        id: 'CUST-001',
        name: 'Adani Shantigram Estate',
        mobile: '9825012345',
        email: 'procurement@shantigram.in',
        gstNumber: '24AAACO1234F1Z6',
        address: 'SG Highway, Ahmedabad',
        isAlsoArchitect: true,
        linkedArchitectId: '00000000-0000-0000-0000-000000000201',
        createdAt: DateTime.now(),
      );

      final json = customer.toJson();
      expect(json['name'], 'Adani Shantigram Estate');
      expect(json['gstNumber'], '24AAACO1234F1Z6');
      expect(json['isAlsoArchitect'], true);
      expect(json['linkedArchitectId'], '00000000-0000-0000-0000-000000000201');
    });

    test('Dealer model JSON serialization matches DTO contract', () {
      final dealer = Dealer(
        id: 'DLR-001',
        name: 'Ganesh Lighting Gallery',
        companyName: 'Ganesh Lights LLP',
        contactPerson: 'Harish Patel',
        mobile: '9898011223',
        email: 'sales@ganeshlighting.com',
        gstNumber: '24AAACG5678H1Z8',
        address: 'Relief Road, Ahmedabad',
        createdAt: DateTime.now(),
      );

      final json = dealer.toJson();
      expect(json['name'], 'Ganesh Lights LLP');
      expect(json['companyName'], 'Ganesh Lights LLP');
      expect(json['gstNumber'], '24AAACG5678H1Z8');
    });

    test('Architect model JSON serialization matches DTO contract', () {
      final architect = Architect(
        id: 'ARC-001',
        name: 'Ar. Sanjay Puri',
        companyName: 'Sanjay Puri Architects',
        mobile: '9820098200',
        email: 'studio@sanjaypuri.com',
        gstNumber: '27AAACS9988G1Z3',
        address: 'Worli Sea Face, Mumbai',
        defaultCommissionRate: 7.5,
        isAlsoCustomer: true,
        linkedCustomerId: '00000000-0000-0000-0000-000000000301',
        createdAt: DateTime.now(),
      );

      final json = architect.toJson();
      expect(json['name'], 'Ar. Sanjay Puri');
      expect(json['defaultCommissionRate'], 7.5);
      expect(json['isAlsoCustomer'], true);
      expect(json['linkedCustomerId'], '00000000-0000-0000-0000-000000000301');
    });

    test('RawMaterial and FinishedProduct models serialize correctly with category UUID and unitId', () {
      final rm = RawMaterial(
        id: 'RM-001',
        name: 'Extruded Aluminum Profile 6063-T6',
        itemCode: 'RAW-ALU-6063',
        categoryId: '3c4689f6-c2c9-4afc-8b69-8c570100f96d',
        categoryName: 'Raw Metals & Aluminum',
        unitId: '9edf95d2-b4d8-4978-9663-71d79535681a',
        unit: 'MTR',
        currentStock: 450.0,
        openingStock: 450.0,
        minimumStock: 100.0,
        reorderLevel: 150.0,
        defaultPurchasePrice: 285.0,
        gstPercent: 18.0,
        preferredVendorIds: ['a655c645-5c97-457d-b67a-92abaaaecc8d'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final rmJson = rm.toJson();
      expect(rmJson['itemCode'], 'RAW-ALU-6063');
      expect(rmJson['categoryId'], '3c4689f6-c2c9-4afc-8b69-8c570100f96d');
      expect(rmJson['unitId'], '9edf95d2-b4d8-4978-9663-71d79535681a');
      expect(rmJson['defaultPurchasePrice'], 285.0);

      final fp = FinishedProduct(
        id: 'FP-001',
        name: 'Blazon Architectural Linear Pendant 40W',
        itemCode: 'BLZ-LIN-40W',
        categoryId: 'afcf9413-c2a6-4fe7-902f-f29a5757dcee',
        categoryName: 'Pendants & Chandeliers',
        unitId: '9edf95d2-b4d8-4978-9663-71d79535681a',
        unit: 'PCS',
        currentStock: 35.0,
        openingStock: 35.0,
        minimumStock: 10.0,
        costPrice: 2200.0,
        dealerSellingPrice: 3800.0,
        customerSellingPrice: 4800.0,
        gstPercent: 18.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final fpJson = fp.toJson();
      expect(fpJson['itemCode'], 'BLZ-LIN-40W');
      expect(fpJson['categoryId'], 'afcf9413-c2a6-4fe7-902f-f29a5757dcee');
      expect(fpJson['dealerSellingPrice'], 3800.0);
      expect(fpJson['customerSellingPrice'], 4800.0);
    });

    test('RolesApiService maps permission strings bidirectionally', () {
      final permStrings = [
        'dashboard.view',
        'sales.create',
        'sales.edit',
        'inventory.approve',
        'masters.delete',
      ];

      final permMap = RolesApiService.permissionStringsToMap(permStrings);
      expect(permMap[ErpModule.dashboard]!.contains(ErpAction.view), true);
      expect(permMap[ErpModule.sales]!.contains(ErpAction.create), true);
      expect(permMap[ErpModule.sales]!.contains(ErpAction.edit), true);
      expect(permMap[ErpModule.inventory]!.contains(ErpAction.approve), true);
      expect(permMap[ErpModule.masters]!.contains(ErpAction.delete), true);

      final convertedBack = RolesApiService.permissionMapToStrings(permMap);
      expect(convertedBack.contains('sales.create'), true);
      expect(convertedBack.contains('inventory.approve'), true);
    });
  });
}
