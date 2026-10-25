import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/figma_metric_card.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';
import '../widgets/sales_pdf_generator.dart';

class SalesDashboardScreen extends ConsumerStatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  ConsumerState<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends ConsumerState<SalesDashboardScreen> {
  DateTime? _invoiceStartDate;
  DateTime? _invoiceEndDate;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header & Quick Action Buttons (Figma Section Header Card)
          ErpSectionHeaderCard(
            icon: Icons.point_of_sale_rounded,
            title: 'Sales Operations Dashboard',
            badgeText: 'SALES PIPELINE',
            action: LayoutBuilder(
              builder: (context, actionBox) {
                final isMobile = actionBox.maxWidth < 600;
                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ErpButton(
                          text: 'New Quotation',
                          icon: Icons.request_quote_outlined,
                          onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createQuotation,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ErpButton(
                          text: 'Create Sales Order',
                          icon: Icons.shopping_cart_outlined,
                          isOutlined: true,
                          onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSalesOrder,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ErpButton(
                          text: 'Direct Sale',
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
                  alignment: WrapAlignment.end,
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
              },
            ),
          ),
          const SizedBox(height: 24),

          // 2. Sales Funnel Workflow Stage Indicator Bar
          _buildSalesWorkflowSection(context, ref, db),
          const SizedBox(height: 20),


          // 3. KPI Metric Cards (Project Theme)
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 850
                  ? (constraints.maxWidth - (3 * 12)) / 4
                  : (constraints.maxWidth > 550 ? (constraints.maxWidth - 12) / 2 : double.infinity);
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.point_of_sale_outlined,
                      iconColor: AppColors.primary,
                      title: 'Net Sales Revenue',
                      value: Formatters.formatCurrency(db.netSalesRevenue),
                      subtext: 'Gross: ${Formatters.formatCurrency(db.totalInvoicedRevenue)}',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.assignment_return_outlined,
                      iconColor: AppColors.danger,
                      title: 'Sales Returns & Rate',
                      value: Formatters.formatCurrency(db.totalSalesReturnsAmount),
                      subtext: '${db.salesReturnRatePercentage.toStringAsFixed(1)}% Return Rate (${db.salesReturns.length})',
                      subtextColor: AppColors.danger,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.local_shipping_outlined,
                      iconColor: AppColors.primary,
                      title: 'Ready for Dispatch',
                      value: '${db.ordersReadyForDispatchCount} Orders',
                      subtext: '${db.ordersPendingProductionCount} Orders in production',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.primary,
                      title: 'Pending Customer Due',
                      value: Formatters.formatCurrency(db.pendingCustomerPayments),
                      subtext: '${db.pendingRefundsCount} pending refund settlements',
                    ),
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

  Widget _buildSalesWorkflowSection(BuildContext context, WidgetRef ref, MockDatabaseService db) {
    final steps = [
      _SalesWorkflowStepData(
        stepNumber: '01',
        title: 'Quotations',
        count: '${db.pendingQuotationsCount} Pending',
        activeCount: '${db.quotations.length} Total',
        icon: Icons.request_quote_outlined,
        color: AppColors.primary,
        section: ErpNavSection.quotations,
      ),
      _SalesWorkflowStepData(
        stepNumber: '02',
        title: 'Proforma Invoices',
        count: '${db.proformaInvoices.length} Issued',
        activeCount: 'Advance Tracking',
        icon: Icons.receipt_outlined,
        color: AppColors.purple,
        section: ErpNavSection.proformaInvoices,
      ),
      _SalesWorkflowStepData(
        stepNumber: '03',
        title: 'Stock & Production',
        count: '${db.ordersPendingProductionCount} In Production',
        activeCount: '${db.ordersReadyForDispatchCount} Ready',
        icon: Icons.inventory_2_outlined,
        color: AppColors.warning,
        section: ErpNavSection.salesOrders,
      ),
      _SalesWorkflowStepData(
        stepNumber: '04',
        title: 'Delivery / Dispatch',
        count: '${db.deliveries.length} Dispatched',
        activeCount: 'Stock Out Movement',
        icon: Icons.local_shipping_outlined,
        color: AppColors.info,
        section: ErpNavSection.salesDeliveries,
      ),
      _SalesWorkflowStepData(
        stepNumber: '05',
        title: 'Sales Invoices',
        count: '${db.salesInvoices.length} Invoiced',
        activeCount: Formatters.formatCurrency(db.totalInvoicedRevenue),
        icon: Icons.receipt_long_outlined,
        color: AppColors.success,
        section: ErpNavSection.salesInvoiceList,
      ),
      _SalesWorkflowStepData(
        stepNumber: '06',
        title: 'Sales Returns',
        count: '${db.salesReturns.length} Returned',
        activeCount: 'Restock & Credit Note',
        icon: Icons.assignment_return_outlined,
        color: AppColors.danger,
        section: ErpNavSection.salesReturns,
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 500 ? 12 : 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorderRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              final titleGroup = Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.alt_route_rounded,
                          size: 17,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Sales Workflow Stages',
                          style: AppTextStyles.h3.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: const Text(
                      '6 Stages Active',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              );

              final subtitleText = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sync_alt_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Seamless End-to-End Enterprise Flow',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleGroup,
                    const SizedBox(height: 6),
                    subtitleText,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  titleGroup,
                  const SizedBox(width: 12),
                  subtitleText,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1050) {
                final rowChildren = <Widget>[];
                for (int i = 0; i < steps.length; i++) {
                  rowChildren.add(
                    Expanded(
                      child: _buildWorkflowCard(context, ref, steps[i]),
                    ),
                  );
                  if (i < steps.length - 1) {
                    rowChildren.add(_buildStepConnector());
                  }
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rowChildren,
                  ),
                );
              } else if (constraints.maxWidth >= 640) {
                final itemWidth = (constraints.maxWidth - 16) / 3;
                return Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: steps
                      .map((s) => SizedBox(
                            width: itemWidth,
                            child: _buildWorkflowCard(context, ref, s),
                          ))
                      .toList(),
                );
              } else {
                final isSingleColumn = constraints.maxWidth < 360;
                final itemWidth = isSingleColumn ? double.infinity : (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: steps
                      .map((s) => SizedBox(
                            width: itemWidth,
                            child: _buildWorkflowCard(context, ref, s),
                          ))
                      .toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowCard(
    BuildContext context,
    WidgetRef ref,
    _SalesWorkflowStepData step,
  ) {
    return _SalesWorkflowCardItem(
      step: step,
      onTap: () => ref.read(currentNavSectionProvider.notifier).state = step.section,
    );
  }



  Widget _buildStepConnector() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Icon(
            Icons.chevron_right_rounded,
            size: 14,
            color: Color(0xFF64748B),
          ),
        ),
      ),
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
                ErpColumn(title: 'SO Number', width: 130),
                ErpColumn(title: 'Customer', width: 150),
                ErpColumn(title: 'Total', width: 110, isNumeric: true),
                ErpColumn(title: 'Status', width: 110),
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
    final filteredInvoices = db.salesInvoices.where((inv) {
      if (_invoiceStartDate != null && inv.saleDate.isBefore(DateTime(_invoiceStartDate!.year, _invoiceStartDate!.month, _invoiceStartDate!.day))) return false;
      if (_invoiceEndDate != null && inv.saleDate.isAfter(DateTime(_invoiceEndDate!.year, _invoiceEndDate!.month, _invoiceEndDate!.day, 23, 59, 59))) return false;
      return true;
    }).toList();
    final recentInvoices = filteredInvoices.take(5).toList();

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Recent Sales Invoices',
                style: AppTextStyles.h3,
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ErpDateFilterBox(
                    startDate: _invoiceStartDate,
                    endDate: _invoiceEndDate,
                    onDateRangeSelected: (start, end) {
                      setState(() {
                        _invoiceStartDate = start;
                        _invoiceEndDate = end;
                      });
                    },
                  ),
                  TextButton(
                    onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList,
                    child: const Text('View All'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentInvoices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No sales invoices found for selected range.')),
            )
          else
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'Invoice No', width: 130),
                ErpColumn(title: 'Party', width: 150),
                ErpColumn(title: 'Amount', width: 110, isNumeric: true),
                ErpColumn(title: 'Action', width: 80, alignment: Alignment.center),
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

class _SalesWorkflowStepData {
  final String stepNumber;
  final String title;
  final String count;
  final String activeCount;
  final IconData icon;
  final Color color;
  final ErpNavSection section;

  const _SalesWorkflowStepData({
    required this.stepNumber,
    required this.title,
    required this.count,
    required this.activeCount,
    required this.icon,
    required this.color,
    required this.section,
  });
}

class _SalesWorkflowCardItem extends StatefulWidget {
  final _SalesWorkflowStepData step;
  final VoidCallback onTap;

  const _SalesWorkflowCardItem({
    required this.step,
    required this.onTap,
  });

  @override
  State<_SalesWorkflowCardItem> createState() => _SalesWorkflowCardItemState();
}

class _SalesWorkflowCardItemState extends State<_SalesWorkflowCardItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final color = step.color;

    return Tooltip(
      message: 'Navigate to ${step.title}',
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (hovering) {
            if (mounted && _isHovered != hovering) {
              setState(() => _isHovered = hovering);
            }
          },
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.transparent,
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered ? AppColors.primary : const Color(0xFFE5E7EB),
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
                  const BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 14,
                  right: 14,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: color.withValues(alpha: 0.20),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'STEP ${step.stepNumber}',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: color,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(step.icon, color: color, size: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        step.title,
                        style: AppTextStyles.bodyBold.copyWith(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        step.count,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        step.activeCount,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

