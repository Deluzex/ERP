import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/vendor_model.dart';
import 'package:frontend/core/utils/validators.dart';
import 'package:frontend/core/api/api_exception.dart';

void main() {
  group('Vendor Model & API Binding Test Suite', () {
    test('Vendor.fromJson correctly parses NestJS backend response envelope item', () {
      final json = {
        'id': 'ven_1234567890',
        'name': 'Apex Extrusions Ltd',
        'contactPerson': 'Rajesh Sharma',
        'mobile': '9876543210',
        'email': 'rajesh@apex.com',
        'gstNumber': '24AAATE1234F1Z5',
        'panNumber': 'AAATE1234F',
        'address': 'Plot 42, GIDC Industrial Estate, Vadodara, Gujarat',
        'paymentTerms': 'Net 45 Days',
        'creditLimit': '750000.00',
        'outstandingBalance': '125000.50',
        'isDeleted': false,
        'deleteReason': null,
        'deletedAt': null,
        'createdAt': '2026-09-16T05:30:00.000Z',
      };

      final vendor = Vendor.fromJson(json);

      expect(vendor.id, 'ven_1234567890');
      expect(vendor.name, 'Apex Extrusions Ltd');
      expect(vendor.contactPerson, 'Rajesh Sharma');
      expect(vendor.mobile, '9876543210');
      expect(vendor.email, 'rajesh@apex.com');
      expect(vendor.gstNumber, '24AAATE1234F1Z5');
      expect(vendor.panNumber, 'AAATE1234F');
      expect(vendor.address, 'Plot 42, GIDC Industrial Estate, Vadodara, Gujarat');
      expect(vendor.paymentTerms, 'Net 45 Days');
      expect(vendor.creditLimit, 750000.00);
      expect(vendor.outstandingBalance, 125000.50);
      expect(vendor.isDeleted, false);
      expect(vendor.deleteReason, isNull);
      expect(vendor.deletedAt, isNull);
    });

    test('Vendor.toJson serializes to match NestJS CreateVendorDto/UpdateVendorDto', () {
      final vendor = Vendor(
        id: 'VEN-999',
        name: 'Bhagwati Metals',
        contactPerson: 'Suresh Patel',
        mobile: '9123456780',
        email: 'sales@bhagwatimetals.com',
        gstNumber: '24BBBPK1234E1Z8',
        panNumber: 'BBBPK1234E',
        address: '102 Industrial Zone, Ahmedabad',
        paymentTerms: 'Net 30 Days',
        creditLimit: 500000.0,
        createdAt: DateTime.now(),
      );

      final json = vendor.toJson();

      expect(json['name'], 'Bhagwati Metals');
      expect(json['contactPerson'], 'Suresh Patel');
      expect(json['mobile'], '9123456780');
      expect(json['email'], 'sales@bhagwatimetals.com');
      expect(json['gstNumber'], '24BBBPK1234E1Z8');
      expect(json['panNumber'], 'BBBPK1234E');
      expect(json['address'], '102 Industrial Zone, Ahmedabad');
      expect(json['paymentTerms'], 'Net 30 Days');
      expect(json['creditLimit'], 500000.0);
    });

    test('Validators.gst statutory validation', () {
      // Valid statutory GSTINs
      expect(Validators.gst('24AAATE1234F1Z5'), isNull);
      expect(Validators.gst('27AADCS1234A1Z9'), isNull);

      // Invalid GSTINs
      expect(Validators.gst(''), 'GST Number is required');
      expect(Validators.gst('INVALID_GST'), contains('Enter valid 15-character GSTIN'));
      expect(Validators.gst('12345'), contains('Enter valid 15-character GSTIN'));
      expect(Validators.gst('24AAATE1234F1Z'), contains('Enter valid 15-character GSTIN')); // 14 chars
    });

    test('Validators.pan statutory validation', () {
      // Valid PAN
      expect(Validators.pan('AAATE1234F'), isNull);
      expect(Validators.pan('BBBPK1234E'), isNull);

      // Invalid PAN
      expect(Validators.pan(''), 'PAN Number is required');
      expect(Validators.pan('AAATE1234'), contains('Enter valid 10-character PAN'));
      expect(Validators.pan('12345AAAAA'), contains('Enter valid 10-character PAN'));
    });

    test('ApiException correctly captures domain errors from backend', () {
      const exception = ConflictException(
        message: 'Vendor with GST 24AAATE1234F1Z5 already exists',
        correlationId: 'cid_test_001',
      );

      expect(exception.statusCode, 409);
      expect(exception.errorCode, 'CONFLICT');
      expect(exception.message, 'Vendor with GST 24AAATE1234F1Z5 already exists');
      expect(exception.correlationId, 'cid_test_001');
    });
  });
}
