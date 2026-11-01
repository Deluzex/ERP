import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/erp_filter_controls.dart';
import 'package:frontend/features/masters/screens/customers_screen.dart';
import 'package:frontend/features/masters/screens/dealers_screen.dart';
import 'package:frontend/features/masters/screens/architects_screen.dart';
import 'package:frontend/features/masters/screens/vendors_screen.dart';
import 'package:frontend/core/models/customer_model.dart';
import 'package:frontend/core/models/dealer_model.dart';
import 'package:frontend/core/models/architect_model.dart';
import 'package:frontend/core/models/vendor_model.dart';
import 'package:frontend/shared/services/mock_database_service.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';

void main() {
  group('Master Address Columns & Future Date Restriction Suite', () {
    late MockDatabaseService db;

    setUp(() {
      db = MockDatabaseService();

      // Seed Customer with address
      db.addCustomer(Customer(
        id: 'cust-test-1',
        name: 'Alpha Customer Ltd',
        mobile: '9876543210',
        email: 'alpha@example.com',
        gstNumber: '24AAAAA0000A1Z5',
        address: 'Plot 42, GIDC Industrial Estate, Phase 2, Vatva, Ahmedabad, Gujarat',
        state: 'Gujarat',
        pincode: '382445',
        outstandingAmount: 25000,
        createdAt: DateTime.now(),
      ));

      // Seed Dealer with address
      db.addDealer(Dealer(
        id: 'deal-test-1',
        name: 'Beta Showroom',
        companyName: 'Beta Ceramics & Hardware',
        contactPerson: 'Bhavik Patel',
        mobile: '9876543211',
        email: 'beta@example.com',
        gstNumber: '24AAAAA0000A1Z6',
        address: '101 Trade Center, Ring Road, Surat, Gujarat',
        state: 'Gujarat',
        pincode: '395002',
        outstandingAmount: 50000,
        createdAt: DateTime.now(),
      ));

      // Seed Architect with address
      db.addArchitect(Architect(
        id: 'arch-test-1',
        name: 'Ar. Chirag Sharma',
        companyName: 'Chirag Architects & Associates',
        mobile: '9876543212',
        email: 'chirag@example.com',
        gstNumber: '24AAAAA0000A1Z7',
        address: '5th Floor Design Tower, CG Road, Navrangpura, Ahmedabad, Gujarat',
        state: 'Gujarat',
        pincode: '380009',
        defaultCommissionRate: 5.0,
        createdAt: DateTime.now(),
      ));

      // Seed Vendor with address
      db.addVendor(Vendor(
        id: 'vend-test-1',
        name: 'Delta Raw Materials Pvt Ltd',
        contactPerson: 'Dinesh Shah',
        mobile: '9876543213',
        email: 'delta@example.com',
        gstNumber: '24AAAAA0000A1Z8',
        panNumber: 'ABCDE1234F',
        creditLimit: 500000,
        address: 'Survey No 88, Near Toll Plaza, NH-48, Vadodara, Gujarat',
        state: 'Gujarat',
        pincode: '390001',
        outstandingBalance: 120000,
        createdAt: DateTime.now(),
      ));
    });

    testWidgets('Customers table renders address in dedicated column and not under Name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CustomersScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm Table Column Headers
      expect(find.text('CUSTOMER NAME'), findsOneWidget);
      expect(find.text('SITE / BILLING ADDRESS'), findsOneWidget);

      // Confirm Name is present
      expect(find.text('Alpha Customer Ltd'), findsOneWidget);

      // Confirm address is present
      final addressFinder = find.text('Plot 42, GIDC Industrial Estate, Phase 2, Vatva, Ahmedabad, Gujarat');
      expect(addressFinder, findsOneWidget);

      // Verify that the text under name does NOT contain the address combination
      expect(find.text('Plot 42, GIDC Industrial Estate, Phase 2, Vatva, Ahmedabad, Gujarat, Gujarat, 382445'), findsNothing);
    });

    testWidgets('Dealers table has dedicated Address column and clean Dealer Name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DealersScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm Table Column Headers
      expect(find.text('SHOWROOM / DEALER NAME'), findsOneWidget);
      expect(find.text('ADDRESS'), findsOneWidget);

      // Confirm Dealer Name
      expect(find.text('Beta Showroom'), findsOneWidget);

      // Confirm Address in table
      expect(find.text('101 Trade Center, Ring Road, Surat, Gujarat'), findsOneWidget);

      // Verify no subtitle address concatenation exists under Dealer Name
      expect(find.text('101 Trade Center, Ring Road, Surat, Gujarat, Gujarat, 395002'), findsNothing);
    });

    testWidgets('Architects table has dedicated Address column and clean Architect Name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ArchitectsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm Table Column Headers
      expect(find.text('ARCHITECT NAME'), findsOneWidget);
      expect(find.text('ADDRESS'), findsOneWidget);

      // Confirm Architect Name
      expect(find.text('Ar. Chirag Sharma'), findsOneWidget);

      // Confirm Address in table
      expect(find.text('5th Floor Design Tower, CG Road, Navrangpura, Ahmedabad, Gujarat'), findsOneWidget);

      // Verify no address concatenation exists under Architect Name
      expect(find.text('5th Floor Design Tower, CG Road, Navrangpura, Ahmedabad, Gujarat, Gujarat, 380009'), findsNothing);
    });

    testWidgets('Vendors table has dedicated Address column and clean Vendor Name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VendorsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm Table Column Headers
      expect(find.text('VENDOR NAME'), findsOneWidget);
      expect(find.text('ADDRESS'), findsOneWidget);

      // Confirm Vendor Name
      expect(find.text('Delta Raw Materials Pvt Ltd'), findsOneWidget);

      // Confirm Address in table
      expect(find.text('Survey No 88, Near Toll Plaza, NH-48, Vadodara, Gujarat'), findsOneWidget);

      // Verify no address concatenation exists under Vendor Name
      expect(find.text('Survey No 88, Near Toll Plaza, NH-48, Vadodara, Gujarat, Gujarat, 390001'), findsNothing);
    });

    testWidgets('ErpDateFilterBox clamps future dates and restricts selection to today or earlier', (tester) async {
      DateTime? appliedStart;
      DateTime? appliedEnd;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErpDateFilterBox(
              startDate: null,
              endDate: null,
              onDateRangeSelected: (start, end) {
                appliedStart = start;
                appliedEnd = end;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Date Filter Dialog
      await tester.tap(find.text('Filter by Date'));
      await tester.pumpAndSettle();

      expect(find.text('Filter by Date'), findsWidgets);
      expect(find.text('Quick Ranges'), findsNothing); // In Single Date mode by default

      // Switch to Date Range mode
      await tester.tap(find.text('Date Range'));
      await tester.pumpAndSettle();

      expect(find.text('Quick Ranges'), findsOneWidget);

      // Click "Today" Quick Range
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Tap Apply Range button
      final applyButton = find.byWidgetPredicate(
        (widget) => widget is ElevatedButton && widget.child is Text && (widget.child as Text).data!.startsWith('Apply Range'),
      );
      expect(applyButton, findsOneWidget);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(appliedStart, isNotNull);
      expect(appliedEnd, isNotNull);
      expect(appliedStart!.isAfter(today), isFalse);
      expect(appliedEnd!.isAfter(today), isFalse);
    });
  });
}
