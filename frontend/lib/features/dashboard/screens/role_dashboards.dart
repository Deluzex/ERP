import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/production_model.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../shared/providers/app_state_providers.dart';

// =====================================================================
// 1. INVENTORY ROLE DASHBOARD
// =====================================================================
class InventoryRoleDashboard extends ConsumerStatefulWidget {
  const InventoryRoleDashboard({super.key});

  @override
  ConsumerState<InventoryRoleDashboard> createState() => _InventoryRoleDashboardState();
}

class _InventoryRoleDashboardState extends ConsumerState<InventoryRoleDashboard> {
  DateTime? _movementsStartDate;
  DateTime? _movementsEndDate;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final lowStockRM = db.lowStockRawMaterials;
    final lowStockFP = db.lowStockFinishedProducts;
    final activeRawMaterials = db.rawMaterials.where((r) => !r.isDeleted).toList();
    final activeFinishedProducts = db.finishedProducts.where((p) => !p.isDeleted).toList();
    final recentMovements = db.stockMovements.take(6).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.inventory_2_rounded,
            title: 'Inventory & Warehouse Dashboard',
            badgeText: 'INVENTORY MANAGER',
            action: LayoutBuilder(
              builder: (context, actionBox) {
                final isMobileHeader = actionBox.maxWidth < 520;
                if (isMobileHeader) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ErpButton(
                          text: 'New Stock Adjustment',
                          icon: Icons.tune_rounded,
                          onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.stockAdjustments,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ErpButton(
                          text: 'Raw Material Stock',
                          icon: Icons.category_outlined,
                          isOutlined: true,
                          onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.rawMaterialStock,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ErpButton(
                          text: 'Finished Product Stock',
                          icon: Icons.inventory_2_outlined,
                          isOutlined: true,
                          onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.finishedProductStock,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ErpButton(
                          text: 'Stock Movement Ledger',
                          icon: Icons.swap_horiz_rounded,
                          isOutlined: true,
                          onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.stockMovement,
                        ),
                      ),
                    ],
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ErpButton(
                      text: 'New Stock Adjustment',
                      icon: Icons.tune_rounded,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.stockAdjustments,
                    ),
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
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // 4 Key Metrics
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Raw Material Valuation',
              value: Formatters.formatCurrency(db.rawMaterialStockValue),
              subtitle: '${activeRawMaterials.length} Unique items',
              icon: Icons.view_in_ar_rounded,
              color: Colors.blue,
            ),
            _buildMetricCard(
              title: 'Finished Goods Valuation',
              value: Formatters.formatCurrency(db.finishedProductStockValue),
              subtitle: '${activeFinishedProducts.length} Product SKUs',
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

          // Recent Stock Movements (Transaction History: Date filter only)
          Builder(
            builder: (context) {
              final filteredMovements = db.stockMovements.where((m) {
                if (_movementsStartDate != null &&
                    m.date.isBefore(DateTime(_movementsStartDate!.year, _movementsStartDate!.month, _movementsStartDate!.day))) {
                  return false;
                }
                if (_movementsEndDate != null &&
                    m.date.isAfter(DateTime(_movementsEndDate!.year, _movementsEndDate!.month, _movementsEndDate!.day, 23, 59, 59))) {
                  return false;
                }
                return true;
              }).toList();

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 650;
                          final headerText = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Recent Stock Movements (Ledger)', style: AppTextStyles.h3),
                              const SizedBox(height: 2),
                              Text(
                                'Real-time immutable stock ledger transactions',
                                style: AppTextStyles.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          );
                          final dateFilter = ErpDateFilterBox(
                            startDate: _movementsStartDate,
                            endDate: _movementsEndDate,
                            onDateRangeSelected: (start, end) {
                              setState(() {
                                _movementsStartDate = start;
                                _movementsEndDate = end;
                              });
                            },
                          );
                          final button = OutlinedButton(
                            onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.stockMovement,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border, width: 1),
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text('View Full Ledger', style: AppTextStyles.button.copyWith(fontSize: 12)),
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                headerText,
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    dateFilter,
                                    button,
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              headerText,
                              Row(
                                children: [
                                  dateFilter,
                                  const SizedBox(width: 8),
                                  button,
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    if (filteredMovements.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text('No movements recorded for the selected date range.', style: AppTextStyles.bodyMedium),
                        ),
                      )
                    else
                      ErpDataTable(
                        columns: const [
                          ErpColumn(title: 'Date & Time'),
                          ErpColumn(title: 'Item / SKU'),
                          ErpColumn(title: 'Movement Type'),
                          ErpColumn(title: 'Quantity Changed', isNumeric: true),
                          ErpColumn(title: 'Balance After', isNumeric: true),
                          ErpColumn(title: 'Reference / Source'),
                        ],
                        rows: filteredMovements.take(10).map((m) {
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
            },
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
          ErpSectionHeaderCard(
            icon: Icons.shopping_bag_outlined,
            title: 'Procurement & Purchase Hub',
            badgeText: 'PURCHASE MANAGER',
            actions: [
              ErpButton(
                text: 'Create Direct Purchase',
                icon: Icons.add_shopping_cart,
                onPressed: () {
                  ref.read(editingPurchaseProvider.notifier).state = null;
                  ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase;
                },
              ),
              ErpButton(
                text: 'Purchase Invoices',
                icon: Icons.list_alt_rounded,
                isOutlined: true,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseList,
              ),
              // ErpButton(
              //   text: 'Vendors Directory',
              //   icon: Icons.storefront_outlined,
              //   isOutlined: true,
              //   onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.vendors,
              // ),
              // ErpButton(
              //   text: 'Vendor Settlements',
              //   icon: Icons.payments_outlined,
              //   isOutlined: true,
              //   onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.vendorPaymentsSection,
              // ),
            ],
          ),
          const SizedBox(height: 24),

          // 4 Key Metrics
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Total Purchases Placed',
              value: Formatters.formatCurrency(db.totalPurchaseAmount),
              subtitle: '${db.purchases.length} Purchase Invoices',
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
              subtitle: '${db.vendors.where((v) => !v.isDeleted && v.outstandingBalance > 0).length} Vendors pending payment',
              icon: Icons.account_balance_outlined,
              color: Colors.red,
            ),
          ]),
          const SizedBox(height: 28),

          // Recent Purchase Orders Table
          Text('Recent Purchase Invoices', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Invoice Number'),
              ErpColumn(title: 'Invoice Date'),
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
                _buildPurchaseStatusBadge(p.status, p.statusLabel),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseStatusBadge(PurchaseStatus status, String label) {
    switch (status) {
      case PurchaseStatus.paid:
        return ErpStatusBadge.success(label);
      case PurchaseStatus.partialPaid:
        return ErpStatusBadge.warning(label);
      case PurchaseStatus.saved:
        return ErpStatusBadge.info(label);
      case PurchaseStatus.draft:
        return ErpStatusBadge.neutral(label);
      case PurchaseStatus.cancelled:
        return ErpStatusBadge.danger(label);
    }
  }
}

// =====================================================================
// 3. PRODUCTION ROLE DASHBOARD
// =====================================================================
class ProductionRoleDashboard extends ConsumerStatefulWidget {
  const ProductionRoleDashboard({super.key});

  @override
  ConsumerState<ProductionRoleDashboard> createState() => _ProductionRoleDashboardState();
}

class _ProductionRoleDashboardState extends ConsumerState<ProductionRoleDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = ref.read(databaseServiceProvider);
      db.loadProductionOrders(forceRefresh: true);
      db.loadRawMaterials(forceRefresh: true);
      db.loadFinishedProducts(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final activeOrders = db.productionOrders.where((po) => !po.isDeleted).toList();
    final pendingOrders = activeOrders.where((po) => po.status.name == 'planned' || po.status.name == 'inProgress').toList();
    final completedOrders = activeOrders.where((po) => po.status.name == 'completed').toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.precision_manufacturing_rounded,
            title: 'Factory & Production Dashboard',
            badgeText: 'PRODUCTION MANAGER',
            actions: [
              ErpButton(
                text: 'Create Production Order',
                icon: Icons.add_circle_outline,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createProduction,
              ),
              ErpButton(
                text: 'Production Orders',
                icon: Icons.precision_manufacturing_outlined,
                isOutlined: true,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionOrders,
              ),
              // ErpButton(
              //   text: 'Raw Material Buffer',
              //   icon: Icons.inventory_2_outlined,
              //   isOutlined: true,
              //   onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.rawMaterialStock,
              // ),
            ],
          ),
          const SizedBox(height: 24),

          // 4 Key Metrics
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Total Production Orders',
              value: '${activeOrders.length}',
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
              ErpColumn(title: 'Order No'),
              ErpColumn(title: 'Start Date'),
              ErpColumn(title: 'Product to Produce'),
              ErpColumn(title: 'Target Qty', isNumeric: true),
              ErpColumn(title: 'Project Ref'),
              ErpColumn(title: 'Estimated Cost (₹)', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: activeOrders.take(7).map((po) {
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
                _buildProductionStatusBadge(po.status, po.statusLabel),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductionStatusBadge(ProductionStatus status, String label) {
    switch (status) {
      case ProductionStatus.planned:
        return ErpStatusBadge.warning('WAITING APPROVAL');
      case ProductionStatus.inProgress:
        return ErpStatusBadge.info(label);
      case ProductionStatus.completed:
        return ErpStatusBadge.success(label);
      case ProductionStatus.cancelled:
        return ErpStatusBadge.danger(label);
    }
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

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.payments_rounded,
            title: 'Finance, Accounts & Payment Control',
            badgeText: 'ACCOUNTS & FINANCE',
            actions: [
              ErpButton(
                text: 'Customer Payments',
                icon: Icons.receipt_long_outlined,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.customerPayments,
              ),
              ErpButton(
                text: 'Vendor Payments',
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
          const SizedBox(height: 24),

          // 4 Key Financial Metrics
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Customer Receivables',
              value: Formatters.formatCurrency(db.pendingCustomerPayments),
              subtitle: '${db.customers.where((c) => !c.isDeleted && c.outstandingAmount > 0).length} Clients pending dues',
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.teal,
            ),
            _buildMetricCard(
              title: 'Vendor Payables Due',
              value: Formatters.formatCurrency(db.pendingVendorPayments),
              subtitle: '${db.vendors.where((v) => !v.isDeleted && v.outstandingBalance > 0).length} Suppliers awaiting payment',
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
          if (db.payments.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text('No payment transactions recorded yet.', style: AppTextStyles.bodyMedium),
            )
          else
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
              rows: db.payments.take(10).map((p) {
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
    final nonDeletedProjects = db.projects.where((p) => !p.isDeleted).toList();
    final activeProjects = nonDeletedProjects.where((p) => p.status.name == 'inProgress' || p.status.name == 'planning' || p.status.name == 'active').toList();
    final completedProjects = nonDeletedProjects.where((p) => p.status.name == 'completed').toList();
    final activeArchitects = db.architects.where((a) => !a.isDeleted).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.apartment_rounded,
            title: 'Architectural Projects Portfolio',
            badgeText: 'PROJECT MANAGER',
            actions: [
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
          const SizedBox(height: 24),

          // 4 Key Metrics
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Total Projects',
              value: '${nonDeletedProjects.length}',
              subtitle: Formatters.formatCurrency(nonDeletedProjects.fold(0.0, (sum, p) => sum + p.totalSalesAmount)),
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
              value: '${activeArchitects.length}',
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
            rows: nonDeletedProjects.take(7).map((prj) {
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
class MastersRoleDashboard extends ConsumerStatefulWidget {
  const MastersRoleDashboard({super.key});

  @override
  ConsumerState<MastersRoleDashboard> createState() => _MastersRoleDashboardState();
}

class _MastersRoleDashboardState extends ConsumerState<MastersRoleDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = ref.read(databaseServiceProvider);
      db.loadProjects();
      db.loadVendors();
      db.loadArchitects();
      db.loadCustomers();
      db.loadDealers();
      db.loadPurchases();
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);

    final activeCustomers = db.customers.where((c) => !c.isDeleted).toList();
    final activeVendors = db.vendors.where((v) => !v.isDeleted).toList();
    final activeDealers = db.dealers.where((d) => !d.isDeleted).toList();
    final activeArchitects = db.architects.where((a) => !a.isDeleted).toList();
    final activeProjects = db.projects.where((p) => !p.isDeleted).toList();
    final activeRawMaterials = db.rawMaterials.where((r) => !r.isDeleted).toList();
    final activeFinishedProducts = db.finishedProducts.where((p) => !p.isDeleted).toList();

    // Dynamically calculate projects linked to architects
    final linkedProjectsCount = activeProjects
        .where((p) => p.architectId != null && p.architectId!.isNotEmpty)
        .length;
    final displayProjectsCount = linkedProjectsCount > 0 ? linkedProjectsCount : activeProjects.length;

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.dataset_rounded,
            title: 'Master Data & Entity Registry',
            badgeText: 'MASTER DATA MANAGER',
          ),
          const SizedBox(height: 20),

          // 8 Entity Metric Cards (Responsive Grid)
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Customers Master',
              value: '${activeCustomers.length} Clients',
              subtitle: '${activeCustomers.where((c) => c.outstandingAmount > 0).length} with active balances',
              icon: Icons.people_outline,
              color: Colors.blue,
            ),
            _buildMetricCard(
              title: 'Vendors Master',
              value: '${activeVendors.length} Suppliers',
              subtitle: '${activeVendors.where((v) => v.outstandingBalance > 0).length} with active payables',
              icon: Icons.storefront_outlined,
              color: Colors.purple,
            ),
            _buildMetricCard(
              title: 'Dealers Master',
              value: '${activeDealers.length} Retailers',
              subtitle: 'Active distribution network',
              icon: Icons.store_mall_directory_outlined,
              color: Colors.teal,
            ),
            _buildMetricCard(
              title: 'Architect Partners',
              value: '${activeArchitects.length} Specifiers',
              subtitle: '$displayProjectsCount linked projects',
              icon: Icons.architecture_rounded,
              color: Colors.deepPurple,
            ),
          ]),
          const SizedBox(height: 16),
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Raw Material Items',
              value: '${activeRawMaterials.length} Items',
              subtitle: '${activeRawMaterials.where((rm) => rm.isLowStock).length} below buffer level',
              icon: Icons.view_in_ar_outlined,
              color: Colors.indigo,
            ),
            _buildMetricCard(
              title: 'Finished Product SKUs',
              value: '${activeFinishedProducts.length} Products',
              subtitle: '${activeFinishedProducts.where((fp) => fp.isLowStock).length} below buffer level',
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
                    title: 'Category Master',
                    subtitle: 'Item, expense & payment categories',
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
    return _ModernMasterShortcutCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }
}

class _ModernMasterShortcutCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModernMasterShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ModernMasterShortcutCard> createState() => _ModernMasterShortcutCardState();
}

class _ModernMasterShortcutCardState extends State<_ModernMasterShortcutCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (hovering) {
          if (mounted && _isHovered != hovering) {
            setState(() => _isHovered = hovering);
          }
        },
        borderRadius: AppRadius.mdBorderRadius,
        hoverColor: Colors.transparent,
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.mdBorderRadius,
            border: Border.all(
              color: _isHovered ? AppColors.primary : AppColors.border,
              width: 1.0,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.title, style: AppTextStyles.bodyBold.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(widget.subtitle, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: _isHovered ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ),
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
    final db = ref.watch(databaseServiceProvider);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.analytics_outlined,
            title: 'Executive Financial Reports & Audit Hub',
            badgeText: 'AUDITOR & REPORT ANALYST',
            actions: [
              ErpButton(
                text: 'All ERP Statements',
                icon: Icons.bar_chart_rounded,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.reportsDashboard,
              ),
              ErpButton(
                text: 'Inventory Reports',
                icon: Icons.inventory_2_outlined,
                isOutlined: true,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.inventoryReports,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 4 Executive Audit KPI Metrics
          _buildResponsiveMetricGrid(context, [
            _buildMetricCard(
              title: 'Total Stock Valuation',
              value: Formatters.formatCurrency(db.totalStockValue),
              subtitle: 'Raw Materials & Finished Goods',
              icon: Icons.inventory_2_outlined,
              color: Colors.blue,
            ),
            _buildMetricCard(
              title: 'Gross Invoiced Revenue',
              value: Formatters.formatCurrency(db.totalInvoicedRevenue),
              subtitle: '${db.sales.length} Invoices Generated',
              icon: Icons.point_of_sale_outlined,
              color: Colors.green,
            ),
            _buildMetricCard(
              title: 'Procurement Spending',
              value: Formatters.formatCurrency(db.purchases.fold(0.0, (s, p) => s + p.totalAmount)),
              subtitle: '${db.purchases.length} Purchase Orders',
              icon: Icons.shopping_bag_outlined,
              color: Colors.purple,
            ),
            _buildMetricCard(
              title: 'Total Business Assets',
              value: Formatters.formatCurrency(db.totalStockValue + db.pendingCustomerPayments),
              subtitle: 'Inventory + Receivables',
              icon: Icons.account_balance_outlined,
              color: Colors.teal,
            ),
          ]),
          const SizedBox(height: 28),

          Text('Available ERP Analytical Reports', style: AppTextStyles.h2),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1100
                  ? 3
                  : width >= 650
                      ? 2
                      : 1;

              final aspectRatio = width >= 1400
                  ? 2.35
                  : width >= 1100
                      ? 2.1
                      : width >= 650
                          ? 2.15
                          : 2.4;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: aspectRatio,
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
    return _ModernReportHubCard(
      title: title,
      description: description,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }
}

class _ModernReportHubCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModernReportHubCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ModernReportHubCard> createState() => _ModernReportHubCardState();
}

class _ModernReportHubCardState extends State<_ModernReportHubCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (hovering) {
          if (mounted && _isHovered != hovering) {
            setState(() => _isHovered = hovering);
          }
        },
        borderRadius: AppRadius.lgBorderRadius,
        hoverColor: Colors.transparent,
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorderRadius,
            border: Border.all(
              color: _isHovered ? AppColors.primary : AppColors.border,
              width: 1.0,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(widget.icon, color: widget.color, size: 22),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: _isHovered ? AppColors.primary : widget.color.withValues(alpha: 0.6),
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(widget.title, style: AppTextStyles.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                widget.description,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Text('Open Report', style: TextStyle(color: _isHovered ? AppColors.primary : widget.color, fontWeight: FontWeight.bold, fontSize: 12.5)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: _isHovered ? AppColors.primary : widget.color, size: 14),
                ],
              ),
            ],
          ),
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
          ErpSectionHeaderCard(
            icon: Icons.edit_note_rounded,
            title: 'Data Entry Workspace',
            badgeText: 'DATA ENTRY OPERATOR',
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
              onTap: () {
                ref.read(editingPurchaseProvider.notifier).state = null;
                ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase;
              },
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
    return _ModernActionShortcutTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }
}

class _ModernActionShortcutTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModernActionShortcutTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ModernActionShortcutTile> createState() => _ModernActionShortcutTileState();
}

class _ModernActionShortcutTileState extends State<_ModernActionShortcutTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (hovering) {
          if (mounted && _isHovered != hovering) {
            setState(() => _isHovered = hovering);
          }
        },
        borderRadius: AppRadius.mdBorderRadius,
        hoverColor: Colors.transparent,
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.mdBorderRadius,
            border: Border.all(
              color: _isHovered ? AppColors.primary : AppColors.border,
              width: 1.0,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(widget.subtitle, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: _isHovered ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// SHARED RESPONSIVE HELPER WIDGETS
// =====================================================================
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
