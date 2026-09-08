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
    'Sales Reports',
    'Project Reports',
    'Commission Reports',
    'Financial Reports',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    if (widget.reportType != null) {
      _tabController.index = _getIndexForSection(widget.reportType!);
    }
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    setState(() {});
    if (!_tabController.indexIsChanging) {
      final targetSection = _getSectionForIndex(_tabController.index);
      if (ref.read(currentNavSectionProvider) != targetSection) {
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
        return 5;
      case ErpNavSection.financialReports:
        return 6;
      default:
        return 0;
    }
  }

  ErpNavSection _getSectionForIndex(int index) {
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
        return ErpNavSection.commissionReports;
      case 6:
        return ErpNavSection.financialReports;
      default:
        return ErpNavSection.inventoryReports;
    }
  }

  bool _isReportSection(ErpNavSection section) {
    return section == ErpNavSection.inventoryReports ||
        section == ErpNavSection.purchaseReports ||
        section == ErpNavSection.productionReports ||
        section == ErpNavSection.salesReports ||
        section == ErpNavSection.projectReports ||
        section == ErpNavSection.commissionReports ||
        section == ErpNavSection.financialReports;
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
        return 'Inventory Stock Flow & Valuation Audit Statement';
      case 1:
        return 'Raw Materials Purchase Orders & Procurement Register';
      case 2:
        return 'Finished Goods Production Costing & Manufacturing Summary';
      case 3:
        return 'Sales Revenue, Taxable Turnover & GST Invoice Register';
      case 4:
        return 'Project Commercial Execution & Performance Report';
      case 5:
        return 'Architect Referrals & Commission Payout Ledger';
      case 6:
        return 'ERP Financial Balance Sheet & Working Capital Statement';
      default:
        return 'ERP Business Intelligence Statement';
    }
  }

  String _getActionButtonLabel(int index) {
    switch (index) {
      case 0:
        return 'Generate Inventory Report';
      case 1:
        return 'Generate Purchase Report';
      case 2:
        return 'Generate Production Report';
      case 3:
        return 'Generate Sales Report';
      case 4:
        return 'Generate Project Report';
      case 5:
        return 'Generate Commission Report';
      case 6:
        return 'Generate Financial Report';
      default:
        return 'Generate Report';
    }
  }

  List<ErpColumn> _getReportColumns(int index) {
    switch (index) {
      case 0: // Inventory
        return const [
          ErpColumn(title: 'Item Name & SKU'),
          ErpColumn(title: 'Category / Type'),
          ErpColumn(title: 'Opening Stock', isNumeric: true),
          ErpColumn(title: 'Inflow', isNumeric: true),
          ErpColumn(title: 'Outflow', isNumeric: true),
          ErpColumn(title: 'Current Stock', isNumeric: true),
          ErpColumn(title: 'Unit Cost', isNumeric: true),
          ErpColumn(title: 'Total Valuation', isNumeric: true),
        ];
      case 1: // Purchase
        return const [
          ErpColumn(title: 'PO Number'),
          ErpColumn(title: 'Vendor Name'),
          ErpColumn(title: 'Order Date'),
          ErpColumn(title: 'Vendor Invoice'),
          ErpColumn(title: 'Payment Mode'),
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
          ErpColumn(title: 'Total Batch Cost', isNumeric: true),
          ErpColumn(title: 'Unit Cost', isNumeric: true),
          ErpColumn(title: 'Status'),
        ];
      case 3: // Sales
        return const [
          ErpColumn(title: 'Invoice / Doc No'),
          ErpColumn(title: 'Customer / Dealer'),
          ErpColumn(title: 'Invoice Date'),
          ErpColumn(title: 'Doc Type'),
          ErpColumn(title: 'Taxable Amount', isNumeric: true),
          ErpColumn(title: 'GST Amount', isNumeric: true),
          ErpColumn(title: 'Grand Total', isNumeric: true),
          ErpColumn(title: 'Pending Due', isNumeric: true),
        ];
      case 4: // Projects
        return const [
          ErpColumn(title: 'Project Name'),
          ErpColumn(title: 'Customer / Architect'),
          ErpColumn(title: 'Start Date'),
          ErpColumn(title: 'Target Date'),
          ErpColumn(title: 'Project Sales', isNumeric: true),
          ErpColumn(title: 'Commission', isNumeric: true),
          ErpColumn(title: 'Status'),
        ];
      case 5: // Commission
        return const [
          ErpColumn(title: 'Architect / Partner'),
          ErpColumn(title: 'Firm / Contact'),
          ErpColumn(title: 'Commission Rate'),
          ErpColumn(title: 'Total Earned', isNumeric: true),
          ErpColumn(title: 'Pending Due', isNumeric: true),
          ErpColumn(title: 'Approved', isNumeric: true),
          ErpColumn(title: 'Paid to Date', isNumeric: true),
        ];
      case 6: // Financial
        return const [
          ErpColumn(title: 'Ledger Account / Balance Sheet Head'),
          ErpColumn(title: 'Classification'),
          ErpColumn(title: 'Receivable / Asset', isNumeric: true),
          ErpColumn(title: 'Payable / Liability', isNumeric: true),
          ErpColumn(title: 'Net Position', isNumeric: true),
        ];
      default:
        return const [
          ErpColumn(title: 'Ledger Head'),
          ErpColumn(title: 'Balance', isNumeric: true),
        ];
    }
  }

  List<List<Widget>> _getReportRows(MockDatabaseService db, int index) {
    switch (index) {
      case 0: // Inventory Flow & Valuation
        final List<List<Widget>> rows = [];

        // Raw Materials
        for (final rm in db.rawMaterials) {
          final purchaseIn = db.purchases
              .where((p) => p.status != PurchaseStatus.draft && p.status != PurchaseStatus.cancelled)
              .expand((p) => p.items)
              .where((item) => item.rawMaterialId == rm.id)
              .fold(0.0, (sum, item) => sum + item.quantity);

          final prodCons = db.productionOrders
              .where((po) => po.status == ProductionStatus.inProgress || po.status == ProductionStatus.completed)
              .expand((po) => po.rawMaterialsUsed)
              .where((usage) => usage.rawMaterialId == rm.id)
              .fold(0.0, (sum, usage) => sum + usage.quantityUsed);

          rows.add([
            Text('${rm.name} (${rm.itemCode})', style: AppTextStyles.bodyBold),
            Text('${rm.categoryName} [RAW]', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
            Text('${rm.openingStock} ${rm.unit}', style: AppTextStyles.bodySmall),
            Text('${purchaseIn.toStringAsFixed(1)} ${rm.unit}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText)),
            Text('${prodCons.toStringAsFixed(1)} ${rm.unit}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
            Text('${rm.currentStock} ${rm.unit}', style: AppTextStyles.bodyBold.copyWith(color: rm.isLowStock ? AppColors.dangerText : AppColors.textPrimary)),
            Text(Formatters.formatCurrency(rm.defaultPurchasePrice), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(rm.totalValuation), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
          ]);
        }

        // Finished Products
        for (final fp in db.finishedProducts) {
          final prodOut = db.productionOrders
              .where((po) => po.status == ProductionStatus.completed && po.finishedProductId == fp.id)
              .fold(0.0, (sum, po) => sum + po.actualQuantityProduced);

          final salesOut = db.sales
              .where((s) => s.documentType == SalesDocumentType.invoice && s.status != SaleStatus.draft && s.status != SaleStatus.cancelled)
              .expand((s) => s.items)
              .where((item) => item.finishedProductId == fp.id)
              .fold(0.0, (sum, item) => sum + item.quantity);

          rows.add([
            Text('${fp.name} (${fp.itemCode})', style: AppTextStyles.bodyBold),
            Text('${fp.categoryName} [FG]', style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText)),
            Text('${fp.openingStock} ${fp.unit}', style: AppTextStyles.bodySmall),
            Text('${prodOut.toStringAsFixed(1)} ${fp.unit}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText)),
            Text('${salesOut.toStringAsFixed(1)} ${fp.unit}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
            Text('${fp.currentStock} ${fp.unit}', style: AppTextStyles.bodyBold.copyWith(color: fp.isLowStock ? AppColors.dangerText : AppColors.textPrimary)),
            Text(Formatters.formatCurrency(fp.costPrice), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(fp.totalValuation), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
          ]);
        }
        return rows;

      case 1: // Purchase Orders
        return db.purchases.map((p) {
          return [
            Text(p.purchaseNumber, style: AppTextStyles.bodyBold),
            Text(p.vendorName, style: AppTextStyles.bodyMedium),
            Text(Formatters.formatDate(p.purchaseDate), style: AppTextStyles.bodySmall),
            Text(p.vendorInvoiceNumber.isNotEmpty ? p.vendorInvoiceNumber : '-', style: AppTextStyles.bodySmall),
            Text(p.paymentMode.name.toUpperCase(), style: AppTextStyles.bodySmall),
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

      case 3: // Sales Register
        return db.sales.map((s) {
          return [
            Text(s.invoiceNumber, style: AppTextStyles.bodyBold),
            Text(s.partyName, style: AppTextStyles.bodyMedium),
            Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
            Text(s.documentType.name.toUpperCase(), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(s.subtotalAmount - s.discountAmount), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(s.gstAmount), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold),
            Text(
              Formatters.formatCurrency(s.pendingAmount),
              style: AppTextStyles.bodyBold.copyWith(color: s.pendingAmount > 0 ? AppColors.dangerText : AppColors.successText),
            ),
          ];
        }).toList();

      case 4: // Projects Report
        return db.projects.map((pr) {
          return [
            Text(pr.name, style: AppTextStyles.bodyBold),
            Text(pr.customerName ?? pr.architectName ?? '-', style: AppTextStyles.bodyMedium),
            Text(Formatters.formatDate(pr.startDate), style: AppTextStyles.bodySmall),
            Text(Formatters.formatDate(pr.expectedCompletionDate), style: AppTextStyles.bodySmall),
            Text(Formatters.formatCurrency(pr.totalSalesAmount), style: AppTextStyles.bodyBold),
            Text(Formatters.formatCurrency(pr.totalCommissionAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
            ErpStatusBadge.neutral(pr.statusLabel),
          ];
        }).toList();

      case 5: // Commission Report
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

      case 6: // Financial Balance Ledger
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
            Text('Inventory Asset (Produced Goods)', style: AppTextStyles.bodySmall),
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
          final purchaseIn = db.purchases
              .where((p) => p.status != PurchaseStatus.draft && p.status != PurchaseStatus.cancelled)
              .expand((p) => p.items)
              .where((item) => item.rawMaterialId == rm.id)
              .fold(0.0, (sum, item) => sum + item.quantity);

          final prodCons = db.productionOrders
              .where((po) => po.status == ProductionStatus.inProgress || po.status == ProductionStatus.completed)
              .expand((po) => po.rawMaterialsUsed)
              .where((usage) => usage.rawMaterialId == rm.id)
              .fold(0.0, (sum, usage) => sum + usage.quantityUsed);

          rows.add([
            '${rm.name} (${rm.itemCode})',
            '${rm.categoryName} [RAW]',
            '${rm.openingStock} ${rm.unit}',
            '${purchaseIn.toStringAsFixed(1)} ${rm.unit}',
            '${prodCons.toStringAsFixed(1)} ${rm.unit}',
            '${rm.currentStock} ${rm.unit}',
            Formatters.formatCurrency(rm.defaultPurchasePrice),
            Formatters.formatCurrency(rm.totalValuation),
          ]);
        }
        for (final fp in db.finishedProducts) {
          final prodOut = db.productionOrders
              .where((po) => po.status == ProductionStatus.completed && po.finishedProductId == fp.id)
              .fold(0.0, (sum, po) => sum + po.actualQuantityProduced);

          final salesOut = db.sales
              .where((s) => s.documentType == SalesDocumentType.invoice && s.status != SaleStatus.draft && s.status != SaleStatus.cancelled)
              .expand((s) => s.items)
              .where((item) => item.finishedProductId == fp.id)
              .fold(0.0, (sum, item) => sum + item.quantity);

          rows.add([
            '${fp.name} (${fp.itemCode})',
            '${fp.categoryName} [FG]',
            '${fp.openingStock} ${fp.unit}',
            '${prodOut.toStringAsFixed(1)} ${fp.unit}',
            '${salesOut.toStringAsFixed(1)} ${fp.unit}',
            '${fp.currentStock} ${fp.unit}',
            Formatters.formatCurrency(fp.costPrice),
            Formatters.formatCurrency(fp.totalValuation),
          ]);
        }
        return rows;

      case 1:
        return db.purchases.map((p) {
          return [
            p.purchaseNumber,
            p.vendorName,
            Formatters.formatDate(p.purchaseDate),
            p.vendorInvoiceNumber.isNotEmpty ? p.vendorInvoiceNumber : '-',
            p.paymentMode.name.toUpperCase(),
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
            s.documentType.name.toUpperCase(),
            Formatters.formatCurrency(s.subtotalAmount - s.discountAmount),
            Formatters.formatCurrency(s.gstAmount),
            Formatters.formatCurrency(s.totalAmount),
            Formatters.formatCurrency(s.pendingAmount),
          ];
        }).toList();

      case 4:
        return db.projects.map((pr) {
          return [
            pr.name,
            pr.customerName ?? pr.architectName ?? '-',
            Formatters.formatDate(pr.startDate),
            Formatters.formatDate(pr.expectedCompletionDate),
            Formatters.formatCurrency(pr.totalSalesAmount),
            Formatters.formatCurrency(pr.totalCommissionAmount),
            pr.statusLabel,
          ];
        }).toList();

      case 5:
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

      case 6:
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
            'Inventory Asset (Produced Stock)',
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
        return {
          'Commission Earned': Formatters.formatCurrency(db.architects.fold(0.0, (s, a) => s + a.totalCommissionEarned)),
          'Pending Dues': Formatters.formatCurrency(db.pendingCommissionAmount),
          'Disbursed to Date': Formatters.formatCurrency(db.architects.fold(0.0, (s, a) => s + a.paidCommission)),
          'Registered Architects': '${db.architects.length} Partners',
        };
      case 6:
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

    await ReportPdfGenerator.printOrPreviewReport(
      title: reportTitle,
      subtitle: 'Comprehensive Module Statement & Ledger Audit',
      columnHeaders: headers,
      dataRows: stringRows,
      isNumericColumns: isNumeric,
      summaryKpis: kpis,
    );
  }

  void _openPdfPreviewDialog() {
    final db = ref.read(databaseServiceProvider);
    final activeIndex = _tabController.index;
    final reportTitle = _getReportTitle(activeIndex);
    final columns = _getReportColumns(activeIndex);
    final rows = _getReportRows(db, activeIndex);
    final kpis = _getReportKpisMap(db, activeIndex);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorderRadius),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Generated Report Preview - ${_tabLabels[activeIndex]}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 900,
            height: 640,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Letterhead Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DELUZEX ERP SYSTEMS PVT. LTD.',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'GSTIN: 27AABCO8890K1Z9 | contact@deluzex.com | +91 22 2890 1234',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                            Text(
                              'Architectural & High-End Commercial Lighting Solutions, Mumbai, MH',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'AUDIT REPORT',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Generated: ${Formatters.formatDateTime(DateTime.now())}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Colors.black87, thickness: 1.5, height: 24),

                    // Report Title & Subtitle
                    Center(
                      child: Column(
                        children: [
                          Text(
                            reportTitle.toUpperCase(),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.1),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Comprehensive Module Statement & Ledger Audit',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // KPI Summary Cards
                    if (kpis.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: kpis.entries.map((entry) {
                            return Column(
                              children: [
                                Text(entry.key, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                                const SizedBox(height: 3),
                                Text(entry.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Report Table
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade400),
                      columnWidths: {
                        for (int i = 0; i < columns.length; i++)
                          i: i == 0 ? const FlexColumnWidth(2.2) : const FlexColumnWidth(1.2),
                      },
                      children: [
                        // PDF Header Row
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade200),
                          children: columns.map((col) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                              child: Text(
                                col.title,
                                style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.black87),
                                textAlign: col.isNumeric ? TextAlign.right : TextAlign.left,
                              ),
                            );
                          }).toList(),
                        ),
                        // PDF Data Rows
                        ...rows.map((row) {
                          return TableRow(
                            children: row.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final cell = entry.value;
                              final isNumeric = idx < columns.length && columns[idx].isNumeric;
                              String txt = '';
                              if (cell is Text) {
                                txt = cell.data ?? '';
                              } else {
                                txt = cell.toString();
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                                child: Text(
                                  txt,
                                  style: const TextStyle(fontSize: 8.5, color: Colors.black87),
                                  textAlign: isNumeric ? TextAlign.right : TextAlign.left,
                                ),
                              );
                            }).toList(),
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // PDF Signatures Block
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Prepared & Verified By:',
                              style: TextStyle(fontSize: 10, color: Colors.black87),
                            ),
                            const SizedBox(height: 24),
                            Container(width: 140, height: 1, color: Colors.black54),
                            const SizedBox(height: 4),
                            const Text('ERP Operations Auditor', style: TextStyle(fontSize: 9, color: Colors.black54)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'For DELUZEX ERP SYSTEMS PVT. LTD.',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 24),
                            Container(width: 160, height: 1, color: Colors.black54),
                            const SizedBox(height: 4),
                            const Text('Authorized Commercial Signatory', style: TextStyle(fontSize: 9, color: Colors.black54)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            ErpButton(
              text: 'Print / System PDF',
              icon: Icons.print,
              isOutlined: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                _printOrLayoutReport(activeIndex);
              },
            ),
            const SizedBox(width: 8),
            ErpButton(
              text: 'Download PDF to PC',
              icon: Icons.download_rounded,
              onPressed: () {
                Navigator.of(ctx).pop();
                _downloadReportToDevice(activeIndex);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards(MockDatabaseService db, int index) {
    switch (index) {
      case 0: // Inventory KPIs
        return Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Total Stock Valuation',
                value: Formatters.formatCurrency(db.totalStockValue),
                trendText: '${db.rawMaterials.length + db.finishedProducts.length} Total SKUs',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Raw Material Value',
                value: Formatters.formatCurrency(db.rawMaterialStockValue),
                trendText: '${db.rawMaterials.length} Raw items',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Finished Goods Value',
                value: Formatters.formatCurrency(db.finishedProductStockValue),
                trendText: '${db.finishedProducts.length} Product SKUs',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Low Stock Items',
                value: '${db.totalLowStockCount} Items',
                trendText: 'Immediate reorder needed',
                isPositiveTrend: false,
              ),
            ),
          ],
        );

      case 1: // Purchase KPIs
        final totalPurchases = db.purchases.fold(0.0, (s, p) => s + p.totalAmount);
        return Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Total Procurement',
                value: Formatters.formatCurrency(totalPurchases),
                trendText: '${db.purchases.length} Purchase Orders',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Vendor Payables Due',
                value: Formatters.formatCurrency(db.pendingVendorPayments),
                trendText: 'Outstanding procurement',
                isPositiveTrend: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Active Vendors',
                value: '${db.vendors.where((v) => !v.isDeleted).length} Vendors',
                trendText: 'Supplying raw materials',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Average PO Value',
                value: Formatters.formatCurrency(db.purchases.isNotEmpty ? totalPurchases / db.purchases.length : 0),
                trendText: 'Per order ticket size',
                isPositiveTrend: true,
              ),
            ),
          ],
        );

      case 2: // Production KPIs
        final totalProdCost = db.productionOrders.fold(0.0, (s, p) => s + p.totalProductionCost);
        final totalUnits = db.productionOrders.fold(0.0, (s, p) => s + p.actualQuantityProduced).toInt();
        return Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Manufacturing Cost',
                value: Formatters.formatCurrency(totalProdCost),
                trendText: 'Materials + Labor + Overheads',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Total Units Produced',
                value: '$totalUnits Units',
                trendText: '${db.productionOrders.length} Completed batches',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Avg Batch Cost',
                value: Formatters.formatCurrency(db.productionOrders.isNotEmpty ? totalProdCost / db.productionOrders.length : 0),
                trendText: 'Average cost per batch',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Avg Unit Cost',
                value: Formatters.formatCurrency(totalUnits > 0 ? totalProdCost / totalUnits : 0),
                trendText: 'Unit manufacturing cost',
                isPositiveTrend: true,
              ),
            ),
          ],
        );

      case 3: // Sales KPIs
        final totalGst = db.sales.fold(0.0, (s, i) => s + i.gstAmount);
        return Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Total Gross Revenue',
                value: Formatters.formatCurrency(db.totalSalesAmount),
                trendText: '${db.sales.length} Invoices generated',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Customer Receivables',
                value: Formatters.formatCurrency(db.pendingCustomerPayments),
                trendText: 'Pending client collections',
                isPositiveTrend: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'GST Collected',
                value: Formatters.formatCurrency(totalGst),
                trendText: 'Tax liability recorded',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Customer Accounts',
                value: '${db.customers.length + db.dealers.length} Parties',
                trendText: '${db.customers.length} Cust + ${db.dealers.length} Dealers',
                isPositiveTrend: true,
              ),
            ),
          ],
        );

      case 4: // Projects KPIs
        final totalProjSales = db.projects.fold(0.0, (s, p) => s + p.totalSalesAmount);
        final totalProjComm = db.projects.fold(0.0, (s, p) => s + p.totalCommissionAmount);
        return Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Active Projects',
                value: '${db.projects.length} Projects',
                trendText: 'Commercial lighting pipeline',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Project Sales Value',
                value: Formatters.formatCurrency(totalProjSales),
                trendText: 'Total contracted revenue',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Allocated Commission',
                value: Formatters.formatCurrency(totalProjComm),
                trendText: 'Architect project share',
                isPositiveTrend: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Completed Projects',
                value: '${db.projects.where((p) => p.status == ProjectStatus.completed || p.status == ProjectStatus.closed).length}',
                trendText: 'Fully delivered & closed',
                isPositiveTrend: true,
              ),
            ),
          ],
        );

      case 5: // Commission KPIs
        final totalEarned = db.architects.fold(0.0, (s, a) => s + a.totalCommissionEarned);
        final totalPaid = db.architects.fold(0.0, (s, a) => s + a.paidCommission);
        return Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Total Commission Earned',
                value: Formatters.formatCurrency(totalEarned),
                trendText: '${db.architects.length} Partners enrolled',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Pending Commission Dues',
                value: Formatters.formatCurrency(db.pendingCommissionAmount),
                trendText: 'To be approved / disbursed',
                isPositiveTrend: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Disbursed to Date',
                value: Formatters.formatCurrency(totalPaid),
                trendText: 'Paid to partners',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Registered Architects',
                value: '${db.architects.length} Architects',
                trendText: 'Active referral network',
                isPositiveTrend: true,
              ),
            ),
          ],
        );

      case 6: // Financial KPIs
      default:
        final rawVal = db.rawMaterialStockValue;
        final fgVal = db.finishedProductStockValue;
        final totalAssets = (rawVal + fgVal) + db.pendingCustomerPayments;
        final totalLiabilities = db.pendingVendorPayments + db.pendingCommissionAmount;
        final netWorkingCap = totalAssets - totalLiabilities;
        return Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Total Business Assets',
                value: Formatters.formatCurrency(totalAssets),
                trendText: 'Stock assets + Receivables',
                isPositiveTrend: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Total Liabilities',
                value: Formatters.formatCurrency(totalLiabilities),
                trendText: 'Vendor + Commission dues',
                isPositiveTrend: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Net Working Capital',
                value: Formatters.formatCurrency(netWorkingCap),
                trendText: 'Assets minus Liabilities',
                isPositiveTrend: netWorkingCap >= 0,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Gross Sales Turnover',
                value: Formatters.formatCurrency(db.totalSalesAmount),
                trendText: '${db.sales.length} Cumulative invoices',
                isPositiveTrend: true,
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final activeIndex = _tabController.index;

    // Listen to currentNavSectionProvider to sync tab when user clicks from sidebar
    ref.listen<ErpNavSection>(currentNavSectionProvider, (previous, next) {
      if (_isReportSection(next)) {
        final targetIndex = _getIndexForSection(next);
        if (_tabController.index != targetIndex) {
          _tabController.animateTo(targetIndex);
        }
      }
    });

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
              Row(
                children: [
                  ErpButton(
                    text: _getActionButtonLabel(activeIndex),
                    icon: Icons.description_outlined,
                    onPressed: _openPdfPreviewDialog,
                  ),
                  const SizedBox(width: 12),
                  ErpButton(
                    text: 'Download PDF',
                    icon: Icons.download_rounded,
                    isOutlined: true,
                    onPressed: () => _downloadReportToDevice(activeIndex),
                  ),
                ],
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
            onTap: (index) {
              final targetSection = _getSectionForIndex(index);
              if (ref.read(currentNavSectionProvider) != targetSection) {
                ref.read(currentNavSectionProvider.notifier).state = targetSection;
              }
            },
            tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
          ),
          const SizedBox(height: 24),

          // Dynamic Summary Metrics Cards for Reporting
          _buildSummaryCards(db, activeIndex),
          const SizedBox(height: 24),

          // Tab Content - Separate dedicated table data for each report type
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: List.generate(7, (i) {
                return ErpDataTable(
                  columns: _getReportColumns(i),
                  rows: _getReportRows(db, i),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
