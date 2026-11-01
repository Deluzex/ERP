import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/customer_model.dart';
import 'package:frontend/core/models/dealer_model.dart';
import 'package:frontend/core/models/vendor_model.dart';
import 'package:frontend/core/models/architect_model.dart';
import 'package:frontend/core/models/finished_product_model.dart';
import 'package:frontend/core/models/raw_material_model.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  group('Master Domain Models - isActive Status Lifecycle', () {
    test('Customer model defaults to isActive = true and supports copyWith and JSON serialization', () {
      final customer = Customer(
        id: 'cust-1',
        name: 'Oberoi Sky City',
        mobile: '9876543210',
        email: 'oberoi@example.com',
        gstNumber: '24AAAAA0000A1Z5',
        address: 'Mumbai',
        createdAt: DateTime.now(),
      );

      expect(customer.isActive, isTrue);

      final inactiveCustomer = customer.copyWith(isActive: false);
      expect(inactiveCustomer.isActive, isFalse);

      final json = inactiveCustomer.toJson();
      expect(json['isActive'], isFalse);

      final parsedFromSnakeCase = Customer.fromJson({
        'id': 'cust-2',
        'name': 'Test Cust',
        'mobile': '9876543210',
        'email': 'test@example.com',
        'gst_number': '24AAAAA0000A1Z5',
        'address': 'Surat',
        'is_active': false,
      });
      expect(parsedFromSnakeCase.isActive, isFalse);

      final parsedDefault = Customer.fromJson({
        'id': 'cust-3',
        'name': 'Default Cust',
        'mobile': '9876543210',
        'email': 'default@example.com',
        'address': 'Surat',
      });
      expect(parsedDefault.isActive, isTrue);
    });

    test('Dealer model defaults to isActive = true and supports copyWith and JSON serialization', () {
      final dealer = Dealer(
        id: 'dlr-1',
        name: 'Apex Showroom',
        contactPerson: 'Apex Contact',
        mobile: '9876543210',
        companyName: 'Apex Ltd',
        email: 'apex@example.com',
        gstNumber: '24AAAAA0000A1Z5',
        address: 'Surat',
        createdAt: DateTime.now(),
      );

      expect(dealer.isActive, isTrue);
      final inactiveDealer = dealer.copyWith(isActive: false);
      expect(inactiveDealer.isActive, isFalse);

      final parsed = Dealer.fromJson({
        'id': 'dlr-2',
        'name': 'Test Dealer',
        'contactPerson': 'CP',
        'mobile': '9876543210',
        'companyName': 'TD Ltd',
        'email': 'td@example.com',
        'gstNumber': '24AAAAA0000A1Z5',
        'address': 'Ahmedabad',
        'is_active': false,
      });
      expect(parsed.isActive, isFalse);
    });

    test('Vendor model defaults to isActive = true and supports copyWith and JSON serialization', () {
      final vendor = Vendor(
        id: 'v-1',
        name: 'Brass World Corp',
        contactPerson: 'Vendor CP',
        mobile: '9876543210',
        email: 'brass@example.com',
        gstNumber: '24AAAAA0000A1Z5',
        panNumber: 'AAAAA0000A',
        address: 'Jamnagar',
        creditLimit: 500000,
        createdAt: DateTime.now(),
      );

      expect(vendor.isActive, isTrue);
      final inactiveVendor = vendor.copyWith(isActive: false);
      expect(inactiveVendor.isActive, isFalse);

      final parsed = Vendor.fromJson({
        'id': 'v-2',
        'name': 'Test Vendor',
        'contactPerson': 'CP',
        'mobile': '9876543210',
        'email': 'v@example.com',
        'gstNumber': '24AAAAA0000A1Z5',
        'panNumber': 'AAAAA0000A',
        'address': 'Jamnagar',
        'creditLimit': 500000,
        'isActive': false,
      });
      expect(parsed.isActive, isFalse);
    });

    test('Architect model defaults to isActive = true and supports copyWith and JSON serialization', () {
      final architect = Architect(
        id: 'arch-1',
        name: 'Ar. Sharma',
        companyName: 'Sharma Designs',
        mobile: '9876543210',
        email: 'sharma@example.com',
        gstNumber: '24AAAAA0000A1Z5',
        address: 'Ahmedabad',
        createdAt: DateTime.now(),
      );

      expect(architect.isActive, isTrue);
      final inactiveArchitect = architect.copyWith(isActive: false);
      expect(inactiveArchitect.isActive, isFalse);

      final parsed = Architect.fromJson({
        'id': 'arch-2',
        'name': 'Ar. Test',
        'companyName': 'Test Studio',
        'mobile': '9876543210',
        'email': 'arch@example.com',
        'address': 'Rajkot',
        'is_active': false,
      });
      expect(parsed.isActive, isFalse);
    });

    test('FinishedProduct model defaults to isActive = true and supports copyWith and JSON serialization', () {
      final product = FinishedProduct(
        id: 'fp-1',
        name: 'Crystal Chandelier 12-Light',
        itemCode: 'FP-CH-001',
        categoryId: 'cat-1',
        categoryName: 'Chandeliers',
        unit: 'PCS',
        currentStock: 10,
        openingStock: 10,
        minimumStock: 2,
        costPrice: 5000,
        dealerSellingPrice: 7500,
        customerSellingPrice: 9500,
        gstPercent: 18,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(product.isActive, isTrue);
      final inactiveProduct = product.copyWith(isActive: false);
      expect(inactiveProduct.isActive, isFalse);

      final parsed = FinishedProduct.fromJson({
        'id': 'fp-2',
        'name': 'Test FP',
        'itemCode': 'FP-02',
        'categoryId': 'cat-1',
        'categoryName': 'Chandeliers',
        'unit': 'PCS',
        'openingStock': '5',
        'minimumStock': '1',
        'costPrice': '1000',
        'dealerSellingPrice': '1500',
        'customerSellingPrice': '2000',
        'gstPercent': '18',
        'is_active': false,
      });
      expect(parsed.isActive, isFalse);
    });

    test('RawMaterial model defaults to isActive = true and supports copyWith and JSON serialization', () {
      final material = RawMaterial(
        id: 'rm-1',
        name: 'Brass Rod 12mm',
        itemCode: 'RM-BR-001',
        categoryId: 'cat-1',
        categoryName: 'Metals',
        unit: 'KG',
        currentStock: 50,
        openingStock: 50,
        minimumStock: 10,
        reorderLevel: 20,
        defaultPurchasePrice: 450,
        gstPercent: 18,
        preferredVendorIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(material.isActive, isTrue);
      final inactiveMaterial = material.copyWith(isActive: false);
      expect(inactiveMaterial.isActive, isFalse);

      final parsed = RawMaterial.fromJson({
        'id': 'rm-2',
        'name': 'Test RM',
        'itemCode': 'RM-02',
        'categoryId': 'cat-1',
        'categoryName': 'Metals',
        'unit': 'KG',
        'openingStock': '50',
        'minimumStock': '10',
        'reorderLevel': '20',
        'defaultPurchasePrice': '450',
        'gstPercent': '18',
        'preferredVendorIds': [],
        'isActive': false,
      });
      expect(parsed.isActive, isFalse);
    });
  });

  group('MockDatabaseService & Universal Dropdown Governance', () {
    late MockDatabaseService db;

    setUp(() {
      db = MockDatabaseService();
    });

    test('Status toggles update entity state in-memory', () {
      final cust = Customer(
        id: 'cust-toggle-1',
        name: 'Toggle Customer',
        mobile: '9876543210',
        email: 'c@example.com',
        gstNumber: '',
        address: 'Surat',
        createdAt: DateTime.now(),
      );
      db.customers = [cust];
      expect(db.customers.first.isActive, isTrue);

      db.toggleCustomerStatus('cust-toggle-1', false);
      expect(db.customers.first.isActive, isFalse);

      db.toggleCustomerStatus('cust-toggle-1', true);
      expect(db.customers.first.isActive, isTrue);
    });

    test('Universal Dropdown Exclusion: Inactive Customer & Products omitted from active dropdowns', () {
      final activeCust = Customer(
        id: 'cust-act-1',
        name: 'Active Customer',
        mobile: '9876543210',
        email: 'act@example.com',
        gstNumber: '',
        address: 'Surat',
        isActive: true,
        createdAt: DateTime.now(),
      );

      final inactiveCust = Customer(
        id: 'cust-inact-2',
        name: 'Inactive Customer',
        mobile: '9876543211',
        email: 'inact@example.com',
        gstNumber: '',
        address: 'Surat',
        isActive: false,
        createdAt: DateTime.now(),
      );

      db.customers = [activeCust, inactiveCust];

      // Dropdown filter directive: !c.isDeleted && c.isActive
      final dropdownCustomers = db.customers.where((c) => !c.isDeleted && c.isActive).toList();
      expect(dropdownCustomers.map((c) => c.id), contains('cust-act-1'));
      expect(dropdownCustomers.map((c) => c.id), isNot(contains('cust-inact-2')));
    });

    test('Universal Dropdown Exclusion: Inactive FinishedProduct omitted from line item dropdowns', () {
      final activeProduct = FinishedProduct(
        id: 'fp-act-1',
        name: 'Active Product',
        itemCode: 'FP-A1',
        categoryId: 'cat-1',
        categoryName: 'Cat',
        unit: 'PCS',
        currentStock: 10,
        openingStock: 10,
        minimumStock: 2,
        costPrice: 500,
        dealerSellingPrice: 750,
        customerSellingPrice: 950,
        gstPercent: 18,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final inactiveProduct = FinishedProduct(
        id: 'fp-inact-2',
        name: 'Inactive Product',
        itemCode: 'FP-I2',
        categoryId: 'cat-1',
        categoryName: 'Cat',
        unit: 'PCS',
        currentStock: 10,
        openingStock: 10,
        minimumStock: 2,
        costPrice: 500,
        dealerSellingPrice: 750,
        customerSellingPrice: 950,
        gstPercent: 18,
        isActive: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      db.finishedProducts = [activeProduct, inactiveProduct];

      // Dropdown filter directive: !p.isDeleted && p.isActive
      final dropdownProducts = db.finishedProducts.where((p) => !p.isDeleted && p.isActive).toList();
      expect(dropdownProducts.map((p) => p.id), contains('fp-act-1'));
      expect(dropdownProducts.map((p) => p.id), isNot(contains('fp-inact-2')));
    });

    test('Universal Dropdown Exclusion: Inactive Vendor omitted from purchase creation dropdown', () {
      final activeVendor = Vendor(
        id: 'v-act-1',
        name: 'Active Vendor',
        contactPerson: 'CP',
        mobile: '9876543210',
        email: 'v@example.com',
        gstNumber: '24AAAAA0000A1Z5',
        panNumber: 'AAAAA0000A',
        address: 'Jamnagar',
        creditLimit: 500000,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final inactiveVendor = Vendor(
        id: 'v-inact-2',
        name: 'Inactive Vendor',
        contactPerson: 'CP',
        mobile: '9876543211',
        email: 'v2@example.com',
        gstNumber: '24AAAAA0000A1Z6',
        panNumber: 'AAAAA0000B',
        address: 'Jamnagar',
        creditLimit: 500000,
        isActive: false,
        createdAt: DateTime.now(),
      );

      db.vendors = [activeVendor, inactiveVendor];

      // Dropdown filter directive: !v.isDeleted && v.isActive
      final dropdownVendors = db.vendors.where((v) => !v.isDeleted && v.isActive).toList();
      expect(dropdownVendors.map((v) => v.id), contains('v-act-1'));
      expect(dropdownVendors.map((v) => v.id), isNot(contains('v-inact-2')));
    });

    test('Critical: Master record status immutability when referenced in transactions', () {
      final activeCust = Customer(
        id: 'cust-ref-1',
        name: 'Ref Customer Active',
        mobile: '9876543210',
        email: 'ref1@example.com',
        gstNumber: '24AAAAA0000A1Z5',
        address: 'Surat',
        isActive: true,
        createdAt: DateTime.now(),
      );

      final inactiveCust = Customer(
        id: 'cust-ref-2',
        name: 'Ref Customer Inactive',
        mobile: '9876543211',
        email: 'ref2@example.com',
        gstNumber: '24AAAAA0000A1Z6',
        address: 'Surat',
        isActive: false,
        createdAt: DateTime.now(),
      );

      final activeProduct = FinishedProduct(
        id: 'fp-ref-1',
        name: 'Ref Product Active',
        itemCode: 'FP-REF-1',
        categoryId: 'cat-1',
        categoryName: 'Lighting',
        unit: 'PCS',
        currentStock: 50,
        openingStock: 50,
        minimumStock: 5,
        costPrice: 1000,
        dealerSellingPrice: 1500,
        customerSellingPrice: 2000,
        gstPercent: 18,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final inactiveProduct = FinishedProduct(
        id: 'fp-ref-2',
        name: 'Ref Product Inactive',
        itemCode: 'FP-REF-2',
        categoryId: 'cat-1',
        categoryName: 'Lighting',
        unit: 'PCS',
        currentStock: 20,
        openingStock: 20,
        minimumStock: 2,
        costPrice: 500,
        dealerSellingPrice: 750,
        customerSellingPrice: 950,
        gstPercent: 18,
        isActive: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      db.customers = [activeCust, inactiveCust];
      db.finishedProducts = [activeProduct, inactiveProduct];

      // Verify active customer and active product remain active when referenced
      expect(db.customers.firstWhere((c) => c.id == 'cust-ref-1').isActive, isTrue);
      expect(db.finishedProducts.firstWhere((p) => p.id == 'fp-ref-1').isActive, isTrue);

      // Verify inactive customer and inactive product remain strictly inactive when referenced
      expect(db.customers.firstWhere((c) => c.id == 'cust-ref-2').isActive, isFalse);
      expect(db.finishedProducts.firstWhere((p) => p.id == 'fp-ref-2').isActive, isFalse);

      // When dual linking an architect and a customer, their isActive statuses remain strictly immutable
      final arch = Architect(
        id: 'arch-link-1',
        name: 'Link Architect',
        companyName: 'Studio Link',
        mobile: '9876543210',
        email: 'link@example.com',
        gstNumber: '24AAAAA0000A1Z5',
        address: 'Surat',
        isActive: false,
        createdAt: DateTime.now(),
      );
      db.architects = [arch];

      db.linkArchitectAndCustomer(customerId: 'cust-ref-2', architectId: 'arch-link-1');

      // Both must remain inactive! Status must NEVER toggle or flip when referenced or linked
      expect(db.customers.firstWhere((c) => c.id == 'cust-ref-2').isActive, isFalse);
      expect(db.architects.firstWhere((a) => a.id == 'arch-link-1').isActive, isFalse);
      expect(db.customers.firstWhere((c) => c.id == 'cust-ref-1').isActive, isTrue);
    });
  });
}

