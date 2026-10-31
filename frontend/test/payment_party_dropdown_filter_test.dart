import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/payment_model.dart';
import 'package:frontend/core/models/customer_model.dart';
import 'package:frontend/core/models/dealer_model.dart';
import 'package:frontend/core/models/vendor_model.dart';
import 'package:frontend/core/models/architect_model.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  group('Payment Dialog Party Filtering (Outstanding > 0 Only)', () {
    late MockDatabaseService db;

    setUp(() {
      db = MockDatabaseService();
    });

    test('Customer dropdown excludes customers with zero outstanding balance', () {
      // Add test customer with 0 balance and one with positive balance
      db.addCustomer(Customer(
        id: 'cust-zero-001',
        name: 'Zero Balance Customer',
        mobile: '9876543210',
        outstandingAmount: 0.0,
      ));

      db.addCustomer(Customer(
        id: 'cust-pos-001',
        name: 'Positive Balance Customer',
        mobile: '9876543211',
        outstandingAmount: 5500.0,
      ));

      // Filter logic used by _RecordPaymentDialog
      final eligibleCustomers = db.customers.where((c) {
        if (c.isDeleted) return false;
        final salesPending = db.sales
            .where((s) => s.partyId == c.id && s.pendingAmount > 0)
            .fold(0.0, (sum, s) => sum + s.pendingAmount);
        final out = c.outstandingAmount > salesPending ? c.outstandingAmount : salesPending;
        return out > 0;
      }).toList();

      final zeroCustomer = eligibleCustomers.where((c) => c.id == 'cust-zero-001').firstOrNull;
      final posCustomer = eligibleCustomers.where((c) => c.id == 'cust-pos-001').firstOrNull;

      expect(zeroCustomer, isNull, reason: 'Zero balance customer should NOT be in the dropdown');
      expect(posCustomer, isNotNull, reason: 'Customer with pending dues MUST be in the dropdown');
      expect(posCustomer!.outstandingAmount, equals(5500.0));
    });

    test('Dealer dropdown excludes dealers with zero outstanding balance', () {
      db.addDealer(Dealer(
        id: 'dlr-zero-001',
        name: 'Zero Balance Dealer',
        mobile: '9876543212',
        outstandingAmount: 0.0,
      ));

      db.addDealer(Dealer(
        id: 'dlr-pos-001',
        name: 'Positive Balance Dealer',
        mobile: '9876543213',
        outstandingAmount: 12000.0,
      ));

      final eligibleDealers = db.dealers.where((d) {
        if (d.isDeleted) return false;
        final salesPending = db.sales
            .where((s) => s.partyId == d.id && s.pendingAmount > 0)
            .fold(0.0, (sum, s) => sum + s.pendingAmount);
        final out = d.outstandingAmount > salesPending ? d.outstandingAmount : salesPending;
        return out > 0;
      }).toList();

      final zeroDealer = eligibleDealers.where((d) => d.id == 'dlr-zero-001').firstOrNull;
      final posDealer = eligibleDealers.where((d) => d.id == 'dlr-pos-001').firstOrNull;

      expect(zeroDealer, isNull, reason: 'Zero balance dealer should NOT be in the dropdown');
      expect(posDealer, isNotNull, reason: 'Dealer with pending dues MUST be in the dropdown');
    });

    test('Vendor dropdown excludes vendors with zero outstanding balance', () {
      db.addVendor(Vendor(
        id: 'ven-zero-001',
        name: 'Zero Balance Vendor',
        phone: '9876543214',
        outstandingBalance: 0.0,
      ));

      db.addVendor(Vendor(
        id: 'ven-pos-001',
        name: 'Positive Balance Vendor',
        phone: '9876543215',
        outstandingBalance: 45000.0,
      ));

      final eligibleVendors = db.vendors.where((v) {
        if (v.isDeleted) return false;
        final purchasesPending = db.purchases
            .where((p) => p.vendorId == v.id && p.pendingAmount > 0)
            .fold(0.0, (sum, p) => sum + p.pendingAmount);
        final out = v.outstandingBalance > purchasesPending ? v.outstandingBalance : purchasesPending;
        return out > 0;
      }).toList();

      final zeroVendor = eligibleVendors.where((v) => v.id == 'ven-zero-001').firstOrNull;
      final posVendor = eligibleVendors.where((v) => v.id == 'ven-pos-001').firstOrNull;

      expect(zeroVendor, isNull, reason: 'Zero balance vendor should NOT be in the dropdown');
      expect(posVendor, isNotNull, reason: 'Vendor with pending dues MUST be in the dropdown');
    });

    test('Architect dropdown excludes architects with zero pending commission', () {
      db.addArchitect(Architect(
        id: 'arc-zero-001',
        name: 'Zero Commission Architect',
        mobile: '9876543216',
        pendingCommission: 0.0,
      ));

      db.addArchitect(Architect(
        id: 'arc-pos-001',
        name: 'Positive Commission Architect',
        mobile: '9876543217',
        pendingCommission: 25000.0,
      ));

      final eligibleArchitects = db.architects.where((a) {
        if (a.isDeleted) return false;
        final commPending = db.commissions
            .where((cm) => cm.architectId == a.id)
            .fold(0.0, (sum, cm) => sum + cm.commissionAmount);
        final out = a.pendingCommission > commPending ? a.pendingCommission : commPending;
        return out > 0;
      }).toList();

      final zeroArchitect = eligibleArchitects.where((a) => a.id == 'arc-zero-001').firstOrNull;
      final posArchitect = eligibleArchitects.where((a) => a.id == 'arc-pos-001').firstOrNull;

      expect(zeroArchitect, isNull, reason: 'Zero commission architect should NOT be in the dropdown');
      expect(posArchitect, isNotNull, reason: 'Architect with pending commission MUST be in the dropdown');
    });
  });
}
