import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/projects/screens/project_list_screen.dart';
import 'package:frontend/core/models/project_model.dart';
import 'package:frontend/shared/services/mock_database_service.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Master Edit Disabled for Inactive Records & Unlinked ID Governance', () {
    late MockDatabaseService db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = MockDatabaseService();
    });

    testWidgets('Inactive project has Edit action disabled with tooltip and cannot be edited', (tester) async {
      await tester.binding.setSurfaceSize(const Size(2800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      db.projects = [
        Project(
          id: 'prj-inactive-1',
          projectCode: 'PRJ-2026-0002',
          name: 'Inactive Tower Project',
          startDate: DateTime(2026, 1, 15),
          status: ProjectStatus.active,
          budgetAmount: 1000000,
          totalSalesAmount: 0,
          totalCommissionAmount: 0,
          isActive: false,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProjectListScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify inactive project rendered
      expect(find.text('Inactive Tower Project'), findsOneWidget);
      expect(find.text('INACTIVE'), findsOneWidget);

      // Open popup menu
      final actionsMenuButton = find.byType(PopupMenuButton<String>);
      expect(actionsMenuButton, findsOneWidget);
      await tester.tap(actionsMenuButton);
      await tester.pumpAndSettle();

      // Find Edit Project PopupMenuItem
      final editItem = find.widgetWithText(PopupMenuItem<String>, 'Edit Project');
      expect(editItem, findsOneWidget);

      // Verify that enabled is false
      final popupMenuItem = tester.widget<PopupMenuItem<String>>(editItem);
      expect(popupMenuItem.enabled, isFalse);

      // Verify tooltip
      final tooltip = find.byWidgetPredicate((w) =>
          w is Tooltip && w.message == 'Cannot edit an inactive record. Activate it first.');
      expect(tooltip, findsOneWidget);

      // Tapping disabled item does not open dialog
      await tester.tap(editItem, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Edit Architectural Project'), findsNothing);
    });

    testWidgets('Active project with unlinked CUST-002 customer ID opens Edit dialog without crashing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(2800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Project references CUST-002 which is NOT in db.customers
      db.projects = [
        Project(
          id: 'prj-active-cust-002',
          projectCode: 'PRJ-2026-0003',
          name: 'Hyatt Presidential Suite Renovation',
          customerId: 'CUST-002',
          customerName: 'Grand Hyatt Hotel Group',
          startDate: DateTime(2026, 1, 15),
          status: ProjectStatus.active,
          budgetAmount: 2500000,
          totalSalesAmount: 0,
          totalCommissionAmount: 0,
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProjectListScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hyatt Presidential Suite Renovation'), findsOneWidget);

      // Open popup menu
      final actionsMenuButton = find.byType(PopupMenuButton<String>);
      await tester.tap(actionsMenuButton);
      await tester.pumpAndSettle();

      // Find Edit Project PopupMenuItem and verify enabled is true
      final editItem = find.widgetWithText(PopupMenuItem<String>, 'Edit Project');
      expect(editItem, findsOneWidget);
      final popupMenuItem = tester.widget<PopupMenuItem<String>>(editItem);
      expect(popupMenuItem.enabled, isTrue);

      // Click Edit Project -> MUST NOT throw assertion error
      await tester.tap(editItem);
      await tester.pumpAndSettle();

      // Verify dialog opened successfully with unlinked customer name displayed
      expect(find.text('Edit Architectural Project'), findsOneWidget);
      expect(find.text('Grand Hyatt Hotel Group'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Architectural Project'), findsNothing);
    });
  });
}
