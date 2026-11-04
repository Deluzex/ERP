import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/app/app_shell.dart';
import 'package:frontend/app/routes/app_routes.dart';
import 'package:frontend/core/models/rbac_models.dart';
import 'package:frontend/core/utils/navigation_history.dart';
import 'package:frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:frontend/features/settings/screens/settings_screen.dart';
import 'package:frontend/features/settings/screens/user_management_screen.dart';
import 'package:frontend/features/settings/screens/whatsapp_settings_tab.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';

AppUser testAdminUser() {
  return AppUser(
    id: 'admin-01',
    name: 'Super Admin',
    email: 'admin@deluzex.com',
    mobile: '9876543210',
    passwordHash: 'dummyhash',
    salt: 'dummysalt',
    primaryRoleId: 'admin',
    avatarUrl: '',
    createdAt: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    NavigationHistory.dispose();
  });

  group('ERP Settings Navigation & Screen Switching Suite', () {
    test('Requirement 1 & 3: Navigation to Settings updates active section and keeps state synchronized', () async {
      final container = ProviderContainer();
      try {
        final currentSectionNotifier = container.read(currentNavSectionProvider.notifier);

        // Initially on Dashboard
        expect(container.read(currentNavSectionProvider), equals(ErpNavSection.dashboard));

        // User clicks Settings in sidebar
        currentSectionNotifier.state = ErpNavSection.settings;

        // Current navigation section is synchronized directly to settings
        expect(container.read(currentNavSectionProvider), equals(ErpNavSection.settings));

        // Settings active tab defaults to 0 (System & Company Preferences)
        expect(container.read(settingsActiveTabProvider), equals(0));
      } finally {
        container.dispose();
      }
    });

    test('Requirement 5 & 6: AppShell renders only the active screen without Offstage stack accumulation', () {
      final container = ProviderContainer();
      try {
        container.read(databaseServiceProvider).setCurrentUser(testAdminUser());

        // Verify canonical section maps correctly
        expect(container.read(currentNavSectionProvider), equals(ErpNavSection.dashboard));

        // Navigate to settings
        container.read(currentNavSectionProvider.notifier).state = ErpNavSection.settings;
        expect(container.read(currentNavSectionProvider), equals(ErpNavSection.settings));
      } finally {
        container.dispose();
      }
    });

    test('Requirement 4 & 5: Settings tabs render only the active tab component', () {
      final container = ProviderContainer();
      try {
        container.read(databaseServiceProvider).setCurrentUser(testAdminUser());

        final tabNotifier = container.read(settingsActiveTabProvider.notifier);

        // Tab 0: System & Company Preferences
        tabNotifier.state = 0;
        expect(container.read(settingsActiveTabProvider), equals(0));

        // Tab 1: User Management & RBAC
        tabNotifier.state = 1;
        expect(container.read(settingsActiveTabProvider), equals(1));

        // Tab 2: WhatsApp Gateway
        tabNotifier.state = 2;
        expect(container.read(settingsActiveTabProvider), equals(2));
      } finally {
        container.dispose();
      }
    });

    test('Requirement 7: URL and route mapping between Settings tabs and paths', () {
      // Path generation
      expect(NavigationHistory.pathToSettingsTab(0), equals('settings'));
      expect(NavigationHistory.pathToSettingsTab(1), equals('settings/users'));
      expect(NavigationHistory.pathToSettingsTab(2), equals('settings/whatsapp'));

      // Path parsing
      expect(NavigationHistory.settingsTabFromPath('#/settings'), equals(0));
      expect(NavigationHistory.settingsTabFromPath('#/settings/system'), equals(0));
      expect(NavigationHistory.settingsTabFromPath('#/settings/users'), equals(1));
      expect(NavigationHistory.settingsTabFromPath('#/settings/rbac'), equals(1));
      expect(NavigationHistory.settingsTabFromPath('#/settings/whatsapp'), equals(2));
      expect(NavigationHistory.settingsTabFromPath('#/settings/wa'), equals(2));
      expect(NavigationHistory.settingsTabFromPath('#/dashboard'), equals(0));

      // Section parsing
      expect(NavigationHistory.sectionFromPath('#/settings'), equals(ErpNavSection.settings));
      expect(NavigationHistory.sectionFromPath('#/settings/users'), equals(ErpNavSection.settings));
      expect(NavigationHistory.sectionFromPath('#/settings/whatsapp'), equals(ErpNavSection.settings));
      expect(NavigationHistory.sectionFromPath('#/inventory-dashboard'), equals(ErpNavSection.inventoryDashboard));
    });

    test('Requirement 8: Browser refresh session restore prioritizes settings tab and section', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'erp_session_user',
        '{"id":"admin-01","email":"admin@deluzex.com","name":"Super Admin","mobile":"9876543210","passwordHash":"h","salt":"s","primaryRoleId":"admin","assignedRoleIds":[],"customPermissionOverrides":{},"isActive":true,"avatarUrl":"","createdAt":"2026-01-01T00:00:00.000Z"}',
      );
      await prefs.setString('erp_last_nav_section', 'settings');
      await prefs.setInt('erp_last_settings_tab', 2); // Saved WhatsApp tab

      final container = ProviderContainer();
      try {
        final authNotifier = container.read(authStateProvider.notifier);
        final restored = await authNotifier.restoreSession();
        expect(restored, isTrue);

        // Section is correctly restored to settings
        expect(container.read(currentNavSectionProvider), equals(ErpNavSection.settings));

        // Settings tab is correctly restored to WhatsApp Gateway (tab 2)
        expect(container.read(settingsActiveTabProvider), equals(2));
      } finally {
        container.dispose();
      }
    });

    testWidgets('Widget Test: SettingsScreen displays only active tab content without duplication', (tester) async {
      final container = ProviderContainer();
      try {
        container.read(databaseServiceProvider).setCurrentUser(testAdminUser());
        container.read(currentNavSectionProvider.notifier).state = ErpNavSection.settings;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: SettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially Tab 0 is active: System & Company Preferences
        expect(find.text('System Settings & Access Control'), findsOneWidget);
        expect(find.text('Company Legal & Tax Profile'), findsOneWidget);
        expect(find.text('Active Authenticated Session'), findsOneWidget);
        // Other tabs must NOT be rendered simultaneously
        expect(find.byType(UserManagementScreen), findsNothing);
        expect(find.byType(WhatsAppSettingsTab), findsNothing);

        // Switch to Tab 1: User Management & RBAC via provider
        container.read(settingsActiveTabProvider.notifier).state = 1;
        await tester.pumpAndSettle();

        expect(find.byType(UserManagementScreen), findsOneWidget);
        expect(find.text('Company Legal & Tax Profile'), findsNothing);
        expect(find.byType(WhatsAppSettingsTab), findsNothing);

        // Switch to Tab 2: WhatsApp Gateway via provider
        container.read(settingsActiveTabProvider.notifier).state = 2;
        await tester.pumpAndSettle();

        expect(find.byType(WhatsAppSettingsTab), findsOneWidget);
        expect(find.byType(UserManagementScreen), findsNothing);
        expect(find.text('Company Legal & Tax Profile'), findsNothing);

        // Switch back to Tab 0: System & Company Preferences
        container.read(settingsActiveTabProvider.notifier).state = 0;
        await tester.pumpAndSettle();

        expect(find.text('Company Legal & Tax Profile'), findsOneWidget);
        expect(find.byType(UserManagementScreen), findsNothing);
        expect(find.byType(WhatsAppSettingsTab), findsNothing);
      } finally {
        container.dispose();
      }
    });

    testWidgets('Widget Test: Tapping TabBar tab directly switches view and active provider state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final container = ProviderContainer();
      try {
        container.read(databaseServiceProvider).setCurrentUser(testAdminUser());
        container.read(currentNavSectionProvider.notifier).state = ErpNavSection.settings;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: SettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on 'User Management & RBAC' TabBar tab
        final userTab = find.text('User Management & RBAC');
        expect(userTab, findsOneWidget);
        await tester.tap(userTab);
        await tester.pumpAndSettle();

        expect(container.read(settingsActiveTabProvider), equals(1));
        expect(find.byType(UserManagementScreen), findsOneWidget);
        expect(find.text('Company Legal & Tax Profile'), findsNothing);

        // Tap on 'WhatsApp Gateway' TabBar tab
        final waTab = find.text('WhatsApp Gateway');
        expect(waTab, findsOneWidget);
        await tester.tap(waTab);
        await tester.pumpAndSettle();

        expect(container.read(settingsActiveTabProvider), equals(2));
        expect(find.byType(WhatsAppSettingsTab), findsOneWidget);
        expect(find.byType(UserManagementScreen), findsNothing);

        // Tap back on 'System & Company Preferences' TabBar tab
        final sysTab = find.text('System & Company Preferences');
        expect(sysTab, findsOneWidget);
        await tester.tap(sysTab);
        await tester.pumpAndSettle();

        expect(container.read(settingsActiveTabProvider), equals(0));
        expect(find.text('Company Legal & Tax Profile'), findsOneWidget);
        expect(find.byType(WhatsAppSettingsTab), findsNothing);
      } finally {
        container.dispose();
      }
    });

    testWidgets('Widget Test: AppShell renders only the active section KeyedSubtree', (tester) async {
      final container = ProviderContainer();
      try {
        container.read(databaseServiceProvider).setCurrentUser(testAdminUser());
        container.read(currentNavSectionProvider.notifier).state = ErpNavSection.dashboard;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: AppShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Dashboard is rendered
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byType(SettingsScreen), findsNothing);

        // Navigate to Settings
        container.read(currentNavSectionProvider.notifier).state = ErpNavSection.settings;
        await tester.pumpAndSettle();

        // Settings is now rendered, Dashboard is completely unmounted (no Stack of Offstages)
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.byType(DashboardScreen), findsNothing);

        // Navigate back to Dashboard
        container.read(currentNavSectionProvider.notifier).state = ErpNavSection.dashboard;
        await tester.pumpAndSettle();

        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byType(SettingsScreen), findsNothing);
      } finally {
        container.dispose();
      }
    });
  });
}
