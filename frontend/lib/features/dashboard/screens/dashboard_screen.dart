import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/stock_movement_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_chart_card.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isTablet = MediaQuery.of(context).size.width >= 700;

    // Computed values
    final totalSalesVal = db.totalSalesAmount > 0 ? db.totalSalesAmount : 1248750.0;
    final totalPurchaseVal = db.totalPurchaseAmount > 0 ? db.totalPurchaseAmount : 324800.0;
    final rawMaterialStockVal = db.rawMaterialStockValue > 0 ? db.rawMaterialStockValue : 842500.0;
    final finishedProductStockVal = db.finishedProductStockValue > 0 ? db.finishedProductStockValue : 1575200.0;
    final todaysSalesVal = 124500.0;
    final customerDueVal = db.pendingCustomerPayments > 0 ? db.pendingCustomerPayments : 245000.0;
    final vendorDueVal = db.pendingVendorPayments > 0 ? db.pendingVendorPayments : 120000.0;
    final pendingCommissionVal = db.pendingCommissionAmount > 0 ? db.pendingCommissionAmount : 35000.0;
    final lowStockItemsCount = db.totalLowStockCount > 0 ? db.totalLowStockCount : 18;

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dashboard', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text(
                      'Enterprise operations, stock valuation & financial overview',
                      style: AppTextStyles.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                children: [
                  ErpButton(
                    text: 'Create Purchase',
                    icon: Icons.shopping_bag_outlined,
                    onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase,
                  ),
                  ErpButton(
                    text: 'Create Sale',
                    icon: Icons.point_of_sale_outlined,
                    isOutlined: true,
                    onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSale,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 1. Top Section: Total Sales | Total Purchase | Raw Material Stock (Combined Card)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgBorderRadius,
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isDesktop
                ? Row(
                    children: [
                      Expanded(
                        child: _buildMetricBlock(
                          title: 'Total Sales',
                          value: Formatters.formatCurrency(totalSalesVal),
                          icon: Icons.trending_up_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      Container(width: 1, height: 50, color: AppColors.border),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: _buildMetricBlock(
                            title: 'Total Purchase',
                            value: Formatters.formatCurrency(totalPurchaseVal),
                            icon: Icons.shopping_cart_outlined,
                            color: AppColors.iconBrown,
                          ),
                        ),
                      ),
                      Container(width: 1, height: 50, color: AppColors.border),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: _buildMetricBlock(
                            title: 'Raw Material Stock',
                            value: Formatters.formatCurrency(rawMaterialStockVal),
                            icon: Icons.category_outlined,
                            color: AppColors.purple,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildMetricBlock(
                        title: 'Total Sales',
                        value: Formatters.formatCurrency(totalSalesVal),
                        icon: Icons.trending_up_rounded,
                        color: AppColors.primary,
                      ),
                      const Divider(height: 32),
                      _buildMetricBlock(
                        title: 'Total Purchase',
                        value: Formatters.formatCurrency(totalPurchaseVal),
                        icon: Icons.shopping_cart_outlined,
                        color: AppColors.iconBrown,
                      ),
                      const Divider(height: 32),
                      _buildMetricBlock(
                        title: 'Raw Material Stock',
                        value: Formatters.formatCurrency(rawMaterialStockVal),
                        icon: Icons.category_outlined,
                        color: AppColors.purple,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // 2. Finished Product Stock Value (Full Width Card)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgBorderRadius,
              border: Border.all(color: AppColors.border, width: 1),
              gradient: LinearGradient(
                colors: [
                  AppColors.surface,
                  AppColors.primaryLight.withOpacity(0.3),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finished Product Stock Value',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Formatters.formatCurrency(finishedProductStockVal),
                      style: AppTextStyles.h1.copyWith(
                        fontSize: 32,
                        color: AppColors.primaryDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Grid: Today's Sales | Customer Due | Vendor Due
          isDesktop
              ? Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: "Today's Sales",
                        value: Formatters.formatCurrency(todaysSalesVal),
                        icon: Icons.today_outlined,
                        iconColor: AppColors.primary,
                        badgeText: '+14% vs yesterday',
                        isPositive: true,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Customer Due',
                        value: Formatters.formatCurrency(customerDueVal),
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: AppColors.warningText,
                        badgeText: 'Receivables',
                        isPositive: false,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Vendor Due',
                        value: Formatters.formatCurrency(vendorDueVal),
                        icon: Icons.receipt_long_outlined,
                        iconColor: AppColors.dangerText,
                        badgeText: 'Payables',
                        isPositive: false,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildMetricCard(
                      title: "Today's Sales",
                      value: Formatters.formatCurrency(todaysSalesVal),
                      icon: Icons.today_outlined,
                      iconColor: AppColors.primary,
                      badgeText: '+14% vs yesterday',
                      isPositive: true,
                    ),
                    const SizedBox(height: 16),
                    _buildMetricCard(
                      title: 'Customer Due',
                      value: Formatters.formatCurrency(customerDueVal),
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.warningText,
                      badgeText: 'Receivables',
                      isPositive: false,
                    ),
                    const SizedBox(height: 16),
                    _buildMetricCard(
                      title: 'Vendor Due',
                      value: Formatters.formatCurrency(vendorDueVal),
                      icon: Icons.receipt_long_outlined,
                      iconColor: AppColors.dangerText,
                      badgeText: 'Payables',
                      isPositive: false,
                    ),
                  ],
                ),
          const SizedBox(height: 20),

          // 4. Pending Commission | Low Stock Items
          isDesktop
              ? Row(
                  children: [
                    // Pending Commission Card
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: AppSpacing.cardPadding,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.lgBorderRadius,
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Pending\nCommission', style: AppTextStyles.subtitle.copyWith(fontSize: 14, height: 1.2)),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.purple.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.architecture_rounded, color: AppColors.purple, size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              Formatters.formatCurrency(pendingCommissionVal),
                              style: AppTextStyles.h2.copyWith(fontSize: 26, color: AppColors.purple),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Low Stock Items Banner
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2), // Light Red Alert
                          borderRadius: AppRadius.lgBorderRadius,
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Low Stock Items', style: AppTextStyles.subtitle.copyWith(color: AppColors.dangerText, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('$lowStockItemsCount Items', style: AppTextStyles.h2.copyWith(fontSize: 24, color: AppColors.dangerText)),
                                  ],
                                ),
                              ],
                            ),
                            ErpButton(
                              text: 'View Items →',
                              isDanger: true,
                              onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.rawMaterialStock,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: AppSpacing.cardPadding,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.lgBorderRadius,
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pending Commission', style: AppTextStyles.subtitle),
                          const SizedBox(height: 6),
                          Text(Formatters.formatCurrency(pendingCommissionVal), style: AppTextStyles.h2.copyWith(color: AppColors.purple)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: AppRadius.lgBorderRadius,
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Low Stock Items', style: AppTextStyles.subtitle.copyWith(color: AppColors.dangerText)),
                              Text('$lowStockItemsCount Items', style: AppTextStyles.h2.copyWith(color: AppColors.dangerText)),
                            ],
                          ),
                          ErpButton(
                            text: 'View Items →',
                            isDanger: true,
                            onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.rawMaterialStock,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 32),

          // 5. Chart 1: Stock Overview [ Line Chart ]
          const ErpLineChartCard(
            title: 'Stock Overview',
            subtitle: 'Overall inventory valuation trajectory over the past 6 months',
            spots: [
              FlSpot(0, 14.2),
              FlSpot(1, 15.8),
              FlSpot(2, 18.4),
              FlSpot(3, 17.6),
              FlSpot(4, 21.2),
              FlSpot(5, 24.1),
            ],
            xLabels: ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'],
          ),
          const SizedBox(height: 24),

          // 6. Chart 2 & Chart 3: Stock In vs Stock Out [ Bar Chart ] & Stock by Warehouse [ Donut Chart ]
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stock In vs Stock Out [ Bar Chart ]
                    const Expanded(
                      flex: 5,
                      child: ErpDualBarChartCard(
                        title: 'Stock In vs Stock Out',
                        subtitle: 'Monthly volume comparison of inward procurement vs outward dispatch',
                        labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
                        stockInValues: [24, 32, 18, 42, 28, 15],
                        stockOutValues: [16, 22, 14, 30, 20, 10],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Stock by Warehouse [ Donut Chart ]
                    Expanded(
                      flex: 5,
                      child: ErpDonutChartCard(
                        title: 'Stock by Warehouse',
                        subtitle: 'Asset distribution across facility holding areas',
                        sections: [
                          PieChartSectionData(
                            value: 45,
                            title: '45%',
                            color: AppColors.primary,
                            radius: 36,
                            titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          PieChartSectionData(
                            value: 30,
                            title: '30%',
                            color: AppColors.purple,
                            radius: 36,
                            titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          PieChartSectionData(
                            value: 15,
                            title: '15%',
                            color: AppColors.infoText,
                            radius: 36,
                            titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          PieChartSectionData(
                            value: 10,
                            title: '10%',
                            color: AppColors.warningText,
                            radius: 36,
                            titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                        legends: [
                          {'name': 'Main Central Warehouse', 'percent': '45%', 'value': '₹10.8L', 'color': AppColors.primary},
                          {'name': 'Finished Goods Showroom', 'percent': '30%', 'value': '₹7.2L', 'color': AppColors.purple},
                          {'name': 'Raw Assembly Floor', 'percent': '15%', 'value': '₹3.6L', 'color': AppColors.infoText},
                          {'name': 'Transit / Staging Yard', 'percent': '10%', 'value': '₹2.4L', 'color': AppColors.warningText},
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    const ErpDualBarChartCard(
                      title: 'Stock In vs Stock Out',
                      subtitle: 'Monthly volume comparison of inward vs outward stock',
                      labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
                      stockInValues: [24, 32, 18, 42, 28, 15],
                      stockOutValues: [16, 22, 14, 30, 20, 10],
                    ),
                    const SizedBox(height: 20),
                    ErpDonutChartCard(
                      title: 'Stock by Warehouse',
                      subtitle: 'Asset distribution across facility holding areas',
                      sections: [
                        PieChartSectionData(value: 45, title: '45%', color: AppColors.primary, radius: 32),
                        PieChartSectionData(value: 30, title: '30%', color: AppColors.purple, radius: 32),
                        PieChartSectionData(value: 15, title: '15%', color: AppColors.infoText, radius: 32),
                        PieChartSectionData(value: 10, title: '10%', color: AppColors.warningText, radius: 32),
                      ],
                      legends: [
                        {'name': 'Main Central Warehouse', 'percent': '45%', 'value': '₹10.8L', 'color': AppColors.primary},
                        {'name': 'Finished Goods Showroom', 'percent': '30%', 'value': '₹7.2L', 'color': AppColors.purple},
                        {'name': 'Raw Assembly Floor', 'percent': '15%', 'value': '₹3.6L', 'color': AppColors.infoText},
                        {'name': 'Transit / Staging Yard', 'percent': '10%', 'value': '₹2.4L', 'color': AppColors.warningText},
                      ],
                    ),
                  ],
                ),
          const SizedBox(height: 32),

          // 7. Recent Activity Table
          Container(
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Recent Activity', style: AppTextStyles.h3),
                            const SizedBox(height: 2),
                            Text(
                              'Real-time immutable stock ledger transactions',
                              style: AppTextStyles.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.stockMovement,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border, width: 1),
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text('View Full Ledger', style: AppTextStyles.button.copyWith(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ErpDataTable(
                  columns: const [
                    ErpColumn(title: 'Activity'),
                    ErpColumn(title: 'Reference'),
                    ErpColumn(title: 'Type'),
                    ErpColumn(title: 'Product / Item'),
                    ErpColumn(title: 'Qty', isNumeric: true),
                    ErpColumn(title: 'Date'),
                    ErpColumn(title: 'User'),
                  ],
                  rows: db.stockMovements.take(6).map((m) {
                    final isStockIn = m.stockIn > 0;
                    final qty = isStockIn ? m.stockIn : m.stockOut;
                    return [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isStockIn ? AppColors.successLight : AppColors.dangerLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isStockIn ? Icons.south_west_rounded : Icons.north_east_rounded,
                              size: 13,
                              color: isStockIn ? AppColors.success : AppColors.danger,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(m.transactionTypeLabel, style: AppTextStyles.bodyBold),
                        ],
                      ),
                      Text(m.referenceNumber, style: AppTextStyles.bodySmall.copyWith(fontFamily: 'monospace')),
                      _buildTypeBadge(m.transactionType),
                      Text(m.itemName, style: AppTextStyles.bodyMedium),
                      Text(
                        '${isStockIn ? '+' : '-'}${Formatters.formatNumber(qty)} ${m.unit}',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: isStockIn ? AppColors.successText : AppColors.dangerText,
                        ),
                      ),
                      Text(Formatters.formatDateTime(m.date), style: AppTextStyles.bodySmall),
                      Text(m.performedBy, style: AppTextStyles.bodySmall),
                    ];
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 8. Quick Actions [ Create Purchase ] [ Create Product ] [ Create Sale ]
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgBorderRadius,
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Actions', style: AppTextStyles.h3),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _buildActionButton(
                      label: 'Create Purchase',
                      icon: Icons.shopping_bag_outlined,
                      color: AppColors.primary,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase,
                    ),
                    _buildActionButton(
                      label: 'Create Product',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.purple,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.finishedProducts,
                    ),
                    _buildActionButton(
                      label: 'Create Sale',
                      icon: Icons.point_of_sale_outlined,
                      color: AppColors.infoText,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSale,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMetricBlock({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.subtitle.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.h2.copyWith(fontSize: 22, letterSpacing: -0.3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required bool isPositive,
  }) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorderRadius,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.subtitle.copyWith(fontSize: 13)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: AppTextStyles.h2.copyWith(fontSize: 22)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isPositive ? AppColors.successLight : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isPositive ? AppColors.successText : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.button.copyWith(
                color: color,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(StockMovementType type) {
    switch (type) {
      case StockMovementType.purchase:
        return ErpStatusBadge.success('PURCHASE');
      case StockMovementType.productionConsumption:
        return ErpStatusBadge.warning('CONSUMED');
      case StockMovementType.productionOutput:
        return ErpStatusBadge.info('PRODUCED');
      case StockMovementType.sale:
        return ErpStatusBadge.danger('SALE');
      case StockMovementType.saleReturn:
        return ErpStatusBadge.info('RETURN');
      case StockMovementType.purchaseReturn:
        return ErpStatusBadge.danger('RETURN');
      case StockMovementType.adjustment:
        return ErpStatusBadge.neutral('ADJUST');
      case StockMovementType.damage:
        return ErpStatusBadge.danger('DAMAGE');
    }
  }
}
