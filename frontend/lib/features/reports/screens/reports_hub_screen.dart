import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_radius.dart';
import '../../../core/models/project_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/models/production_model.dart';
import '../../../core/models/expense_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/report_pdf_generator.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';

class ReportsHubScreen extends ConsumerStatefulWidget {
  final ErpNavSection? reportType;

  const ReportsHubScreen({super.key, this.reportType});

  @override
  ConsumerState<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends ConsumerState<ReportsHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<String> _tabLabels = [
    'Inventory Reports',
    'Purchase Reports',
    'Production Reports',
    'Sales & GST Reports',
    'Project Costing',
    'Expense Reports',
    'Commission Reports',
    'Financial Balance',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    if (widget.reportType != null) {
      _tabController.index = _getIndexForSection(widget.reportType!);
    }
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    setState(() {});
    if (!_tabController.indexIsChanging) {
      final targetSection = _getSectionForIndex(_tabController.index);
      if (targetSection != null && ref.read(currentNavSectionProvider) != targetSection) {
        ref.read(currentNavSectionProvider.notifier).state = targetSection;
      }
    }
  }

  int _getIndexForSection(ErpNavSection section) {
    switch (section) {
      case ErpNavSection.inventoryReports:
        return 0;
      case ErpNavSection.purchaseReports:
        return 1;
      case ErpNavSection.productionReports:
        return 2;
      case ErpNavSection.salesReports:
        return 3;
      case ErpNavSection.projectReports:
        return 4;
      case ErpNavSection.commissionReports:
        return 6;
      case ErpNavSection.financialReports:
        return 7;
      default:
        return 0;
    }
  }

  ErpNavSection? _getSectionForIndex(int index) {
    switch (index) {
      case 0:
        return ErpNavSection.inventoryReports;
      case 1:
        return ErpNavSection.purchaseReports;
      case 2:
        return ErpNavSection.productionReports;
      case 3:
        return ErpNavSection.salesReports;
      case 4:
        return ErpNavSection.projectReports;
      case 5:
        return null; // Internal Expense Ledger report statement
      case 6:
        return ErpNavSection.commissionReports;
      case 7:
        return ErpNavSection.financialReports;
      default:
        return null;
    }
  }

  @override
  void didUpdateWidget(ReportsHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reportType != null && widget.reportType != oldWidget.reportType) {
      final target = _getIndexForSection(widget.reportType!);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  String _getReportTitle(int index) {
    switch (index) {
      case 0:
        return 'Inventory Stock Flow, Source & Valuation Audit Statement';
      case 1:
        return 'Raw Materials & Finished Product Purchases Register';
      case 2:
        return 'Finished Goods Production Costing & Manufacturing Summary';
      case 3:
        return 'Sales Revenue, Taxable Turnover & GST (CGST/SGST/IGST) Register';
      case 4:
        return 'Project Commercial Execution, Purchases, Expenses & Margin Report';
      case 5:
        return 'Operating Expenses & Project Overhead Ledger Statement';
      case 6:
        return 'Architect Referrals & Commission Payout Ledger';
      case 7:
        return 'ERP Financial Balance Sheet & Working Capital Statement';
      default:
        return 'ERP Business Intelligence Statement';
    }
  }

  List<ErpColumn> _getReportColumns(int index) {
    switch (index) {
      case 0: // Inventory
        return const [
          ErpColumn(title: 'Item Name & SKU'),
          ErpColumn(title: 'Type / Category'),
          ErpColumn(title: 'Stock Source'),
          ErpColumn(title: 'Opening Stock', isNumeric: true),
          ErpColumn(title: 'Current Stock', isNumeric: true),
          ErpColumn(title: 'Unit Cost', isNumeric: true),
          ErpColumn(title: 'Total Valuation', isNumeric: true),
        ];
      case 1: // Purchase
        return const [
          ErpColumn(title: 'PO Number'),
          ErpColumn(title: 'Vendor Name'),
          ErpColumn(title: 'Item Type'),
          ErpColumn(title: 'Order Date'),
          ErpColumn(title: 'Tax Mode'),
          ErpColumn(title: 'Total Amount', isNumeric: true),
          ErpColumn(title: 'Pending Due', isNumeric: true),
          ErpColumn(title: 'Status'),
        ];
      case 2: // Production
        return const [
          ErpColumn(title: 'Batch Ref'),
          ErpColumn(title: 'Finished Product'),
          ErpColumn(title: 'Produced Qty', isNumeric: true),
          ErpColumn(title: 'Raw Material Cost', isNumeric: true),
          ErpColumn(title: 'Labour & Overheads', isNumeric: true),
          ErpColumn(title: 'Total Cost', isNumeric: true),
          ErpColumn(title: 'Unit Cost', isNumeric: true),
          ErpColumn(title: 'Status'),
        ];
      case 3: // Sales & GST
        return const [
          ErpColumn(title: 'Invoice / Doc No'),
          ErpColumn(title: 'Customer / Party'),
          ErpColumn(title: 'Date'),
          ErpColumn(title: 'Taxable Amount', isNumeric: true),
          ErpColumn(title: 'CGST (9%)', isNumeric: true),
          ErpColumn(title: 'SGST (9%)', isNumeric: true),
          ErpColumn(title: 'IGST (18%)', isNumeric: true),
          ErpColumn(title: 'Grand Total', isNumeric: true),
        ];
      case 4: // Project Costing
        return const [
          ErpColumn(title: 'Project Name'),
          ErpColumn(title: 'Client / Architect'),
          ErpColumn(title: 'Invoiced Revenue', isNumeric: true),
          ErpColumn(title: 'Direct Purchases', isNumeric: true),
          ErpColumn(title: 'Expenses / Site', isNumeric: true),
          ErpColumn(title: 'Estimated Margin', isNumeric: true),
          ErpColumn(title: 'Status'),
        ];
      case 5: // Expenses
        return const [
          ErpColumn(title: 'Expense No'),
          ErpColumn(title: 'Category'),
          ErpColumn(title: 'Description'),
          ErpColumn(title: 'Project Linked'),
          ErpColumn(title: 'Date'),
          ErpColumn(title: 'Payment Mode'),
          ErpColumn(title: 'Amount (₹)', isNumeric: true),
        ];
      case 6: // Commission
        return const [
          ErpColumn(title: 'Architect / Partner'),
          ErpColumn(title: 'Firm / Contact'),
          ErpColumn(title: 'Commission Rate'),
          ErpColumn(title: 'Total Earned', isNumeric: true),
          ErpColumn(title: 'Pending Due', isNumeric: true),
          ErpColumn(title: 'Approved', isNumeric: true),
          ErpColumn(title: 'Paid to Date', isNumeric: true),
        ];
      case 7: // Financial
      default:
        return const [
          ErpColumn(title: 'Ledger Account / Balance Sheet Head'),
          ErpColumn(title: 'Classification'),
          ErpColumn(title: 'Receivable / Asset', isNumeric: true),
          ErpColumn(title: 'Payable / Liability', isNumeric: true),
          ErpColumn(title: 'Net Position', isNumeric: true),
        ];
    }
  }

  List<List<Widget>> _getReportRows(MockDatabaseService db, int index) {
    switch (index) {
      case 0: // Inventory Flow & Source
        final List<List<Widget>> rows = [];

        for (final rm in db.rawMaterials) {
          rows.add([
            Text('${rm.name} (${rm.itemCode})', style: AppTextStyles.bodyBold),
            Text('${rm.categoryName} [RAW]', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
            const Text('Purchased RM', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
            Text('${rm.openingStock} ${rm.unit}', style: AppTextStyles.bodySmall),
            Text('${rm.currentStock} ${rm.unit}', style: AppTextStyles.bodyBold.copyWith(color: rm.isLowStock ? AppColors.dangerText : AppColors.textPrimary)),
            Text(Formatters.formatCurrency(rm.defaultPurchasePrice), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(rm.totalValuation), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
          ]);
        }

        for (final fp in db.finishedProducts) {
          final isPurchased = (fp.purchasedStock ?? 0) > (fp.producedStock ?? 0);
          rows.add([
            Text('${fp.name} (${fp.itemCode})', style: AppTextStyles.bodyBold),
            Text('${fp.categoryName} [FG]', style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isPurchased ? Colors.teal.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isPurchased ? 'Purchased Goods' : 'In-house Produced',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isPurchased ? Colors.teal : Colors.blue),
              ),
            ),
            Text('${fp.openingStock} ${fp.unit}', style: AppTextStyles.bodySmall),
            Text('${fp.currentStock} ${fp.unit}', style: AppTextStyles.bodyBold.copyWith(color: fp.isLowStock ? AppColors.dangerText : AppColors.textPrimary)),
            Text(Formatters.formatCurrency(fp.costPrice), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(fp.currentStock * fp.costPrice), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
          ]);
        }
        return rows;

      case 1: // Purchases Register
        return db.purchases.map((p) {
          final isFinished = p.items.any((it) => it.itemType == PurchaseItemType.finishedProduct);
          return [
            Text(p.purchaseNumber, style: AppTextStyles.bodyBold),
            Text(p.vendorName, style: AppTextStyles.bodyMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isFinished ? Colors.teal.withOpacity(0.12) : Colors.blueGrey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isFinished ? 'FINISHED GOODS' : 'RAW MATERIAL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isFinished ? Colors.teal : Colors.blueGrey),
              ),
            ),
            Text(Formatters.formatDate(p.purchaseDate), style: AppTextStyles.bodySmall),
            Text(p.isInterStateTax ? 'IGST (Inter-State)' : 'CGST+SGST', style: TextStyle(fontSize: 11, color: p.isInterStateTax ? Colors.purple : AppColors.textSecondary)),
            Text(Formatters.formatCurrency(p.totalAmount), style: AppTextStyles.bodyBold),
            Text(
              Formatters.formatCurrency(p.pendingAmount),
              style: AppTextStyles.bodyBold.copyWith(color: p.pendingAmount > 0 ? AppColors.dangerText : AppColors.successText),
            ),
            ErpStatusBadge.success(p.statusLabel),
          ];
        }).toList();

      case 2: // Production Costing
        return db.productionOrders.map((po) {
          return [
            Text(po.productionNumber, style: AppTextStyles.bodyBold),
            Text(po.finishedProductName, style: AppTextStyles.bodyMedium),
            Text('${Formatters.formatNumber(po.actualQuantityProduced)} ${po.unit}', style: AppTextStyles.bodyBold),
            Text(Formatters.formatCurrency(po.rawMaterialCost), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(po.labourCost + po.otherExpenses), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(po.totalProductionCost), style: AppTextStyles.bodyBold),
            Text(Formatters.formatCurrency(po.costPerUnit), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
            ErpStatusBadge.success(po.status.name.toUpperCase()),
          ];
        }).toList();

      case 3: // Sales & GST
        return db.sales.map((s) {
          return [
            Text(s.invoiceNumber, style: AppTextStyles.bodyBold),
            Text(s.partyName, style: AppTextStyles.bodyMedium),
            Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(s.taxableAmount), style: AppTextStyles.bodySmall),
            Text(
              !s.isInterStateTax && s.igstAmount == 0 ? Formatters.formatCurrency(s.cgstAmount) : '0.00',
              style: AppTextStyles.bodySmall,
            ),
            Text(
              !s.isInterStateTax && s.igstAmount == 0 ? Formatters.formatCurrency(s.sgstAmount) : '0.00',
              style: AppTextStyles.bodySmall,
            ),
            Text(
              s.isInterStateTax || s.igstAmount > 0 ? Formatters.formatCurrency(s.igstAmount > 0 ? s.igstAmount : s.gstAmount) : '0.00',
              style: AppTextStyles.bodySmall.copyWith(color: s.isInterStateTax ? Colors.purple : null),
            ),
            Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
          ];
        }).toList();

      case 4: // Project Costing
        return db.projects.map((pr) {
          final prPurchases = db.purchases.where((p) => p.projectId == pr.id).fold(0.0, (s, p) => s + p.totalAmount);
          final prExpenses = db.expenses.where((e) => e.projectId == pr.id).fold(0.0, (s, e) => s + e.amount);
          final margin = pr.totalSalesAmount - prPurchases - prExpenses;

          return [
            Text(pr.name, style: AppTextStyles.bodyBold),
            Text(pr.customerName ?? pr.architectName ?? '-', style: AppTextStyles.bodyMedium),
            Text(Formatters.formatCurrency(pr.totalSalesAmount), style: AppTextStyles.bodyBold),
            Text(Formatters.formatCurrency(prPurchases), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(prExpenses), style: AppTextStyles.bodySmall),
            Text(
              Formatters.formatCurrency(margin),
              style: AppTextStyles.bodyBold.copyWith(color: margin >= 0 ? AppColors.successText : AppColors.dangerText),
            ),
            ErpStatusBadge.neutral(pr.statusLabel),
          ];
        }).toList();

      case 5: // Expenses
        return db.expenses.map((exp) {
          return [
            Text(exp.expenseNumber, style: AppTextStyles.bodyBold),
            Text(exp.categoryName, style: AppTextStyles.bodyMedium),
            Text(exp.description ?? '-', style: AppTextStyles.bodySmall),
            Text(exp.projectName ?? 'General Overhead', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
            Text(Formatters.formatDate(exp.expenseDate), style: AppTextStyles.bodySmall),
            Text(exp.paymentMethod.toUpperCase(), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(exp.amount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
          ];
        }).toList();

      case 6: // Commission
        return db.architects.map((a) {
          return [
            Text(a.name, style: AppTextStyles.bodyBold),
            Text(a.companyName.isNotEmpty ? a.companyName : a.mobile, style: AppTextStyles.bodySmall),
            Text('${a.defaultCommissionRate}% Rate', style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(a.totalCommissionEarned), style: AppTextStyles.bodyBold),
            Text(Formatters.formatCurrency(a.pendingCommission), style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
            Text(Formatters.formatCurrency(a.approvedCommission), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(a.paidCommission), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
          ];
        }).toList();

      case 7: // Financial Balance
      default:
        final rawVal = db.rawMaterialStockValue;
        final fgVal = db.finishedProductStockValue;
        final totalStock = rawVal + fgVal;
        final custRec = db.pendingCustomerPayments;
        final venPay = db.pendingVendorPayments;
        final commPay = db.pendingCommissionAmount;
        final storeCredits = db.customers.fold(0.0, (sum, c) => sum + c.creditBalance);
        final totalAssets = totalStock + custRec;
        final totalLiabilities = venPay + commPay + storeCredits;
        final netWorkingCap = totalAssets - totalLiabilities;

        return [
          [
            Text('Customer Accounts Receivable', style: AppTextStyles.bodyBold),
            Text('Current Asset (Collections Due)', style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(custRec), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
            const Text('-', style: TextStyle(fontSize: 12)),
            Text(Formatters.formatCurrency(custRec), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
          ],
          [
            Text('Raw Material Stock Assets', style: AppTextStyles.bodyBold),
            Text('Inventory Asset (Raw Inventory)', style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(rawVal), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
            const Text('-', style: TextStyle(fontSize: 12)),
            Text(Formatters.formatCurrency(rawVal), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
          ],
          [
            Text('Finished Goods Stock Assets', style: AppTextStyles.bodyBold),
            Text('Inventory Asset (Produced & Purchased Goods)', style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(fgVal), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
            const Text('-', style: TextStyle(fontSize: 12)),
            Text(Formatters.formatCurrency(fgVal), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
          ],
          [
            Text('Vendor Accounts Payable', style: AppTextStyles.bodyBold),
            Text('Current Liability (Procurement Dues)', style: AppTextStyles.bodySmall),
            const Text('-', style: TextStyle(fontSize: 12)),
            Text(Formatters.formatCurrency(venPay), style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
            Text('-${Formatters.formatCurrency(venPay)}', style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
          ],
          [
            Text('Architect Commission Payable', style: AppTextStyles.bodyBold),
            Text('Current Liability (Partner Payouts)', style: AppTextStyles.bodySmall),
            const Text('-', style: TextStyle(fontSize: 12)),
            Text(Formatters.formatCurrency(commPay), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
            Text('-${Formatters.formatCurrency(commPay)}', style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
          ],
          if (storeCredits > 0)
            [
              Text('Customer Store Credit Notes', style: AppTextStyles.bodyBold),
              Text('Current Liability (Customer Wallets)', style: AppTextStyles.bodySmall),
              const Text('-', style: TextStyle(fontSize: 12)),
              Text(Formatters.formatCurrency(storeCredits), style: AppTextStyles.bodyBold.copyWith(color: AppColors.warningText)),
              Text('-${Formatters.formatCurrency(storeCredits)}', style: AppTextStyles.bodyBold.copyWith(color: AppColors.warningText)),
            ],
          [
            Text('Net Working Capital & Operating Balance', style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
            Text('Total Assets - Liabilities', style: AppTextStyles.bodyBold),
            Text(Formatters.formatCurrency(totalAssets), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
            Text(Formatters.formatCurrency(totalLiabilities), style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
            Text(
              Formatters.formatCurrency(netWorkingCap),
              style: AppTextStyles.bodyBold.copyWith(color: netWorkingCap >= 0 ? AppColors.primary : AppColors.dangerText, fontSize: 14),
            ),
          ],
        ];
    }
  }

  List<List<String>> _getReportStringRows(MockDatabaseService db, int index) {
    switch (index) {
      case 0:
        final List<List<String>> rows = [];
        for (final rm in db.rawMaterials) {
          rows.add([
            '${rm.name} (${rm.itemCode})',
            '${rm.categoryName} [RAW]',
            'Purchased RM',
            '${rm.openingStock} ${rm.unit}',
            '${rm.currentStock} ${rm.unit}',
            Formatters.formatCurrency(rm.defaultPurchasePrice),
            Formatters.formatCurrency(rm.totalValuation),
          ]);
        }
        for (final fp in db.finishedProducts) {
          final isPurchased = (fp.purchasedStock ?? 0) > (fp.producedStock ?? 0);
          rows.add([
            '${fp.name} (${fp.itemCode})',
            '${fp.categoryName} [FG]',
            isPurchased ? 'Purchased Goods' : 'In-house Produced',
            '${fp.openingStock} ${fp.unit}',
            '${fp.currentStock} ${fp.unit}',
            Formatters.formatCurrency(fp.costPrice),
            Formatters.formatCurrency(fp.currentStock * fp.costPrice),
          ]);
        }
        return rows;

      case 1:
        return db.purchases.map((p) {
          final isFinished = p.items.any((it) => it.itemType == PurchaseItemType.finishedProduct);
          return [
            p.purchaseNumber,
            p.vendorName,
            isFinished ? 'FINISHED GOODS' : 'RAW MATERIAL',
            Formatters.formatDate(p.purchaseDate),
            p.isInterStateTax ? 'IGST' : 'CGST+SGST',
            Formatters.formatCurrency(p.totalAmount),
            Formatters.formatCurrency(p.pendingAmount),
            p.statusLabel,
          ];
        }).toList();

      case 2:
        return db.productionOrders.map((po) {
          return [
            po.productionNumber,
            po.finishedProductName,
            '${Formatters.formatNumber(po.actualQuantityProduced)} ${po.unit}',
            Formatters.formatCurrency(po.rawMaterialCost),
            Formatters.formatCurrency(po.labourCost + po.otherExpenses),
            Formatters.formatCurrency(po.totalProductionCost),
            Formatters.formatCurrency(po.costPerUnit),
            po.status.name.toUpperCase(),
          ];
        }).toList();

      case 3:
        return db.sales.map((s) {
          return [
            s.invoiceNumber,
            s.partyName,
            Formatters.formatDate(s.saleDate),
            Formatters.formatCurrency(s.taxableAmount),
            !s.isInterStateTax && s.igstAmount == 0 ? Formatters.formatCurrency(s.cgstAmount) : '0.00',
            !s.isInterStateTax && s.igstAmount == 0 ? Formatters.formatCurrency(s.sgstAmount) : '0.00',
            s.isInterStateTax || s.igstAmount > 0 ? Formatters.formatCurrency(s.igstAmount > 0 ? s.igstAmount : s.gstAmount) : '0.00',
            Formatters.formatCurrency(s.totalAmount),
          ];
        }).toList();

      case 4:
        return db.projects.map((pr) {
          final prPurchases = db.purchases.where((p) => p.projectId == pr.id).fold(0.0, (s, p) => s + p.totalAmount);
          final prExpenses = db.expenses.where((e) => e.projectId == pr.id).fold(0.0, (s, e) => s + e.amount);
          final margin = pr.totalSalesAmount - prPurchases - prExpenses;
          return [
            pr.name,
            pr.customerName ?? pr.architectName ?? '-',
            Formatters.formatCurrency(pr.totalSalesAmount),
            Formatters.formatCurrency(prPurchases),
            Formatters.formatCurrency(prExpenses),
            Formatters.formatCurrency(margin),
            pr.statusLabel,
          ];
        }).toList();

      case 5:
        return db.expenses.map((exp) {
          return [
            exp.expenseNumber,
            exp.categoryName,
            exp.description ?? '-',
            exp.projectName ?? 'General Overhead',
            Formatters.formatDate(exp.expenseDate),
            exp.paymentMethod.toUpperCase(),
            Formatters.formatCurrency(exp.amount),
          ];
        }).toList();

      case 6:
        return db.architects.map((a) {
          return [
            a.name,
            a.companyName.isNotEmpty ? a.companyName : a.mobile,
            '${a.defaultCommissionRate}% Rate',
            Formatters.formatCurrency(a.totalCommissionEarned),
            Formatters.formatCurrency(a.pendingCommission),
            Formatters.formatCurrency(a.approvedCommission),
            Formatters.formatCurrency(a.paidCommission),
          ];
        }).toList();

      case 7:
      default:
        final rawVal = db.rawMaterialStockValue;
        final fgVal = db.finishedProductStockValue;
        final custRec = db.pendingCustomerPayments;
        final venPay = db.pendingVendorPayments;
        final commPay = db.pendingCommissionAmount;
        final storeCredits = db.customers.fold(0.0, (sum, c) => sum + c.creditBalance);
        final totalAssets = (rawVal + fgVal) + custRec;
        final totalLiabilities = venPay + commPay + storeCredits;
        final netWorkingCap = totalAssets - totalLiabilities;
        return [
          [
            'Customer Accounts Receivable',
            'Current Asset (Collections Due)',
            Formatters.formatCurrency(custRec),
            '-',
            Formatters.formatCurrency(custRec),
          ],
          [
            'Raw Material Stock Assets',
            'Inventory Asset (Raw Stock)',
            Formatters.formatCurrency(rawVal),
            '-',
            Formatters.formatCurrency(rawVal),
          ],
          [
            'Finished Goods Stock Assets',
            'Inventory Asset (Produced & Purchased)',
            Formatters.formatCurrency(fgVal),
            '-',
            Formatters.formatCurrency(fgVal),
          ],
          [
            'Vendor Accounts Payable',
            'Current Liability (Procurement Dues)',
            '-',
            Formatters.formatCurrency(venPay),
            '-${Formatters.formatCurrency(venPay)}',
          ],
          [
            'Architect Commission Payable',
            'Current Liability (Partner Payouts)',
            '-',
            Formatters.formatCurrency(commPay),
            '-${Formatters.formatCurrency(commPay)}',
          ],
          if (storeCredits > 0)
            [
              'Customer Store Credit Notes',
              'Current Liability (Customer Wallets)',
              '-',
              Formatters.formatCurrency(storeCredits),
              '-${Formatters.formatCurrency(storeCredits)}',
            ],
          [
            'Net Working Capital & Operating Balance',
            'Total Assets - Total Liabilities',
            Formatters.formatCurrency(totalAssets),
            Formatters.formatCurrency(totalLiabilities),
            Formatters.formatCurrency(netWorkingCap),
          ],
        ];
    }
  }

  Map<String, String> _getReportKpisMap(MockDatabaseService db, int index) {
    switch (index) {
      case 0:
        return {
          'Total Stock Valuation': Formatters.formatCurrency(db.totalStockValue),
          'Raw Material Stock': Formatters.formatCurrency(db.rawMaterialStockValue),
          'Finished Goods Stock': Formatters.formatCurrency(db.finishedProductStockValue),
          'Low Stock SKUs': '${db.totalLowStockCount} Items',
        };
      case 1:
        final totalPurchases = db.purchases.fold(0.0, (s, p) => s + p.totalAmount);
        return {
          'Total Procurement': Formatters.formatCurrency(totalPurchases),
          'Purchase Orders': '${db.purchases.length} Orders',
          'Vendor Payables Due': Formatters.formatCurrency(db.pendingVendorPayments),
          'Active Vendors': '${db.vendors.where((v) => !v.isDeleted).length} Vendors',
        };
      case 2:
        final totalProdCost = db.productionOrders.fold(0.0, (s, p) => s + p.totalProductionCost);
        final totalUnits = db.productionOrders.fold(0.0, (s, p) => s + p.actualQuantityProduced).toInt();
        return {
          'Total Manufacturing Cost': Formatters.formatCurrency(totalProdCost),
          'Total Units Produced': '$totalUnits Units',
          'Completed Batches': '${db.productionOrders.length} Batches',
          'Avg Unit Cost': Formatters.formatCurrency(totalUnits > 0 ? totalProdCost / totalUnits : 0),
        };
      case 3:
        return {
          'Gross Turnover': Formatters.formatCurrency(db.totalInvoicedRevenue),
          'Sales Returns': Formatters.formatCurrency(db.totalSalesReturnsAmount),
          'Net Revenue': Formatters.formatCurrency(db.netSalesRevenue),
          'Customer Receivables': Formatters.formatCurrency(db.pendingCustomerPayments),
        };
      case 4:
        return {
          'Active Projects': '${db.projects.length} Projects',
          'Contracted Revenue': Formatters.formatCurrency(db.projects.fold(0.0, (s, p) => s + p.totalSalesAmount)),
          'Commission Allocated': Formatters.formatCurrency(db.projects.fold(0.0, (s, p) => s + p.totalCommissionAmount)),
          'Completed Projects': '${db.projects.where((p) => p.status == ProjectStatus.completed || p.status == ProjectStatus.closed).length}',
        };
      case 5:
        final totalExpenses = db.expenses.fold(0.0, (s, e) => s + e.amount);
        return {
          'Total Expenses': Formatters.formatCurrency(totalExpenses),
          'Expense Records': '${db.expenses.length} Vouchers',
          'Expense Categories': '${db.expenseCategories.length} Categories',
          'Project Expenses': Formatters.formatCurrency(db.expenses.where((e) => e.projectId != null).fold(0.0, (s, e) => s + e.amount)),
        };
      case 6:
        return {
          'Commission Earned': Formatters.formatCurrency(db.architects.fold(0.0, (s, a) => s + a.totalCommissionEarned)),
          'Pending Dues': Formatters.formatCurrency(db.pendingCommissionAmount),
          'Disbursed to Date': Formatters.formatCurrency(db.architects.fold(0.0, (s, a) => s + a.paidCommission)),
          'Registered Architects': '${db.architects.length} Partners',
        };
      case 7:
      default:
        final rawVal = db.rawMaterialStockValue;
        final fgVal = db.finishedProductStockValue;
        final storeCredits = db.customers.fold(0.0, (sum, c) => sum + c.creditBalance);
        final totalAssets = (rawVal + fgVal) + db.pendingCustomerPayments;
        final totalLiabilities = db.pendingVendorPayments + db.pendingCommissionAmount + storeCredits;
        final netWorkingCap = totalAssets - totalLiabilities;
        return {
          'Total Business Assets': Formatters.formatCurrency(totalAssets),
          'Total Liabilities': Formatters.formatCurrency(totalLiabilities),
          'Net Working Capital': Formatters.formatCurrency(netWorkingCap),
          'Net Sales Turnover': Formatters.formatCurrency(db.netSalesRevenue),
        };
    }
  }

  Future<void> _downloadReportToDevice(int activeIndex) async {
    final db = ref.read(databaseServiceProvider);
    final reportTitle = _getReportTitle(activeIndex);
    final columns = _getReportColumns(activeIndex);
    final headers = columns.map((c) => c.title).toList();
    final isNumeric = columns.map((c) => c.isNumeric).toList();
    final stringRows = _getReportStringRows(db, activeIndex);
    final kpis = _getReportKpisMap(db, activeIndex);
    final cleanLabel = _tabLabels[activeIndex].replaceAll(' ', '_');
    final filename = 'Deluzex_${cleanLabel}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    try {
      await ReportPdfGenerator.downloadReportPdf(
        filename: filename,
        title: reportTitle,
        subtitle: 'Comprehensive Module Statement & Ledger Audit',
        columnHeaders: headers,
        dataRows: stringRows,
        isNumericColumns: isNumeric,
        summaryKpis: kpis,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF Export Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _printOrLayoutReport(int activeIndex) async {
    final db = ref.read(databaseServiceProvider);
    final reportTitle = _getReportTitle(activeIndex);
    final columns = _getReportColumns(activeIndex);
    final headers = columns.map((c) => c.title).toList();
    final isNumeric = columns.map((c) => c.isNumeric).toList();
    final stringRows = _getReportStringRows(db, activeIndex);
    final kpis = _getReportKpisMap(db, activeIndex);

    try {
      await ReportPdfGenerator.printOrPreviewReport(
        title: reportTitle,
        subtitle: 'Comprehensive Module Statement & Ledger Audit',
        columnHeaders: headers,
        dataRows: stringRows,
        isNumericColumns: isNumeric,
        summaryKpis: kpis,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print layout error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final activeIndex = _tabController.index;
    final kpis = _getReportKpisMap(db, activeIndex);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 650;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reports & Analytics Hub', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text(
                    'Stock sources, purchase types, expense registers, and GST tax breakup statements',
                    style: AppTextStyles.subtitle,
                  ),
                ],
              );

              final actionBlock = Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ErpButton(
                    text: 'Print Statement',
                    icon: Icons.print_outlined,
                    isOutlined: true,
                    onPressed: () => _printOrLayoutReport(activeIndex),
                  ),
                  ErpButton(
                    text: 'Download PDF Report',
                    icon: Icons.download_outlined,
                    onPressed: () => _downloadReportToDevice(activeIndex),
                  ),
                ],
              );

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 12),
                    actionBlock,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 16),
                  actionBlock,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          ),
          const SizedBox(height: 20),

          // KPI Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1000
                  ? (kpis.length > 3 ? 4 : kpis.length)
                  : (width >= 600 ? 2 : 1);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: width < 450 ? 2.2 : (crossAxisCount >= 4 ? 1.8 : 2.0),
                ),
                itemCount: kpis.length,
                itemBuilder: (context, index) {
                  final e = kpis.entries.elementAt(index);
                  return StatCard(
                    title: e.key,
                    value: e.value,
                    icon: const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),

          // Report Statement Title Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final isNarrow = box.maxWidth < 600;
                final titleRow = Row(
                  children: [
                    const Icon(Icons.assessment_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getReportTitle(activeIndex),
                        style: AppTextStyles.h3.copyWith(fontSize: 15),
                      ),
                    ),
                  ],
                );

                final timeText = Text(
                  'As of ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleRow,
                      const SizedBox(height: 6),
                      timeText,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleRow),
                    const SizedBox(width: 12),
                    timeText,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Data Table for Active Tab
          ErpDataTable(
            columns: _getReportColumns(activeIndex),
            rows: _getReportRows(db, activeIndex),
          ),
        ],
      ),
    );
  }
}
