import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_radius.dart';
import '../../../core/models/commission_model.dart';
import '../../../core/models/production_model.dart';
import '../../../core/models/project_model.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/report_pdf_generator.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';

/// Internal wrapper holding both table widget cells and clean strings for exports.
class _ReportRowItem {
  final List<Widget> cells;
  final List<String> stringValues;

  const _ReportRowItem({
    required this.cells,
    required this.stringValues,
  });
}

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

  // Filtering & Pagination State with null-safe hot-reload resilience
  TextEditingController? _searchController;
  String? _searchQuery = '';
  String? _statusFilter = 'ALL';
  String? _typeFilter = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;
  int? _currentPage = 0;
  int? _pageSize = 10;

  TextEditingController get _safeSearchController => _searchController ??= TextEditingController();
  String get _safeSearchQuery => _searchQuery ?? '';
  String get _safeStatusFilter => _statusFilter ?? 'ALL';
  String get _safeTypeFilter => _typeFilter ?? 'ALL';
  int get _safeCurrentPage => _currentPage ?? 0;
  int get _safePageSize => (_pageSize == null || _pageSize! <= 0) ? 10 : _pageSize!;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchQuery = '';
    _statusFilter = 'ALL';
    _typeFilter = 'ALL';
    _startDate = null;
    _endDate = null;
    _currentPage = 0;
    _pageSize = 10;
    _tabController = TabController(length: 8, vsync: this);
    if (widget.reportType != null) {
      _tabController.index = _getIndexForSection(widget.reportType!);
    }
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = ref.read(databaseServiceProvider);
      if (!db.hasLoadedProjects) {
        db.loadProjects();
      }
    });
  }

  void _handleTabChange() {
    setState(() {
      _currentPage = 0;
      _safeSearchController.clear();
      _searchQuery = '';
      _statusFilter = 'ALL';
      _typeFilter = 'ALL';
      _startDate = null;
      _endDate = null;
    });
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
        return null;
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
    _searchController?.dispose();
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

  bool _matchesDate(DateTime? date) {
    if (date == null) return true;
    if (_startDate != null) {
      final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      if (date.isBefore(start)) return false;
    }
    if (_endDate != null) {
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59, 999);
      if (date.isAfter(end)) return false;
    }
    return true;
  }

  /// Builds filtered row items for the given tab index
  List<_ReportRowItem> _getFilteredData(MockDatabaseService db, int tabIndex) {
    final query = _safeSearchQuery.trim().toLowerCase();

    switch (tabIndex) {
      case 0: // Inventory
        final List<_ReportRowItem> items = [];

        // Raw materials
        if (_safeTypeFilter == 'ALL' || _safeTypeFilter == 'RAW') {
          for (final rm in db.rawMaterials) {
            if (rm.isDeleted) continue;
            if (query.isNotEmpty &&
                !rm.name.toLowerCase().contains(query) &&
                !rm.itemCode.toLowerCase().contains(query) &&
                !rm.categoryName.toLowerCase().contains(query)) {
              continue;
            }
            if (_safeStatusFilter == 'LOW' && !rm.isLowStock) continue;
            if (_safeStatusFilter == 'IN_STOCK' && rm.currentStock <= 0) continue;
            if (_safeStatusFilter == 'OUT_OF_STOCK' && rm.currentStock > 0) continue;

            items.add(_ReportRowItem(
              cells: [
                Text('${rm.name} (${rm.itemCode})', style: AppTextStyles.bodyBold),
                Text('${rm.categoryName} [RAW]', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                const Text('Purchased RM', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                Text('${rm.openingStock} ${rm.unit}', style: AppTextStyles.bodySmall),
                Text(
                  '${rm.currentStock} ${rm.unit}',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: rm.isLowStock ? AppColors.dangerText : AppColors.textPrimary,
                  ),
                ),
                Text(Formatters.formatCurrency(rm.defaultPurchasePrice), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(rm.totalValuation), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ],
              stringValues: [
                '${rm.name} (${rm.itemCode})',
                '${rm.categoryName} [RAW]',
                'Purchased RM',
                '${rm.openingStock} ${rm.unit}',
                '${rm.currentStock} ${rm.unit}',
                Formatters.formatCurrency(rm.defaultPurchasePrice),
                Formatters.formatCurrency(rm.totalValuation),
              ],
            ));
          }
        }

        // Finished goods
        if (_safeTypeFilter == 'ALL' || _safeTypeFilter == 'FG') {
          for (final fp in db.finishedProducts) {
            if (fp.isDeleted) continue;
            if (query.isNotEmpty &&
                !fp.name.toLowerCase().contains(query) &&
                !fp.itemCode.toLowerCase().contains(query) &&
                !fp.categoryName.toLowerCase().contains(query)) {
              continue;
            }
            if (_safeStatusFilter == 'LOW' && !fp.isLowStock) continue;
            if (_safeStatusFilter == 'IN_STOCK' && fp.currentStock <= 0) continue;
            if (_safeStatusFilter == 'OUT_OF_STOCK' && fp.currentStock > 0) continue;

            final isPurchased = fp.purchasedStock > fp.producedStock;
            final unitCost = fp.costPrice > 0
                ? fp.costPrice
                : (fp.dealerSellingPrice > 0
                    ? fp.dealerSellingPrice * 0.7
                    : (fp.customerSellingPrice > 0 ? fp.customerSellingPrice * 0.6 : 0.0));
            final valuation = fp.currentStock * unitCost;

            items.add(_ReportRowItem(
              cells: [
                Text('${fp.name} (${fp.itemCode})', style: AppTextStyles.bodyBold),
                Text('${fp.categoryName} [FG]', style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPurchased ? Colors.teal.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPurchased ? 'Purchased Goods' : 'In-house Produced',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isPurchased ? Colors.teal : Colors.blue,
                    ),
                  ),
                ),
                Text('${fp.openingStock} ${fp.unit}', style: AppTextStyles.bodySmall),
                Text(
                  '${fp.currentStock} ${fp.unit}',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: fp.isLowStock ? AppColors.dangerText : AppColors.textPrimary,
                  ),
                ),
                Text(Formatters.formatCurrency(unitCost), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(valuation), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ],
              stringValues: [
                '${fp.name} (${fp.itemCode})',
                '${fp.categoryName} [FG]',
                isPurchased ? 'Purchased Goods' : 'In-house Produced',
                '${fp.openingStock} ${fp.unit}',
                '${fp.currentStock} ${fp.unit}',
                Formatters.formatCurrency(unitCost),
                Formatters.formatCurrency(valuation),
              ],
            ));
          }
        }
        return items;

      case 1: // Purchase
        return db.purchases.where((p) {
          if (query.isNotEmpty &&
              !p.purchaseNumber.toLowerCase().contains(query) &&
              !p.vendorName.toLowerCase().contains(query)) {
            return false;
          }
          if (_safeStatusFilter != 'ALL' && p.status.name.toLowerCase() != _safeStatusFilter.toLowerCase()) {
            return false;
          }
          if (_safeTypeFilter == 'FG' && !p.items.any((it) => it.itemType == PurchaseItemType.finishedProduct)) {
            return false;
          }
          if (_safeTypeFilter == 'RAW' && !p.items.any((it) => it.itemType == PurchaseItemType.rawMaterial)) {
            return false;
          }
          if (!_matchesDate(p.purchaseDate)) return false;
          return true;
        }).map((p) {
          final isFinished = p.items.any((it) => it.itemType == PurchaseItemType.finishedProduct);
          return _ReportRowItem(
            cells: [
              Text(p.purchaseNumber, style: AppTextStyles.bodyBold),
              Text(p.vendorName, style: AppTextStyles.bodyMedium),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isFinished ? Colors.teal.withValues(alpha: 0.12) : Colors.blueGrey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isFinished ? 'FINISHED GOODS' : 'RAW MATERIAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isFinished ? Colors.teal : Colors.blueGrey,
                  ),
                ),
              ),
              Text(Formatters.formatDate(p.purchaseDate), style: AppTextStyles.bodySmall),
              Text(
                p.isInterStateTax ? 'IGST (Inter-State)' : 'CGST+SGST',
                style: TextStyle(
                  fontSize: 11,
                  color: p.isInterStateTax ? Colors.purple : AppColors.textSecondary,
                ),
              ),
              Text(Formatters.formatCurrency(p.totalAmount), style: AppTextStyles.bodyBold),
              Text(
                Formatters.formatCurrency(p.pendingAmount),
                style: AppTextStyles.bodyBold.copyWith(
                  color: p.pendingAmount > 0 ? AppColors.dangerText : AppColors.successText,
                ),
              ),
              ErpStatusBadge.success(p.statusLabel),
            ],
            stringValues: [
              p.purchaseNumber,
              p.vendorName,
              isFinished ? 'FINISHED GOODS' : 'RAW MATERIAL',
              Formatters.formatDate(p.purchaseDate),
              p.isInterStateTax ? 'IGST' : 'CGST+SGST',
              Formatters.formatCurrency(p.totalAmount),
              Formatters.formatCurrency(p.pendingAmount),
              p.statusLabel,
            ],
          );
        }).toList();

      case 2: // Production
        return db.productionOrders.where((po) {
          if (query.isNotEmpty &&
              !po.productionNumber.toLowerCase().contains(query) &&
              !po.finishedProductName.toLowerCase().contains(query)) {
            return false;
          }
          if (_safeStatusFilter != 'ALL' && po.status.name.toLowerCase() != _safeStatusFilter.toLowerCase()) {
            return false;
          }
          if (!_matchesDate(po.productionDate)) return false;
          return true;
        }).map((po) {
          final qty = po.actualQuantityProduced > 0 ? po.actualQuantityProduced : po.plannedQuantity;
          final cpu = po.costPerUnit > 0 ? po.costPerUnit : (qty > 0 ? po.totalProductionCost / qty : 0.0);
          return _ReportRowItem(
            cells: [
              Text(po.productionNumber, style: AppTextStyles.bodyBold),
              Text(po.finishedProductName, style: AppTextStyles.bodyMedium),
              Text('${Formatters.formatNumber(qty)} ${po.unit}', style: AppTextStyles.bodyBold),
              Text(Formatters.formatCurrency(po.rawMaterialCost), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(po.labourCost + po.otherExpenses), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(po.totalProductionCost), style: AppTextStyles.bodyBold),
              Text(Formatters.formatCurrency(cpu), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ErpStatusBadge.success(po.status.name.toUpperCase()),
            ],
            stringValues: [
              po.productionNumber,
              po.finishedProductName,
              '${Formatters.formatNumber(qty)} ${po.unit}',
              Formatters.formatCurrency(po.rawMaterialCost),
              Formatters.formatCurrency(po.labourCost + po.otherExpenses),
              Formatters.formatCurrency(po.totalProductionCost),
              Formatters.formatCurrency(cpu),
              po.status.name.toUpperCase(),
            ],
          );
        }).toList();

      case 3: // Sales & GST
        return db.sales.where((s) {
          if (query.isNotEmpty &&
              !s.invoiceNumber.toLowerCase().contains(query) &&
              !s.partyName.toLowerCase().contains(query)) {
            return false;
          }
          if (_safeStatusFilter != 'ALL') {
            final filter = _safeStatusFilter.toLowerCase();
            if (filter == 'invoice' && s.documentType != SalesDocumentType.invoice) return false;
            if (filter == 'salesreturn' && s.documentType != SalesDocumentType.salesReturn) return false;
            if (filter == 'salesorder' && s.documentType != SalesDocumentType.salesOrder) return false;
            if (filter == 'quotation' && s.documentType != SalesDocumentType.quotation) return false;
            if (filter == 'delivery' && s.documentType != SalesDocumentType.delivery) return false;
            if (filter == 'proformainvoice' && s.documentType != SalesDocumentType.proformaInvoice) return false;
            if (filter == 'paid' && (s.status != SaleStatus.paid && s.pendingAmount > 0)) return false;
            if (filter == 'due' && s.pendingAmount <= 0) return false;
          }
          if (_safeTypeFilter == 'INTRA' && s.isInterStateTax) return false;
          if (_safeTypeFilter == 'INTER' && !s.isInterStateTax) return false;
          if (!_matchesDate(s.saleDate)) return false;
          return true;
        }).map((s) {
          final cgst = !s.isInterStateTax && s.igstAmount == 0
              ? (s.cgstAmount > 0 ? s.cgstAmount : s.gstAmount / 2)
              : 0.0;
          final sgst = !s.isInterStateTax && s.igstAmount == 0
              ? (s.sgstAmount > 0 ? s.sgstAmount : s.gstAmount / 2)
              : 0.0;
          final igst = s.isInterStateTax || s.igstAmount > 0
              ? (s.igstAmount > 0 ? s.igstAmount : s.gstAmount)
              : 0.0;

          return _ReportRowItem(
            cells: [
              Text(s.invoiceNumber, style: AppTextStyles.bodyBold),
              Text(s.partyName, style: AppTextStyles.bodyMedium),
              Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(s.taxableAmount), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(cgst), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(sgst), style: AppTextStyles.bodySmall),
              Text(
                Formatters.formatCurrency(igst),
                style: AppTextStyles.bodySmall.copyWith(color: s.isInterStateTax ? Colors.purple : null),
              ),
              Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
            ],
            stringValues: [
              s.invoiceNumber,
              s.partyName,
              Formatters.formatDate(s.saleDate),
              Formatters.formatCurrency(s.taxableAmount),
              Formatters.formatCurrency(cgst),
              Formatters.formatCurrency(sgst),
              Formatters.formatCurrency(igst),
              Formatters.formatCurrency(s.totalAmount),
            ],
          );
        }).toList();

      case 4: // Project Costing
        return db.projects.where((pr) {
          if (query.isNotEmpty &&
              !pr.name.toLowerCase().contains(query) &&
              !(pr.customerName?.toLowerCase().contains(query) ?? false) &&
              !(pr.architectName?.toLowerCase().contains(query) ?? false)) {
            return false;
          }
          if (_safeStatusFilter != 'ALL' && pr.status.name.toLowerCase() != _safeStatusFilter.toLowerCase()) {
            return false;
          }
          if (!_matchesDate(pr.startDate)) return false;
          return true;
        }).map((pr) {
          final prSales = pr.totalSalesAmount > 0
              ? pr.totalSalesAmount
              : db.sales
                  .where((s) => s.projectId == pr.id && s.documentType == SalesDocumentType.invoice && s.status != SaleStatus.cancelled)
                  .fold(0.0, (s, sale) => s + sale.totalAmount);
          final prPurchases = db.purchases.where((p) => p.projectId == pr.id).fold(0.0, (s, p) => s + p.totalAmount);
          final prExpenses = db.expenses.where((e) => e.projectId == pr.id).fold(0.0, (s, e) => s + e.amount);
          final margin = prSales - prPurchases - prExpenses;

          return _ReportRowItem(
            cells: [
              Text(pr.name, style: AppTextStyles.bodyBold),
              Text(pr.customerName ?? pr.architectName ?? '-', style: AppTextStyles.bodyMedium),
              Text(Formatters.formatCurrency(prSales), style: AppTextStyles.bodyBold),
              Text(Formatters.formatCurrency(prPurchases), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(prExpenses), style: AppTextStyles.bodySmall),
              Text(
                Formatters.formatCurrency(margin),
                style: AppTextStyles.bodyBold.copyWith(color: margin >= 0 ? AppColors.successText : AppColors.dangerText),
              ),
              ErpStatusBadge.neutral(pr.statusLabel),
            ],
            stringValues: [
              pr.name,
              pr.customerName ?? pr.architectName ?? '-',
              Formatters.formatCurrency(prSales),
              Formatters.formatCurrency(prPurchases),
              Formatters.formatCurrency(prExpenses),
              Formatters.formatCurrency(margin),
              pr.statusLabel,
            ],
          );
        }).toList();

      case 5: // Expenses
        return db.expenses.where((exp) {
          if (query.isNotEmpty &&
              !exp.expenseNumber.toLowerCase().contains(query) &&
              !exp.categoryName.toLowerCase().contains(query) &&
              !(exp.description?.toLowerCase().contains(query) ?? false) &&
              !(exp.projectName?.toLowerCase().contains(query) ?? false)) {
            return false;
          }
          if (_safeTypeFilter != 'ALL') {
            final cat = _safeTypeFilter.toLowerCase();
            final matchesCatEnum = exp.category.name.toLowerCase() == cat;
            final matchesCatName = exp.categoryName.toLowerCase().replaceAll(' ', '') == cat;
            if (!matchesCatEnum && !matchesCatName) return false;
          }
          if (!_matchesDate(exp.expenseDate)) return false;
          return true;
        }).map((exp) {
          return _ReportRowItem(
            cells: [
              Text(exp.expenseNumber, style: AppTextStyles.bodyBold),
              Text(exp.categoryName, style: AppTextStyles.bodyMedium),
              Text(exp.description ?? '-', style: AppTextStyles.bodySmall),
              Text(exp.projectName ?? 'General Overhead', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
              Text(Formatters.formatDate(exp.expenseDate), style: AppTextStyles.bodySmall),
              Text(exp.paymentMethod.toUpperCase(), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(exp.amount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
            ],
            stringValues: [
              exp.expenseNumber,
              exp.categoryName,
              exp.description ?? '-',
              exp.projectName ?? 'General Overhead',
              Formatters.formatDate(exp.expenseDate),
              exp.paymentMethod.toUpperCase(),
              Formatters.formatCurrency(exp.amount),
            ],
          );
        }).toList();

      case 6: // Commission
        return db.architects.where((a) {
          if (query.isNotEmpty &&
              !a.name.toLowerCase().contains(query) &&
              !a.companyName.toLowerCase().contains(query) &&
              !a.mobile.contains(query)) {
            return false;
          }
          if (_safeStatusFilter == 'PENDING' && a.pendingCommission <= 0) return false;
          if (_safeStatusFilter == 'APPROVED' && a.approvedCommission <= 0) return false;
          if (_safeStatusFilter == 'PAID' && a.paidCommission <= 0) return false;
          if (_startDate != null || _endDate != null) {
            final aComms = db.commissions.where((c) => c.architectId == a.id).toList();
            final hasMatchingComm = aComms.any((c) => _matchesDate(c.generatedDate));
            final hasMatchingSale = db.sales.any((s) => s.architectId == a.id && _matchesDate(s.saleDate));
            if (!hasMatchingComm && !hasMatchingSale) return false;
          }
          return true;
        }).map((a) {
          final aComms = db.commissions.where((c) => c.architectId == a.id).toList();
          final commEarned = aComms.where((c) => c.status != CommissionStatus.rejected).fold(0.0, (s, c) => s + c.commissionAmount);
          final commPending = aComms.where((c) => c.status == CommissionStatus.generated).fold(0.0, (s, c) => s + c.commissionAmount);
          final commApproved = aComms.where((c) => c.status == CommissionStatus.approved).fold(0.0, (s, c) => s + c.commissionAmount);
          final commPaid = aComms.where((c) => c.status == CommissionStatus.paid).fold(0.0, (s, c) => s + c.commissionAmount);

          final invComms = db.sales
              .where((s) => s.architectId == a.id && s.documentType == SalesDocumentType.invoice && s.status != SaleStatus.cancelled)
              .fold(0.0, (s, sale) => s + sale.architectCommissionAmount);

          final displayEarned = a.totalCommissionEarned > 0 ? a.totalCommissionEarned : (commEarned > 0 ? commEarned : invComms);
          final displayPending = a.pendingCommission > 0 ? a.pendingCommission : (commPending > 0 ? commPending : (commEarned == 0 ? invComms : 0.0));
          final displayApproved = a.approvedCommission > 0 ? a.approvedCommission : commApproved;
          final displayPaid = a.paidCommission > 0 ? a.paidCommission : commPaid;

          return _ReportRowItem(
            cells: [
              Text(a.name, style: AppTextStyles.bodyBold),
              Text(a.companyName.isNotEmpty ? a.companyName : a.mobile, style: AppTextStyles.bodySmall),
              Text('${a.defaultCommissionRate}% Rate', style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(displayEarned), style: AppTextStyles.bodyBold),
              Text(Formatters.formatCurrency(displayPending), style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
              Text(Formatters.formatCurrency(displayApproved), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(displayPaid), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
            ],
            stringValues: [
              a.name,
              a.companyName.isNotEmpty ? a.companyName : a.mobile,
              '${a.defaultCommissionRate}% Rate',
              Formatters.formatCurrency(displayEarned),
              Formatters.formatCurrency(displayPending),
              Formatters.formatCurrency(displayApproved),
              Formatters.formatCurrency(displayPaid),
            ],
          );
        }).toList();

      case 7: // Financial Balance
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

        final allItems = [
          _ReportRowItem(
            cells: [
              Text('Customer Accounts Receivable', style: AppTextStyles.bodyBold),
              Text('Current Asset (Collections Due)', style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(custRec), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
              const Text('-', style: TextStyle(fontSize: 12)),
              Text(Formatters.formatCurrency(custRec), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
            ],
            stringValues: [
              'Customer Accounts Receivable',
              'Current Asset (Collections Due)',
              Formatters.formatCurrency(custRec),
              '-',
              Formatters.formatCurrency(custRec),
            ],
          ),
          _ReportRowItem(
            cells: [
              Text('Raw Material Stock Assets', style: AppTextStyles.bodyBold),
              Text('Inventory Asset (Raw Inventory)', style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(rawVal), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
              const Text('-', style: TextStyle(fontSize: 12)),
              Text(Formatters.formatCurrency(rawVal), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
            ],
            stringValues: [
              'Raw Material Stock Assets',
              'Inventory Asset (Raw Stock)',
              Formatters.formatCurrency(rawVal),
              '-',
              Formatters.formatCurrency(rawVal),
            ],
          ),
          _ReportRowItem(
            cells: [
              Text('Finished Goods Stock Assets', style: AppTextStyles.bodyBold),
              Text('Inventory Asset (Produced & Purchased Goods)', style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(fgVal), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
              const Text('-', style: TextStyle(fontSize: 12)),
              Text(Formatters.formatCurrency(fgVal), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
            ],
            stringValues: [
              'Finished Goods Stock Assets',
              'Inventory Asset (Produced & Purchased)',
              Formatters.formatCurrency(fgVal),
              '-',
              Formatters.formatCurrency(fgVal),
            ],
          ),
          _ReportRowItem(
            cells: [
              Text('Vendor Accounts Payable', style: AppTextStyles.bodyBold),
              Text('Current Liability (Procurement Dues)', style: AppTextStyles.bodySmall),
              const Text('-', style: TextStyle(fontSize: 12)),
              Text(Formatters.formatCurrency(venPay), style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
              Text(
                venPay > 0 ? '-${Formatters.formatCurrency(venPay)}' : Formatters.formatCurrency(0),
                style: AppTextStyles.bodyBold.copyWith(color: venPay > 0 ? AppColors.dangerText : AppColors.textMuted),
              ),
            ],
            stringValues: [
              'Vendor Accounts Payable',
              'Current Liability (Procurement Dues)',
              '-',
              Formatters.formatCurrency(venPay),
              venPay > 0 ? '-${Formatters.formatCurrency(venPay)}' : Formatters.formatCurrency(0),
            ],
          ),
          _ReportRowItem(
            cells: [
              Text('Architect Commission Payable', style: AppTextStyles.bodyBold),
              Text('Current Liability (Partner Payouts)', style: AppTextStyles.bodySmall),
              const Text('-', style: TextStyle(fontSize: 12)),
              Text(Formatters.formatCurrency(commPay), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
              Text(
                commPay > 0 ? '-${Formatters.formatCurrency(commPay)}' : Formatters.formatCurrency(0),
                style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple),
              ),
            ],
            stringValues: [
              'Architect Commission Payable',
              'Current Liability (Partner Payouts)',
              '-',
              Formatters.formatCurrency(commPay),
              commPay > 0 ? '-${Formatters.formatCurrency(commPay)}' : Formatters.formatCurrency(0),
            ],
          ),
          if (storeCredits > 0)
            _ReportRowItem(
              cells: [
                Text('Customer Store Credit Notes', style: AppTextStyles.bodyBold),
                Text('Current Liability (Customer Wallets)', style: AppTextStyles.bodySmall),
                const Text('-', style: TextStyle(fontSize: 12)),
                Text(Formatters.formatCurrency(storeCredits), style: AppTextStyles.bodyBold.copyWith(color: AppColors.warningText)),
                Text(
                  storeCredits > 0 ? '-${Formatters.formatCurrency(storeCredits)}' : Formatters.formatCurrency(0),
                  style: AppTextStyles.bodyBold.copyWith(color: storeCredits > 0 ? AppColors.warningText : AppColors.textMuted),
                ),
              ],
              stringValues: [
                'Customer Store Credit Notes',
                'Current Liability (Customer Wallets)',
                '-',
                Formatters.formatCurrency(storeCredits),
                storeCredits > 0 ? '-${Formatters.formatCurrency(storeCredits)}' : Formatters.formatCurrency(0),
              ],
            ),
          _ReportRowItem(
            cells: [
              Text('Net Working Capital & Operating Balance', style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
              Text('Total Assets - Liabilities', style: AppTextStyles.bodyBold),
              Text(Formatters.formatCurrency(totalAssets), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
              Text(Formatters.formatCurrency(totalLiabilities), style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
              Text(
                Formatters.formatCurrency(netWorkingCap),
                style: AppTextStyles.bodyBold.copyWith(
                  color: netWorkingCap >= 0 ? AppColors.primary : AppColors.dangerText,
                  fontSize: 14,
                ),
              ),
            ],
            stringValues: [
              'Net Working Capital & Operating Balance',
              'Total Assets - Total Liabilities',
              Formatters.formatCurrency(totalAssets),
              Formatters.formatCurrency(totalLiabilities),
              Formatters.formatCurrency(netWorkingCap),
            ],
          ),
        ];

        return allItems.where((it) {
          if (query.isNotEmpty) {
            final head = it.stringValues[0].toLowerCase();
            final desc = it.stringValues[1].toLowerCase();
            if (!head.contains(query) && !desc.contains(query)) return false;
          }
          if (_safeStatusFilter == 'ASSET' && !it.stringValues[1].toLowerCase().contains('asset')) return false;
          if (_safeStatusFilter == 'LIABILITY' && !it.stringValues[1].toLowerCase().contains('liability')) return false;
          return true;
        }).toList();
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
        final totalUnits = db.productionOrders.fold(0.0, (s, p) {
          final q = p.actualQuantityProduced > 0 ? p.actualQuantityProduced : (p.status == ProductionStatus.completed ? p.plannedQuantity : 0.0);
          return s + q;
        }).toInt();
        return {
          'Total Manufacturing Cost': Formatters.formatCurrency(totalProdCost),
          'Total Units Produced': '$totalUnits Units',
          'Completed Batches': '${db.productionOrders.where((p) => p.status == ProductionStatus.completed).length} Batches',
          'Avg Unit Cost': Formatters.formatCurrency(totalUnits > 0 ? totalProdCost / totalUnits : 0),
        };
      case 3:
        final returnsAmt = db.totalSalesReturnsAmount.abs();
        return {
          'Gross Turnover': Formatters.formatCurrency(db.totalInvoicedRevenue.abs()),
          'Sales Returns': returnsAmt > 0 ? Formatters.formatCurrency(returnsAmt) : Formatters.formatCurrency(0),
          'Net Revenue': Formatters.formatCurrency(db.netSalesRevenue.abs()),
          'Customer Receivables': Formatters.formatCurrency(db.pendingCustomerPayments.abs()),
        };
      case 4:
        final totalContracted = db.projects.fold(0.0, (s, p) {
          final pSales = p.totalSalesAmount > 0
              ? p.totalSalesAmount
              : db.sales
                  .where((sl) => sl.projectId == p.id && sl.documentType == SalesDocumentType.invoice && sl.status != SaleStatus.cancelled)
                  .fold(0.0, (sm, sl) => sm + sl.totalAmount);
          return s + pSales;
        });
        final totalCommAllocated = db.projects.fold(0.0, (s, p) {
          final pComms = p.totalCommissionAmount > 0
              ? p.totalCommissionAmount
              : db.commissions.where((c) => c.projectId == p.id).fold(0.0, (sm, c) => sm + c.commissionAmount);
          return s + pComms;
        });
        return {
          'Active Projects': '${db.projects.length} Projects',
          'Contracted Revenue': Formatters.formatCurrency(totalContracted),
          'Commission Allocated': Formatters.formatCurrency(totalCommAllocated),
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
        final totalEarned = db.architects.fold(0.0, (s, a) {
          final aComms = db.commissions.where((c) => c.architectId == a.id).toList();
          final commEarned = aComms.where((c) => c.status != CommissionStatus.rejected).fold(0.0, (sum, c) => sum + c.commissionAmount);
          final invComms = db.sales
              .where((sl) => sl.architectId == a.id && sl.documentType == SalesDocumentType.invoice && sl.status != SaleStatus.cancelled)
              .fold(0.0, (sum, sale) => sum + sale.architectCommissionAmount);
          return s + (a.totalCommissionEarned > 0 ? a.totalCommissionEarned : (commEarned > 0 ? commEarned : invComms));
        });
        final totalPaid = db.architects.fold(0.0, (s, a) {
          final commPaid = db.commissions.where((c) => c.architectId == a.id && c.status == CommissionStatus.paid).fold(0.0, (sum, c) => sum + c.commissionAmount);
          return s + (a.paidCommission > 0 ? a.paidCommission : commPaid);
        });
        return {
          'Commission Earned': Formatters.formatCurrency(totalEarned),
          'Pending Dues': Formatters.formatCurrency(db.pendingCommissionAmount),
          'Disbursed to Date': Formatters.formatCurrency(totalPaid),
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
    final allFilteredItems = _getFilteredData(db, activeIndex);
    final stringRows = allFilteredItems.map((it) => it.stringValues).toList();
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
    final allFilteredItems = _getFilteredData(db, activeIndex);
    final stringRows = allFilteredItems.map((it) => it.stringValues).toList();
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

  Widget _buildFilterDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    double? width,
  }) {
    return Container(
      height: 38,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: AppTextStyles.bodyMedium.copyWith(fontSize: 12.5),
          items: items,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _currentPage = 0;
              });
              onChanged(val);
            }
          },
        ),
      ),
    );
  }

  List<Widget> _buildDateRangeFilterControls(BuildContext context) {
    return [
      ErpDateFilterBox(
        startDate: _startDate,
        endDate: _endDate,
        onDateRangeSelected: (start, end) {
          setState(() {
            _startDate = start;
            _endDate = end;
            _currentPage = 0;
          });
        },
      ),
    ];
  }

  Widget _buildFilterBar(BuildContext context, MockDatabaseService db, int activeIndex) {
    String searchHint = 'Search records...';
    List<Widget> filterControls = [];

    switch (activeIndex) {
      case 0: // Inventory
        searchHint = 'Search by item name or SKU...';
        filterControls = [
          _buildFilterDropdown(
            value: _safeTypeFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Item Types')),
              DropdownMenuItem(value: 'RAW', child: Text('Raw Materials')),
              DropdownMenuItem(value: 'FG', child: Text('Finished Goods')),
            ],
            onChanged: (v) => setState(() => _typeFilter = v!),
          ),
          const SizedBox(width: 8),
          _buildFilterDropdown(
            value: _safeStatusFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Stock Levels')),
              DropdownMenuItem(value: 'LOW', child: Text('Low Stock Alerts')),
              DropdownMenuItem(value: 'IN_STOCK', child: Text('In Stock')),
              DropdownMenuItem(value: 'OUT_OF_STOCK', child: Text('Out of Stock')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v!),
          ),
        ];
        break;

      case 1: // Purchase
        searchHint = 'Search by PO# or vendor...';
        filterControls = [
          _buildFilterDropdown(
            value: _safeStatusFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Status')),
              DropdownMenuItem(value: 'saved', child: Text('Saved')),
              DropdownMenuItem(value: 'partialPaid', child: Text('Partially Paid')),
              DropdownMenuItem(value: 'paid', child: Text('Paid')),
              DropdownMenuItem(value: 'draft', child: Text('Draft')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v!),
          ),
          const SizedBox(width: 8),
          _buildFilterDropdown(
            value: _safeTypeFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Products')),
              DropdownMenuItem(value: 'RAW', child: Text('Raw Materials')),
              DropdownMenuItem(value: 'FG', child: Text('Finished Products')),
            ],
            onChanged: (v) => setState(() => _typeFilter = v!),
          ),
          const SizedBox(width: 8),
          ..._buildDateRangeFilterControls(context),
        ];
        break;

      case 2: // Production
        searchHint = 'Search batch ref or product...';
        filterControls = [
          _buildFilterDropdown(
            value: _safeStatusFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Status')),
              DropdownMenuItem(value: 'planned', child: Text('Planned')),
              DropdownMenuItem(value: 'inProgress', child: Text('In Progress')),
              DropdownMenuItem(value: 'completed', child: Text('Completed')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v!),
          ),
          const SizedBox(width: 8),
          ..._buildDateRangeFilterControls(context),
        ];
        break;

      case 3: // Sales & GST
        searchHint = 'Search invoice# or customer...';
        filterControls = [
          _buildFilterDropdown(
            value: _safeStatusFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Documents & Status')),
              DropdownMenuItem(value: 'invoice', child: Text('Tax Invoices')),
              DropdownMenuItem(value: 'salesReturn', child: Text('Sales Returns')),
              DropdownMenuItem(value: 'salesOrder', child: Text('Sales Orders')),
              DropdownMenuItem(value: 'delivery', child: Text('Delivery Challans')),
              DropdownMenuItem(value: 'proformaInvoice', child: Text('Proforma Invoices')),
              DropdownMenuItem(value: 'quotation', child: Text('Quotations')),
              DropdownMenuItem(value: 'paid', child: Text('Paid')),
              DropdownMenuItem(value: 'due', child: Text('Pending Balance')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v!),
          ),
          const SizedBox(width: 8),
          _buildFilterDropdown(
            value: _safeTypeFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Tax Modes')),
              DropdownMenuItem(value: 'INTRA', child: Text('Intra-State (CGST+SGST)')),
              DropdownMenuItem(value: 'INTER', child: Text('Inter-State (IGST)')),
            ],
            onChanged: (v) => setState(() => _typeFilter = v!),
          ),
          const SizedBox(width: 8),
          ..._buildDateRangeFilterControls(context),
        ];
        break;

      case 4: // Project Costing
        searchHint = 'Search project, client or architect...';
        filterControls = [
          _buildFilterDropdown(
            value: _safeStatusFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Status')),
              DropdownMenuItem(value: 'planned', child: Text('Planned')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'completed', child: Text('Completed')),
              DropdownMenuItem(value: 'closed', child: Text('Closed')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v!),
          ),
          const SizedBox(width: 8),
          ..._buildDateRangeFilterControls(context),
        ];
        break;

      case 5: // Expenses
        searchHint = 'Search expense#, category, notes...';
        filterControls = [
          _buildFilterDropdown(
            value: _safeTypeFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
              DropdownMenuItem(value: 'transportation', child: Text('Transportation')),
              DropdownMenuItem(value: 'courier', child: Text('Courier')),
              DropdownMenuItem(value: 'fuel', child: Text('Fuel')),
              DropdownMenuItem(value: 'labour', child: Text('Labour')),
              DropdownMenuItem(value: 'electricity', child: Text('Electricity')),
              DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
              DropdownMenuItem(value: 'officeExpense', child: Text('Office Expense')),
              DropdownMenuItem(value: 'productionExpense', child: Text('Production Expense')),
              DropdownMenuItem(value: 'projectExpense', child: Text('Project Expense')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _typeFilter = v!),
          ),
          const SizedBox(width: 8),
          ..._buildDateRangeFilterControls(context),
        ];
        break;

      case 6: // Commission
        searchHint = 'Search architect name or mobile...';
        filterControls = [
          _buildFilterDropdown(
            value: _safeStatusFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Payout Status')),
              DropdownMenuItem(value: 'PENDING', child: Text('Pending Payout')),
              DropdownMenuItem(value: 'APPROVED', child: Text('Approved Payout')),
              DropdownMenuItem(value: 'PAID', child: Text('Paid to Date')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v!),
          ),
          const SizedBox(width: 8),
          ..._buildDateRangeFilterControls(context),
        ];
        break;

      case 7: // Financial Balance
      default:
        searchHint = 'Search balance sheet head...';
        filterControls = [
          _buildFilterDropdown(
            value: _safeStatusFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Classifications')),
              DropdownMenuItem(value: 'ASSET', child: Text('Assets & Receivables')),
              DropdownMenuItem(value: 'LIABILITY', child: Text('Liabilities & Payables')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v!),
          ),
        ];
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        final searchBox = SizedBox(
          width: isCompact ? double.infinity : 260,
          height: 38,
          child: TextField(
            controller: _safeSearchController,
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
            decoration: InputDecoration(
              hintText: searchHint,
              hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted, fontSize: 12.5),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
              suffixIcon: _safeSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _safeSearchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _currentPage = 0;
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _currentPage = 0;
              });
            },
          ),
        );

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            searchBox,
            ...filterControls,
          ],
        );
      },
    );
  }

  Widget _buildPaginationBar({
    required int totalRecords,
    required int totalPages,
    required int startIndex,
    required int endIndex,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;

        final infoText = Text(
          'Showing ${totalRecords == 0 ? 0 : startIndex + 1} to $endIndex of $totalRecords records',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        );

        final pageSizeSelector = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rows:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: 6),
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _safePageSize,
                  isDense: true,
                  style: AppTextStyles.bodySmall,
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                    DropdownMenuItem(value: 100, child: Text('100')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 0;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        );

        // Page selector buttons
        final List<Widget> pageButtons = [];

        // Previous button
        pageButtons.add(
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: _safeCurrentPage > 0
                ? () => setState(() => _currentPage = _safeCurrentPage - 1)
                : null,
          ),
        );

        // Determine visible page numbers
        List<int> pagesToShow = [];
        if (totalPages <= 7) {
          pagesToShow = List.generate(totalPages, (i) => i);
        } else {
          pagesToShow.add(0);
          int start = max(1, _safeCurrentPage - 1);
          int end = min(totalPages - 2, _safeCurrentPage + 1);
          if (start > 1) pagesToShow.add(-1); // Ellipsis
          for (int i = start; i <= end; i++) {
            pagesToShow.add(i);
          }
          if (end < totalPages - 2) pagesToShow.add(-2); // Ellipsis
          pagesToShow.add(totalPages - 1);
        }

        for (final p in pagesToShow) {
          if (p < 0) {
            pageButtons.add(
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: Colors.grey)),
              ),
            );
          } else {
            final isCurrent = p == _safeCurrentPage;
            pageButtons.add(
              InkWell(
                onTap: () => setState(() => _currentPage = p),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isCurrent ? null : Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    '${p + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }
        }

        // Next button
        pageButtons.add(
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: _safeCurrentPage < totalPages - 1
                ? () => setState(() => _currentPage = _safeCurrentPage + 1)
                : null,
          ),
        );

        final controlsRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: pageButtons,
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  infoText,
                  pageSizeSelector,
                ],
              ),
              const SizedBox(height: 12),
              Center(child: controlsRow),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                infoText,
                const SizedBox(width: 16),
                pageSizeSelector,
              ],
            ),
            controlsRow,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final activeIndex = _tabController.index;
    final kpis = _getReportKpisMap(db, activeIndex);

    // Filtered data for active tab
    final allFilteredItems = _getFilteredData(db, activeIndex);
    final totalRecords = allFilteredItems.length;
    final totalPages = max(1, (totalRecords / _safePageSize).ceil());

    if (_safeCurrentPage >= totalPages) {
      _currentPage = max(0, totalPages - 1);
    }

    final startIndex = _safeCurrentPage * _safePageSize;
    final endIndex = min(startIndex + _safePageSize, totalRecords);
    final pagedItems = totalRecords > 0 ? allFilteredItems.sublist(startIndex, endIndex) : <_ReportRowItem>[];
    final pagedRows = pagedItems.map((it) => it.cells).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 650;
              final titleBlock = Text(
                'Stock sources, purchase types, expense registers, and GST tax breakup statements',
                style: AppTextStyles.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                    isOutlined: false,
                    isPrimary: true,
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
                  childAspectRatio: width < 450 ? 2.4 : (crossAxisCount >= 4 ? 2.8 : 2.4),
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

          // Modern Filter Bar
          _buildFilterBar(context, db, activeIndex),
          const SizedBox(height: 16),

          // Data Table for Active Tab (Paginated for instant load!)
          ErpDataTable(
            columns: _getReportColumns(activeIndex),
            rows: pagedRows,
            emptyState: Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_outlined, size: 40, color: AppColors.textMuted.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text('No records matching the selected filters', style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 8),
                  if (_safeSearchQuery.isNotEmpty || _safeStatusFilter != 'ALL' || _safeTypeFilter != 'ALL' || _startDate != null || _endDate != null)
                    TextButton.icon(
                      onPressed: () {
                        _safeSearchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _statusFilter = 'ALL';
                          _typeFilter = 'ALL';
                          _startDate = null;
                          _endDate = null;
                          _currentPage = 0;
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset All Filters'),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bottom Pagination Bar
          _buildPaginationBar(
            totalRecords: totalRecords,
            totalPages: totalPages,
            startIndex: startIndex,
            endIndex: endIndex,
          ),
        ],
      ),
    );
  }
}
