import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../shared/providers/app_state_providers.dart';

class ReportsHubScreen extends ConsumerStatefulWidget {
  final ErpNavSection? reportType;

  const ReportsHubScreen({super.key, this.reportType});

  @override
  ConsumerState<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends ConsumerState<ReportsHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    if (widget.reportType != null) {
      switch (widget.reportType!) {
        case ErpNavSection.inventoryReports:
          _tabController.index = 0;
          break;
        case ErpNavSection.purchaseReports:
          _tabController.index = 1;
          break;
        case ErpNavSection.productionReports:
          _tabController.index = 2;
          break;
        case ErpNavSection.salesReports:
          _tabController.index = 3;
          break;
        case ErpNavSection.commissionReports:
          _tabController.index = 4;
          break;
        case ErpNavSection.financialReports:
          _tabController.index = 5;
          break;
        default:
          _tabController.index = 0;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ERP Reports & Intelligence', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Cross-module reporting for stock valuation, sales performance, production costing, and financials', style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'Export PDF / Excel',
                icon: Icons.file_download_outlined,
                isOutlined: true,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report exported to PDF / CSV successfully!')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Inventory Reports'),
              Tab(text: 'Purchase Reports'),
              Tab(text: 'Production Reports'),
              Tab(text: 'Sales Reports'),
              Tab(text: 'Commission Reports'),
              Tab(text: 'Financial Reports'),
            ],
          ),
          const SizedBox(height: 24),

          // Summary Metrics Cards for Reporting
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Total Stock Valuation',
                  value: Formatters.formatCurrency(db.totalStockValue),
                  trendText: 'Raw materials + Finished goods',
                  isPositiveTrend: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'Total Sales Revenue',
                  value: Formatters.formatCurrency(db.totalSalesAmount),
                  trendText: '${db.sales.length} Invoices',
                  isPositiveTrend: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'Customer Receivables',
                  value: Formatters.formatCurrency(db.pendingCustomerPayments),
                  trendText: 'Pending Collections',
                  isPositiveTrend: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'Vendor Payables',
                  value: Formatters.formatCurrency(db.pendingVendorPayments),
                  trendText: 'Pending Disbursements',
                  isPositiveTrend: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tab Content
          SizedBox(
            height: 480,
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Inventory Report
                ErpDataTable(
                  columns: const [
                    ErpColumn(title: 'Item Type'),
                    ErpColumn(title: 'Code'),
                    ErpColumn(title: 'Item Name'),
                    ErpColumn(title: 'Current Stock', isNumeric: true),
                    ErpColumn(title: 'Unit Valuation', isNumeric: true),
                    ErpColumn(title: 'Total Value', isNumeric: true),
                  ],
                  rows: [
                    ...db.rawMaterials.map((rm) => [
                          Text('Raw Material', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                          Text(rm.itemCode, style: AppTextStyles.bodyBold),
                          Text(rm.name, style: AppTextStyles.bodyMedium),
                          Text('${rm.currentStock} ${rm.unit}', style: AppTextStyles.bodyMedium),
                          Text(Formatters.formatCurrency(rm.defaultPurchasePrice), style: AppTextStyles.bodySmall),
                          Text(Formatters.formatCurrency(rm.currentStock * rm.defaultPurchasePrice), style: AppTextStyles.bodyBold),
                        ]),
                    ...db.finishedProducts.map((fp) => [
                          Text('Finished Good', style: AppTextStyles.bodySmall.copyWith(color: AppColors.infoText)),
                          Text(fp.itemCode, style: AppTextStyles.bodyBold),
                          Text(fp.name, style: AppTextStyles.bodyMedium),
                          Text('${fp.currentStock} ${fp.unit}', style: AppTextStyles.bodyMedium),
                          Text(Formatters.formatCurrency(fp.costPrice), style: AppTextStyles.bodySmall),
                          Text(Formatters.formatCurrency(fp.currentStock * fp.costPrice), style: AppTextStyles.bodyBold),
                        ]),
                  ],
                ),

                // 2. Purchase Report
                ErpDataTable(
                  columns: const [
                    ErpColumn(title: 'Purchase Order'),
                    ErpColumn(title: 'Vendor'),
                    ErpColumn(title: 'Date'),
                    ErpColumn(title: 'Invoice No'),
                    ErpColumn(title: 'Total Amount', isNumeric: true),
                    ErpColumn(title: 'Status'),
                  ],
                  rows: db.purchases.map((p) {
                    return [
                      Text(p.purchaseNumber, style: AppTextStyles.bodyBold),
                      Text(p.vendorName, style: AppTextStyles.bodyMedium),
                      Text(Formatters.formatDate(p.purchaseDate), style: AppTextStyles.bodySmall),
                      Text(p.vendorInvoiceNumber, style: AppTextStyles.bodySmall),
                      Text(Formatters.formatCurrency(p.totalAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                      Text(p.statusLabel, style: AppTextStyles.bodySmall),
                    ];
                  }).toList(),
                ),

                // 3. Production Report
                ErpDataTable(
                  columns: const [
                    ErpColumn(title: 'Batch Order'),
                    ErpColumn(title: 'Product Produced'),
                    ErpColumn(title: 'Produced Qty', isNumeric: true),
                    ErpColumn(title: 'Raw Material Cost', isNumeric: true),
                    ErpColumn(title: 'Labor & Expenses', isNumeric: true),
                    ErpColumn(title: 'Total Cost', isNumeric: true),
                    ErpColumn(title: 'Unit Cost', isNumeric: true),
                  ],
                  rows: db.productionOrders.map((po) {
                    return [
                      Text(po.productionNumber, style: AppTextStyles.bodyBold),
                      Text(po.finishedProductName, style: AppTextStyles.bodyMedium),
                      Text('${po.actualQuantityProduced} ${po.unit}', style: AppTextStyles.bodyBold),
                      Text(Formatters.formatCurrency(po.rawMaterialCost), style: AppTextStyles.bodySmall),
                      Text(Formatters.formatCurrency(po.labourCost + po.otherExpenses), style: AppTextStyles.bodySmall),
                      Text(Formatters.formatCurrency(po.totalProductionCost), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                      Text(Formatters.formatCurrency(po.costPerUnit), style: AppTextStyles.bodySmall),
                    ];
                  }).toList(),
                ),

                // 4. Sales Report
                ErpDataTable(
                  columns: const [
                    ErpColumn(title: 'Invoice No'),
                    ErpColumn(title: 'Customer / Dealer'),
                    ErpColumn(title: 'Date'),
                    ErpColumn(title: 'Taxable Amount', isNumeric: true),
                    ErpColumn(title: 'GST Tax', isNumeric: true),
                    ErpColumn(title: 'Total Invoiced', isNumeric: true),
                  ],
                  rows: db.sales.map((s) {
                    return [
                      Text(s.invoiceNumber, style: AppTextStyles.bodyBold),
                      Text(s.partyName, style: AppTextStyles.bodyMedium),
                      Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
                      Text(Formatters.formatCurrency(s.subtotalAmount - s.discountAmount), style: AppTextStyles.bodySmall),
                      Text(Formatters.formatCurrency(s.gstAmount), style: AppTextStyles.bodySmall),
                      Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                    ];
                  }).toList(),
                ),

                // 5. Commission Report
                ErpDataTable(
                  columns: const [
                    ErpColumn(title: 'Architect'),
                    ErpColumn(title: 'Total Earned', isNumeric: true),
                    ErpColumn(title: 'Pending Review', isNumeric: true),
                    ErpColumn(title: 'Approved', isNumeric: true),
                    ErpColumn(title: 'Paid to Date', isNumeric: true),
                  ],
                  rows: db.architects.map((a) {
                    return [
                      Text(a.name, style: AppTextStyles.bodyBold),
                      Text(Formatters.formatCurrency(a.totalCommissionEarned), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
                      Text(Formatters.formatCurrency(a.pendingCommission), style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningText)),
                      Text(Formatters.formatCurrency(a.approvedCommission), style: AppTextStyles.bodySmall.copyWith(color: AppColors.infoText)),
                      Text(Formatters.formatCurrency(a.paidCommission), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                    ];
                  }).toList(),
                ),

                // 7. Financial Reports (Outstanding receivables & payables)
                ErpDataTable(
                  columns: const [
                    ErpColumn(title: 'Financial Ledger Statement'),
                    ErpColumn(title: 'Account Balance', isNumeric: true),
                  ],
                  rows: [
                    [
                      Text('Customer Accounts Receivable (Outstanding)', style: AppTextStyles.bodyBold),
                      Text(Formatters.formatCurrency(db.pendingCustomerPayments), style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
                    ],
                    [
                      Text('Vendor Accounts Payable (Outstanding)', style: AppTextStyles.bodyBold),
                      Text(Formatters.formatCurrency(db.pendingVendorPayments), style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
                    ],
                    [
                      Text('Architect Commission Payable', style: AppTextStyles.bodyBold),
                      Text(Formatters.formatCurrency(db.pendingCommissionAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
                    ],
                    [
                      Text('Total Stock Capital Value (Inventory Assets)', style: AppTextStyles.bodyBold),
                      Text(Formatters.formatCurrency(db.totalStockValue), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
