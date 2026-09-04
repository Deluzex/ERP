import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../shared/providers/app_state_providers.dart';

class ErpSidebar extends ConsumerStatefulWidget {
  const ErpSidebar({super.key});

  @override
  ConsumerState<ErpSidebar> createState() => _ErpSidebarState();
}

class _ErpSidebarState extends ConsumerState<ErpSidebar> {
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
    if (section == ErpNavSection.rawMaterialStock ||
        section == ErpNavSection.finishedProductStock ||
        section == ErpNavSection.stockMovement ||
        section == ErpNavSection.stockAdjustments) {
      _expandedGroups['Inventory'] = true;
    } else if (section == ErpNavSection.purchaseList ||
        section == ErpNavSection.purchaseHistory ||
        section == ErpNavSection.createPurchase ||
        section == ErpNavSection.vendorPayments) {
      _expandedGroups['Purchase'] = true;
    } else if (section == ErpNavSection.productionOrders ||
        section == ErpNavSection.productionHistory ||
        section == ErpNavSection.productionCosting ||
        section == ErpNavSection.createProduction) {
      _expandedGroups['Production'] = true;
    } else if (section == ErpNavSection.quotations ||
        section == ErpNavSection.salesOrders ||
        section == ErpNavSection.salesInvoiceList ||
        section == ErpNavSection.salesReturns) {
      _expandedGroups['Sales'] = true;
    } else if (section == ErpNavSection.customerPayments ||
        section == ErpNavSection.dealerPayments ||
        section == ErpNavSection.vendorPaymentsSection ||
        section == ErpNavSection.commissionPayments) {
      _expandedGroups['Payments'] = true;
    } else if (section == ErpNavSection.categoriesUnits ||
        section == ErpNavSection.rawMaterials ||
        section == ErpNavSection.finishedProducts ||
        section == ErpNavSection.vendors ||
        section == ErpNavSection.customers ||
        section == ErpNavSection.dealers ||
        section == ErpNavSection.architects ||
        section == ErpNavSection.projectList) {
      _expandedGroups['Masters'] = true;
    } else if (section == ErpNavSection.inventoryReports ||
        section == ErpNavSection.purchaseReports ||
        section == ErpNavSection.productionReports ||
        section == ErpNavSection.salesReports ||
        section == ErpNavSection.projectReports ||
        section == ErpNavSection.commissionReports ||
        section == ErpNavSection.financialReports) {
      _expandedGroups['Reports'] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSection = ref.watch(currentNavSectionProvider);
    _autoExpandForSection(currentSection);
    final db = ref.watch(databaseServiceProvider);

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

          // Scrollable Navigation List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [
                // 1. Dashboard
                _buildNavItem(
                  icon: Icons.home_outlined,
                  title: 'Dashboard',
                  isSelected: currentSection == ErpNavSection.dashboard,
                  onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.dashboard,
                ),

                // 2. Inventory (Group)
                _buildNavGroup(
                  groupTitle: 'Inventory',
                  icon: Icons.inventory_2_outlined,
                  isExpanded: _expandedGroups['Inventory'] ?? false,
                  onGroupTap: () => _toggleGroup('Inventory'),
                  children: [
                    _buildSubNavItem(
                      title: 'Raw Material Stock',
                      isSelected: currentSection == ErpNavSection.rawMaterialStock,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.rawMaterialStock,
                    ),
                    _buildSubNavItem(
                      title: 'Finished Product Stock',
                      isSelected: currentSection == ErpNavSection.finishedProductStock,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.finishedProductStock,
                    ),
                    _buildSubNavItem(
                      title: 'Stock Movement (Ledger)',
                      isSelected: currentSection == ErpNavSection.stockMovement,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.stockMovement,
                    ),
                    _buildSubNavItem(
                      title: 'Stock Adjustments',
                      isSelected: currentSection == ErpNavSection.stockAdjustments,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.stockAdjustments,
                    ),
                  ],
                ),

                // 3. Purchase (Group)
                _buildNavGroup(
                  groupTitle: 'Purchase',
                  icon: Icons.shopping_bag_outlined,
                  isExpanded: _expandedGroups['Purchase'] ?? false,
                  onGroupTap: () => _toggleGroup('Purchase'),
                  children: [
                    _buildSubNavItem(
                      title: 'Purchase List',
                      isSelected: currentSection == ErpNavSection.purchaseList,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseList,
                    ),
                    _buildSubNavItem(
                      title: 'Create Purchase',
                      isSelected: currentSection == ErpNavSection.createPurchase,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase,
                    ),
                  ],
                ),

                // 4. Production (Group)
                _buildNavGroup(
                  groupTitle: 'Production',
                  icon: Icons.precision_manufacturing_outlined,
                  isExpanded: _expandedGroups['Production'] ?? false,
                  onGroupTap: () => _toggleGroup('Production'),
                  children: [
                    _buildSubNavItem(
                      title: 'Production Orders',
                      isSelected: currentSection == ErpNavSection.productionOrders,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionOrders,
                    ),
                    _buildSubNavItem(
                      title: 'Create Production',
                      isSelected: currentSection == ErpNavSection.createProduction,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createProduction,
                    ),
<<<<<<< Updated upstream
                    _buildSubNavItem(
                      title: 'Production History',
                      isSelected: currentSection == ErpNavSection.productionHistory,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionHistory,
                    ),
                    _buildSubNavItem(
                      title: 'Production Costing',
                      isSelected: currentSection == ErpNavSection.productionCosting,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionCosting,
                    ),
=======
>>>>>>> Stashed changes
                  ],
                ),

                // 5. Sales (Group)
                _buildNavGroup(
                  groupTitle: 'Sales',
                  icon: Icons.point_of_sale_outlined,
                  isExpanded: _expandedGroups['Sales'] ?? false,
                  onGroupTap: () => _toggleGroup('Sales'),
                  children: [
                    _buildSubNavItem(
                      title: 'Sales Invoices',
                      isSelected: currentSection == ErpNavSection.salesInvoiceList,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList,
                    ),
                    _buildSubNavItem(
                      title: 'Create Sale',
                      isSelected: currentSection == ErpNavSection.createSale,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSale,
                    ),
                    _buildSubNavItem(
                      title: 'Quotations',
                      isSelected: currentSection == ErpNavSection.quotations,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.quotations,
                    ),
                    _buildSubNavItem(
                      title: 'Sales Orders',
                      isSelected: currentSection == ErpNavSection.salesOrders,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesOrders,
                    ),
                    _buildSubNavItem(
                      title: 'Sales Returns',
                      isSelected: currentSection == ErpNavSection.salesReturns,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesReturns,
                    ),
                  ],
                ),

                // 6. Payments (Group)
                _buildNavGroup(
                  groupTitle: 'Payments',
                  icon: Icons.payments_outlined,
                  isExpanded: _expandedGroups['Payments'] ?? false,
                  onGroupTap: () => _toggleGroup('Payments'),
                  children: [
                    _buildSubNavItem(
                      title: 'Customer Payments',
                      isSelected: currentSection == ErpNavSection.customerPayments,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.customerPayments,
                    ),
                    _buildSubNavItem(
                      title: 'Dealer Payments',
                      isSelected: currentSection == ErpNavSection.dealerPayments,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.dealerPayments,
                    ),
                    _buildSubNavItem(
                      title: 'Vendor Payments',
                      isSelected: currentSection == ErpNavSection.vendorPaymentsSection,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.vendorPaymentsSection,
                    ),
                    _buildSubNavItem(
                      title: 'Commission Payouts',
                      isSelected: currentSection == ErpNavSection.commissionPayments,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.commissionPayments,
                    ),
                  ],
                ),

                // 8. Masters (Group)
                _buildNavGroup(
                  groupTitle: 'Masters',
                  icon: Icons.dataset_outlined,
                  isExpanded: _expandedGroups['Masters'] ?? false,
                  onGroupTap: () => _toggleGroup('Masters'),
                  children: [
                    _buildSubNavItem(
                      title: 'Categories & Units',
                      isSelected: currentSection == ErpNavSection.categoriesUnits,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.categoriesUnits,
                    ),
                    _buildSubNavItem(
                      title: 'Raw Material Master',
                      isSelected: currentSection == ErpNavSection.rawMaterials,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.rawMaterials,
                    ),
                    _buildSubNavItem(
                      title: 'Product Master',
                      isSelected: currentSection == ErpNavSection.finishedProducts,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.finishedProducts,
                    ),
                    _buildSubNavItem(
                      title: 'Vendors',
                      isSelected: currentSection == ErpNavSection.vendors,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.vendors,
                    ),
                    _buildSubNavItem(
                      title: 'Customers',
                      isSelected: currentSection == ErpNavSection.customers,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.customers,
                    ),
                    _buildSubNavItem(
                      title: 'Dealers',
                      isSelected: currentSection == ErpNavSection.dealers,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.dealers,
                    ),
                    _buildSubNavItem(
<<<<<<< Updated upstream
                      title: 'Architects & Commission',
                      isSelected: currentSection == ErpNavSection.architects,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.architects,
=======
                      title: 'Projects',
                      isSelected: currentSection == ErpNavSection.projectList,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.projectList,
                    ),
                    _buildNestedNavGroup(
                      groupTitle: 'Architects',
                      isExpanded: _expandedGroups['Architects'] ?? false,
                      onGroupTap: () {
                        setState(() {
                          _expandedGroups['Architects'] = !(_expandedGroups['Architects'] ?? false);
                        });
                        ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.architects;
                      },
                      children: [
                        _buildNestedSubNavItem(
                          title: 'Architect Details',
                          isSelected: currentSection == ErpNavSection.architects && ref.watch(architectsTabActiveIndexProvider) == 0,
                          onTap: () {
                            ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.architects;
                            ref.read(architectsTabActiveIndexProvider.notifier).state = 0;
                          },
                        ),
                        _buildNestedSubNavItem(
                          title: 'Related Sales',
                          isSelected: currentSection == ErpNavSection.architects && ref.watch(architectsTabActiveIndexProvider) == 1,
                          onTap: () {
                            ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.architects;
                            ref.read(architectsTabActiveIndexProvider.notifier).state = 1;
                          },
                        ),
                        _buildNestedSubNavItem(
                          title: 'Projects',
                          isSelected: currentSection == ErpNavSection.architects && ref.watch(architectsTabActiveIndexProvider) == 2,
                          onTap: () {
                            ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.architects;
                            ref.read(architectsTabActiveIndexProvider.notifier).state = 2;
                          },
                        ),
                        _buildNestedSubNavItem(
                          title: 'Commission',
                          isSelected: currentSection == ErpNavSection.architects && ref.watch(architectsTabActiveIndexProvider) == 3,
                          onTap: () {
                            ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.architects;
                            ref.read(architectsTabActiveIndexProvider.notifier).state = 3;
                          },
                        ),
                      ],
>>>>>>> Stashed changes
                    ),
                    _buildSubNavItem(
                      title: 'Raw Materials',
                      isSelected: currentSection == ErpNavSection.rawMaterials,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.rawMaterials,
                    ),
                    _buildSubNavItem(
                      title: 'Finished Products',
                      isSelected: currentSection == ErpNavSection.finishedProducts,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.finishedProducts,
                    ),
                  ],
                ),

                // 9. Reports (Group)
                _buildNavGroup(
                  groupTitle: 'Reports',
                  icon: Icons.bar_chart_rounded,
                  isExpanded: _expandedGroups['Reports'] ?? false,
                  onGroupTap: () => _toggleGroup('Reports'),
                  children: [
                    _buildSubNavItem(
                      title: 'Inventory Reports',
                      isSelected: currentSection == ErpNavSection.inventoryReports,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.inventoryReports,
                    ),
                    _buildSubNavItem(
                      title: 'Purchase Reports',
                      isSelected: currentSection == ErpNavSection.purchaseReports,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseReports,
                    ),
                    _buildSubNavItem(
                      title: 'Production Reports',
                      isSelected: currentSection == ErpNavSection.productionReports,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionReports,
                    ),
                    _buildSubNavItem(
                      title: 'Sales Reports',
                      isSelected: currentSection == ErpNavSection.salesReports,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesReports,
                    ),
                    _buildSubNavItem(
                      title: 'Project Reports',
                      isSelected: currentSection == ErpNavSection.projectReports,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.projectReports,
                    ),
                    _buildSubNavItem(
                      title: 'Commission Reports',
                      isSelected: currentSection == ErpNavSection.commissionReports,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.commissionReports,
                    ),
                    _buildSubNavItem(
                      title: 'Financial Reports',
                      isSelected: currentSection == ErpNavSection.financialReports,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.financialReports,
                    ),
                  ],
                ),

                // 10. Settings
                _buildNavItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  isSelected: currentSection == ErpNavSection.settings,
                  onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.settings,
                ),
              ],
            ),
          ),

          // User Profile Card Footer (Alex Sterling - Service Manager)
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
                  child: const Text(
                    'AS',
                    style: TextStyle(
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
                        db.currentUser.name,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        db.currentUser.role,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.sidebarTextMuted,
                          fontSize: 11,
                        ),
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
                  color: Colors.white,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                      color: Colors.white,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        groupTitle,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                      size: 18,
                      color: Colors.white,
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
