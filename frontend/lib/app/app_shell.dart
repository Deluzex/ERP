import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/payment_model.dart';
import '../core/widgets/erp_header.dart';
import '../core/widgets/erp_sidebar.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
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
import '../features/sales/screens/create_sale_screen.dart';
import '../features/sales/screens/sales_invoice_list_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../shared/providers/app_state_providers.dart';
import 'routes/app_routes.dart';
import 'theme/app_colors.dart';

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

    Widget contentWidget;
    switch (currentSection) {
      case ErpNavSection.dashboard:
      case ErpNavSection.inventoryDashboard:
        contentWidget = const DashboardScreen();
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
      case ErpNavSection.productionOrders:
      case ErpNavSection.productionHistory:
      case ErpNavSection.productionCosting:
        contentWidget = const ProductionOrdersScreen();
        break;
      case ErpNavSection.createProduction:
        contentWidget = const CreateProductionScreen();
        break;
      case ErpNavSection.salesInvoiceList:
      case ErpNavSection.quotations:
      case ErpNavSection.salesOrders:
      case ErpNavSection.salesReturns:
        contentWidget = const SalesInvoiceListScreen();
        break;
      case ErpNavSection.createSale:
        contentWidget = const CreateSaleScreen();
        break;
      case ErpNavSection.projectList:
      case ErpNavSection.createProject:
        contentWidget = const ProjectListScreen();
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: isDesktop ? null : const Drawer(child: ErpSidebar()),
      body: Row(
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
    );
  }
}
