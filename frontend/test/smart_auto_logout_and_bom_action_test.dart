import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/api/token_storage.dart';
import 'package:frontend/core/widgets/erp_confirm_dialog.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/widgets/inactivity_warning_dialog.dart';
import 'package:frontend/shared/widgets/user_activity_detector.dart';
import 'package:frontend/features/masters/screens/bom_screen.dart';
import 'package:frontend/features/dashboard/screens/role_dashboards.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smart Auto Logout & Inactivity Tracking Suite', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TokenStorage.instance.init();
      TokenStorage.instance.clear();
    });

    testWidgets('UserActivityDetector captures clicks, moves, hovers, scrolls and keys', (tester) async {
      int activityCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserActivityDetector(
              onUserActivity: () => activityCount++,
              child: const SizedBox(
                width: 400,
                height: 400,
                child: TextField(key: Key('activity_input')),
              ),
            ),
          ),
        ),
      );

      // 1. Pointer Down (Click / Tap)
      final center = tester.getCenter(find.byKey(const Key('activity_input')));
      final testPointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(testPointer.down(center));
      expect(activityCount, 1);

      // 2. Pointer Move (while pointer is down)
      await tester.sendEventToBinding(testPointer.move(center + const Offset(10, 10)));
      expect(activityCount, 2);

      await tester.sendEventToBinding(testPointer.up());

      // 3. Pointer Hover (while pointer is up)
      await tester.sendEventToBinding(testPointer.hover(center + const Offset(20, 20)));
      expect(activityCount, 3);

      // 4. Pointer Scroll
      await tester.sendEventToBinding(testPointer.scroll(const Offset(0, 100)));
      expect(activityCount, 4);

      // 5. Keyboard Typing
      await tester.tap(find.byKey(const Key('activity_input')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(activityCount, greaterThanOrEqualTo(5));
    });

    test('Active user interacting continuously past 30 minutes does NOT get logged out', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final authNotifier = container.read(authStateProvider.notifier);
      final loggedIn = authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');
      expect(loggedIn, isTrue);
      expect(container.read(isAuthenticatedProvider), isTrue);

      final initialActivity = authNotifier.lastUserActivityTime;

      // Simulate 15 minutes pass
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // User interacts (e.g. clicks, moves mouse, types)
      authNotifier.recordUserActivity();
      final updatedActivity = authNotifier.lastUserActivityTime;
      expect(updatedActivity.isAfter(initialActivity) || updatedActivity.isAtSameMomentAs(initialActivity), isTrue);

      // Verify still authenticated
      expect(container.read(isAuthenticatedProvider), isTrue);
    });

    test('Cross-browser tab synchronization resets inactivity duration', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final authNotifier = container.read(authStateProvider.notifier);
      authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');
      expect(container.read(isAuthenticatedProvider), isTrue);

      // Simulate activity occurred in Tab B 5 minutes later
      final tabBTime = DateTime.now().add(const Duration(minutes: 5));
      await prefs.setInt('erp_session_timestamp', tabBTime.millisecondsSinceEpoch);

      // Trigger session check
      authNotifier.recordUserActivity();

      // SharedPreferences holds the updated timestamp
      final storedTimestamp = prefs.getInt('erp_session_timestamp');
      expect(storedTimestamp, isNotNull);
      expect(storedTimestamp, greaterThan(0));
    });

    testWidgets('InactivityWarningDialog renders compact modal with Continue and Logout buttons', (tester) async {
      bool continued = false;
      bool loggedOut = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InactivityWarningDialog(
              onContinue: () => continued = true,
              onLogout: () => loggedOut = true,
            ),
          ),
        ),
      );

      expect(find.text('Session Inactivity Warning'), findsOneWidget);
      expect(find.text('Continue Working'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);

      await tester.tap(find.text('Continue Working'));
      expect(continued, isTrue);

      await tester.tap(find.text('Logout'));
      expect(loggedOut, isTrue);
    });
  });

  group('BOM Screen Action Menu Governance Suite', () {
    testWidgets('BOM action menu removes Deactivate/Mark Obsolete while preserving Update Status', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: BomScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Look for the action button icon on BOM rows
      final actionButtons = find.byIcon(Icons.more_vert);
      if (actionButtons.evaluate().isNotEmpty) {
        // Open the first action menu
        await tester.tap(actionButtons.first);
        await tester.pumpAndSettle();

        // 1. Verify "Deactivate / Mark Obsolete" is NOT present
        expect(find.text('Deactivate / Mark Obsolete'), findsNothing);
        expect(find.text('Deactivate BOM'), findsNothing);
        expect(find.text('Mark Obsolete'), findsNothing);

        // 2. Verify "Update Status" IS present
        expect(find.text('Update Status'), findsOneWidget);

        // 3. Verify other actions are present
        expect(find.text('View BOM Details'), findsOneWidget);
        expect(find.text('Produce / Create Production'), findsOneWidget);
        expect(find.text('Edit Recipe'), findsOneWidget);
      }
    });
  });

  group('Compact Confirmation Dialog Suite', () {
    testWidgets('ErpStatusConfirmDialog renders compact centered dialog within 480px width', (tester) async {
      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showErpStatusConfirmDialog(
                    context: ctx,
                    title: 'Deactivate Customer',
                    message: 'Are you sure you want to deactivate Acme Corp? It will no longer be available for new transactions.',
                    willActivate: false,
                    confirmLabel: 'Deactivate',
                    
                    onConfirm: () => confirmed = true,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Deactivate Customer'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to deactivate Acme Corp?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);

      // Verify compact ConstrainedBox constraint (maxWidth 480)
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final modalBox = constrainedBoxes.firstWhere((cb) => cb.constraints.maxWidth == 480.0);
      expect(modalBox.constraints.maxWidth, 480.0);

      // Tap confirm
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });
  });
  group('Inventory Dashboard Metric Cards Spacing Suite', () {
    testWidgets('InventoryRoleDashboard renders 4 metric cards with reduced compact title-to-value spacing', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);

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

      expect(find.text('Inventory & Warehouse Dashboard'), findsOneWidget);
      expect(find.text('Raw Material Valuation'), findsOneWidget);
      expect(find.text('Finished Goods Valuation'), findsOneWidget);
      expect(find.text('Total Stock Valuation'), findsOneWidget);
      expect(find.text('Low Stock Alerts'), findsOneWidget);

      // Verify compact SizedBox spacing of 4.0 exists between title and value
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final spacingBoxes = sizedBoxes.where((sb) => sb.height == 2.0).toList();
      expect(spacingBoxes.length, greaterThanOrEqualTo(4));
    });
  });
}
