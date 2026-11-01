import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/payment_model.dart';
import 'package:frontend/core/models/customer_model.dart';
import 'package:frontend/core/models/dealer_model.dart';
import 'package:frontend/core/models/vendor_model.dart';
import 'package:frontend/core/models/architect_model.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  group('Payment Dialog Party Filtering (Outstanding > 0 & Active Only)', () {
    late MockDatabaseService db;

    setUp(() {
      db = MockDatabaseService();
    });

    test('Customer dropdown excludes zero balance and inactive customers', () {
      // Add test customer with 0 balance
      db.addCustomer(Customer(
        id: 'cust-zero-001',
        name: 'Zero Balance Customer',
        mobile: '9876543210',
        email: 'zero@example.com',
        gstNumber: '24AAAAA0000A1Z5',
        address: '123 Street',
        outstandingAmount: 0.0,
        createdAt: DateTime.now(),
      ));

      // Add active customer with positive balance
      db.addCustomer(Customer(
        id: 'cust-pos-001',
        name: 'Positive Balance Customer',
        mobile: '9876543211',
        email: 'pos@example.com',
        gstNumber: '24AAAAA0000A1Z6',
        address: '124 Street',
        outstandingAmount: 5500.0,
        isActive: true,
        createdAt: DateTime.now(),
      ));

      // Add inactive customer with positive balance
      db.addCustomer(Customer(
        id: 'cust-inactive-001',
        name: 'Inactive Customer',
        mobile: '9876543219',
        email: 'inactive@example.com',
        gstNumber: '24AAAAA0000A1Z7',
        address: '125 Street',
        outstandingAmount: 7000.0,
        isActive: false,
        createdAt: DateTime.now(),
      ));

      // Filter logic used by _RecordPaymentDialog
      final eligibleCustomers = db.customers.where((c) {
        if (c.isDeleted || !c.isActive) return false;
        final salesPending = db.sales
            .where((s) => s.partyId == c.id && s.pendingAmount > 0)
            .fold(0.0, (sum, s) => sum + s.pendingAmount);
        final out = c.outstandingAmount > salesPending ? c.outstandingAmount : salesPending;
        return out > 0;
      }).toList();

      final zeroCustomer = eligibleCustomers.where((c) => c.id == 'cust-zero-001').firstOrNull;
      final posCustomer = eligibleCustomers.where((c) => c.id == 'cust-pos-001').firstOrNull;
      final inactiveCustomer = eligibleCustomers.where((c) => c.id == 'cust-inactive-001').firstOrNull;

      expect(zeroCustomer, isNull, reason: 'Zero balance customer should NOT be in the dropdown');
      expect(inactiveCustomer, isNull, reason: 'Inactive customer should NOT be in the dropdown');
      expect(posCustomer, isNotNull, reason: 'Active customer with pending dues MUST be in the dropdown');
      expect(posCustomer!.outstandingAmount, equals(5500.0));
    });

    test('Dealer dropdown excludes zero balance and inactive dealers', () {
      db.addDealer(Dealer(
        id: 'dlr-zero-001',
        name: 'Zero Balance Dealer',
        contactPerson: 'Contact A',
        companyName: 'Company A',
        email: 'dealer0@example.com',
        gstNumber: '24AAAAA0000A1Z5',
        address: 'Dealer St',
        mobile: '9876543212',
        outstandingAmount: 0.0,
        createdAt: DateTime.now(),
      ));

      db.addDealer(Dealer(
        id: 'dlr-pos-001',
        name: 'Positive Balance Dealer',
        contactPerson: 'Contact B',
        companyName: 'Company B',
        email: 'dealer1@example.com',
        gstNumber: '24AAAAA0000A1Z6',
        address: 'Dealer St 2',
        mobile: '9876543213',
        outstandingAmount: 12000.0,
        isActive: true,
        createdAt: DateTime.now(),
      ));

      db.addDealer(Dealer(
        id: 'dlr-inactive-001',
        name: 'Inactive Dealer',
        contactPerson: 'Contact C',
        companyName: 'Company C',
        email: 'dealer2@example.com',
        gstNumber: '24AAAAA0000A1Z7',
        address: 'Dealer St 3',
        mobile: '9876543218',
        outstandingAmount: 15000.0,
        isActive: false,
        createdAt: DateTime.now(),
      ));

      final eligibleDealers = db.dealers.where((d) {
        if (d.isDeleted || !d.isActive) return false;
        final salesPending = db.sales
            .where((s) => s.partyId == d.id && s.pendingAmount > 0)
            .fold(0.0, (sum, s) => sum + s.pendingAmount);
        final out = d.outstandingAmount > salesPending ? d.outstandingAmount : salesPending;
        return out > 0;
      }).toList();

      final zeroDealer = eligibleDealers.where((d) => d.id == 'dlr-zero-001').firstOrNull;
      final posDealer = eligibleDealers.where((d) => d.id == 'dlr-pos-001').firstOrNull;
      final inactiveDealer = eligibleDealers.where((d) => d.id == 'dlr-inactive-001').firstOrNull;

      expect(zeroDealer, isNull, reason: 'Zero balance dealer should NOT be in the dropdown');
      expect(inactiveDealer, isNull, reason: 'Inactive dealer should NOT be in the dropdown');
      expect(posDealer, isNotNull, reason: 'Active dealer with pending dues MUST be in the dropdown');
    });

    test('Vendor dropdown excludes zero balance and inactive vendors', () {
      db.addVendor(Vendor(
        id: 'ven-zero-001',
        name: 'Zero Balance Vendor',
        contactPerson: 'Vendor CP',
        mobile: '9876543214',
        email: 'vendor0@example.com',
        gstNumber: '24AAAAA0000A1Z5',
        panNumber: 'ABCDE1234F',
        address: 'Vendor Address',
        creditLimit: 50000,
        outstandingBalance: 0.0,
        createdAt: DateTime.now(),
      ));

      db.addVendor(Vendor(
        id: 'ven-pos-001',
        name: 'Positive Balance Vendor',
        contactPerson: 'Vendor CP 2',
        mobile: '9876543215',
        email: 'vendor1@example.com',
        gstNumber: '24AAAAA0000A1Z6',
        panNumber: 'ABCDE1234G',
        address: 'Vendor Address 2',
        creditLimit: 100000,
        outstandingBalance: 45000.0,
        isActive: true,
        createdAt: DateTime.now(),
      ));

      db.addVendor(Vendor(
        id: 'ven-inactive-001',
        name: 'Inactive Vendor',
        contactPerson: 'Vendor CP 3',
        mobile: '9876543220',
        email: 'vendor2@example.com',
        gstNumber: '24AAAAA0000A1Z7',
        panNumber: 'ABCDE1234H',
        address: 'Vendor Address 3',
        creditLimit: 100000,
        outstandingBalance: 60000.0,
        isActive: false,
        createdAt: DateTime.now(),
      ));

      final eligibleVendors = db.vendors.where((v) {
        if (v.isDeleted || !v.isActive) return false;
        final purchasesPending = db.purchases
            .where((p) => p.vendorId == v.id && p.pendingAmount > 0)
            .fold(0.0, (sum, p) => sum + p.pendingAmount);
        final out = v.outstandingBalance > purchasesPending ? v.outstandingBalance : purchasesPending;
        return out > 0;
      }).toList();

      final zeroVendor = eligibleVendors.where((v) => v.id == 'ven-zero-001').firstOrNull;
      final posVendor = eligibleVendors.where((v) => v.id == 'ven-pos-001').firstOrNull;
      final inactiveVendor = eligibleVendors.where((v) => v.id == 'ven-inactive-001').firstOrNull;

      expect(zeroVendor, isNull, reason: 'Zero balance vendor should NOT be in the dropdown');
      expect(inactiveVendor, isNull, reason: 'Inactive vendor should NOT be in the dropdown');
      expect(posVendor, isNotNull, reason: 'Active vendor with pending dues MUST be in the dropdown');
    });

    test('Architect dropdown excludes zero pending commission and inactive architects', () {
      db.addArchitect(Architect(
        id: 'arc-zero-001',
        name: 'Zero Commission Architect',
        companyName: 'Arch Co',
        email: 'arch0@example.com',
        gstNumber: '24AAAAA0000A1Z5',
        address: 'Arch St',
        mobile: '9876543216',
        pendingCommission: 0.0,
        createdAt: DateTime.now(),
      ));

      db.addArchitect(Architect(
        id: 'arc-pos-001',
        name: 'Positive Commission Architect',
        companyName: 'Arch Co 2',
        email: 'arch1@example.com',
        gstNumber: '24AAAAA0000A1Z6',
        address: 'Arch St 2',
        mobile: '9876543217',
        pendingCommission: 25000.0,
        isActive: true,
        createdAt: DateTime.now(),
      ));

      db.addArchitect(Architect(
        id: 'arc-inactive-001',
        name: 'Inactive Architect',
        companyName: 'Arch Co 3',
        email: 'arch2@example.com',
        gstNumber: '24AAAAA0000A1Z7',
        address: 'Arch St 3',
        mobile: '9876543222',
        pendingCommission: 30000.0,
        isActive: false,
        createdAt: DateTime.now(),
      ));

      final eligibleArchitects = db.architects.where((a) {
        if (a.isDeleted || !a.isActive) return false;
        final commPending = db.commissions
            .where((cm) => cm.architectId == a.id)
            .fold(0.0, (sum, cm) => sum + cm.commissionAmount);
        final out = a.pendingCommission > commPending ? a.pendingCommission : commPending;
        return out > 0;
      }).toList();

      final zeroArchitect = eligibleArchitects.where((a) => a.id == 'arc-zero-001').firstOrNull;
      final posArchitect = eligibleArchitects.where((a) => a.id == 'arc-pos-001').firstOrNull;
      final inactiveArchitect = eligibleArchitects.where((a) => a.id == 'arc-inactive-001').firstOrNull;

      expect(zeroArchitect, isNull, reason: 'Zero commission architect should NOT be in the dropdown');
      expect(inactiveArchitect, isNull, reason: 'Inactive architect should NOT be in the dropdown');
      expect(posArchitect, isNotNull, reason: 'Active architect with pending commission MUST be in the dropdown');
    });
  });
}
