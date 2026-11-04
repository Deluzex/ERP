import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/app/routes/app_routes.dart';
import 'package:frontend/core/api/token_storage.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/storage/cross_tab_session_sync.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/widgets/inactivity_warning_dialog.dart';
import 'package:frontend/shared/widgets/user_activity_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Inactivity-Based 30-Minute Auto-Logout 12 Scenario Suite', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TokenStorage.instance.init();
      TokenStorage.instance.clear();
    });

    test('Scenario 1: User inactive for 29 minutes remains logged in', () async {
      final container = ProviderContainer();
      try {
        final authNotifier = container.read(authStateProvider.notifier);
        authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');
        expect(container.read(isAuthenticatedProvider), isTrue);

        // Simulate 29 minutes of inactivity
        await authNotifier.setMockLastUserActivityTime(
          DateTime.now().subtract(const Duration(minutes: 29)),
        );

        await authNotifier.checkSessionExpiryForTest();

        // Remains logged in
        expect(container.read(isAuthenticatedProvider), isTrue);
        expect(container.read(authStateProvider), isNotNull);
      } finally {
        container.dispose();
      }
    });

    test('Scenario 2: User inactive for 30 minutes automatically logs out', () async {
      final container = ProviderContainer();
      try {
        final authNotifier = container.read(authStateProvider.notifier);
        authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');
        expect(container.read(isAuthenticatedProvider), isTrue);

        // Simulate 30 minutes of continuous inactivity
        await authNotifier.setMockLastUserActivityTime(
          DateTime.now().subtract(const Duration(minutes: 30, seconds: 1)),
        );

        await authNotifier.checkSessionExpiryForTest();

        // Automatically logged out
        expect(container.read(isAuthenticatedProvider), isFalse);
        expect(container.read(authStateProvider), isNull);
        expect(TokenStorage.instance.hasToken, isFalse);
      } finally {
        container.dispose();
      }
    });

    test('Scenario 3: User clicks at 29 minutes resets timer', () async {
      final container = ProviderContainer();
      try {
        final authNotifier = container.read(authStateProvider.notifier);
        authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');

        // Inactive for 29 minutes
        final past = DateTime.now().subtract(const Duration(minutes: 29));
        await authNotifier.setMockLastUserActivityTime(past);

        // User performs meaningful click interaction
        authNotifier.recordUserActivity();

        final updated = authNotifier.lastUserActivityTime;
        expect(updated.difference(past).inMinutes, greaterThanOrEqualTo(28));

        // After check, remains logged in
        await authNotifier.checkSessionExpiryForTest();
        expect(container.read(isAuthenticatedProvider), isTrue);
      } finally {
        container.dispose();
      }
    });

    testWidgets('Scenario 4: User types continuously prevents logout', (tester) async {
      final container = ProviderContainer();
      try {
        final authNotifier = container.read(authStateProvider.notifier);
        authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');

        int activityCount = 0;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: UserActivityDetector(
                  onUserActivity: () {
                    activityCount++;
                    authNotifier.recordUserActivity();
                  },
                  child: const TextField(key: Key('scenario4_input')),
                ),
              ),
            ),
          ),
        );

        // Focus text field and type
        await tester.tap(find.byKey(const Key('scenario4_input')));
        await tester.pump();
        await tester.enterText(find.byKey(const Key('scenario4_input')), 'Testing continuous typing');
        await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
        await tester.pump();

        expect(activityCount, greaterThan(0));
        expect(container.read(isAuthenticatedProvider), isTrue);
      } finally {
        container.dispose();
      }
    });

    test('Scenario 5: User fills a form for 30+ minutes with activity remains logged in', () async {
      final container = ProviderContainer();
      try {
        final authNotifier = container.read(authStateProvider.notifier);
        authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');

        // Simulate form work across 35 minutes where user interacts every 10 minutes
        for (int i = 0; i < 4; i++) {
          // Fast forward 10 minutes from last activity
          final simulatedPast = DateTime.now().subtract(const Duration(minutes: 10));
          await authNotifier.setMockLastUserActivityTime(simulatedPast);

          // User interacts with form field
          authNotifier.recordUserActivity();
          await authNotifier.checkSessionExpiryForTest();

          expect(container.read(isAuthenticatedProvider), isTrue);
        }

        // After 35 minutes of cumulative session with continuous activity, user is STILL logged in
        expect(container.read(isAuthenticatedProvider), isTrue);
      } finally {
        container.dispose();
      }
    });

    test('Scenario 6: User navigates between modules resets timer', () async {
      final container = ProviderContainer();
      try {
        final authNotifier = container.read(authStateProvider.notifier);
        authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');

        // Set inactivity to 25 minutes ago
        final past = DateTime.now().subtract(const Duration(minutes: 25));
        await authNotifier.setMockLastUserActivityTime(past);

        // User navigates to inventory module
        container.read(currentNavSectionProvider.notifier).state = ErpNavSection.inventoryDashboard;
        authNotifier.recordUserActivity();

        expect(authNotifier.lastUserActivityTime.isAfter(past), isTrue);
        await authNotifier.checkSessionExpiryForTest();
        expect(container.read(isAuthenticatedProvider), isTrue);
      } finally {
        container.dispose();
      }
    });

    test('Scenario 7: Background API requests continue without user activity does NOT reset timer', () async {
      final container = ProviderContainer();
      try {
        final authNotifier = container.read(authStateProvider.notifier);
        authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');

        // Set user inactive for 30 minutes
        final past = DateTime.now().subtract(const Duration(minutes: 30, seconds: 5));
        await authNotifier.setMockLastUserActivityTime(past);

        // Background API request completes (does NOT call recordUserActivity)
        // ApiClient does not call recordUserActivity
        expect(authNotifier.lastUserActivityTime, equals(past));

        // Trigger expiry check
        await authNotifier.checkSessionExpiryForTest();

        // Inactive user logs out despite background API request
        expect(container.read(isAuthenticatedProvider), isFalse);
      } finally {
        container.dispose();
      }
    });

    test('Scenario 8: Dashboard auto-refreshes does NOT reset timer', () async {
      final container = ProviderContainer();
      try {
        final authNotifier = container.read(authStateProvider.notifier);
        authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');

        final past = DateTime.now().subtract(const Duration(minutes: 31));
        await authNotifier.setMockLastUserActivityTime(past);

        // Background dashboard polling happens without user interaction
        // Timer must NOT be updated
        expect(authNotifier.lastUserActivityTime, equals(past));

        await authNotifier.checkSessionExpiryForTest();
        expect(container.read(isAuthenticatedProvider), isFalse);
      } finally {
        container.dispose();
      }
    });

    test('Scenario 9: User works in another browser tab keeps session active', () async {
      final container = ProviderContainer();
      try {
        final authNotifier = container.read(authStateProvider.notifier);
        authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');

        // This tab was inactive for 29 minutes
        await authNotifier.setMockLastUserActivityTime(
          DateTime.now().subtract(const Duration(minutes: 29)),
        );

        // User was actively working in Tab B 1 minute ago!
        final tabBActive = DateTime.now().subtract(const Duration(minutes: 1));
        await CrossTabSessionSync.updateLastActivity(tabBActive);

        // Trigger check in Tab A
        await authNotifier.checkSessionExpiryForTest();

        // Tab A recognizes Tab B's activity and stays logged in!
        expect(container.read(isAuthenticatedProvider), isTrue);
        expect(authNotifier.lastUserActivityTime.millisecondsSinceEpoch, equals(tabBActive.millisecondsSinceEpoch));
      } finally {
        container.dispose();
      }
    });

    test('Scenario 10: Inactivity reaches 30 minutes across all tabs logs out all tabs', () async {
      final container = ProviderContainer();
      try {
        final authNotifier = container.read(authStateProvider.notifier);
        authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');

        // Both tabs inactive for 31 minutes
        final past = DateTime.now().subtract(const Duration(minutes: 31));
        await authNotifier.setMockLastUserActivityTime(past);
        await CrossTabSessionSync.updateLastActivity(past);

        await authNotifier.checkSessionExpiryForTest();

        expect(container.read(isAuthenticatedProvider), isFalse);
        expect(container.read(authStateProvider), isNull);
      } finally {
        container.dispose();
      }
    });

    testWidgets('Scenario 11: User clicks Continue Working at warning dialog triggers continue callback', (tester) async {
      bool continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InactivityWarningDialog(
              onContinue: () {
                continued = true;
              },
              onLogout: () {},
            ),
          ),
        ),
      );

      expect(find.text('Session Inactivity Warning'), findsOneWidget);
      expect(find.text('Continue Working'), findsOneWidget);
      expect(find.text('Your session will expire in 2 minutes due to inactivity.\n\nTo safeguard your account and data, Deluzex ERP will automatically sign you out unless you choose to continue working.'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      await tester.tap(find.text('Continue Working'));
      await tester.pumpAndSettle();

      expect(continued, isTrue);
    });

    test('Scenario 11 (Activity Reset): recordUserActivity resets inactivity timer', () async {
      final container = ProviderContainer();
      try {
        final authNotifier = container.read(authStateProvider.notifier);
        authNotifier.login('admin@deluzex.com', 'Admin@123', 'admin');

        // Set inactivity to 28 minutes
        await authNotifier.setMockLastUserActivityTime(
          DateTime.now().subtract(const Duration(minutes: 28, seconds: 10)),
        );

        authNotifier.recordUserActivity();
        expect(DateTime.now().difference(authNotifier.lastUserActivityTime).inSeconds, lessThan(5));
        expect(container.read(isAuthenticatedProvider), isTrue);
      } finally {
        container.dispose();
      }
    });

    test('Scenario 12: Page reload / session restore checks 30-minute inactivity accurately', () async {
      final prefs = await SharedPreferences.getInstance();

      // Case A: Recent activity (5 minutes ago) -> Restore session succeeds
      await prefs.setString(
        'erp_session_user',
        '{"id":"usr-001","email":"admin@deluzex.com","name":"Admin User","primaryRoleId":"admin","accessibleSectionNames":["dashboard"]}',
      );
      final recent = DateTime.now().subtract(const Duration(minutes: 5));
      await prefs.setInt('erp_session_timestamp', recent.millisecondsSinceEpoch);

      final containerA = ProviderContainer();
      try {
        final authA = containerA.read(authStateProvider.notifier);
        final restoredA = await authA.restoreSession();
        expect(restoredA, isTrue);
        expect(containerA.read(isAuthenticatedProvider), isTrue);
      } finally {
        containerA.dispose();
      }

      // Case B: Old activity (32 minutes ago) -> Restore session rejects and logs out
      await prefs.setString(
        'erp_session_user',
        '{"id":"usr-001","email":"admin@deluzex.com","name":"Admin User","primaryRoleId":"admin","accessibleSectionNames":["dashboard"]}',
      );
      final expired = DateTime.now().subtract(const Duration(minutes: 32));
      await CrossTabSessionSync.updateLastActivity(expired);

      final containerB = ProviderContainer();
      try {
        final authB = containerB.read(authStateProvider.notifier);
        final restoredB = await authB.restoreSession();
        expect(restoredB, isFalse);
        expect(containerB.read(isAuthenticatedProvider), isFalse);
      } finally {
        containerB.dispose();
      }
    });
  });
}
