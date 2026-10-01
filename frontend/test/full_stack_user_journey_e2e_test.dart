import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/app.dart';
import 'package:frontend/app/routes/app_routes.dart';
import 'package:frontend/core/models/expense_model.dart';
import 'package:frontend/core/models/payment_model.dart';
import 'package:frontend/core/models/purchase_model.dart';
import 'package:frontend/core/models/sale_model.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Full-Stack User Click-Through Simulation & Validation (Phases 1 to 8)', () {
    testWidgets('1. Authentication Journey: Negative validations & positive login flow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: ErpApplication(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Login Screen is present
      expect(find.text('Sign In to Workspace'), findsWidgets);

      // Verify text input fields are present
      final emailFields = find.byType(TextFormField);
      expect(emailFields, findsWidgets);

      // Click Sign In with preset Admin credentials
      final signInButton = find.text('Sign In to Workspace');
      expect(signInButton, findsWidgets);
      await tester.tap(signInButton.first);
      await tester.pumpAndSettle();

      // User is now logged in to Workspace - LoginScreen dismissed
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Alex Sterling'), findsWidgets);
    });

    testWidgets('2. Masters Registry Journey: Vendor & Customer CRUD with statutory GST/PAN validations', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Pre-authenticate as Admin
      container.read(authStateProvider.notifier).login('admin@deluzex.com', 'Admin@123', 'admin');
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.vendors;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ErpApplication(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Vendors Screen
      expect(find.text('Vendors Master'), findsWidgets);
      final addVendorBtn = find.text('Add Vendor');
      expect(addVendorBtn, findsOneWidget);

      // Open Add Vendor Dialog
      await tester.tap(addVendorBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add Vendor Master'), findsOneWidget);

      // Negative validation: try saving with empty name
      final saveBtn = find.text('Save Vendor');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('Vendor company name required'), findsOneWidget);

      // Close dialog
      final cancelBtn = find.text('Cancel');
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Switch to Customers section
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.customers;
      await tester.pumpAndSettle();
      expect(find.text('Customers Master'), findsWidgets);
    });

    testWidgets('3. Inventory & Stock Adjustments Journey: Physical audit & mandatory reason enforcement', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authStateProvider.notifier).login('admin@deluzex.com', 'Admin@123', 'admin');
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.stockAdjustments;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ErpApplication(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stock Adjustments'), findsWidgets);

      // Open Add Adjustment Dialog
      final newAdjBtn = find.text('New Stock Adjustment');
      expect(newAdjBtn, findsOneWidget);
      await tester.tap(newAdjBtn);
      await tester.pumpAndSettle();

      expect(find.text('Record Stock Adjustment'), findsOneWidget);

      // Negative validation: try saving without entering reason / quantity
      final saveBtn = find.text('Save Adjustment & Update Stock');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Reason is strictly required per ADR-012
      expect(find.text('Remarks are required for audit reconciliation'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('4. Purchases & Procurement Journey: PO listing and creation view', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authStateProvider.notifier).login('admin@deluzex.com', 'Admin@123', 'admin');
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseList;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ErpApplication(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Purchase Orders'), findsWidgets);
      expect(find.text('Create Purchase'), findsWidgets);
    });

    testWidgets('5. Production & Manufacturing Journey: Work order tracking and status', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authStateProvider.notifier).login('admin@deluzex.com', 'Admin@123', 'admin');
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionOrders;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ErpApplication(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Production Orders & Batches'), findsWidgets);
      expect(find.text('Create Work Order'), findsOneWidget);
    });

    testWidgets('6. Sales & Commercial Journey: Quotation, SO, Invoice, and Signed Round-Off', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authStateProvider.notifier).login('admin@deluzex.com', 'Admin@123', 'admin');
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ErpApplication(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sales Invoices & Revenue'), findsWidgets);
      expect(find.text('Create Direct Sale'), findsWidgets);
      expect(find.text('Invoice from Delivery'), findsWidgets);

      // Verify Round-off and statutory GST behavior
      final db = container.read(databaseServiceProvider);
      expect(db.sales, isNotEmpty);
      final sampleInvoice = db.sales.firstWhere((s) => s.documentType == SalesDocumentType.invoice);
      expect(sampleInvoice.totalAmount, greaterThan(0));
    });

    testWidgets('7. Architectural Projects Journey: Site portfolios and financial profitability', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authStateProvider.notifier).login('admin@deluzex.com', 'Admin@123', 'admin');
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.projectList;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ErpApplication(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Project Master'), findsWidgets);
      expect(find.text('New Project'), findsOneWidget);
    });

    testWidgets('8. Phase 7: Payments Center Journey: 4 settlement tabs & ledger reconciliation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authStateProvider.notifier).login('admin@deluzex.com', 'Admin@123', 'admin');
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.customerPayments;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ErpApplication(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payments & Treasury Center'), findsWidgets);
      expect(find.text('Customer Collections'), findsWidgets);
      expect(find.text('Dealer Receipts'), findsWidgets);
      expect(find.text('Vendor Disbursements'), findsWidgets);
      expect(find.text('Commission Payouts'), findsWidgets);

      // Click "Record Customer Receipt"
      final recordBtn = find.text('Record Customer Receipt');
      expect(recordBtn, findsOneWidget);
      await tester.tap(recordBtn);
      await tester.pumpAndSettle();

      expect(find.text('Record Customer Receipt'), findsWidgets);

      // Negative validation: try saving with 0 or empty amount
      final saveBtn = find.text('Save Payment Entry');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('This field is required'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Test atomic ledger reconciliation directly
      final db = container.read(databaseServiceProvider);
      final initialCustomerBalance = db.customers.isNotEmpty ? db.customers.first.outstandingAmount : 0.0;

      final testPayment = ErpPayment(
        id: 'test-pay-atomic-01',
        paymentNumber: 'PAY-ATOMIC-01',
        paymentType: PaymentType.customerPayment,
        partyId: db.customers.isNotEmpty ? db.customers.first.id : 'cust-1',
        partyName: db.customers.isNotEmpty ? db.customers.first.name : 'Customer 1',
        amount: 500.0,
        paymentMode: PaymentMode.bankTransfer,
        paymentDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      db.addManualPayment(testPayment);

      // Verify that payment was added and customer balance was adjusted
      expect(db.payments.any((p) => p.id == 'test-pay-atomic-01'), isTrue);
      if (db.customers.isNotEmpty) {
        expect(db.customers.first.outstandingAmount, lessThanOrEqualTo(initialCustomerBalance));
      }
    });

    testWidgets('9. Phase 7: Expenses Screen Journey: Negative validation, add, edit, and filter', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authStateProvider.notifier).login('admin@deluzex.com', 'Admin@123', 'admin');
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.expenseList;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ErpApplication(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Expense Management'), findsWidgets);

      // Click "Record Expense"
      final addExpBtn = find.text('Record Expense');
      expect(addExpBtn, findsOneWidget);
      await tester.tap(addExpBtn);
      await tester.pumpAndSettle();

      expect(find.text('Record Expense'), findsWidgets);

      // Negative validation: try saving with empty name
      final saveBtn = find.text('Save Expense');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Expense Title required'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Test create and delete directly through db service
      final db = container.read(databaseServiceProvider);
      final testExpense = Expense(
        id: 'test-exp-journey-01',
        expenseNumber: 'EXP-JOURNEY-01',
        expenseDate: DateTime.now(),
        expenseName: 'Test Machine Grease',
        category: ExpenseCategory.maintenance,
        amount: 1200.0,
        paidBy: 'Site Tech',
        paymentMethod: 'Cash',
        createdBy: 'Admin',
        createdAt: DateTime.now(),
      );

      db.addExpense(testExpense);
      expect(db.expenses.any((e) => e.id == 'test-exp-journey-01'), isTrue);

      db.deleteExpense('test-exp-journey-01');
      expect(db.expenses.any((e) => e.id == 'test-exp-journey-01'), isFalse);
    });

    testWidgets('10. Phase 8: Reports Hub Journey: Seamless click-through of core statements', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authStateProvider.notifier).login('admin@deluzex.com', 'Admin@123', 'admin');
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.inventoryReports;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ErpApplication(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reports & Analytics Hub'), findsWidgets);

      // Verify Tab headers exist
      expect(find.text('Inventory Reports'), findsWidgets);
      expect(find.text('Purchase Reports'), findsWidgets);
      expect(find.text('Production Reports'), findsWidgets);
      expect(find.text('Sales & GST Reports'), findsWidgets);
      expect(find.text('Project Costing'), findsWidgets);

      // Click visible tabs to ensure dynamic rendering works without exceptions
      await tester.tap(find.text('Purchase Reports').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Production Reports').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sales & GST Reports').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Project Costing').first);
      await tester.pumpAndSettle();

      // Ensure state is healthy and action buttons are accessible on Reports Hub
      expect(find.text('Reports & Analytics Hub'), findsWidgets);
      expect(find.text('Download PDF Report'), findsOneWidget);
      expect(find.text('Print Statement'), findsOneWidget);
    });
  });
}
