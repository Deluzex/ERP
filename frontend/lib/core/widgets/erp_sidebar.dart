import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../models/rbac_models.dart';
import '../../shared/providers/app_state_providers.dart';
import '../../shared/widgets/access_required_dialog.dart';

class ErpSidebar extends ConsumerStatefulWidget {
  const ErpSidebar({super.key});

  @override
  ConsumerState<ErpSidebar> createState() => _ErpSidebarState();
}

class _ErpSidebarState extends ConsumerState<ErpSidebar> {
  ErpNavSection? _lastSection;
  final Map<String, bool> _expandedGroups = {
    'Inventory': true,
    'Purchase': false,
    'Production': false,
    'Sales': false,
    'Payments': false,
    'Masters': false,
    'Reports': false,
  };

  void _toggleGroup(String group) {
    setState(() {
      _expandedGroups[group] = !(_expandedGroups[group] ?? false);
    });
  }

  void _autoExpandForSection(ErpNavSection section) {
    if (section == ErpNavSection.inventoryDashboard ||
        section == ErpNavSection.rawMaterialStock ||
        section == ErpNavSection.finishedProductStock ||
        section == ErpNavSection.stockMovement ||
        section == ErpNavSection.stockAdjustments) {
      _expandedGroups['Inventory'] = true;
    } else if (section == ErpNavSection.purchaseDashboard ||
        section == ErpNavSection.purchaseList ||
        section == ErpNavSection.purchaseHistory ||
        section == ErpNavSection.createPurchase ||
        section == ErpNavSection.vendorPayments) {
      _expandedGroups['Purchase'] = true;
    } else if (section == ErpNavSection.productionDashboard ||
        section == ErpNavSection.productionOrders ||
        section == ErpNavSection.createProduction ||
        section == ErpNavSection.productionHistory) {
      _expandedGroups['Production'] = true;
    } else if (section == ErpNavSection.salesDashboard ||
        section == ErpNavSection.quotations ||
        section == ErpNavSection.createQuotation ||
        section == ErpNavSection.proformaInvoices ||
        section == ErpNavSection.salesOrders ||
        section == ErpNavSection.createSalesOrder ||
        section == ErpNavSection.salesDeliveries ||
        section == ErpNavSection.salesInvoiceList ||
        section == ErpNavSection.createSale ||
        section == ErpNavSection.salesReturns ||
        section == ErpNavSection.createSalesReturn) {
      _expandedGroups['Sales'] = true;
    } else if (section == ErpNavSection.paymentsDashboard ||
        section == ErpNavSection.customerPayments ||
        section == ErpNavSection.dealerPayments ||
        section == ErpNavSection.vendorPaymentsSection ||
        section == ErpNavSection.commissionPayments ||
        section == ErpNavSection.expenseList) {
      _expandedGroups['Payments'] = true;
    } else if (section == ErpNavSection.mastersDashboard ||
        section == ErpNavSection.categoriesUnits ||
        section == ErpNavSection.rawMaterials ||
        section == ErpNavSection.finishedProducts ||
        section == ErpNavSection.vendors ||
        section == ErpNavSection.customers ||
        section == ErpNavSection.dealers ||
        section == ErpNavSection.architects ||
        section == ErpNavSection.projectList) {
      _expandedGroups['Masters'] = true;
    } else if (section == ErpNavSection.reportsDashboard ||
        section == ErpNavSection.inventoryReports ||
        section == ErpNavSection.purchaseReports ||
        section == ErpNavSection.productionReports ||
        section == ErpNavSection.salesReports ||
        section == ErpNavSection.projectReports ||
        section == ErpNavSection.commissionReports ||
        section == ErpNavSection.financialReports) {
      _expandedGroups['Reports'] = true;
    }
  }

  void _handleNavigation(BuildContext context, ErpNavSection targetSection, ErpModule module, [ErpAction? action]) {
    final db = ref.read(databaseServiceProvider);
    final currentUser = ref.read(currentUserProvider) ?? db.currentUser;
    final allRoles = db.roles;
    final temporaryGrants = db.temporaryGrants;

    // Auto close navigation drawer on mobile/tablet if open
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    final hasAccess = currentUser.hasPermission(module, action ?? ErpAction.view, allRoles, temporaryGrants);

    if (hasAccess) {
      ref.read(currentNavSectionProvider.notifier).state = targetSection;
      ref.read(activeRecordDetailsStackProvider.notifier).clear();
    } else {
      AccessRequiredDialog.show(
        context,
        module: module,
        action: action ?? ErpAction.view,
        customTitle: '🔒 Access Required: ${module.label}',
        customMessage:
            'You do not have direct permission to access the "${module.label}" module under your assigned role (${db.getUserRole(currentUser).name}).',
        onAccessGranted: (grant) {
          ref.read(currentNavSectionProvider.notifier).state = targetSection;
          ref.read(activeRecordDetailsStackProvider.notifier).clear();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSection = ref.watch(currentNavSectionProvider);
    if (_lastSection != currentSection) {
      _lastSection = currentSection;
      _autoExpandForSection(currentSection);
    }
    final db = ref.watch(databaseServiceProvider);
    final currentUser = ref.watch(currentUserProvider) ?? db.currentUser;
    final allRoles = db.roles;
    final userRole = db.getUserRole(currentUser);
    final temporaryGrants = db.temporaryGrants;

    // Permission state per module (for subtle lock indicator, but all modules stay 100% visible)
    final canAccessDashboard = currentUser.canAccessModule(ErpModule.dashboard, allRoles, temporaryGrants);
    final canAccessInventory = currentUser.canAccessModule(ErpModule.inventory, allRoles, temporaryGrants);
    final canAccessPurchase = currentUser.canAccessModule(ErpModule.purchase, allRoles, temporaryGrants);
    final canAccessProduction = currentUser.canAccessModule(ErpModule.production, allRoles, temporaryGrants);
    final canAccessSales = currentUser.canAccessModule(ErpModule.sales, allRoles, temporaryGrants);
    final canAccessPayments = currentUser.canAccessModule(ErpModule.payments, allRoles, temporaryGrants);
    final canAccessMasters = currentUser.canAccessModule(ErpModule.masters, allRoles, temporaryGrants);
    final canAccessReports = currentUser.canAccessModule(ErpModule.reports, allRoles, temporaryGrants);
    final canAccessSettings = currentUser.canAccessModule(ErpModule.settings, allRoles, temporaryGrants);

    return RepaintBoundary(
      child: Container(
        width: 250,
        color: AppColors.sidebarBackground,
        child: Column(
          children: [
            // Logo Area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/logo.png',
                height: 38,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'd',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Scrollable Navigation List - ALL MODULES REMAIN VISIBLE
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                children: [
                  // 1. Main Dashboard
                  if (canAccessDashboard)
                    _buildNavItem(
                      icon: Icons.home_outlined,
                      title: 'Dashboard',
                      isRestricted: !canAccessDashboard,
                      isSelected: currentSection == ErpNavSection.dashboard,
                      onTap: () {
                        _handleNavigation(context, userRole.defaultDashboardSection, ErpModule.dashboard);
                      },
                    ),

                  // 2. Inventory (Group)
                  if (canAccessInventory)
                    _buildNavGroup(
                      groupTitle: 'Inventory',
                      icon: Icons.inventory_2_outlined,
                    isRestricted: !canAccessInventory,
                    isExpanded: _expandedGroups['Inventory'] ?? false,
                    onGroupTap: () => _toggleGroup('Inventory'),
                    children: [
                      _buildSubNavItem(
                        title: 'Inventory Dashboard',
                        isRestricted: !canAccessInventory,
                        isSelected: currentSection == ErpNavSection.inventoryDashboard,
                        onTap: () => _handleNavigation(context, ErpNavSection.inventoryDashboard, ErpModule.inventory),
                      ),
                      _buildSubNavItem(
                        title: 'Raw Material Stock',
                        isRestricted: !canAccessInventory,
                        isSelected: currentSection == ErpNavSection.rawMaterialStock,
                        onTap: () => _handleNavigation(context, ErpNavSection.rawMaterialStock, ErpModule.inventory),
                      ),
                      _buildSubNavItem(
                        title: 'Finished Product Stock',
                        isRestricted: !canAccessInventory,
                        isSelected: currentSection == ErpNavSection.finishedProductStock,
                        onTap: () => _handleNavigation(context, ErpNavSection.finishedProductStock, ErpModule.inventory),
                      ),
                      _buildSubNavItem(
                        title: 'Stock Movement (Ledger)',
                        isRestricted: !canAccessInventory,
                        isSelected: currentSection == ErpNavSection.stockMovement,
                        onTap: () => _handleNavigation(context, ErpNavSection.stockMovement, ErpModule.inventory),
                      ),
                      _buildSubNavItem(
                        title: 'Stock Adjustments',
                        isRestricted: !canAccessInventory,
                        isSelected: currentSection == ErpNavSection.stockAdjustments,
                        onTap: () => _handleNavigation(context, ErpNavSection.stockAdjustments, ErpModule.inventory),
                      ),
                    ],
                  ),

                  // 3. Purchase (Group)
                  if (canAccessPurchase)
                    _buildNavGroup(
                      groupTitle: 'Purchase',
                      icon: Icons.shopping_bag_outlined,
                      isRestricted: !canAccessPurchase,
                      isExpanded: _expandedGroups['Purchase'] ?? false,
                      onGroupTap: () => _toggleGroup('Purchase'),
                      children: [
                        _buildSubNavItem(
                          title: 'Purchase Dashboard',
                          isRestricted: !canAccessPurchase,
                          isSelected: currentSection == ErpNavSection.purchaseDashboard,
                          onTap: () => _handleNavigation(context, ErpNavSection.purchaseDashboard, ErpModule.purchase),
                        ),
                        _buildSubNavItem(
                          title: 'Purchase Orders',
                          isRestricted: !canAccessPurchase,
                          isSelected: currentSection == ErpNavSection.purchaseList,
                          onTap: () => _handleNavigation(context, ErpNavSection.purchaseList, ErpModule.purchase),
                        ),
                        _buildSubNavItem(
                          title: 'Create Purchase',
                          isRestricted: !canAccessPurchase,
                          isSelected: currentSection == ErpNavSection.createPurchase,
                          onTap: () => _handleNavigation(context, ErpNavSection.createPurchase, ErpModule.purchase, ErpAction.create),
                        ),
                      ],
                    ),

                  // 4. Production (Group)
                  if (canAccessProduction)
                    _buildNavGroup(
                    groupTitle: 'Production',
                    icon: Icons.precision_manufacturing_outlined,
                    isRestricted: !canAccessProduction,
                    isExpanded: _expandedGroups['Production'] ?? false,
                    onGroupTap: () => _toggleGroup('Production'),
                    children: [
                      _buildSubNavItem(
                        title: 'Production Dashboard',
                        isRestricted: !canAccessProduction,
                        isSelected: currentSection == ErpNavSection.productionDashboard,
                        onTap: () => _handleNavigation(context, ErpNavSection.productionDashboard, ErpModule.production),
                      ),
                      _buildSubNavItem(
                        title: 'Work Orders',
                        isRestricted: !canAccessProduction,
                        isSelected: currentSection == ErpNavSection.productionOrders,
                        onTap: () => _handleNavigation(context, ErpNavSection.productionOrders, ErpModule.production),
                      ),
                      _buildSubNavItem(
                        title: 'Create Work Order',
                        isRestricted: !canAccessProduction,
                        isSelected: currentSection == ErpNavSection.createProduction,
                        onTap: () => _handleNavigation(context, ErpNavSection.createProduction, ErpModule.production, ErpAction.create),
                      ),
                    ],
                  ),

                  // 5. Sales (Group)
                  if (canAccessSales)
                    _buildNavGroup(
                      groupTitle: 'Sales',
                      icon: Icons.point_of_sale_outlined,
                      isRestricted: !canAccessSales,
                      isExpanded: _expandedGroups['Sales'] ?? false,
                      onGroupTap: () => _toggleGroup('Sales'),
                      children: [
                        _buildSubNavItem(
                          title: 'Sales Dashboard',
                          isRestricted: !canAccessSales,
                          isSelected: currentSection == ErpNavSection.salesDashboard,
                          onTap: () => _handleNavigation(context, ErpNavSection.salesDashboard, ErpModule.sales),
                        ),
                        _buildSubNavItem(
                          title: 'Quotations',
                          isRestricted: !canAccessSales,
                          isSelected: currentSection == ErpNavSection.quotations || currentSection == ErpNavSection.createQuotation,
                          onTap: () => _handleNavigation(context, ErpNavSection.quotations, ErpModule.sales),
                        ),
                        _buildSubNavItem(
                          title: 'Proforma Invoices',
                          isRestricted: !canAccessSales,
                          isSelected: currentSection == ErpNavSection.proformaInvoices,
                          onTap: () => _handleNavigation(context, ErpNavSection.proformaInvoices, ErpModule.sales),
                        ),
                        _buildSubNavItem(
                          title: 'Sales Orders',
                          isRestricted: !canAccessSales,
                          isSelected: currentSection == ErpNavSection.salesOrders || currentSection == ErpNavSection.createSalesOrder,
                          onTap: () => _handleNavigation(context, ErpNavSection.salesOrders, ErpModule.sales),
                        ),
                        _buildSubNavItem(
                          title: 'Deliveries & Dispatch',
                          isRestricted: !canAccessSales,
                          isSelected: currentSection == ErpNavSection.salesDeliveries,
                          onTap: () => _handleNavigation(context, ErpNavSection.salesDeliveries, ErpModule.sales),
                        ),
                        _buildSubNavItem(
                          title: 'Sales Invoices',
                          isRestricted: !canAccessSales,
                          isSelected: currentSection == ErpNavSection.salesInvoiceList,
                          onTap: () => _handleNavigation(context, ErpNavSection.salesInvoiceList, ErpModule.sales),
                        ),
                        _buildSubNavItem(
                          title: 'Create Direct Sale',
                          isRestricted: !canAccessSales,
                          isSelected: currentSection == ErpNavSection.createSale,
                          onTap: () => _handleNavigation(context, ErpNavSection.createSale, ErpModule.sales, ErpAction.create),
                        ),
                        _buildSubNavItem(
                          title: 'Sales Returns',
                          isRestricted: !canAccessSales,
                          isSelected: currentSection == ErpNavSection.salesReturns || currentSection == ErpNavSection.createSalesReturn,
                          onTap: () => _handleNavigation(context, ErpNavSection.salesReturns, ErpModule.sales),
                        ),
                      ],
                    ),

                  // 6. Payments (Group)
                  if (canAccessPayments)
                    _buildNavGroup(
                      groupTitle: 'Payments',
                      icon: Icons.payments_outlined,
                      isRestricted: !canAccessPayments,
                      isExpanded: _expandedGroups['Payments'] ?? false,
                      onGroupTap: () => _toggleGroup('Payments'),
                      children: [
                        _buildSubNavItem(
                          title: 'Payments Dashboard',
                          isRestricted: !canAccessPayments,
                          isSelected: currentSection == ErpNavSection.paymentsDashboard,
                          onTap: () => _handleNavigation(context, ErpNavSection.paymentsDashboard, ErpModule.payments),
                        ),
                        _buildSubNavItem(
                          title: 'Customer Payments',
                          isRestricted: !canAccessPayments,
                          isSelected: currentSection == ErpNavSection.customerPayments,
                          onTap: () => _handleNavigation(context, ErpNavSection.customerPayments, ErpModule.payments),
                        ),
                        _buildSubNavItem(
                          title: 'Dealer Payments',
                          isRestricted: !canAccessPayments,
                          isSelected: currentSection == ErpNavSection.dealerPayments,
                          onTap: () => _handleNavigation(context, ErpNavSection.dealerPayments, ErpModule.payments),
                        ),
                        _buildSubNavItem(
                          title: 'Vendor Payments',
                          isRestricted: !canAccessPayments,
                          isSelected: currentSection == ErpNavSection.vendorPaymentsSection,
                          onTap: () => _handleNavigation(context, ErpNavSection.vendorPaymentsSection, ErpModule.payments),
                        ),
                        _buildSubNavItem(
                          title: 'Commission Payouts',
                          isRestricted: !canAccessPayments,
                          isSelected: currentSection == ErpNavSection.commissionPayments,
                          onTap: () => _handleNavigation(context, ErpNavSection.commissionPayments, ErpModule.payments),
                        ),
                        _buildSubNavItem(
                          title: 'Expense Management',
                          isRestricted: !canAccessPayments,
                          isSelected: currentSection == ErpNavSection.expenseList,
                          onTap: () => _handleNavigation(context, ErpNavSection.expenseList, ErpModule.payments),
                        ),
                      ],
                    ),

                  // 7. Masters (Group)
                  if (canAccessMasters)
                    _buildNavGroup(
                      groupTitle: 'Masters',
                      icon: Icons.dataset_outlined,
                      isRestricted: !canAccessMasters,
                      isExpanded: _expandedGroups['Masters'] ?? false,
                      onGroupTap: () => _toggleGroup('Masters'),
                      children: [
                        _buildSubNavItem(
                          title: 'Masters Dashboard',
                          isRestricted: !canAccessMasters,
                          isSelected: currentSection == ErpNavSection.mastersDashboard,
                          onTap: () => _handleNavigation(context, ErpNavSection.mastersDashboard, ErpModule.masters),
                        ),
                        _buildSubNavItem(
                          title: 'Customers',
                          isRestricted: !canAccessMasters,
                          isSelected: currentSection == ErpNavSection.customers,
                          onTap: () => _handleNavigation(context, ErpNavSection.customers, ErpModule.masters),
                        ),
                        _buildSubNavItem(
                          title: 'Vendors',
                          isRestricted: !canAccessMasters,
                          isSelected: currentSection == ErpNavSection.vendors,
                          onTap: () => _handleNavigation(context, ErpNavSection.vendors, ErpModule.masters),
                        ),
                        _buildSubNavItem(
                          title: 'Dealers',
                          isRestricted: !canAccessMasters,
                          isSelected: currentSection == ErpNavSection.dealers,
                          onTap: () => _handleNavigation(context, ErpNavSection.dealers, ErpModule.masters),
                        ),
                        _buildSubNavItem(
                          title: 'Architects & Commission',
                          isRestricted: !canAccessMasters,
                          isSelected: currentSection == ErpNavSection.architects,
                          onTap: () => _handleNavigation(context, ErpNavSection.architects, ErpModule.masters),
                        ),
                        _buildSubNavItem(
                          title: 'Raw Material Master',
                          isRestricted: !canAccessMasters,
                          isSelected: currentSection == ErpNavSection.rawMaterials,
                          onTap: () => _handleNavigation(context, ErpNavSection.rawMaterials, ErpModule.masters),
                        ),
                        _buildSubNavItem(
                          title: 'Product Master',
                          isRestricted: !canAccessMasters,
                          isSelected: currentSection == ErpNavSection.finishedProducts,
                          onTap: () => _handleNavigation(context, ErpNavSection.finishedProducts, ErpModule.masters),
                        ),
                        _buildSubNavItem(
                          title: 'Categories & Units',
                          isRestricted: !canAccessMasters,
                          isSelected: currentSection == ErpNavSection.categoriesUnits,
                          onTap: () => _handleNavigation(context, ErpNavSection.categoriesUnits, ErpModule.masters),
                        ),
                        _buildSubNavItem(
                          title: 'Projects',
                          isRestricted: !canAccessMasters,
                          isSelected: currentSection == ErpNavSection.projectList,
                          onTap: () => _handleNavigation(context, ErpNavSection.projectList, ErpModule.masters),
                        ),
                      ],
                    ),

                  // 8. Reports (Group)
                  if (canAccessReports)
                    _buildNavGroup(
                      groupTitle: 'Reports',
                      icon: Icons.bar_chart_rounded,
                      isRestricted: !canAccessReports,
                      isExpanded: _expandedGroups['Reports'] ?? false,
                      onGroupTap: () => _toggleGroup('Reports'),
                      children: [
                        _buildSubNavItem(
                          title: 'Reports Hub & Analytics',
                          isRestricted: !canAccessReports,
                          isSelected: currentSection == ErpNavSection.reportsDashboard,
                          onTap: () => _handleNavigation(context, ErpNavSection.reportsDashboard, ErpModule.reports),
                        ),
                        _buildSubNavItem(
                          title: 'Inventory Reports',
                          isRestricted: !canAccessReports,
                          isSelected: currentSection == ErpNavSection.inventoryReports,
                          onTap: () => _handleNavigation(context, ErpNavSection.inventoryReports, ErpModule.reports),
                        ),
                        _buildSubNavItem(
                          title: 'Purchase Reports',
                          isRestricted: !canAccessReports,
                          isSelected: currentSection == ErpNavSection.purchaseReports,
                          onTap: () => _handleNavigation(context, ErpNavSection.purchaseReports, ErpModule.reports),
                        ),
                        _buildSubNavItem(
                          title: 'Production Reports',
                          isRestricted: !canAccessReports,
                          isSelected: currentSection == ErpNavSection.productionReports,
                          onTap: () => _handleNavigation(context, ErpNavSection.productionReports, ErpModule.reports),
                        ),
                        _buildSubNavItem(
                          title: 'Sales Reports',
                          isRestricted: !canAccessReports,
                          isSelected: currentSection == ErpNavSection.salesReports,
                          onTap: () => _handleNavigation(context, ErpNavSection.salesReports, ErpModule.reports),
                        ),
                        _buildSubNavItem(
                          title: 'Project Reports',
                          isRestricted: !canAccessReports,
                          isSelected: currentSection == ErpNavSection.projectReports,
                          onTap: () => _handleNavigation(context, ErpNavSection.projectReports, ErpModule.reports),
                        ),
                        _buildSubNavItem(
                          title: 'Financial Reports',
                          isRestricted: !canAccessReports,
                          isSelected: currentSection == ErpNavSection.financialReports,
                          onTap: () => _handleNavigation(context, ErpNavSection.financialReports, ErpModule.reports),
                        ),
                      ],
                    ),

                  // 9. Settings
                  if (canAccessSettings)
                    _buildNavItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      isRestricted: !canAccessSettings,
                      isSelected: currentSection == ErpNavSection.settings,
                      onTap: () => _handleNavigation(context, ErpNavSection.settings, ErpModule.settings),
                    ),
                ],
              ),
            ),

            // User Profile Card Footer (Dynamic Role-Based)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.sidebarBackground,
                border: Border(
                  top: BorderSide(color: AppColors.sidebarBorder, width: 1),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      currentUser.name.isNotEmpty ? currentUser.name.substring(0, 1).toUpperCase() : 'U',
                      style: const TextStyle(
                        color: AppColors.sidebarBackground,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentUser.name,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                userRole.name,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    bool isRestricted = false,
    required VoidCallback onTap,
  }) {
    if (isSelected) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Top inverse curve
            Positioned(
              top: -20,
              right: 0,
              width: 20,
              height: 20,
              child: Container(
                color: AppColors.surface,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.sidebarBackground,
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom inverse curve
            Positioned(
              bottom: -20,
              right: 0,
              width: 20,
              height: 20,
              child: Container(
                color: AppColors.surface,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.sidebarBackground,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
            // Active item pill extending to right edge
            Container(
              height: 48,
              margin: const EdgeInsets.only(left: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: AppColors.sidebarActiveText,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.sidebarActiveText,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRestricted)
                          Icon(Icons.lock_outline, size: 14, color: AppColors.sidebarActiveText.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 44,
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppColors.sidebarHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isRestricted ? Colors.white70 : Colors.white,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isRestricted ? Colors.white70 : Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isRestricted)
                  const Icon(Icons.lock_outline, size: 14, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavGroup({
    required String groupTitle,
    required IconData icon,
    required bool isExpanded,
    bool isRestricted = false,
    required VoidCallback onGroupTap,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          margin: const EdgeInsets.only(left: 12, right: 12, bottom: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onGroupTap,
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              hoverColor: AppColors.sidebarHover,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isRestricted ? Colors.white70 : Colors.white,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        groupTitle,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isRestricted ? Colors.white70 : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRestricted) ...[
                      const Icon(Icons.lock_outline, size: 13, color: Colors.white38),
                      const SizedBox(width: 4),
                    ],
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              children: children,
            ),
          ),
      ],
    );
  }

  Widget _buildSubNavItem({
    required String title,
    required bool isSelected,
    bool isRestricted = false,
    required VoidCallback onTap,
  }) {
    if (isSelected) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Top inverse curve
            Positioned(
              top: -18,
              right: 0,
              width: 18,
              height: 18,
              child: Container(
                color: AppColors.surface,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.sidebarBackground,
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom inverse curve
            Positioned(
              bottom: -18,
              right: 0,
              width: 18,
              height: 18,
              child: Container(
                color: AppColors.surface,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.sidebarBackground,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
            // Active sub item pill
            Container(
              height: 42,
              margin: const EdgeInsets.only(left: 20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(21),
                  bottomLeft: Radius.circular(21),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(21),
                    bottomLeft: Radius.circular(21),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.sidebarActiveText,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.sidebarActiveText,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRestricted)
                          Icon(Icons.lock_outline, size: 12, color: AppColors.sidebarActiveText.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 38,
      margin: const EdgeInsets.only(left: 20, right: 12, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.sidebarHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isRestricted ? Colors.white38 : Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isRestricted ? Colors.white70 : Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isRestricted)
                  const Icon(Icons.lock_outline, size: 12, color: Colors.white30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
