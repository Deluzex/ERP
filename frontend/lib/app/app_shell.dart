import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/payment_model.dart';
import '../core/models/rbac_models.dart';
import '../core/widgets/erp_button.dart';
import '../core/widgets/erp_header.dart';
import '../core/widgets/erp_sidebar.dart';
import '../core/widgets/record_details_view.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/dashboard/screens/role_dashboards.dart';
import '../features/inventory/screens/finished_product_stock_screen.dart';
import '../features/inventory/screens/raw_material_stock_screen.dart';
import '../features/inventory/screens/stock_adjustment_screen.dart';
import '../features/inventory/screens/stock_movement_screen.dart';
import '../features/masters/screens/architects_screen.dart';
import '../features/masters/screens/categories_units_screen.dart';
import '../features/masters/screens/customers_screen.dart';
import '../features/masters/screens/dealers_screen.dart';
import '../features/masters/screens/product_master_screen.dart';
import '../features/masters/screens/raw_material_master_screen.dart';
import '../features/masters/screens/vendors_screen.dart';
import '../features/payments/screens/payment_center_screen.dart';
import '../features/production/screens/create_production_screen.dart';
import '../features/production/screens/production_orders_screen.dart';
import '../features/projects/screens/project_list_screen.dart';
import '../features/purchase/screens/create_purchase_screen.dart';
import '../features/purchase/screens/purchase_list_screen.dart';
import '../features/reports/screens/reports_hub_screen.dart';
import '../features/sales/screens/create_quotation_screen.dart';
import '../features/sales/screens/create_sale_screen.dart';
import '../features/sales/screens/create_sales_order_screen.dart';
import '../features/sales/screens/deliveries_screen.dart';
import '../features/sales/screens/proforma_invoices_screen.dart';
import '../features/sales/screens/quotations_screen.dart';
import '../features/sales/screens/sales_dashboard_screen.dart';
import '../features/sales/screens/sales_invoice_list_screen.dart';
import '../features/sales/screens/sales_orders_screen.dart';
import '../features/sales/screens/sales_returns_screen.dart';
import '../features/expenses/screens/expenses_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../shared/providers/app_state_providers.dart';
import '../shared/widgets/access_required_dialog.dart';
import '../shared/widgets/global_whatsapp_floating_button.dart';
import 'routes/app_routes.dart';
import 'theme/app_colors.dart';
import 'theme/app_radius.dart';
import 'theme/app_text_styles.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final currentSection = ref.watch(currentNavSectionProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final detailsStack = ref.watch(activeRecordDetailsStackProvider);
    final db = ref.watch(databaseServiceProvider);
    final currentUser = ref.watch(currentUserProvider) ?? db.currentUser;
    final isAuthorized = currentUser.canAccessSection(currentSection, db.roles);

    Widget contentWidget;

    // Check if there is an active detail view in the drilldown stack
    if (detailsStack.isNotEmpty) {
      contentWidget = RecordDetailsView(details: detailsStack.last);
    } else if (!isAuthorized) {
      // 403 Forbidden Access Guard Barrier
      contentWidget = _buildAccessDeniedBarrier(context, currentUser, currentSection, db);
    } else {
      switch (currentSection) {
        case ErpNavSection.dashboard:
          // Role-specific Landing Dashboard Selection
          if (currentUser.primaryRoleId == 'admin') {
            contentWidget = const DashboardScreen();
          } else if (currentUser.primaryRoleId == 'inventory_manager') {
            contentWidget = const InventoryRoleDashboard();
          } else if (currentUser.primaryRoleId == 'purchase_manager') {
            contentWidget = const PurchaseRoleDashboard();
          } else if (currentUser.primaryRoleId == 'production_manager') {
            contentWidget = const ProductionRoleDashboard();
          } else if (currentUser.primaryRoleId == 'sales_manager') {
            contentWidget = const SalesDashboardScreen();
          } else if (currentUser.primaryRoleId == 'accounts_manager') {
            contentWidget = const AccountsPaymentRoleDashboard();
          } else if (currentUser.primaryRoleId == 'masters_manager') {
            contentWidget = const MastersRoleDashboard();
          } else if (currentUser.primaryRoleId == 'project_manager') {
            contentWidget = const ProjectManagerRoleDashboard();
          } else if (currentUser.primaryRoleId == 'report_viewer') {
            contentWidget = const ReportViewerRoleDashboard();
          } else if (currentUser.primaryRoleId == 'data_entry') {
            contentWidget = const DataEntryRoleDashboard();
          } else {
            contentWidget = const DashboardScreen();
          }
          break;
        case ErpNavSection.inventoryDashboard:
          contentWidget = const InventoryRoleDashboard();
          break;
        case ErpNavSection.rawMaterialStock:
          contentWidget = const RawMaterialStockScreen();
          break;
        case ErpNavSection.rawMaterials:
          contentWidget = const RawMaterialMasterScreen();
          break;
        case ErpNavSection.finishedProductStock:
          contentWidget = const FinishedProductStockScreen();
          break;
        case ErpNavSection.finishedProducts:
          contentWidget = const ProductMasterScreen();
          break;
        case ErpNavSection.stockMovement:
          contentWidget = const StockMovementScreen();
          break;
        case ErpNavSection.stockAdjustments:
          contentWidget = const StockAdjustmentScreen();
          break;
        case ErpNavSection.purchaseDashboard:
          contentWidget = const PurchaseRoleDashboard();
          break;
        case ErpNavSection.purchaseList:
        case ErpNavSection.purchaseHistory:
          contentWidget = const PurchaseListScreen();
          break;
        case ErpNavSection.createPurchase:
          contentWidget = const CreatePurchaseScreen();
          break;
        case ErpNavSection.vendorPayments:
        case ErpNavSection.vendorPaymentsSection:
          contentWidget = const PaymentCenterScreen(initialTab: PaymentType.vendorPayment);
          break;
        case ErpNavSection.productionDashboard:
          contentWidget = const ProductionRoleDashboard();
          break;
        case ErpNavSection.productionOrders:
        case ErpNavSection.productionHistory:
        case ErpNavSection.productionCosting:
          contentWidget = const ProductionOrdersScreen();
          break;
        case ErpNavSection.createProduction:
          contentWidget = const CreateProductionScreen();
          break;
        // Sales Workflow Suite
        case ErpNavSection.salesDashboard:
          contentWidget = const SalesDashboardScreen();
          break;
        case ErpNavSection.quotations:
          contentWidget = const QuotationsScreen();
          break;
        case ErpNavSection.createQuotation:
          contentWidget = const CreateQuotationScreen();
          break;
        case ErpNavSection.proformaInvoices:
          contentWidget = const ProformaInvoicesScreen();
          break;
        case ErpNavSection.salesOrders:
          contentWidget = const SalesOrdersScreen();
          break;
        case ErpNavSection.createSalesOrder:
          contentWidget = const CreateSalesOrderScreen();
          break;
        case ErpNavSection.salesDeliveries:
          contentWidget = const DeliveriesScreen();
          break;
        case ErpNavSection.salesInvoiceList:
          contentWidget = const SalesInvoiceListScreen();
          break;
        case ErpNavSection.createSale:
          contentWidget = const CreateSaleScreen();
          break;
        case ErpNavSection.salesReturns:
        case ErpNavSection.createSalesReturn:
          contentWidget = const SalesReturnsScreen();
          break;
        // Projects
        case ErpNavSection.projectList:
        case ErpNavSection.createProject:
          contentWidget = const ProjectListScreen();
          break;
        // Payments & Expenses
        case ErpNavSection.paymentsDashboard:
          contentWidget = const AccountsPaymentRoleDashboard();
          break;
        case ErpNavSection.customerPayments:
          contentWidget = const PaymentCenterScreen(initialTab: PaymentType.customerPayment);
          break;
        case ErpNavSection.dealerPayments:
          contentWidget = const PaymentCenterScreen(initialTab: PaymentType.dealerPayment);
          break;
        case ErpNavSection.commissionPayments:
          contentWidget = const PaymentCenterScreen(initialTab: PaymentType.commissionPayment);
          break;
        case ErpNavSection.expenseList:
          contentWidget = const ExpensesScreen();
          break;
        // Masters
        case ErpNavSection.mastersDashboard:
          contentWidget = const MastersRoleDashboard();
          break;
        case ErpNavSection.categoriesUnits:
          contentWidget = const CategoriesUnitsScreen();
          break;
        case ErpNavSection.vendors:
          contentWidget = const VendorsScreen();
          break;
        case ErpNavSection.customers:
          contentWidget = const CustomersScreen();
          break;
        case ErpNavSection.dealers:
          contentWidget = const DealersScreen();
          break;
        case ErpNavSection.architects:
          contentWidget = const ArchitectsScreen();
          break;
        // Reports
        case ErpNavSection.reportsDashboard:
          contentWidget = const ReportViewerRoleDashboard();
          break;
        case ErpNavSection.inventoryReports:
        case ErpNavSection.purchaseReports:
        case ErpNavSection.productionReports:
        case ErpNavSection.salesReports:
        case ErpNavSection.projectReports:
        case ErpNavSection.commissionReports:
        case ErpNavSection.financialReports:
          contentWidget = ReportsHubScreen(reportType: currentSection);
          break;
        case ErpNavSection.settings:
          contentWidget = const SettingsScreen();
          break;
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: isDesktop ? null : const Drawer(child: ErpSidebar()),
      body: Stack(
        children: [
          Row(
            children: [
              // Persistent Dark Sidebar for Desktop
              if (isDesktop) const ErpSidebar(),

              // Main White/Light Content Area
              Expanded(
                child: Column(
                  children: [
                    ErpHeader(
                      onMenuToggle: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),
                    Expanded(
                      child: RepaintBoundary(
                        child: contentWidget,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Floating WhatsApp Quick Support Button in bottom-right corner
          const GlobalWhatsAppFloatingButton(),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedBarrier(BuildContext context, AppUser user, ErpNavSection requestedSection, dynamic db) {
    final role = db.getUserRole(user);
    final targetModule = AppUser.mapSectionToModule(requestedSection);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.xlBorderRadius,
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gpp_bad_rounded, size: 48, color: Colors.red),
            ),
            const SizedBox(height: 20),
            Text('403 - Access Restricted', style: AppTextStyles.h1.copyWith(color: Colors.red)),
            const SizedBox(height: 8),
            Text(
              'Your current role "${role.name}" does not have authorization to view or manage the "${targetModule.label}" module (${requestedSection.name}).',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle_outlined, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text('Operator: ${user.name} (${user.email})', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ErpButton(
                  text: 'Return to Authorized Dashboard',
                  icon: Icons.home_outlined,
                  isOutlined: true,
                  onPressed: () {
                    ref.read(currentNavSectionProvider.notifier).state = role.defaultDashboardSection;
                  },
                ),
                ErpButton(
                  text: 'Authorize Access (Supervisor)',
                  icon: Icons.vpn_key_rounded,
                  onPressed: () {
                    AccessRequiredDialog.show(
                      context,
                      module: targetModule,
                      action: ErpAction.view,
                      customTitle: 'Supervisor Authorization Required',
                      customMessage: 'Enter supervisor or admin password to temporarily unlock ${targetModule.label} (${requestedSection.name}).',
                      onAccessGranted: (grant) {
                        // Refresh UI
                        ref.read(currentNavSectionProvider.notifier).state = requestedSection;
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

