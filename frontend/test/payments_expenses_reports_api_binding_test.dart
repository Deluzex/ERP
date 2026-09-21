import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/payments_api_service.dart';
import 'package:frontend/core/api/expenses_api_service.dart';
import 'package:frontend/core/api/reports_api_service.dart';
import 'package:frontend/core/models/commission_model.dart';
import 'package:frontend/core/models/expense_model.dart';
import 'package:frontend/core/models/payment_model.dart';
import 'package:frontend/core/models/purchase_model.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  group('Phase 7: Payments, Commissions & Expenses Model & API Binding Test Suite', () {
    test('ErpPayment.fromJson parses backend payment JSON payload correctly', () {
      final json = {
        'id': 'pay-uuid-001',
        'paymentNumber': 'PAY-2026-0001',
        'paymentType': 'customerPayment',
        'partyId': 'cust-uuid-001',
        'partyName': 'Apex Luxury Residences',
        'referenceDocumentId': 'inv-uuid-001',
        'referenceDocumentNumber': 'INV-2026-0001',
        'amount': 25000.50,
        'paymentMode': 'bankTransfer',
        'paymentDate': '2026-09-21T10:00:00.000Z',
        'transactionReference': 'UTR998877665544',
        'notes': 'Advance payment for lighting installation',
        'paymentStatus': 'completed',
        'isFullPayment': false,
        'totalDocumentAmount': 50000.00,
        'remainingAmount': 24999.50,
        'projectId': 'proj-uuid-001',
        'projectName': 'Skyline Penthouse',
        'createdAt': '2026-09-21T10:05:00.000Z',
      };

      final payment = ErpPayment.fromJson(json);

      expect(payment.id, 'pay-uuid-001');
      expect(payment.paymentNumber, 'PAY-2026-0001');
      expect(payment.paymentType, PaymentType.customerPayment);
      expect(payment.typeLabel, 'Customer Receipt');
      expect(payment.partyName, 'Apex Luxury Residences');
      expect(payment.amount, 25000.50);
      expect(payment.paymentMode, PaymentMode.bankTransfer);
      expect(payment.transactionReference, 'UTR998877665544');
      expect(payment.isFullPayment, false);
      expect(payment.remainingAmount, 24999.50);
      expect(payment.projectName, 'Skyline Penthouse');
    });

    test('ErpPayment.toJson serializes correctly for POST /api/v1/payments', () {
      final payment = ErpPayment(
        id: 'pay-uuid-002',
        paymentNumber: 'PAY-2026-0002',
        paymentType: PaymentType.vendorPayment,
        partyId: 'vend-uuid-001',
        partyName: 'Philips Lumileds Supplies',
        referenceDocumentId: 'pur-uuid-001',
        referenceDocumentNumber: 'PUR-2026-0001',
        amount: 14160.00,
        paymentMode: PaymentMode.upi,
        paymentDate: DateTime(2026, 9, 21),
        transactionReference: 'UPI-987654321',
        notes: 'Cleared invoice via UPI',
        isFullPayment: true,
        totalDocumentAmount: 14160.00,
        remainingAmount: 0.0,
        createdAt: DateTime(2026, 9, 21),
      );

      final json = payment.toJson();

      expect(json['paymentType'], 'vendorPayment');
      expect(json['amount'], 14160.00);
      expect(json['paymentMode'], 'upi');
      expect(json['isFullPayment'], true);
      expect(json['transactionReference'], 'UPI-987654321');
    });

    test('ArchitectCommission.fromJson and toJson work bidirectionally', () {
      final json = {
        'id': 'comm-uuid-001',
        'commissionNumber': 'COM-2026-0001',
        'architectId': 'arch-uuid-001',
        'architectName': 'Studio Aranya',
        'saleInvoiceId': 'inv-uuid-001',
        'saleInvoiceNumber': 'INV-2026-0001',
        'projectId': 'proj-uuid-001',
        'projectName': 'Skyline Penthouse',
        'saleAmount': 200000.00,
        'commissionRate': 5.0,
        'commissionAmount': 10000.00,
        'status': 'approved',
        'generatedDate': '2026-09-20T00:00:00.000Z',
        'approvedDate': '2026-09-21T00:00:00.000Z',
      };

      final commission = ArchitectCommission.fromJson(json);

      expect(commission.id, 'comm-uuid-001');
      expect(commission.architectName, 'Studio Aranya');
      expect(commission.commissionAmount, 10000.00);
      expect(commission.status, CommissionStatus.approved);
      expect(commission.statusLabel, 'Approved');

      final serialized = commission.toJson();
      expect(serialized['commissionNumber'], 'COM-2026-0001');
      expect(serialized['status'], 'approved');
      expect(serialized['commissionAmount'], 10000.00);
    });

    test('Expense.fromJson and toJson handle categories and optional project links', () {
      final json = {
        'id': 'exp-uuid-001',
        'expenseNumber': 'EXP-2026-0001',
        'expenseDate': '2026-09-21T00:00:00.000Z',
        'expenseName': 'Crane Hoisting at Penthouse Site',
        'category': 'transportation',
        'amount': 8500.00,
        'paidBy': 'Site Supervisor',
        'paymentMethod': 'Bank Transfer',
        'vendorPayee': 'Gujarat Crane Rentals',
        'projectId': 'proj-uuid-001',
        'projectName': 'Skyline Penthouse',
        'expenseReference': 'CRANE-INV-44',
        'description': 'Heavy fixture hoisting up to 14th floor',
        'paymentStatus': 'paid',
        'createdBy': 'Supervisor',
        'createdAt': '2026-09-21T08:00:00.000Z',
      };

      final expense = Expense.fromJson(json);

      expect(expense.expenseName, 'Crane Hoisting at Penthouse Site');
      expect(expense.category, ExpenseCategory.transportation);
      expect(expense.categoryLabel, 'Transportation');
      expect(expense.amount, 8500.00);
      expect(expense.paymentStatus, ExpensePaymentStatus.paid);
      expect(expense.projectName, 'Skyline Penthouse');

      final serialized = expense.toJson();
      expect(serialized['category'], 'transportation');
      expect(serialized['paymentStatus'], 'paid');
      expect(serialized['amount'], 8500.00);
    });

    test('PaymentsApiService, ExpensesApiService, ReportsApiService instantiate correctly', () {
      final payApi = PaymentsApiService();
      final expApi = ExpensesApiService();
      final repApi = ReportsApiService();

      expect(payApi, isNotNull);
      expect(expApi, isNotNull);
      expect(repApi, isNotNull);
    });

    test('MockDatabaseService integrates Phase 7 & 8 async methods with fallback', () async {
      final db = MockDatabaseService();

      // Test load calls
      await db.loadPayments(forceRefresh: true);
      await db.loadCommissions(forceRefresh: true);
      await db.loadExpenses(forceRefresh: true);

      // Verify that local fallback collections remain valid and accessible
      expect(db.payments, isA<List<ErpPayment>>());
      expect(db.commissions, isA<List<ArchitectCommission>>());
      expect(db.expenses, isA<List<Expense>>());

      // Test addPaymentAsync
      final testPayment = ErpPayment(
        id: 'test-pay-local-01',
        paymentNumber: 'PAY-TEST-001',
        paymentType: PaymentType.customerPayment,
        partyId: db.customers.isNotEmpty ? db.customers.first.id : 'cust-1',
        partyName: db.customers.isNotEmpty ? db.customers.first.name : 'Customer 1',
        amount: 5000.0,
        paymentMode: PaymentMode.cash,
        paymentDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final addedPayment = await db.addPaymentAsync(testPayment);
      expect(addedPayment.id, testPayment.id);
      expect(db.payments.any((p) => p.id == testPayment.id), isTrue);

      // Test createExpenseAsync
      final testExpense = Expense(
        id: 'test-exp-local-01',
        expenseNumber: 'EXP-TEST-001',
        expenseDate: DateTime.now(),
        expenseName: 'Test Office Courier',
        category: ExpenseCategory.courier,
        amount: 350.0,
        paidBy: 'Admin',
        paymentMethod: 'Cash',
        createdBy: 'Admin',
        createdAt: DateTime.now(),
      );

      final addedExpense = await db.createExpenseAsync(testExpense);
      expect(addedExpense.id, testExpense.id);
      expect(db.expenses.any((e) => e.id == testExpense.id), isTrue);
    });
  });
}
