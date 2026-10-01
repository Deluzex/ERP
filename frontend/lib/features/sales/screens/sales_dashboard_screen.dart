import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';
import '../widgets/sales_pdf_generator.dart';

class SalesDashboardScreen extends ConsumerWidget {
  const SalesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header & Quick Action Buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 750;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sales Operations Dashboard', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text(
                    'Pipeline tracking: Quotations, Proformas, Orders, Dispatch & Revenue',
                    style: AppTextStyles.subtitle,
                  ),
                ],
              );

              final actionButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ErpButton(
                    text: 'New Quotation',
                    icon: Icons.request_quote_outlined,
                    onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createQuotation,
                  ),
                  ErpButton(
                    text: 'Create Sales Order',
                    icon: Icons.shopping_cart_outlined,
                    isOutlined: true,
                    onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSalesOrder,
                  ),
                  ErpButton(
                    text: 'Direct Sale',
                    icon: Icons.point_of_sale_outlined,
                    isOutlined: true,
                    onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSale,
                  ),
                ],
              );

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 16),
                    actionButtons,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // 2. Sales Funnel Workflow Stage Indicator Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 450;
                    final titleText = Text('Sales Workflow Stages', style: AppTextStyles.h3.copyWith(fontSize: 15));
                    final subtitleText = Text(
                      'Seamless End-to-End Enterprise Flow',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleText,
                          const SizedBox(height: 2),
                          subtitleText,
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        titleText,
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: subtitleText,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildWorkflowStep(
                        context,
                        ref,
                        icon: Icons.request_quote_outlined,
                        title: '1. Quotations',
                        count: '${db.pendingQuotationsCount} Pending',
                        activeCount: '${db.quotations.length} Total',
                        color: AppColors.primary,
                        section: ErpNavSection.quotations,
                      ),
                      _buildStepArrow(),
                      _buildWorkflowStep(
                        context,
                        ref,
                        icon: Icons.receipt_outlined,
                        title: '2. Proforma Invoices',
                        count: '${db.proformaInvoices.length} Issued',
                        activeCount: 'Advance Tracking',
                        color: AppColors.purple,
                        section: ErpNavSection.proformaInvoices,
                      ),
                      _buildStepArrow(),
                      _buildWorkflowStep(
                        context,
                        ref,
                        icon: Icons.inventory_2_outlined,
                        title: '3. Stock & Production',
                        count: '${db.ordersPendingProductionCount} In Production',
                        activeCount: '${db.ordersReadyForDispatchCount} Ready',
                        color: AppColors.warning,
                        section: ErpNavSection.salesOrders,
                      ),
                      _buildStepArrow(),
                      _buildWorkflowStep(
                        context,
                        ref,
                        icon: Icons.local_shipping_outlined,
                        title: '4. Delivery / Dispatch',
                        count: '${db.deliveries.length} Dispatched',
                        activeCount: 'Stock Out Movement',
                        color: AppColors.info,
                        section: ErpNavSection.salesDeliveries,
                      ),
                      _buildStepArrow(),
                      _buildWorkflowStep(
                        context,
                        ref,
                        icon: Icons.receipt_long_outlined,
                        title: '5. Sales Invoices',
                        count: '${db.salesInvoices.length} Invoiced',
                        activeCount: Formatters.formatCurrency(db.totalInvoicedRevenue),
                        color: AppColors.success,
                        section: ErpNavSection.salesInvoiceList,
                      ),
                      _buildStepArrow(),
                      _buildWorkflowStep(
                        context,
                        ref,
                        icon: Icons.assignment_return_outlined,
                        title: '6. Sales Returns',
                        count: '${db.salesReturns.length} Returned',
                        activeCount: 'Restock & Credit Note',
                        color: AppColors.danger,
                        section: ErpNavSection.salesReturns,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. KPI Stat Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1200
                  ? 4
                  : constraints.maxWidth >= 750
                      ? 2
                      : 1;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.1,
                children: [
                  StatCard(
                    title: 'Net Sales Revenue',
                    value: Formatters.formatCurrency(db.netSalesRevenue),
                    trendText: 'Gross: ${Formatters.formatCurrency(db.totalInvoicedRevenue)}',
                    icon: const Icon(Icons.point_of_sale_outlined, color: AppColors.primary, size: 20),
                  ),
                  StatCard(
                    title: 'Sales Returns & Rate',
                    value: Formatters.formatCurrency(db.totalSalesReturnsAmount),
                    trendText: '${db.salesReturnRatePercentage.toStringAsFixed(1)}% Return Rate (${db.salesReturns.length} Returns)',
                    icon: const Icon(Icons.assignment_return_outlined, color: AppColors.danger, size: 20),
                  ),
                  StatCard(
                    title: 'Ready for Dispatch',
                    value: '${db.ordersReadyForDispatchCount}',
                    trendText: '${db.ordersPendingProductionCount} Orders in production',
                    icon: const Icon(Icons.local_shipping_outlined, color: AppColors.info, size: 20),
                  ),
                  StatCard(
                    title: 'Pending Customer Due',
                    value: Formatters.formatCurrency(db.pendingCustomerPayments),
                    trendText: '${db.pendingRefundsCount} pending refund settlements',
                    icon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.warning, size: 20),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // 4. Detailed Split: Recent Sales Orders vs Invoices
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildRecentOrdersCard(context, ref, db)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildRecentInvoicesCard(context, ref, db)),
                  ],
                )
              : Column(
                  children: [
                    _buildRecentOrdersCard(context, ref, db),
                    const SizedBox(height: 20),
                    _buildRecentInvoicesCard(context, ref, db),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String count,
    required String activeCount,
    required Color color,
    required ErpNavSection section,
  }) {
    return InkWell(
      onTap: () => ref.read(currentNavSectionProvider.notifier).state = section,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(count, style: AppTextStyles.bodySmall.copyWith(color: color, fontWeight: FontWeight.bold)),
                Text(activeCount, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey.shade400),
    );
  }

  Widget _buildRecentOrdersCard(BuildContext context, WidgetRef ref, MockDatabaseService db) {
    final recentOrders = db.salesOrders.take(5).toList();

    return Container(
      padding: AppSpacing.cardPadding,
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
                  'Active Sales Orders',
                  style: AppTextStyles.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesOrders,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No active sales orders found.')),
            )
          else
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'SO Number'),
                ErpColumn(title: 'Customer'),
                ErpColumn(title: 'Total', isNumeric: true),
                ErpColumn(title: 'Status'),
              ],
              rows: recentOrders.map((so) {
                ErpStatusBadge badge;
                switch (so.salesOrderStatus) {
                  case SalesOrderStatus.readyForDispatch:
                    badge = ErpStatusBadge.success('READY');
                    break;
                  case SalesOrderStatus.productionPending:
                  case SalesOrderStatus.inProduction:
                    badge = ErpStatusBadge.warning('PRODUCTION');
                    break;
                  case SalesOrderStatus.partiallyDelivered:
                    badge = ErpStatusBadge.info('PARTIAL DELV');
                    break;
                  case SalesOrderStatus.delivered:
                  case SalesOrderStatus.completed:
                  case SalesOrderStatus.done:
                    badge = ErpStatusBadge.neutral('DELIVERED');
                    break;
                  default:
                    badge = ErpStatusBadge.neutral('CONFIRMED');
                }

                return [
                  Text(so.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 11.5)),
                  Text(so.partyName, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(Formatters.formatCurrency(so.totalAmount), style: AppTextStyles.bodyBold),
                  badge,
                ];
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentInvoicesCard(BuildContext context, WidgetRef ref, MockDatabaseService db) {
    final recentInvoices = db.salesInvoices.take(5).toList();

    return Container(
      padding: AppSpacing.cardPadding,
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
                  'Recent Sales Invoices',
                  style: AppTextStyles.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentInvoices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No sales invoices found.')),
            )
          else
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'Invoice No'),
                ErpColumn(title: 'Party'),
                ErpColumn(title: 'Amount', isNumeric: true),
                ErpColumn(title: 'Action'),
              ],
              rows: recentInvoices.map((inv) {
                return [
                  Text(inv.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 11.5)),
                  Text(inv.partyName, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(Formatters.formatCurrency(inv.totalAmount), style: AppTextStyles.bodyBold),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 18),
                    onPressed: () => SalesPdfGeneratorDialog.show(context, inv, db),
                    tooltip: 'Preview PDF',
                  ),
                ];
              }).toList(),
            ),
        ],
      ),
    );
  }
}
