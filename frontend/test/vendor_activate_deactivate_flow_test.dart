import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/masters/screens/vendors_screen.dart';
import 'package:frontend/core/models/vendor_model.dart';
import 'package:frontend/shared/services/mock_database_service.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/core/storage/erp_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Vendor Master Activate / Deactivate Flow Test', () {
    late MockDatabaseService db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = MockDatabaseService();
      db.vendors = [
        Vendor(
          id: 'v-test-flow-1',
          name: 'Supreme Hardware Pvt Ltd',
          contactPerson: 'Suresh Patel',
          
          mobile: '9876543210',
          email: 'supreme@example.com',
          gstNumber: '24AAAAA0000A1Z5',
          panNumber: 'AAAAA0000A',
          address: 'Plot 10, GIDC, Jamnagar, Gujarat',
          creditLimit: 500000,
          outstandingBalance: 0,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      ];
    });

    testWidgets('Active vendor -> Deactivate -> Inactive -> Activate -> Active lifecycle', (tester) async {
      await tester.binding.setSurfaceSize(const Size(2200, 1000));
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

      // Step 1: Verify vendor is Active initially
      expect(find.text('Supreme Hardware Pvt Ltd'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(db.vendors.first.isActive, isTrue);

      // Step 2: Open action popup menu
      final actionsMenuButton = find.byType(PopupMenuButton<String>);
      expect(actionsMenuButton, findsOneWidget);
      await tester.tap(actionsMenuButton);
      await tester.pumpAndSettle();

      // Step 3: Verify menu shows 'Deactivate Vendor'
      expect(find.text('Deactivate Vendor'), findsOneWidget);
      expect(find.text('Activate Vendor'), findsNothing);

      // Step 4: Click 'Deactivate Vendor'
      await tester.tap(find.text('Deactivate Vendor'));
      await tester.pumpAndSettle();

      // Step 5: Confirm dialog appears
      expect(find.text('Deactivate Vendor'), findsWidgets);
      final confirmDeactivateBtn = find.widgetWithText(ElevatedButton, 'Deactivate');
      expect(confirmDeactivateBtn, findsOneWidget);
      await tester.tap(confirmDeactivateBtn);
      await tester.pumpAndSettle();

      // Step 6: Verify vendor status changed to Inactive
      expect(db.vendors.first.isActive, isFalse);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Active'), findsNothing);

      // Step 7: Open action popup menu again
      await tester.tap(actionsMenuButton);
      await tester.pumpAndSettle();

      // Step 8: Verify menu now shows 'Activate Vendor'
      expect(find.text('Activate Vendor'), findsOneWidget);
      expect(find.text('Deactivate Vendor'), findsNothing);

      // Step 9: Click 'Activate Vendor'
      await tester.tap(find.text('Activate Vendor'));
      await tester.pumpAndSettle();

      // Step 10: Confirm dialog appears
      expect(find.text('Activate Vendor'), findsWidgets);
      final confirmActivateBtn = find.widgetWithText(ElevatedButton, 'Activate');
      expect(confirmActivateBtn, findsOneWidget);
      await tester.tap(confirmActivateBtn);
      await tester.pumpAndSettle();

      // Step 11: Verify vendor status changed back to Active
      expect(db.vendors.first.isActive, isTrue);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Inactive'), findsNothing);

      // Step 12: Open action menu again to verify it reverted to 'Deactivate Vendor'
      await tester.tap(actionsMenuButton);
      await tester.pumpAndSettle();
      expect(find.text('Deactivate Vendor'), findsOneWidget);
      expect(find.text('Activate Vendor'), findsNothing);
    });

    test('Dropdown filter correctly excludes Inactive vendor and includes upon Reactivation', () {
      final vendor = db.vendors.first;
      expect(vendor.isActive, isTrue);

      // 1. When Active, appears in purchase dropdown list
      var activeVendors = db.vendors.where((v) => !v.isDeleted && v.isActive).toList();
      expect(activeVendors.any((v) => v.id == vendor.id), isTrue);

      // 2. Deactivate vendor
      db.toggleVendorStatus(vendor.id, false);
      expect(db.vendors.first.isActive, isFalse);

      activeVendors = db.vendors.where((v) => !v.isDeleted && v.isActive).toList();
      expect(activeVendors.any((v) => v.id == vendor.id), isFalse);

      // 3. Reactivate vendor
      db.toggleVendorStatus(vendor.id, true);
      expect(db.vendors.first.isActive, isTrue);

      activeVendors = db.vendors.where((v) => !v.isDeleted && v.isActive).toList();
      expect(activeVendors.any((v) => v.id == vendor.id), isTrue);
    });

    test('Cache persistence preserves Inactive and Reactivated vendor status across reload', () async {
      final vendor = db.vendors.first;

      // Deactivate and save
      db.toggleVendorStatus(vendor.id, false);
      await ErpCacheManager.saveVendors(db.vendors);

      // Simulate new session restoration
      final restoredDb = MockDatabaseService();
      await ErpCacheManager.loadAll(restoredDb);
      expect(restoredDb.vendors.firstWhere((v) => v.id == vendor.id).isActive, isFalse);

      // Reactivate and save
      restoredDb.toggleVendorStatus(vendor.id, true);
      await ErpCacheManager.saveVendors(restoredDb.vendors);

      // Simulate subsequent session restoration
      final secondRestoredDb = MockDatabaseService();
      await ErpCacheManager.loadAll(secondRestoredDb);
      expect(secondRestoredDb.vendors.firstWhere((v) => v.id == vendor.id).isActive, isTrue);
    });
  });
}
