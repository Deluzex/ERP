import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/app/app_shell.dart';
import 'package:frontend/app/routes/app_routes.dart';
import 'package:frontend/core/api/token_storage.dart';
import 'package:frontend/core/storage/form_draft_service.dart';
import 'package:frontend/core/widgets/erp_data_table.dart';
import 'package:frontend/core/widgets/record_details_view.dart';
import 'package:frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:frontend/features/dashboard/screens/role_dashboards.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen Retention, Form Draft Persistence & Universal Selection Suite', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TokenStorage.instance.init();
      TokenStorage.instance.clear();
      await FormDraftService.instance.clearAllDrafts();
    });

    testWidgets('Dashboard metric cards render with compact vertical spacing without overflow', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authStateProvider.notifier).login('admin@deluzex.com', 'Admin@123', 'admin');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that DashboardScreen renders successfully
      expect(find.text('Enterprise Operations Dashboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await container.read(authStateProvider.notifier).logout();
      await tester.pumpAndSettle();
    });

    testWidgets('Inventory Dashboard metric cards render with compact spacing', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authStateProvider.notifier).login('inventory@deluzex.com', 'Admin@123', 'inventory_manager');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InventoryRoleDashboard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Inventory & Warehouse'), findsOneWidget);
      expect(find.text('Raw Material Valuation'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await container.read(authStateProvider.notifier).logout();
      await tester.pumpAndSettle();
    });

    testWidgets('AppShell wraps visible content inside SelectionArea for universal text copying', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authStateProvider.notifier).login('admin@deluzex.com', 'Admin@123', 'admin');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SelectionArea exists in AppShell wrapping the content
      expect(find.byType(SelectionArea), findsOneWidget);
      await container.read(authStateProvider.notifier).logout();
      await tester.pumpAndSettle();
    });

    test('F5 / browser reload restores user to the exact screen they were working on', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('erp_session_user', '{"id":"USR-001","name":"Alex Admin","email":"admin@deluzex.com","primaryRoleId":"admin","isActive":true}');
      await prefs.setString('erp_last_nav_section', ErpNavSection.createQuotation.name);
      await prefs.setInt('erp_session_timestamp', DateTime.now().millisecondsSinceEpoch);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final restored = await container.read(authStateProvider.notifier).restoreSession();
      expect(restored, isTrue);

      final currentSection = container.read(currentNavSectionProvider);
      expect(currentSection, ErpNavSection.createQuotation);
    });

    test('FormDraftService saves and restores drafts across page reload', () async {
      final draftData = {
        'partyType': 'customer',
        'selectedPartyId': 'CUST-001',
        'contactPerson': 'John Doe',
        'notes': 'Urgent project order',
        'items': [
          {
            'itemType': 'finishedProduct',
            'itemId': 'FP-001',
            'itemName': 'Chandelier Pendant',
            'quantity': 5.0,
            'rate': 12000.0,
          }
        ]
      };

      await FormDraftService.instance.saveDraft('quotation', draftData);

      final loadedDraft = await FormDraftService.instance.loadDraft('quotation');
      expect(loadedDraft, isNotNull);
      expect(loadedDraft!['selectedPartyId'], 'CUST-001');
      expect(loadedDraft['contactPerson'], 'John Doe');
      expect((loadedDraft['items'] as List).length, 1);

      // Verify clearDraft removes this draft
      await FormDraftService.instance.clearDraft('quotation');
      final cleared = await FormDraftService.instance.loadDraft('quotation');
      expect(cleared, isNull);
    });

    test('30-minute inactivity auto-logout clears all uncommitted form drafts', () async {
      // 1. User writes an uncommitted draft
      await FormDraftService.instance.saveDraft('quotation', {'partyId': 'CUST-100'});
      await FormDraftService.instance.saveDraft('sale_invoice', {'partyId': 'CUST-200'});

      expect(await FormDraftService.instance.loadDraft('quotation'), isNotNull);
      expect(await FormDraftService.instance.loadDraft('sale_invoice'), isNotNull);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final authNotifier = container.read(authStateProvider.notifier);
      authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');

      // 2. Inactivity timeout or logout occurs
      await authNotifier.logout();

      // 3. User is unauthenticated and all drafts are wiped clean
      expect(container.read(isAuthenticatedProvider), isFalse);
      expect(await FormDraftService.instance.loadDraft('quotation'), isNull);
      expect(await FormDraftService.instance.loadDraft('sale_invoice'), isNull);
    });
  });
}

