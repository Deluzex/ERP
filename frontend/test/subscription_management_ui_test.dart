import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/models/subscription_model.dart';
import 'package:frontend/shared/providers/subscription_provider.dart';
import 'package:frontend/shared/widgets/subscription_badge_pill.dart';
import 'package:frontend/shared/widgets/subscription_expired_dialog.dart';
import 'package:frontend/shared/widgets/subscription_reminder_dialog.dart';

void main() {
  group('Subscription Models & Daily Tracker Unit Tests', () {
    test('SubscriptionStatus.fromJson parses active subscription correctly', () {
      final json = {
        'clientName': 'Kamal Enterprise Ltd.',
        'planName': 'Diamond Annual',
        'isActive': true,
        'isExpired': false,
        'validFrom': '2026-01-01T00:00:00.000Z',
        'validUntil': '2027-01-01T00:00:00.000Z',
        'daysRemaining': 79,
        'showRenewalWarning': false,
        'supportPhone': '+91 98980 98980',
        'supportEmail': 'support@kamal.com',
      };

      final status = SubscriptionStatus.fromJson(json);
      expect(status.clientName, 'Kamal Enterprise Ltd.');
      expect(status.planName, 'Diamond Annual');
      expect(status.isActive, true);
      expect(status.isExpired, false);
      expect(status.daysRemaining, 79);
      expect(status.showRenewalWarning, false);
      expect(status.supportPhone, '+91 98980 98980');
    });

    test('SubscriptionReminderTracker prevents multiple popups on the same calendar day', () {
      SubscriptionReminderTracker.resetForTesting();
      expect(SubscriptionReminderTracker.shouldShowToday(), true);

      SubscriptionReminderTracker.markShownToday();
      expect(SubscriptionReminderTracker.shouldShowToday(), false);

      SubscriptionReminderTracker.resetForTesting();
      expect(SubscriptionReminderTracker.shouldShowToday(), true);
    });
  });

  group('Subscription UI Widgets Tests', () {
    testWidgets('SubscriptionExpiredDialog displays feelingful Gujarati copy and contact actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SubscriptionExpiredDialog.show(
                  context,
                  clientName: 'Kamal Manufacturing',
                  planName: 'Enterprise Edition',
                  expiredOn: '14 Oct 2026',
                  supportPhone: '+91 98250 12345',
                  supportEmail: 'billing@deluzex.com',
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Trigger Dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify Gujarati headers & feelingful messages
      expect(find.text('સબ્સ્ક્રિપ્શન સમાપ્ત થયેલ છે'), findsOneWidget);
      expect(find.textContaining('નમસ્કાર!\nઆપનું સબ્સ્ક્રિપ્શન સમાપ્ત થયેલ છે.'), findsOneWidget);
      expect(find.text('Kamal Manufacturing'), findsOneWidget);
      expect(find.text('Enterprise Edition'), findsOneWidget);

      // Verify buttons
      expect(find.text('WhatsApp પર સંપર્ક કરો'), findsOneWidget);
      expect(find.textContaining('કૉલ કરો'), findsOneWidget);
      expect(find.text('બંધ કરો (Close)'), findsOneWidget);

      // Dismiss dialog
      final closeFinder = find.text('બંધ કરો (Close)');
      await tester.ensureVisible(closeFinder);
      await tester.tap(closeFinder);
      await tester.pumpAndSettle();
      expect(find.text('સબ્સ્ક્રિપ્શન સમાપ્ત થયેલ છે'), findsNothing);
    });

    testWidgets('SubscriptionReminderDialog displays exact user-requested Gujarati reminder text', (tester) async {
      SubscriptionReminderTracker.resetForTesting();
      final status = SubscriptionStatus(
        clientName: 'Raj Lighting',
        planName: 'Standard Annual',
        isActive: true,
        isExpired: false,
        validFrom: DateTime.now().subtract(const Duration(days: 345)),
        validUntil: DateTime.now().add(const Duration(days: 20)),
        daysRemaining: 20,
        showRenewalWarning: true,
        supportPhone: '+91 98250 12345',
        supportEmail: 'billing@deluzex.com',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SubscriptionReminderDialog.show(context, status: status),
                child: const Text('Show Reminder'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Reminder'));
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('સબ્સ્ક્રિપ્શન રિન્યૂઅલ સૂચના'), findsOneWidget);

      // Verify Days left pill and exact Gujarati message components
      expect(find.text('20 Days Left'), findsOneWidget);
      expect(find.text('વોટ્સએપ પર રિન્યૂ કરાવો'), findsOneWidget);
      expect(find.textContaining('કૉલ કરો'), findsOneWidget);

      final dismissFinder = find.text('સમજી ગયા (Dismiss for today)');
      expect(dismissFinder, findsOneWidget);

      // Dismiss dialog and assert tracker marked
      await tester.ensureVisible(dismissFinder);
      await tester.tap(dismissFinder);
      await tester.pumpAndSettle();
      expect(SubscriptionReminderTracker.shouldShowToday(), false);
    });

    testWidgets('SubscriptionBadgePill renders green when healthy', (tester) async {
      final healthyStatus = SubscriptionStatus(
        clientName: 'Raj Lighting',
        planName: 'Standard Annual',
        isActive: true,
        isExpired: false,
        validFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 120)),
        daysRemaining: 120,
        showRenewalWarning: false,
        supportPhone: '+91 98250 12345',
        supportEmail: 'billing@deluzex.com',
      );

      final container = ProviderContainer();
      container.read(subscriptionProvider.notifier).updateStatus(healthyStatus);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: SubscriptionBadgePill()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('120d Left'), findsOneWidget);
    });

    testWidgets('SubscriptionBadgePill renders warning amber and opens details sheet', (tester) async {
      final warningStatus = SubscriptionStatus(
        clientName: 'Raj Lighting',
        planName: 'Standard Annual',
        isActive: true,
        isExpired: false,
        validFrom: DateTime.now().subtract(const Duration(days: 350)),
        validUntil: DateTime.now().add(const Duration(days: 15)),
        daysRemaining: 15,
        showRenewalWarning: true,
        supportPhone: '+91 98250 12345',
        supportEmail: 'billing@deluzex.com',
      );

      final container = ProviderContainer();
      container.read(subscriptionProvider.notifier).updateStatus(warningStatus);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: SubscriptionBadgePill()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('15 Days Left'), findsOneWidget);

      // Tap pill to open SubscriptionDetailsSheet
      await tester.tap(find.text('15 Days Left'));
      await tester.pumpAndSettle();

      expect(find.text('Subscription Details'), findsOneWidget);
      expect(find.text('Raj Lighting'), findsOneWidget);
      expect(find.text('Standard Annual'), findsOneWidget);
      expect(find.text('Call Support'), findsOneWidget);
    });
  });
}
