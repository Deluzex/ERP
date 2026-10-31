import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../features/masters/screens/bom_screen.dart';
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
import '../features/chat/screens/chat_support_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../shared/providers/app_state_providers.dart';
import '../shared/providers/subscription_provider.dart';
import '../shared/widgets/access_required_dialog.dart';
// import '../shared/widgets/global_whatsapp_floating_button.dart';
import '../core/utils/navigation_history.dart';
import 'app.dart';
import 'routes/app_routes.dart';
import 'theme/app_colors.dart';
import 'theme/app_radius.dart';
import 'theme/app_text_styles.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<ErpNavSection, Widget> _cachedScreens = {};
  String? _lastUserId;
  String? _lastRoleId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).fetchStatus();
      NavigationHistory.initialize(ref, navigatorKey: appNavigatorKey);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NavigationHistory.dispose();
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    // 1. If an active modal dialog or subroute is open in Navigator, pop it
    final nav = appNavigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return true;
    }

    // 2. If a drilldown detail view is active in the stack, pop back to the list
    final detailsStack = ref.read(activeRecordDetailsStackProvider);
    if (detailsStack.isNotEmpty) {
      ref.read(activeRecordDetailsStackProvider.notifier).pop();
      return true;
    }

    // 3. If navigation history can go back, return to the previous section
    if (NavigationHistory.canGoBack) {
      return NavigationHistory.goBack();
    }

    return false;
  }

  ErpNavSection _canonicalSection(ErpNavSection section) {
    switch (section) {
      case ErpNavSection.customerPayments:
      case ErpNavSection.dealerPayments:
      case ErpNavSection.vendorPayments:
      case ErpNavSection.vendorPaymentsSection:
      case ErpNavSection.commissionPayments:
        return ErpNavSection.customerPayments;
      default:
        return section;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSection = ref.watch(currentNavSectionProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final detailsStack = ref.watch(activeRecordDetailsStackProvider);
    final db = ref.watch(databaseServiceProvider);
    final currentUser = ref.watch(currentUserProvider) ?? db.currentUser;
    final isAuthorized = currentUser.canAccessSection(currentSection, db.roles);

    // Invalidate cached screens if user or their role changed (e.g. switch user / logout / re-login)
    if (_lastUserId != currentUser.id || _lastRoleId != currentUser.primaryRoleId) {
      _cachedScreens.clear();
      _lastUserId = currentUser.id;
      _lastRoleId = currentUser.primaryRoleId;
    }

    // Persist active section on navigation change so reload stays on active screen
    ref.listen<ErpNavSection>(currentNavSectionProvider, (previous, next) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('erp_last_nav_section', next.name);
      } catch (_) {}
      NavigationHistory.onSectionChanged(next);
    });

    // Sync detail view state with browser history
    ref.listen(activeRecordDetailsStackProvider, (previous, next) {
      NavigationHistory.onDetailStateChanged(next.isNotEmpty, ref.read(currentNavSectionProvider));
    });

    Widget contentWidget;

    // Check if there is an active detail view in the drilldown stack
    if (detailsStack.isNotEmpty) {
      contentWidget = RecordDetailsView(details: detailsStack.last);
    } else if (!isAuthorized) {
      // 403 Forbidden Access Guard Barrier
      contentWidget = _buildAccessDeniedBarrier(context, currentUser, currentSection, db);
    } else {
      final canonicalKey = _canonicalSection(currentSection);
      final isCreationScreen = canonicalKey == ErpNavSection.createPurchase ||
          canonicalKey == ErpNavSection.createSale ||
          canonicalKey == ErpNavSection.createSalesOrder ||
          canonicalKey == ErpNavSection.createQuotation ||
          canonicalKey == ErpNavSection.createProduction;

      if (isCreationScreen) {
        _cachedScreens.remove(canonicalKey);
      }

      // Lazy load screen into cache if not present
      if (!_cachedScreens.containsKey(canonicalKey)) {
        _cachedScreens[canonicalKey] = _buildSectionWidget(canonicalKey, currentUser);
      }

      contentWidget = Stack(
        fit: StackFit.expand,
        children: [
          for (final entry in _cachedScreens.entries)
            Offstage(
              key: ValueKey(entry.key),
              offstage: entry.key != canonicalKey,
              child: TickerMode(
                enabled: entry.key == canonicalKey,
                child: entry.value,
              ),
            ),
        ],
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: isDesktop ? null : const Drawer(child: ErpSidebar()),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => ref.read(authStateProvider.notifier).recordUserActivity(),
        child: Stack(
          children: [
          Row(
            children: [
              // Persistent Dark Sidebar for Desktop
              if (isDesktop) const ErpSidebar(),

              // Main White/Light Content Area
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxHeight <= 1.0 || constraints.maxWidth <= 1.0) {
                      return const SizedBox.shrink();
                    }
                    return ClipRect(
                      child: Column(
                        children: [
                          if (constraints.maxHeight > 64)
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
                    );
                  },
                ),
              ),
            ],
          ),

          // Floating WhatsApp Quick Support Button in bottom-right corner (commented out)
          // const GlobalWhatsAppFloatingButton(),
        ],
      ),
    ),);
  }

  Widget _buildSectionWidget(ErpNavSection section, AppUser currentUser) {
    switch (section) {
      case ErpNavSection.dashboard:
        // Role-specific Landing Dashboard Selection
        if (currentUser.primaryRoleId == 'admin') {
          return const DashboardScreen();
        } else if (currentUser.primaryRoleId == 'inventory_manager') {
          return const InventoryRoleDashboard();
        } else if (currentUser.primaryRoleId == 'purchase_manager') {
          return const PurchaseRoleDashboard();
        } else if (currentUser.primaryRoleId == 'production_manager') {
          return const ProductionRoleDashboard();
        } else if (currentUser.primaryRoleId == 'sales_manager') {
          return const SalesDashboardScreen();
        } else if (currentUser.primaryRoleId == 'accounts_manager') {
          return const AccountsPaymentRoleDashboard();
        } else if (currentUser.primaryRoleId == 'masters_manager') {
          return const MastersRoleDashboard();
        } else if (currentUser.primaryRoleId == 'project_manager') {
          return const ProjectManagerRoleDashboard();
        } else if (currentUser.primaryRoleId == 'report_viewer') {
          return const ReportViewerRoleDashboard();
        } else if (currentUser.primaryRoleId == 'data_entry') {
          return const DataEntryRoleDashboard();
        } else {
          return const DashboardScreen();
        }
      case ErpNavSection.inventoryDashboard:
        return const InventoryRoleDashboard();
      case ErpNavSection.rawMaterialStock:
        return const RawMaterialStockScreen();
      case ErpNavSection.rawMaterials:
        return const RawMaterialMasterScreen();
      case ErpNavSection.finishedProductStock:
        return const FinishedProductStockScreen();
      case ErpNavSection.finishedProducts:
        return const ProductMasterScreen();
      case ErpNavSection.stockMovement:
        return const StockMovementScreen();
      case ErpNavSection.stockAdjustments:
        return const StockAdjustmentScreen();
      case ErpNavSection.purchaseDashboard:
        return const PurchaseRoleDashboard();
      case ErpNavSection.purchaseList:
      case ErpNavSection.purchaseHistory:
        return const PurchaseListScreen();
      case ErpNavSection.createPurchase:
        final editingPurchase = ref.watch(editingPurchaseProvider);
        return CreatePurchaseScreen(
          key: ValueKey(editingPurchase?.id ?? 'create_purchase_new'),
          existingPurchase: editingPurchase,
        );
      case ErpNavSection.vendorPayments:
      case ErpNavSection.vendorPaymentsSection:
        return const PaymentCenterScreen(initialTab: PaymentType.vendorPayment);
      case ErpNavSection.productionDashboard:
        return const ProductionRoleDashboard();
      case ErpNavSection.productionOrders:
      case ErpNavSection.productionHistory:
      case ErpNavSection.productionCosting:
        return const ProductionOrdersScreen();
      case ErpNavSection.createProduction:
        return const CreateProductionScreen();
      // Sales Workflow Suite
      case ErpNavSection.salesDashboard:
        return const SalesDashboardScreen();
      case ErpNavSection.quotations:
        return const QuotationsScreen();
      case ErpNavSection.createQuotation:
        return const CreateQuotationScreen();
      case ErpNavSection.proformaInvoices:
        return const ProformaInvoicesScreen();
      case ErpNavSection.salesOrders:
        return const SalesOrdersScreen();
      case ErpNavSection.createSalesOrder:
        return const CreateSalesOrderScreen();
      case ErpNavSection.salesDeliveries:
        return const DeliveriesScreen();
      case ErpNavSection.salesInvoiceList:
        return const SalesInvoiceListScreen();
      case ErpNavSection.createSale:
        return const CreateSaleScreen();
      case ErpNavSection.salesReturns:
      case ErpNavSection.createSalesReturn:
        return const SalesReturnsScreen();
      // Projects
      case ErpNavSection.projectList:
      case ErpNavSection.createProject:
        return const ProjectListScreen();
      // Payments & Expenses
      case ErpNavSection.paymentsDashboard:
        return const AccountsPaymentRoleDashboard();
      case ErpNavSection.customerPayments:
        return const PaymentCenterScreen(initialTab: PaymentType.customerPayment);
      case ErpNavSection.dealerPayments:
        return const PaymentCenterScreen(initialTab: PaymentType.dealerPayment);
      case ErpNavSection.commissionPayments:
        return const PaymentCenterScreen(initialTab: PaymentType.commissionPayment);
      case ErpNavSection.expenseList:
        return const ExpensesScreen();
      // Masters
      case ErpNavSection.mastersDashboard:
        return const MastersRoleDashboard();
      case ErpNavSection.categoriesUnits:
        return const CategoriesUnitsScreen();
      case ErpNavSection.vendors:
        return const VendorsScreen();
      case ErpNavSection.customers:
        return const CustomersScreen();
      case ErpNavSection.dealers:
        return const DealersScreen();
      case ErpNavSection.architects:
        return const ArchitectsScreen();
      case ErpNavSection.billOfMaterials:
        return const BomScreen();
      // Reports
      case ErpNavSection.reportsDashboard:
        return const ReportViewerRoleDashboard();
      case ErpNavSection.inventoryReports:
      case ErpNavSection.purchaseReports:
      case ErpNavSection.productionReports:
      case ErpNavSection.salesReports:
      case ErpNavSection.projectReports:
      case ErpNavSection.commissionReports:
      case ErpNavSection.financialReports:
        return ReportsHubScreen(reportType: section);
      case ErpNavSection.chatSupport:
        return const ChatSupportScreen();
      case ErpNavSection.settings:
        return const SettingsScreen();
    }
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
                    ref.read(currentNavSectionProvider.notifier).state = user.getAccessibleLandingSection(db.roles);
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

