import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/app.dart';
import 'package:frontend/app/routes/app_routes.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';

void main() {
  final viewports = [
    const Size(320, 568),   // Small Mobile
    const Size(375, 667),   // Mobile
    const Size(425, 800),   // Large Mobile
    const Size(768, 1024),  // Tablet
    const Size(1024, 768),  // Small Laptop
    const Size(1280, 800),  // Laptop
    const Size(1440, 900),  // Desktop
    const Size(1920, 1080), // Large Desktop
  ];

  final allNavSections = [
    ErpNavSection.dashboard,
    // 1. Inventory Module
    ErpNavSection.inventoryDashboard,
    ErpNavSection.rawMaterialStock,
    ErpNavSection.finishedProductStock,
    ErpNavSection.stockMovement,
    ErpNavSection.stockAdjustments,
    // 2. Purchase Module
    ErpNavSection.purchaseDashboard,
    ErpNavSection.purchaseList,
    ErpNavSection.createPurchase,
    ErpNavSection.purchaseHistory,
    ErpNavSection.vendorPayments,
    // 3. Production Module
    ErpNavSection.productionDashboard,
    ErpNavSection.productionOrders,
    ErpNavSection.createProduction,
    ErpNavSection.productionHistory,
    ErpNavSection.productionCosting,
    // 4. Sales Module
    ErpNavSection.salesDashboard,
    ErpNavSection.quotations,
    ErpNavSection.createQuotation,
    ErpNavSection.proformaInvoices,
    ErpNavSection.salesOrders,
    ErpNavSection.createSalesOrder,
    ErpNavSection.salesDeliveries,
    ErpNavSection.salesInvoiceList,
    ErpNavSection.createSale,
    ErpNavSection.salesReturns,
    ErpNavSection.createSalesReturn,
    // Projects
    ErpNavSection.projectList,
    ErpNavSection.createProject,
    // 5. Payments & Expenses
    ErpNavSection.paymentsDashboard,
    ErpNavSection.customerPayments,
    ErpNavSection.dealerPayments,
    ErpNavSection.vendorPaymentsSection,
    ErpNavSection.commissionPayments,
    ErpNavSection.expenseList,
    // 6. Masters
    ErpNavSection.mastersDashboard,
    ErpNavSection.categoriesUnits,
    ErpNavSection.vendors,
    ErpNavSection.customers,
    ErpNavSection.dealers,
    ErpNavSection.architects,
    ErpNavSection.rawMaterials,
    ErpNavSection.finishedProducts,
    // 7. Reports
    ErpNavSection.reportsDashboard,
    ErpNavSection.inventoryReports,
    ErpNavSection.purchaseReports,
    ErpNavSection.productionReports,
    ErpNavSection.salesReports,
    ErpNavSection.projectReports,
    ErpNavSection.commissionReports,
    ErpNavSection.financialReports,
    // Settings
    ErpNavSection.settings,
  ];

  group('Automated 100% Responsive Viewport & No-Overflow Verification Test Suite', () {
    for (final size in viewports) {
      testWidgets('Verify Login & Navigation across all ${allNavSections.length} sections at ${size.width.toInt()}px viewport width', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Pump Login Screen
        await tester.pumpWidget(
          const ProviderScope(
            child: ErpApplication(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Login Screen threw overflow error at ${size.width.toInt()}px');
        expect(find.text('Sign In to Workspace'), findsOneWidget);

        // 2. Sign In to ERP
        await tester.tap(find.text('Sign In to Workspace'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Dashboard threw overflow error at ${size.width.toInt()}px');

        // 3. Test Navigation across each section
        final element = tester.element(find.byType(ErpApplication));
        final container = ProviderScope.containerOf(element);

        for (final section in allNavSections) {
          container.read(currentNavSectionProvider.notifier).state = section;
          await tester.pumpAndSettle();

          final exception = tester.takeException();
          expect(
            exception,
            isNull,
            reason: 'Screen section $section threw RenderFlex overflow or layout error at ${size.width.toInt()}px viewport',
          );
        }
      });
    }
  });
}
