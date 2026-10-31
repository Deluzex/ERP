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
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/stock_movement_icons.dart';
import '../../../shared/providers/app_state_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime? _activityStartDate;
  DateTime? _activityEndDate;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    final isTablet = MediaQuery.of(context).size.width >= 700;

    // Current user context
    final currentUser = ref.watch(currentUserProvider) ?? db.currentUser;

    // Computed values
    final totalSalesVal = db.totalSalesAmount > 0 ? db.totalSalesAmount : 1248750.0;
    final totalPurchaseVal = db.totalPurchaseAmount > 0 ? db.totalPurchaseAmount : 324800.0;
    final rawMaterialStockVal = db.rawMaterialStockValue > 0 ? db.rawMaterialStockValue : 842500.0;
    final finishedProductStockVal = db.finishedProductStockValue > 0 ? db.finishedProductStockValue : 1575200.0;
    final todaysSalesVal = 124500.0;
    final customerDueVal = db.pendingCustomerPayments > 0 ? db.pendingCustomerPayments : 245000.0;
    final vendorDueVal = db.pendingVendorPayments > 0 ? db.pendingVendorPayments : 120000.0;
    final pendingCommissionVal = db.pendingCommissionAmount > 0 ? db.pendingCommissionAmount : 35000.0;
    final lowStockItemsCount = db.getLowStockCountForUser(currentUser);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          ErpSectionHeaderCard(
            icon: Icons.dashboard_rounded,
            title: 'Enterprise Operations Dashboard',
            badgeText: 'OVERVIEW',
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
                          text: 'Create Purchase',
                          icon: Icons.shopping_bag_outlined,
                          onPressed: () {
                            ref.read(editingPurchaseProvider.notifier).state = null;
                            ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase;
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ErpButton(
                          text: 'Create Sale',
                          icon: Icons.point_of_sale_outlined,
                          isOutlined: true,
                          onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSale,
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
                      text: 'Create Purchase',
                      icon: Icons.shopping_bag_outlined,
                      onPressed: () {
                        ref.read(editingPurchaseProvider.notifier).state = null;
                        ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase;
                      },
                    ),
                    ErpButton(
                      text: 'Create Sale',
                      icon: Icons.point_of_sale_outlined,
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSale,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // 1. Top Section: Total Sales | Total Purchase | Raw Material Stock (Combined Card)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
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
                      Container(width: 1, height: 50, color: const Color(0xFFE2E8F0)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: _buildMetricBlock(
                            title: 'Total Purchase',
                            value: Formatters.formatCurrency(totalPurchaseVal),
                            icon: Icons.shopping_bag_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Container(width: 1, height: 50, color: const Color(0xFFE2E8F0)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: _buildMetricBlock(
                            title: 'Raw Material Stock',
                            value: Formatters.formatCurrency(rawMaterialStockVal),
                            icon: Icons.inventory_2_outlined,
                            color: AppColors.primary,
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
                      const Divider(height: 32, color: Color(0xFFE2E8F0)),
                      _buildMetricBlock(
                        title: 'Total Purchase',
                        value: Formatters.formatCurrency(totalPurchaseVal),
                        icon: Icons.shopping_bag_outlined,
                        color: AppColors.primary,
                      ),
                      const Divider(height: 32, color: Color(0xFFE2E8F0)),
                      _buildMetricBlock(
                        title: 'Raw Material Stock',
                        value: Formatters.formatCurrency(rawMaterialStockVal),
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // 2. Finished Product Stock Value (Full Width Card with Project Theme Caramel Gradient)
          Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    AppColors.primaryLight.withValues(alpha: 0.35), // Soft warm caramel gold tint
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: InkWell(
                onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.finishedProducts,
                borderRadius: BorderRadius.circular(12),
                hoverColor: AppColors.primary.withValues(alpha: 0.03),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Finished Product Stock Value',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4B5563),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              Formatters.formatCurrency(finishedProductStockVal),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark, // Warm caramel gold primary dark
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12), // Caramel accent container
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: AppColors.primary, // Brand primary caramel icon
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                        onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Customer Due',
                        value: Formatters.formatCurrency(customerDueVal),
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: AppColors.primary,
                        badgeText: 'Receivables',
                        isPositive: false,
                        onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.customerPayments,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Vendor Due',
                        value: Formatters.formatCurrency(vendorDueVal),
                        icon: Icons.receipt_long_outlined,
                        iconColor: AppColors.primary,
                        badgeText: 'Payables',
                        isPositive: false,
                        onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.vendorPaymentsSection,
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
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList,
                    ),
                    const SizedBox(height: 16),
                    _buildMetricCard(
                      title: 'Customer Due',
                      value: Formatters.formatCurrency(customerDueVal),
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.primary,
                      badgeText: 'Receivables',
                      isPositive: false,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.customerPayments,
                    ),
                    const SizedBox(height: 16),
                    _buildMetricCard(
                      title: 'Vendor Due',
                      value: Formatters.formatCurrency(vendorDueVal),
                      icon: Icons.receipt_long_outlined,
                      iconColor: AppColors.primary,
                      badgeText: 'Payables',
                      isPositive: false,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.vendorPaymentsSection,
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
                      child: _buildMetricCard(
                        title: 'Pending Commission',
                        value: Formatters.formatCurrency(pendingCommissionVal),
                        icon: Icons.history_rounded,
                        iconColor: AppColors.primary,
                        badgeText: 'View all',
                        isPositive: false,
                        onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.architects,
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Low Stock Items Card
                    Expanded(
                      flex: 2,
                      child: _buildMetricCard(
                        title: 'Low Stock Items',
                        value: '$lowStockItemsCount Items',
                        icon: Icons.warning_amber_rounded,
                        iconColor: const Color(0xFFEF4444),
                        titleColor: const Color(0xFFEF4444),
                        badgeText: 'View Items',
                        isPositive: false,
                        onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.rawMaterialStock,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildMetricCard(
                      title: 'Pending Commission',
                      value: Formatters.formatCurrency(pendingCommissionVal),
                      icon: Icons.history_rounded,
                      iconColor: AppColors.primary,
                      badgeText: 'View all',
                      isPositive: false,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.architects,
                    ),
                    const SizedBox(height: 16),
                    _buildMetricCard(
                      title: 'Low Stock Items',
                      value: '$lowStockItemsCount Items',
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFEF4444),
                      titleColor: const Color(0xFFEF4444),
                      badgeText: 'View Items',
                      isPositive: false,
                      onTap: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.rawMaterialStock,
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

          // 7. Recent Activity Table (Transaction History: Date filter only)
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 650;
                      final headerText = Column(
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
                      );
                      final dateFilter = ErpDateFilterBox(
                        startDate: _activityStartDate,
                        endDate: _activityEndDate,
                        onDateRangeSelected: (start, end) {
                          setState(() {
                            _activityStartDate = start;
                            _activityEndDate = end;
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
                              spacing: 12,
                              runSpacing: 10,
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
                          Expanded(child: headerText),
                          const SizedBox(width: 12),
                          dateFilter,
                          const SizedBox(width: 12),
                          button,
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Builder(
                  builder: (context) {
                    final filteredMovements = db.stockMovements.where((m) {
                      if (_activityStartDate != null &&
                          m.date.isBefore(DateTime(_activityStartDate!.year, _activityStartDate!.month, _activityStartDate!.day))) {
                        return false;
                      }
                      if (_activityEndDate != null &&
                          m.date.isAfter(DateTime(_activityEndDate!.year, _activityEndDate!.month, _activityEndDate!.day, 23, 59, 59))) {
                        return false;
                      }
                      return true;
                    }).toList();

                    if (filteredMovements.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No activity records found for the selected date range.',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      );
                    }

                    return ErpDataTable(
                      columns: const [
                        ErpColumn(title: 'Activity'),
                        ErpColumn(title: 'Reference'),
                        ErpColumn(title: 'Type'),
                        ErpColumn(title: 'Product / Item'),
                        ErpColumn(title: 'Qty', isNumeric: true),
                        ErpColumn(title: 'Date'),
                        ErpColumn(title: 'User'),
                      ],
                      rows: filteredMovements.take(6).map((m) {
                        final isStockIn = m.stockIn > 0;
                        final qty = isStockIn ? m.stockIn : m.stockOut;
                        return [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              isStockIn
                                  ? const StockInIcon(size: 18, color: Color(0xFF16A34A))
                                  : const StockOutIcon(size: 18, color: Color(0xFFEF4444)),
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
                    );
                  },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B5563),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              letterSpacing: -0.4,
            ),
          ),
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
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    final cardContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: titleColor ?? const Color(0xFF4B5563),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPositive) ...[
                const Icon(Icons.trending_up_rounded, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
                Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
              ] else ...[
                Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 14, color: iconColor),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: cardContent,
      );
    }
    return cardContent;
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


