import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/shared/widgets/whatsapp_quick_chat_dialog.dart';

void main() {
  group('Customer Payment WhatsApp Reminder Logic & UI Tests', () {
    testWidgets('Opens WhatsApp dialog with 1-month overdue payment reminder prefilled in clean English', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    WhatsAppQuickChatDialog.showCustomerQuickChat(
                      context,
                      customerName: 'Fatema Saiyad',
                      customerPhone: '+91 98250 12345',
                      pendingAmount: 9440.0,
                      saleTotal: 36145642.0,
                      paidAmount: 14533.0,
                      pendingDays: 32,
                      oldestInvoiceDate: DateTime.now().subtract(const Duration(days: 32)),
                    );
                  },
                  child: const Text('Open WhatsApp Reminder'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open dialog
      await tester.tap(find.text('Open WhatsApp Reminder'));
      await tester.pumpAndSettle();

      // Verify Dialog Header
      expect(find.text('Quick WhatsApp Communication'), findsOneWidget);
      expect(find.text('Fatema Saiyad (Customer)'), findsOneWidget);

      // Verify Overdue Warning Banner (English only)
      expect(find.textContaining('Pending Payment Reminder:'), findsOneWidget);
      expect(find.textContaining('1 month (32 days)'), findsWidgets);
      expect(find.textContaining('૧ મહિનો'), findsNothing);

      // Verify Template Selector
      expect(find.text('🔔 Payment Reminder'), findsOneWidget);

      // Verify Message Content prefilled with clean English reminder
      final textFormField = tester.widget<TextFormField>(
        find.byWidgetPredicate((w) => w is TextFormField && w.controller?.text.contains('Fatema Saiyad') == true),
      );
      final text = textFormField.controller!.text;

      expect(text.contains('Dear Fatema Saiyad'), isTrue);
      expect(text.contains('Greetings from Deluzex Lighting Systems'), isTrue);
      expect(text.contains('9,440'), isTrue);
      expect(text.contains('1 month (32 days)'), isTrue);
      expect(text.contains('Total Billed:'), isTrue);
      expect(text.contains('Outstanding Balance:'), isTrue);
      expect(text.contains('Deluzex Accounts & Billing Team'), isTrue);

      // Verify no Gujarati text in the message
      expect(text.contains('નમસ્તે'), isFalse);
      expect(text.contains('બાકી'), isFalse);

      // Verify Send Button is available
      expect(find.text('Send on WhatsApp'), findsOneWidget);
    });

    testWidgets('Formats reminder for recent payment (< 30 days) correctly in English', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    WhatsAppQuickChatDialog.showCustomerQuickChat(
                      context,
                      customerName: 'Ghanshyam Prabhu',
                      customerPhone: '+91 98980 12345',
                      pendingAmount: 47188.0,
                      saleTotal: 47200.0,
                      paidAmount: 12.0,
                      pendingDays: 14,
                      oldestInvoiceDate: DateTime.now().subtract(const Duration(days: 14)),
                    );
                  },
                  child: const Text('Open 14 Days Reminder'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open 14 Days Reminder'));
      await tester.pumpAndSettle();

      final textFormField = tester.widget<TextFormField>(
        find.byWidgetPredicate((w) => w is TextFormField && w.controller?.text.contains('Ghanshyam Prabhu') == true),
      );
      final text = textFormField.controller!.text;

      expect(text.contains('14 days'), isTrue);
      expect(text.contains('47,188'), isTrue);
      expect(text.contains('દિવસ'), isFalse);
    });

    testWidgets('Default custom message when no pending balance exists', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    WhatsAppQuickChatDialog.showCustomerQuickChat(
                      context,
                      customerName: 'Mohammad BHAI',
                      customerPhone: '+91 98251 98251',
                      pendingAmount: 0.0,
                    );
                  },
                  child: const Text('Open Zero Balance Chat'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Zero Balance Chat'));
      await tester.pumpAndSettle();

      // No pending payment alert banner should be rendered
      expect(find.textContaining('Pending Payment Reminder:'), findsNothing);

      // Custom message should be default
      final textFormField = tester.widget<TextFormField>(
        find.byWidgetPredicate((w) => w is TextFormField && w.controller?.text.contains('Mohammad BHAI') == true),
      );
      final text = textFormField.controller!.text;
      expect(text.contains('Greetings from Deluzex Lighting Systems'), isTrue);
    });
  });
}
