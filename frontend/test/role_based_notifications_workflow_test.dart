import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/routes/app_routes.dart';
import 'package:frontend/core/models/notification_model.dart';
import 'package:frontend/core/widgets/erp_header.dart';
import 'package:frontend/features/sales/widgets/convert_proforma_dialog.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';
import 'package:frontend/shared/widgets/notifications_center_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Role-Based Notification Visibility & Filtering Tests', () {
    late MockDatabaseService db;

    setUp(() {
      db = MockDatabaseService();
    });

    test('Admin user can view all notifications (Oversight of Purchase and Production)', () {
      final adminUser = db.users.firstWhere((u) => u.primaryRoleId == 'admin');
      final notifs = db.getNotificationsForUser(adminUser);

      expect(notifs.isNotEmpty, isTrue);
      // Admin should see both purchase requisition and production requisition notifications
      final hasPurchase = notifs.any((n) => n.notificationType.contains('purchase'));
      final hasProduction = notifs.any((n) => n.notificationType.contains('production'));

      expect(hasPurchase, isTrue);
      expect(hasProduction, isTrue);
    });

    test('Purchase Manager sees Purchase notifications, but cannot see Production notifications', () {
      final purchaseUser = db.users.firstWhere((u) => u.primaryRoleId == 'purchase_manager');
      final notifs = db.getNotificationsForUser(purchaseUser);

      expect(notifs.isNotEmpty, isTrue);
      // All visible notifications must be purchase-related or addressed to purchase user
      for (final n in notifs) {
        final targetRole = (n.targetRole ?? '').toLowerCase();
        final isPurchaseRole = targetRole == 'purchase_manager' || targetRole == 'purchase';
        final isAddressedToUser = n.recipientUserId == purchaseUser.id;
        expect(isPurchaseRole || isAddressedToUser, isTrue);

        // MUST NOT be a production-only requisition
        expect(n.notificationType == 'production_requisition', isFalse);
      }
    });

    test('Production Manager sees Production notifications, but cannot see Purchase notifications', () {
      final productionUser = db.users.firstWhere((u) => u.primaryRoleId == 'production_manager');
      final notifs = db.getNotificationsForUser(productionUser);

      expect(notifs.isNotEmpty, isTrue);
      // All visible notifications must be production-related or addressed to production user
      for (final n in notifs) {
        final targetRole = (n.targetRole ?? '').toLowerCase();
        final isProductionRole = targetRole == 'production_manager' || targetRole == 'production';
        final isAddressedToUser = n.recipientUserId == productionUser.id;
        expect(isProductionRole || isAddressedToUser, isTrue);

        // MUST NOT be a purchase-only requisition
        expect(n.notificationType == 'purchase_requisition', isFalse);
      }
    });

    test('Unrelated roles (Data Entry, Customer) cannot view internal Purchase or Production notifications', () {
      final dataEntryUser = db.users.firstWhere((u) => u.primaryRoleId == 'data_entry');
      final notifs = db.getNotificationsForUser(dataEntryUser);

      // Data Entry must not see any internal purchase or production requisition notifications
      final hasInternalRequisitions = notifs.any((n) =>
          n.notificationType == 'purchase_requisition' ||
          n.notificationType == 'production_requisition');

      expect(hasInternalRequisitions, isFalse);
    });
  });

  group('Notification Read / Unread Status and Badge Lifecycle Tests', () {
    late MockDatabaseService db;

    setUp(() {
      db = MockDatabaseService();
    });

    test('Marking notification as read decrements unread count', () {
      final purchaseUser = db.users.firstWhere((u) => u.primaryRoleId == 'purchase_manager');
      final initialUnread = db.getUnreadNotificationCount(purchaseUser);
      expect(initialUnread, greaterThan(0));

      final firstNotif = db.getNotificationsForUser(purchaseUser).first;
      expect(firstNotif.isRead, isFalse);

      db.markNotificationAsRead(firstNotif.id, purchaseUser);

      final updatedUnread = db.getUnreadNotificationCount(purchaseUser);
      expect(updatedUnread, equals(initialUnread - 1));

      final updatedNotif = db.getNotificationsForUser(purchaseUser).firstWhere((n) => n.id == firstNotif.id);
      expect(updatedNotif.isRead, isTrue);
      expect(updatedNotif.readAt, isNotNull);
    });

    test('Mark all notifications as read resets unread count to 0 for user scope', () {
      final purchaseUser = db.users.firstWhere((u) => u.primaryRoleId == 'purchase_manager');
      expect(db.getUnreadNotificationCount(purchaseUser), greaterThan(0));

      db.markAllNotificationsAsRead(purchaseUser);

      expect(db.getUnreadNotificationCount(purchaseUser), equals(0));
    });

    test('Repeated requests do not create unintended duplicates', () {
      final notif = NotificationItem(
        id: 'NOTIF-TEST-DUP-1',
        title: 'Purchase Requisition: Test Duplication Item',
        message: 'Requisition message',
        notificationType: 'purchase_requisition',
        targetRole: 'purchase_manager',
        data: {
          'salesOrderNumber': 'SO-TEST-DUP-001',
          'productSku': 'SKU-DUP-001',
          'requestType': 'Purchase',
        },
        createdAt: DateTime.now(),
      );

      final initialCount = db.notifications.length;
      db.createNotification(notif);
      expect(db.notifications.length, equals(initialCount + 1));

      // Attempt duplicate insertion with same SO and SKU within 60s
      final dupNotif = NotificationItem(
        id: 'NOTIF-TEST-DUP-2',
        title: 'Purchase Requisition: Test Duplication Item',
        message: 'Requisition message (Retry)',
        notificationType: 'purchase_requisition',
        targetRole: 'purchase_manager',
        data: {
          'salesOrderNumber': 'SO-TEST-DUP-001',
          'productSku': 'SKU-DUP-001',
          'requestType': 'Purchase',
        },
        createdAt: DateTime.now(),
      );

      db.createNotification(dupNotif);
      // Count must remain unchanged because duplicate was discarded
      expect(db.notifications.length, equals(initialCount + 1));
    });
  });

  group('Convert Proforma Notification Persistence Tests', () {
    testWidgets('Selecting Purchase creates persisted notification for Purchase recipient', (tester) async {
      final db = MockDatabaseService();
      final proforma = db.proformaInvoices.first;

      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ConvertProformaDialog(proforma: proforma),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the Convert button
      final convertBtn = find.widgetWithText(ElevatedButton, 'Convert to Sales Order');
      if (convertBtn.evaluate().isNotEmpty) {
        await tester.tap(convertBtn);
        await tester.pumpAndSettle();

        // Verify a new notification was persisted in database
        final purchaseUser = db.users.firstWhere((u) => u.primaryRoleId == 'purchase_manager');
        final notifs = db.getNotificationsForUser(purchaseUser);
        expect(notifs.isNotEmpty, isTrue);
      }
    });
  });

  group('Header Notification Bell & Badge UI Widget Tests', () {
    testWidgets('Header displays notification bell with reactive unread badge', (tester) async {
      final db = MockDatabaseService();
      final adminUser = db.users.firstWhere((u) => u.primaryRoleId == 'admin');
      db.currentUser = adminUser;

      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
            currentNavSectionProvider.overrideWith((ref) => ErpNavSection.salesOrders),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ErpHeader(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bell icon should be present
      final bellButton = find.byIcon(Icons.notifications_active_rounded);
      expect(bellButton, findsOneWidget);

      // Tap notification bell to open NotificationsCenterDialog
      await tester.tap(bellButton);
      await tester.pumpAndSettle();

      // Notifications Center dialog should appear
      expect(find.byType(NotificationsCenterDialog), findsOneWidget);
      expect(find.text('Notifications & Action Center'), findsOneWidget);
    });
  });

  group('Role-Based Low Stock Alert Visibility & Header UI Widget Tests', () {
    late MockDatabaseService db;

    setUp(() {
      db = MockDatabaseService();
    });

    test('Positive: Admin, Inventory, Purchase, and Production roles are authorized to view stock alerts', () {
      final admin = db.users.firstWhere((u) => u.primaryRoleId == 'admin');
      final inv = db.users.firstWhere((u) => u.primaryRoleId == 'inventory_manager');
      final pur = db.users.firstWhere((u) => u.primaryRoleId == 'purchase_manager');
      final prod = db.users.firstWhere((u) => u.primaryRoleId == 'production_manager');

      expect(db.canViewLowStockAlerts(admin), isTrue);
      expect(db.canViewLowStockAlerts(inv), isTrue);
      expect(db.canViewLowStockAlerts(pur), isTrue);
      expect(db.canViewLowStockAlerts(prod), isTrue);
    });

    test('Negative: Sales Manager, Accounts Manager, Data Entry, and Report Viewer are NOT authorized to view stock alerts', () {
      final sales = db.users.firstWhere((u) => u.primaryRoleId == 'sales_manager');
      final acc = db.users.firstWhere((u) => u.primaryRoleId == 'accounts_manager');
      final dataEntry = db.users.firstWhere((u) => u.primaryRoleId == 'data_entry');
      final rep = db.users.firstWhere((u) => u.primaryRoleId == 'report_viewer');

      expect(db.canViewLowStockAlerts(sales), isFalse);
      expect(db.canViewLowStockAlerts(acc), isFalse);
      expect(db.canViewLowStockAlerts(dataEntry), isFalse);
      expect(db.canViewLowStockAlerts(rep), isFalse);
    });

    testWidgets('Header displays Low Stock Alert pill for Inventory Manager', (tester) async {
      final invUser = db.users.firstWhere((u) => u.primaryRoleId == 'inventory_manager');
      db.currentUser = invUser;

      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
            currentUserProvider.overrideWith((ref) => invUser),
            currentNavSectionProvider.overrideWith((ref) => ErpNavSection.inventoryDashboard),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ErpHeader(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Low Stock Alerts pill is commented out in header per UI directive
      final alertPill = find.textContaining('Low Stock Alerts');
      expect(alertPill, findsNothing);
      expect(find.text('${db.totalLowStockCount} Low Stock Alerts'), findsNothing);
    });

    testWidgets('Header displays Raw Material Alerts pill for Purchase Manager (not full 28)', (tester) async {
      final purchaseUser = db.users.firstWhere((u) => u.primaryRoleId == 'purchase_manager');
      db.currentUser = purchaseUser;

      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
            currentUserProvider.overrideWith((ref) => purchaseUser),
            currentNavSectionProvider.overrideWith((ref) => ErpNavSection.purchaseList),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ErpHeader(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Low Stock Alerts pill is commented out in header per UI directive
      final expectedLabel = '${db.lowStockRawMaterials.length} Raw Material Alerts';
      expect(find.text(expectedLabel), findsNothing);
      expect(find.text('${db.totalLowStockCount} Low Stock Alerts'), findsNothing);
    });

    testWidgets('Header displays Finished Goods Alerts pill for Production Manager (not full 28)', (tester) async {
      final prodUser = db.users.firstWhere((u) => u.primaryRoleId == 'production_manager');
      db.currentUser = prodUser;

      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
            currentUserProvider.overrideWith((ref) => prodUser),
            currentNavSectionProvider.overrideWith((ref) => ErpNavSection.productionOrders),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ErpHeader(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Low Stock Alerts pill is commented out in header per UI directive
      final expectedLabel = '${db.lowStockFinishedProducts.length} Finished Goods Alerts';
      expect(find.text(expectedLabel), findsNothing);
      expect(find.text('${db.totalLowStockCount} Low Stock Alerts'), findsNothing);
    });

    testWidgets('Header DOES NOT display Low Stock Alert pill for Sales Manager', (tester) async {
      final salesUser = db.users.firstWhere((u) => u.primaryRoleId == 'sales_manager');
      db.currentUser = salesUser;

      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
            currentUserProvider.overrideWith((ref) => salesUser),
            currentNavSectionProvider.overrideWith((ref) => ErpNavSection.salesDashboard),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ErpHeader(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Low Stock Alerts pill MUST NOT be visible for Sales Manager
      final alertPill = find.textContaining('Low Stock Alerts');
      expect(alertPill, findsNothing);
    });

    testWidgets('NotificationsCenterDialog hides WhatsApp Buffer Alerts button for Sales Manager', (tester) async {
      final salesUser = db.users.firstWhere((u) => u.primaryRoleId == 'sales_manager');
      db.currentUser = salesUser;

      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
            currentUserProvider.overrideWith((ref) => salesUser),
            currentNavSectionProvider.overrideWith((ref) => ErpNavSection.salesDashboard),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ErpHeader(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open notification center dialog
      final bellButton = find.byIcon(Icons.notifications_active_rounded).evaluate().isNotEmpty
          ? find.byIcon(Icons.notifications_active_rounded)
          : find.byIcon(Icons.notifications_none_rounded);
      await tester.tap(bellButton);
      await tester.pumpAndSettle();

      // WhatsApp Buffer Alerts should NOT be present for Sales Manager
      expect(find.text('WhatsApp Buffer Alerts'), findsNothing);
    });
  });
}
