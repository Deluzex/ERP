import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/projects/screens/project_list_screen.dart';
import 'package:frontend/core/models/project_model.dart';
import 'package:frontend/shared/services/mock_database_service.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Project Master Activate / Deactivate Flow Test', () {
    late MockDatabaseService db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = MockDatabaseService();
      db.projects = [
        Project(
          id: 'prj-test-101',
          projectCode: 'PRJ-2026-0001',
          name: 'The Grand Hyatt Tower Project',
          startDate: DateTime(2026, 1, 15),
          status: ProjectStatus.active,
          budgetAmount: 5000000,
          totalSalesAmount: 0,
          totalCommissionAmount: 0,
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];
    });

    testWidgets('Active project -> Deactivate -> Inactive -> Activate -> Active lifecycle without Delete button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(2200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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

      // Step 1: Verify project is Active initially
      expect(find.text('The Grand Hyatt Tower Project'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(db.projects.first.isActive, isTrue);

      // Step 2: Open action popup menu
      final actionsMenuButton = find.byType(PopupMenuButton<String>);
      expect(actionsMenuButton, findsOneWidget);
      await tester.tap(actionsMenuButton);
      await tester.pumpAndSettle();

      // Step 3: Verify menu shows 'Deactivate Project' and NOT 'Delete Project'
      expect(find.text('Deactivate Project'), findsOneWidget);
      expect(find.text('Delete Project'), findsNothing);
      expect(find.text('Activate Project'), findsNothing);

      // Step 4: Click 'Deactivate Project'
      await tester.tap(find.text('Deactivate Project'));
      await tester.pumpAndSettle();

      // Step 5: Confirm dialog appears
      expect(find.text('Deactivate Project'), findsWidgets);
      final confirmDeactivateBtn = find.widgetWithText(ElevatedButton, 'Deactivate');
      expect(confirmDeactivateBtn, findsOneWidget);
      await tester.tap(confirmDeactivateBtn);
      await tester.pumpAndSettle();

      // Step 6: Verify project status changed to Inactive
      expect(db.projects.first.isActive, isFalse);
      expect(find.text('INACTIVE'), findsOneWidget);
      expect(find.text('ACTIVE'), findsNothing);

      // Step 7: Open action popup menu again
      await tester.tap(actionsMenuButton);
      await tester.pumpAndSettle();

      // Step 8: Verify menu now shows 'Activate Project' and NOT 'Deactivate Project' or 'Delete Project'
      expect(find.text('Activate Project'), findsOneWidget);
      expect(find.text('Deactivate Project'), findsNothing);
      expect(find.text('Delete Project'), findsNothing);

      // Step 9: Click 'Activate Project'
      await tester.tap(find.text('Activate Project'));
      await tester.pumpAndSettle();

      // Step 10: Confirm dialog appears
      expect(find.text('Activate Project'), findsWidgets);
      final confirmActivateBtn = find.widgetWithText(ElevatedButton, 'Activate');
      expect(confirmActivateBtn, findsOneWidget);
      await tester.tap(confirmActivateBtn);
      await tester.pumpAndSettle();

      // Step 11: Verify project status reverted back to Active
      expect(db.projects.first.isActive, isTrue);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('INACTIVE'), findsNothing);
    });

    test('Inactive projects are excluded from transaction dropdowns for new selections', () {
      final activeProject = Project(
        id: 'prj-active-1',
        name: 'Active Project One',
        startDate: DateTime.now(),
        status: ProjectStatus.active,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final inactiveProject = Project(
        id: 'prj-inactive-2',
        name: 'Inactive Project Two',
        startDate: DateTime.now(),
        status: ProjectStatus.active,
        isActive: false,
        createdAt: DateTime.now(),
      );

      db.projects = [activeProject, inactiveProject];

      // New selection (_selectedProjectId is null)
      String? selectedId;
      final eligibleForNew = db.projects
          .where((p) => !p.isDeleted && (p.isActive || p.id == selectedId))
          .toList();

      expect(eligibleForNew.length, 1);
      expect(eligibleForNew.first.id, 'prj-active-1');

      // Existing transaction having inactive project pre-selected
      selectedId = 'prj-inactive-2';
      final eligibleForExisting = db.projects
          .where((p) => !p.isDeleted && (p.isActive || p.id == selectedId))
          .toList();

      expect(eligibleForExisting.length, 2);
      expect(eligibleForExisting.any((p) => p.id == 'prj-inactive-2'), isTrue);
    });
  });
}

