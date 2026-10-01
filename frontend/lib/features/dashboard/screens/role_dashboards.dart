import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/models/stock_movement_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

// =====================================================================
// 1. INVENTORY ROLE DASHBOARD
// =====================================================================
class InventoryRoleDashboard extends ConsumerWidget {
  const InventoryRoleDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    final lowStockRM = db.lowStockRawMaterials;
    final lowStockFP = db.lowStockFinishedProducts;
    final recentMovements = db.stockMovements.take(6).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoleHeader(
            context: context,
            title: 'Inventory & Warehouse Dashboard',
            subtitle: 'Real-time stock valuation, inventory balances, low stock alerts, and warehouse movements',
            badgeText: 'INVENTORY MANAGER',
            badgeColor: Colors.blue,
          ),
          const SizedBox(height: 20),

          // Quick Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Quick Inventory Actions:', style: AppTextStyles.bodyBold),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ErpButton(
                      text: 'Raw Material Stock',
                      icon: Icons.category_outlined,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.rawMaterialStock,
                    ),
                    ErpButton(
                      text: 'Finished Product Stock',
                      icon: Icons.inventory_2_outlined,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.finishedProductStock,
                    ),
                    ErpButton(
                      text: 'Stock Movement Ledger',
                      icon: Icons.swap_horiz_rounded,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.stockMovement,
                    ),
                    ErpButton(
                      text: 'New Stock Adjustment',
                      icon: Icons.tune_rounded,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.stockAdjustments,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4 Key Metrics
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Raw Material Valuation',
              value: Formatters.formatCurrency(db.rawMaterialStockValue),
              subtitle: '${db.rawMaterials.length} Unique items',
              icon: Icons.view_in_ar_rounded,
              color: Colors.blue,
            ),
            _buildMetricCard(
              title: 'Finished Goods Valuation',
              value: Formatters.formatCurrency(db.finishedProductStockValue),
              subtitle: '${db.finishedProducts.length} Product SKUs',
              icon: Icons.inventory_outlined,
              color: Colors.teal,
            ),
            _buildMetricCard(
              title: 'Total Stock Valuation',
              value: Formatters.formatCurrency(db.totalStockValue),
              subtitle: 'Combined Warehouse Assets',
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.indigo,
            ),
            _buildMetricCard(
              title: 'Low Stock Alerts',
              value: '${db.totalLowStockCount} Items',
              subtitle: '${lowStockRM.length} RM • ${lowStockFP.length} FP below min level',
              icon: Icons.warning_amber_rounded,
              color: db.totalLowStockCount > 0 ? AppColors.danger : AppColors.success,
            ),
          ]),
          const SizedBox(height: 28),

          // Low Stock Alert Tables
          _buildResponsiveTwoPanes(
            context,
            left: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Low Stock Raw Materials',
                          style: AppTextStyles.h3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ErpStatusBadge.warning('${lowStockRM.length} Critical'),
                    ],
                  ),
                  const Divider(height: 24),
                  if (lowStockRM.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('All raw materials are above minimum buffer levels.', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ...lowStockRM.take(5).map((rm) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(rm.name, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('${rm.itemCode} • Min: ${rm.minimumStock} ${rm.unit}', style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '${rm.currentStock} ${rm.unit}',
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
            right: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Low Stock Finished Products',
                          style: AppTextStyles.h3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ErpStatusBadge.warning('${lowStockFP.length} Critical'),
                    ],
                  ),
                  const Divider(height: 24),
                  if (lowStockFP.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('All finished product SKUs have adequate inventory.', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ...lowStockFP.take(5).map((fp) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(fp.name, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('${fp.itemCode} • Min: ${fp.minimumStock} ${fp.unit}', style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '${fp.currentStock} ${fp.unit}',
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Recent Stock Movements
          Text('Recent Stock Movements (Ledger)', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Date & Time'),
              ErpColumn(title: 'Item / SKU'),
              ErpColumn(title: 'Movement Type'),
              ErpColumn(title: 'Quantity Changed', isNumeric: true),
              ErpColumn(title: 'Balance After', isNumeric: true),
              ErpColumn(title: 'Reference / Source'),
            ],
            rows: recentMovements.map((m) {
              final isPositive = m.stockIn > 0;

              return [
                Text(Formatters.formatDateTime(m.date), style: AppTextStyles.bodySmall),
                Text(m.itemName, style: AppTextStyles.bodyBold),
                ErpStatusBadge(
                  label: m.transactionTypeLabel,
                  backgroundColor: isPositive ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  textColor: isPositive ? Colors.green.shade800 : Colors.orange.shade900,
                ),
                Text(
                  '${isPositive ? "+" : "-"}${isPositive ? m.stockIn : m.stockOut} ${m.unit}',
                  style: AppTextStyles.bodyBold.copyWith(color: isPositive ? Colors.green : Colors.red),
                ),
                Text('${m.currentBalance} ${m.unit}', style: AppTextStyles.bodySmall),
                Text(m.referenceNumber.isNotEmpty ? m.referenceNumber : (m.notes ?? '-'), style: AppTextStyles.bodySmall),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// 2. PURCHASE ROLE DASHBOARD
// =====================================================================
class PurchaseRoleDashboard extends ConsumerWidget {
  const PurchaseRoleDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    final pendingPurchases = db.purchases.where((p) => p.status == PurchaseStatus.draft || p.status == PurchaseStatus.saved).toList();
    final completedPurchases = db.purchases.where((p) => p.status == PurchaseStatus.paid || p.status == PurchaseStatus.partialPaid).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoleHeader(
            context: context,
            title: 'Procurement & Purchase Hub',
            subtitle: 'Purchase orders, vendor relations, raw material supplies, and delivery tracking',
            badgeText: 'PURCHASE MANAGER',
            badgeColor: Colors.purple,
          ),
          const SizedBox(height: 20),

          // Quick Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Purchase Actions:', style: AppTextStyles.bodyBold),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ErpButton(
                      text: 'Create Purchase Order',
                      icon: Icons.add_shopping_cart,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase,
                    ),
                    ErpButton(
                      text: 'Purchase List',
                      icon: Icons.list_alt_rounded,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseList,
                    ),
                    ErpButton(
                      text: 'Vendors Directory',
                      icon: Icons.storefront_outlined,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.vendors,
                    ),
                    ErpButton(
                      text: 'Vendor Settlements',
                      icon: Icons.payments_outlined,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.vendorPaymentsSection,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4 Key Metrics
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Total Purchases Placed',
              value: Formatters.formatCurrency(db.totalPurchaseAmount),
              subtitle: '${db.purchases.length} Purchase Orders',
              icon: Icons.shopping_bag_outlined,
              color: Colors.purple,
            ),
            _buildMetricCard(
              title: 'Pending PO Deliveries',
              value: '${pendingPurchases.length} Orders',
              subtitle: Formatters.formatCurrency(pendingPurchases.fold(0.0, (sum, p) => sum + p.totalAmount)),
              icon: Icons.local_shipping_outlined,
              color: Colors.orange,
            ),
            _buildMetricCard(
              title: 'Received & Verified',
              value: '${completedPurchases.length} Orders',
              subtitle: Formatters.formatCurrency(completedPurchases.fold(0.0, (sum, p) => sum + p.totalAmount)),
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            _buildMetricCard(
              title: 'Vendor Payables Due',
              value: Formatters.formatCurrency(db.pendingVendorPayments),
              subtitle: '${db.vendors.where((v) => v.outstandingBalance > 0).length} Vendors pending payment',
              icon: Icons.account_balance_outlined,
              color: Colors.red,
            ),
          ]),
          const SizedBox(height: 28),

          // Recent Purchase Orders Table
          Text('Recent Purchase Orders', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'PO Number'),
              ErpColumn(title: 'PO Date'),
              ErpColumn(title: 'Vendor Name'),
              ErpColumn(title: 'Project Tag'),
              ErpColumn(title: 'Items Count', isNumeric: true),
              ErpColumn(title: 'Total Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: db.purchases.take(7).map((p) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'purchase', ErpNavSection.purchaseList),
                  child: Text(p.purchaseNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                Text(Formatters.formatDate(p.purchaseDate), style: AppTextStyles.bodySmall),
                Text(p.vendorName, style: AppTextStyles.bodyMedium),
                Text(p.projectName ?? 'Warehouse Stock', style: AppTextStyles.bodySmall),
                Text('${p.items.length}', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(p.totalAmount), style: AppTextStyles.bodyBold),
                ErpStatusBadge.info(p.statusLabel),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// 3. PRODUCTION ROLE DASHBOARD
// =====================================================================
class ProductionRoleDashboard extends ConsumerWidget {
  const ProductionRoleDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    final pendingOrders = db.productionOrders.where((po) => po.status.name == 'planned' || po.status.name == 'inProgress').toList();
    final completedOrders = db.productionOrders.where((po) => po.status.name == 'completed').toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoleHeader(
            context: context,
            title: 'Factory & Production Dashboard',
            subtitle: 'Manufacturing work orders, shopfloor assembly batches, BOM consumption, and output yields',
            badgeText: 'PRODUCTION MANAGER',
            badgeColor: Colors.indigo,
          ),
          const SizedBox(height: 20),

          // Quick Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Production Actions:', style: AppTextStyles.bodyBold),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ErpButton(
                      text: 'Create Work Order',
                      icon: Icons.add_circle_outline,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createProduction,
                    ),
                    ErpButton(
                      text: 'Production Orders List',
                      icon: Icons.precision_manufacturing_outlined,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionOrders,
                    ),
                    ErpButton(
                      text: 'Raw Material Buffer',
                      icon: Icons.inventory_2_outlined,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.rawMaterialStock,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4 Key Metrics
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Total Work Orders',
              value: '${db.productionOrders.length}',
              subtitle: 'All-time production jobs',
              icon: Icons.precision_manufacturing_outlined,
              color: Colors.indigo,
            ),
            _buildMetricCard(
              title: 'Active / In-Progress',
              value: '${pendingOrders.length} Orders',
              subtitle: 'Currently on Shopfloor',
              icon: Icons.autorenew_rounded,
              color: Colors.amber.shade800,
            ),
            _buildMetricCard(
              title: 'Completed Batches',
              value: '${completedOrders.length} Finished',
              subtitle: 'Transferred to FG Warehouse',
              icon: Icons.task_alt_rounded,
              color: Colors.green,
            ),
            _buildMetricCard(
              title: 'Critical RM Buffers',
              value: '${db.lowStockRawMaterials.length} Alerts',
              subtitle: 'Materials needing re-order',
              icon: Icons.warning_rounded,
              color: db.lowStockRawMaterials.isNotEmpty ? Colors.red : Colors.green,
            ),
          ]),
          const SizedBox(height: 28),

          // Production Orders Table
          Text('Current & Recent Production Orders', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Work Order No'),
              ErpColumn(title: 'Start Date'),
              ErpColumn(title: 'Product to Produce'),
              ErpColumn(title: 'Target Qty', isNumeric: true),
              ErpColumn(title: 'Project Ref'),
              ErpColumn(title: 'Estimated Cost (₹)', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: db.productionOrders.take(7).map((po) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(po.id, 'production', ErpNavSection.productionOrders),
                  child: Text(po.productionNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                Text(Formatters.formatDate(po.productionDate), style: AppTextStyles.bodySmall),
                Text(po.finishedProductName, style: AppTextStyles.bodyBold),
                Text('${po.plannedQuantity} ${po.unit}', style: AppTextStyles.bodySmall),
                Text(po.projectName ?? 'General Stock', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(po.totalProductionCost), style: AppTextStyles.bodyBold),
                ErpStatusBadge.info(po.statusLabel),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// 4. ACCOUNTS / PAYMENT ROLE DASHBOARD
// =====================================================================
class AccountsPaymentRoleDashboard extends ConsumerWidget {
  const AccountsPaymentRoleDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    final recentPayments = db.payments.take(8).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoleHeader(
            context: context,
            title: 'Finance, Accounts & Payment Control',
            subtitle: 'Customer receivables, dealer ledgers, vendor disbursements, expense vouchers, and partner commissions',
            badgeText: 'ACCOUNTS & FINANCE',
            badgeColor: Colors.teal,
          ),
          const SizedBox(height: 20),

          // Quick Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Finance Actions:', style: AppTextStyles.bodyBold),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ErpButton(
                      text: 'Customer Collections',
                      icon: Icons.receipt_long_outlined,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.customerPayments,
                    ),
                    ErpButton(
                      text: 'Vendor Disbursements',
                      icon: Icons.payments_outlined,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.vendorPaymentsSection,
                    ),
                    ErpButton(
                      text: 'Commission Payouts',
                      icon: Icons.monetization_on_outlined,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.commissionPayments,
                    ),
                    ErpButton(
                      text: 'Expense Voucher Log',
                      icon: Icons.receipt_outlined,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.expenseList,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4 Key Financial Metrics
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Customer Receivables',
              value: Formatters.formatCurrency(db.pendingCustomerPayments),
              subtitle: '${db.customers.where((c) => c.outstandingAmount > 0).length} Clients pending dues',
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.teal,
            ),
            _buildMetricCard(
              title: 'Vendor Payables Due',
              value: Formatters.formatCurrency(db.pendingVendorPayments),
              subtitle: '${db.vendors.where((v) => v.outstandingBalance > 0).length} Suppliers awaiting payment',
              icon: Icons.payment_outlined,
              color: Colors.red,
            ),
            _buildMetricCard(
              title: 'Commission Payable',
              value: Formatters.formatCurrency(db.pendingCommissionAmount),
              subtitle: 'Approved & Pending Vouchers',
              icon: Icons.loyalty_outlined,
              color: Colors.purple,
            ),
            _buildMetricCard(
              title: 'Total Operating Expenses',
              value: Formatters.formatCurrency(db.totalExpenseAmount),
              subtitle: 'Fiscal Year Expenditures',
              icon: Icons.pie_chart_outline_rounded,
              color: Colors.blueGrey,
            ),
          ]),
          const SizedBox(height: 28),

          // Recent Payment Transactions Table
          Text('Recent Payment & Disbursement Transactions', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Voucher No'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Payment Type'),
              ErpColumn(title: 'Party Name'),
              ErpColumn(title: 'Reference / UTR'),
              ErpColumn(title: 'Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Mode'),
            ],
            rows: recentPayments.map((p) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'payment', ErpNavSection.customerPayments),
                  child: Text(p.paymentNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                Text(Formatters.formatDate(p.paymentDate), style: AppTextStyles.bodySmall),
                Text(p.typeLabel, style: AppTextStyles.bodyBold),
                Text(p.partyName, style: AppTextStyles.bodyMedium),
                Text(p.transactionReference ?? '-', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(p.amount), style: AppTextStyles.bodyBold.copyWith(color: Colors.green.shade800)),
                ErpStatusBadge.neutral(p.paymentMode.name.toUpperCase()),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// 5. PROJECT MANAGER ROLE DASHBOARD
// =====================================================================
class ProjectManagerRoleDashboard extends ConsumerWidget {
  const ProjectManagerRoleDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    final activeProjects = db.projects.where((p) => p.status.name == 'inProgress' || p.status.name == 'planning').toList();
    final completedProjects = db.projects.where((p) => p.status.name == 'completed').toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoleHeader(
            context: context,
            title: 'Architectural Projects Portfolio',
            subtitle: 'Commercial project milestones, site deliverables, client scopes, and material budget consumption',
            badgeText: 'PROJECT MANAGER',
            badgeColor: Colors.deepPurple,
          ),
          const SizedBox(height: 20),

          // Quick Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Project Actions:', style: AppTextStyles.bodyBold),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ErpButton(
                      text: 'Projects Directory',
                      icon: Icons.apartment_rounded,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.projectList,
                    ),
                    ErpButton(
                      text: 'Architect Partners',
                      icon: Icons.architecture_rounded,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.architects,
                    ),
                    ErpButton(
                      text: 'Client Masters',
                      icon: Icons.people_outline,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.customers,
                    ),
                    ErpButton(
                      text: 'Project Reports Hub',
                      icon: Icons.analytics_outlined,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.projectReports,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4 Key Metrics
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Total Projects',
              value: '${db.projects.length}',
              subtitle: Formatters.formatCurrency(db.projects.fold(0.0, (sum, p) => sum + p.totalSalesAmount)),
              icon: Icons.apartment_rounded,
              color: Colors.deepPurple,
            ),
            _buildMetricCard(
              title: 'Active On-Site Projects',
              value: '${activeProjects.length}',
              subtitle: 'Under Execution & Delivery',
              icon: Icons.construction_rounded,
              color: Colors.blue,
            ),
            _buildMetricCard(
              title: 'Completed Handover',
              value: '${completedProjects.length}',
              subtitle: 'Successfully Delivered',
              icon: Icons.verified_rounded,
              color: Colors.green,
            ),
            _buildMetricCard(
              title: 'Architect Partners',
              value: '${db.architects.length}',
              subtitle: 'Registered Specifiers',
              icon: Icons.architecture_rounded,
              color: Colors.purple,
            ),
          ]),
          const SizedBox(height: 28),

          // Projects Table
          Text('Active & Recent Architectural Projects', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Project Name'),
              ErpColumn(title: 'Client Name'),
              ErpColumn(title: 'Lead Architect'),
              ErpColumn(title: 'Valuation (₹)', isNumeric: true),
              ErpColumn(title: 'Billed (₹)', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: db.projects.take(7).map((prj) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(prj.id, 'project', ErpNavSection.projectList),
                  child: Text(prj.name, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                Text(prj.customerName ?? 'Direct Client', style: AppTextStyles.bodyMedium),
                Text(prj.architectName ?? '-', style: AppTextStyles.bodySmall.copyWith(color: Colors.purple)),
                Text(Formatters.formatCurrency(prj.totalSalesAmount), style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(prj.totalCommissionAmount), style: AppTextStyles.bodySmall),
                ErpStatusBadge.info(prj.statusLabel),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// 5.1. MASTERS ROLE DASHBOARD
// =====================================================================
class MastersRoleDashboard extends ConsumerWidget {
  const MastersRoleDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoleHeader(
            context: context,
            title: 'Master Data & Entity Registry',
            subtitle: 'Centralized repository of commercial counterparties, architectural specifiers, SKUs, and units',
            badgeText: 'MASTER DATA MANAGER',
            badgeColor: Colors.deepOrange,
          ),
          const SizedBox(height: 20),

          // 8 Entity Metric Cards (Responsive Grid)
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Customers Master',
              value: '${db.customers.length} Clients',
              subtitle: '${db.customers.where((c) => c.outstandingAmount > 0).length} with active balances',
              icon: Icons.people_outline,
              color: Colors.blue,
            ),
            _buildMetricCard(
              title: 'Vendors Master',
              value: '${db.vendors.length} Suppliers',
              subtitle: '${db.vendors.where((v) => v.outstandingBalance > 0).length} with active payables',
              icon: Icons.storefront_outlined,
              color: Colors.purple,
            ),
            _buildMetricCard(
              title: 'Dealers Master',
              value: '${db.dealers.length} Retailers',
              subtitle: 'Active distribution network',
              icon: Icons.store_mall_directory_outlined,
              color: Colors.teal,
            ),
            _buildMetricCard(
              title: 'Architect Partners',
              value: '${db.architects.length} Specifiers',
              subtitle: '${db.projects.length} linked projects',
              icon: Icons.architecture_rounded,
              color: Colors.deepPurple,
            ),
          ]),
          const SizedBox(height: 16),
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Raw Material Items',
              value: '${db.rawMaterials.length} Items',
              subtitle: '${db.lowStockRawMaterials.length} below buffer level',
              icon: Icons.view_in_ar_outlined,
              color: Colors.indigo,
            ),
            _buildMetricCard(
              title: 'Finished Product SKUs',
              value: '${db.finishedProducts.length} Products',
              subtitle: '${db.lowStockFinishedProducts.length} below buffer level',
              icon: Icons.inventory_2_outlined,
              color: Colors.green,
            ),
            _buildMetricCard(
              title: 'Item Categories',
              value: '${db.categories.length} Categories',
              subtitle: 'Product classifications',
              icon: Icons.category_outlined,
              color: Colors.amber.shade800,
            ),
            _buildMetricCard(
              title: 'Units of Measure',
              value: '${db.units.length} Units',
              subtitle: 'PCS, MTR, KG, BOX, ROL',
              icon: Icons.straighten_outlined,
              color: Colors.blueGrey,
            ),
          ]),
          const SizedBox(height: 28),

          // Master Direct Jump Tiles
          Text('Quick Master Record Navigation', style: AppTextStyles.h2),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 650
                      ? 2
                      : 1;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: crossAxisCount == 1 ? 3.5 : 2.2,
                children: [
                  _buildMasterShortcutCard(
                    title: 'Customer Directory',
                    subtitle: 'Manage client accounts & GSTIN',
                    icon: Icons.people_outline,
                    color: Colors.blue,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.customers,
                  ),
                  _buildMasterShortcutCard(
                    title: 'Vendor Directory',
                    subtitle: 'Manage suppliers & payment terms',
                    icon: Icons.storefront_outlined,
                    color: Colors.purple,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.vendors,
                  ),
                  _buildMasterShortcutCard(
                    title: 'Dealer Directory',
                    subtitle: 'Trade discount rates & territory',
                    icon: Icons.store_mall_directory_outlined,
                    color: Colors.teal,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.dealers,
                  ),
                  _buildMasterShortcutCard(
                    title: 'Architect Registry',
                    subtitle: 'Commission rates & client linkage',
                    icon: Icons.architecture_rounded,
                    color: Colors.deepPurple,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.architects,
                  ),
                  _buildMasterShortcutCard(
                    title: 'Raw Material Masters',
                    subtitle: 'Purchase prices & stock thresholds',
                    icon: Icons.view_in_ar_outlined,
                    color: Colors.indigo,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.rawMaterials,
                  ),
                  _buildMasterShortcutCard(
                    title: 'Finished Product Masters',
                    subtitle: 'Selling prices & BOM cost profiles',
                    icon: Icons.inventory_2_outlined,
                    color: Colors.green,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.finishedProducts,
                  ),
                  _buildMasterShortcutCard(
                    title: 'Categories & Units',
                    subtitle: 'Tax rates & measurement symbols',
                    icon: Icons.category_outlined,
                    color: Colors.amber.shade800,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.categoriesUnits,
                  ),
                  _buildMasterShortcutCard(
                    title: 'Project Portfolio',
                    subtitle: 'Site contracts & milestone scopes',
                    icon: Icons.apartment_rounded,
                    color: Colors.deepOrange,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.projectList,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // Architect & Partner Overview Table
          Text('Key Registered Architects & Commercial Specifiers', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Architect Name'),
              ErpColumn(title: 'Contact Phone'),
              ErpColumn(title: 'Email Address'),
              ErpColumn(title: 'Commission Rate', isNumeric: true),
              ErpColumn(title: 'Approved Commission', isNumeric: true),
              ErpColumn(title: 'Commission Earned', isNumeric: true),
            ],
            rows: db.architects.take(6).map((arc) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(arc.id, 'architect', ErpNavSection.architects),
                  child: Text(arc.name, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                Text(arc.mobile, style: AppTextStyles.bodySmall),
                Text(arc.email, style: AppTextStyles.bodySmall),
                Text('${arc.defaultCommissionRate.toStringAsFixed(1)}%', style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(arc.approvedCommission), style: AppTextStyles.bodyMedium),
                Text(Formatters.formatCurrency(arc.totalCommissionEarned), style: AppTextStyles.bodyBold.copyWith(color: Colors.purple)),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterShortcutCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdBorderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdBorderRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 6. REPORT VIEWER ROLE DASHBOARD (AUDITOR / ANALYST)
// =====================================================================
class ReportViewerRoleDashboard extends ConsumerWidget {
  const ReportViewerRoleDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoleHeader(
            context: context,
            title: 'Analytics & Reporting Hub (Read-Only)',
            subtitle: 'Comprehensive audit trails, financial ledgers, stock reconciliations, and cross-department analytics',
            badgeText: 'AUDITOR & REPORT ANALYST',
            badgeColor: Colors.amber.shade900,
          ),
          const SizedBox(height: 24),

          Text('Available ERP Analytical Reports', style: AppTextStyles.h2),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1100
                  ? 3
                  : constraints.maxWidth >= 650
                      ? 2
                      : 1;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: crossAxisCount == 1 ? 1.5 : (crossAxisCount == 2 ? 1.25 : 1.35),
                children: [
                  _buildReportHubCard(
                    title: 'Inventory & Stock Valuation',
                    description: 'Stock ledger, raw material buffer analysis, dead inventory, and reorder levels.',
                    icon: Icons.inventory_2_outlined,
                    color: Colors.blue,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.inventoryReports,
                  ),
                  _buildReportHubCard(
                    title: 'Sales & Revenue Analysis',
                    description: 'Tax invoice registry, sales by category, quotation conversion rate, and margins.',
                    icon: Icons.point_of_sale_outlined,
                    color: Colors.green,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesReports,
                  ),
                  _buildReportHubCard(
                    title: 'Procurement & Purchase Reports',
                    description: 'Vendor spending trends, purchase variance, delivery timelines, and item prices.',
                    icon: Icons.shopping_bag_outlined,
                    color: Colors.purple,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseReports,
                  ),
                  _buildReportHubCard(
                    title: 'Production & Shopfloor Yields',
                    description: 'BOM consumption accuracy, manufacturing output, work order cycle time, and costs.',
                    icon: Icons.precision_manufacturing_outlined,
                    color: Colors.indigo,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionReports,
                  ),
                  _buildReportHubCard(
                    title: 'Project Cost & Consumption',
                    description: 'Project-wise raw material usage, finished goods scheduled, and commercial profitability.',
                    icon: Icons.apartment_outlined,
                    color: Colors.deepPurple,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.projectReports,
                  ),
                  _buildReportHubCard(
                    title: 'Financial & Payment Audit',
                    description: 'Accounts receivable aging, vendor payable ledger, expense audit, and partner payouts.',
                    icon: Icons.account_balance_outlined,
                    color: Colors.teal,
                    onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.financialReports,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportHubCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgBorderRadius,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgBorderRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Text('Open Report', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, color: color, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 7. DATA ENTRY ROLE DASHBOARD
// =====================================================================
class DataEntryRoleDashboard extends ConsumerWidget {
  const DataEntryRoleDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoleHeader(
            context: context,
            title: 'Data Entry Workspace',
            subtitle: 'Direct data input shortcuts, draft creation queues, and recent document submissions',
            badgeText: 'DATA ENTRY OPERATOR',
            badgeColor: Colors.blueGrey,
          ),
          const SizedBox(height: 24),

          Text('Quick Record Creation Shortcuts', style: AppTextStyles.h2),
          const SizedBox(height: 16),

          _buildResponsiveMetricGrid(context, [
            _buildActionShortcutTile(
              title: 'Create Quotation',
              subtitle: 'New estimate for client',
              icon: Icons.description_outlined,
              color: Colors.orange,
              onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createQuotation,
            ),
            _buildActionShortcutTile(
              title: 'Create Direct Sale',
              subtitle: 'Tax Invoice & Dispatch',
              icon: Icons.receipt_long_outlined,
              color: Colors.green,
              onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSale,
            ),
            _buildActionShortcutTile(
              title: 'Create Purchase Order',
              subtitle: 'PO for Vendor supply',
              icon: Icons.add_shopping_cart,
              color: Colors.purple,
              onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase,
            ),
            _buildActionShortcutTile(
              title: 'Add New Customer',
              subtitle: 'Register buyer master',
              icon: Icons.person_add_alt_1,
              color: Colors.blue,
              onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.customers,
            ),
          ]),
          const SizedBox(height: 28),

          Text('Recently Created Sales Invoices', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Invoice No'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Customer Name'),
              ErpColumn(title: 'Total Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: db.salesInvoices.take(6).map((s) {
              return [
                Text(s.invoiceNumber, style: AppTextStyles.bodyBold),
                Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
                Text(s.partyName, style: AppTextStyles.bodyMedium),
                Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold),
                ErpStatusBadge.info(s.statusLabel),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionShortcutTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdBorderRadius,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdBorderRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// SHARED RESPONSIVE HELPER WIDGETS
// =====================================================================
Widget _buildRoleHeader({
  required BuildContext context,
  required String title,
  required String subtitle,
  required String badgeText,
  required Color badgeColor,
}) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.lgBorderRadius,
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: AppTextStyles.h1),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: AppTextStyles.subtitle),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildMetricCard({
  required String title,
  required String value,
  required String subtitle,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.lgBorderRadius,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.tableHeader.copyWith(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, size: 18, color: color),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(value, style: AppTextStyles.metricValue.copyWith(fontSize: 20, color: color)),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

Widget _buildResponsiveMetricGrid(BuildContext context, List<Widget> cards) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width >= 1100) {
        return Row(
          children: cards.asMap().entries.map((entry) {
            final idx = entry.key;
            final card = entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: idx == 0 ? 0 : 16),
                child: card,
              ),
            );
          }).toList(),
        );
      } else if (width >= 600) {
        final halfWidth = (width - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards.map((card) {
            return SizedBox(
              width: halfWidth,
              child: card,
            );
          }).toList(),
        );
      } else {
        return Column(
          children: cards.map((card) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card,
            );
          }).toList(),
        );
      }
    },
  );
}

Widget _buildResponsiveTwoPanes(
  BuildContext context, {
  required Widget left,
  required Widget right,
  int flexLeft = 1,
  int flexRight = 1,
}) {
  final isDesktop = MediaQuery.of(context).size.width >= 1024;
  if (isDesktop) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: flexLeft, child: left),
        const SizedBox(width: 20),
        Expanded(flex: flexRight, child: right),
      ],
    );
  } else {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        left,
        const SizedBox(height: 20),
        right,
      ],
    );
  }
}
