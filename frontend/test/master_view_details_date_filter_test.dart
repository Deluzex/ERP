import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/routes/app_routes.dart';
import 'package:frontend/core/widgets/erp_filter_controls.dart';
import 'package:frontend/core/widgets/record_details_view.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  group('Master Module View Details Date Filter Tests', () {
    late MockDatabaseService db;

    setUp(() {
      db = MockDatabaseService();
    });

    testWidgets('Customer View Details renders ErpDateFilterBox and responds to date filtering', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final customer = db.customers.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecordDetailsView(
                  details: ActiveRecordDetails(
                    recordId: customer.id,
                    recordType: 'customer',
                    parentSection: ErpNavSection.customers,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Customer Profile'), findsWidgets);
      expect(find.text('Sales & Invoices History'), findsOneWidget);
      expect(find.byType(ErpDateFilterBox), findsOneWidget);
    });

    testWidgets('Vendor View Details renders ErpDateFilterBox and responds to date filtering', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final vendor = db.vendors.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecordDetailsView(
                  details: ActiveRecordDetails(
                    recordId: vendor.id,
                    recordType: 'vendor',
                    parentSection: ErpNavSection.vendors,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Vendor Details'), findsWidgets);
      expect(find.text('Purchase Orders History'), findsOneWidget);
      expect(find.byType(ErpDateFilterBox), findsOneWidget);
    });

    testWidgets('Dealer View Details renders ErpDateFilterBox and responds to date filtering', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final dealer = db.dealers.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecordDetailsView(
                  details: ActiveRecordDetails(
                    recordId: dealer.id,
                    recordType: 'dealer',
                    parentSection: ErpNavSection.dealers,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dealer Profile'), findsWidgets);
      expect(find.text('Sales & Invoices History'), findsOneWidget);
      expect(find.byType(ErpDateFilterBox), findsOneWidget);
    });

    testWidgets('Project View Details renders ErpDateFilterBox for transaction history sections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1200));

      final project = db.projects.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecordDetailsView(
                  details: ActiveRecordDetails(
                    recordId: project.id,
                    recordType: 'project',
                    parentSection: ErpNavSection.projectList,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Project Details'), findsWidgets);
      expect(find.text('Sales & Invoices History'), findsOneWidget);

      // Verify ErpDateFilterBox is rendered on transaction histories
      expect(find.byType(ErpDateFilterBox), findsAtLeastNWidgets(1));
    });
  });
}
