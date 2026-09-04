import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class SalesInvoiceListScreen extends ConsumerStatefulWidget {
  const SalesInvoiceListScreen({super.key});

  @override
  ConsumerState<SalesInvoiceListScreen> createState() => _SalesInvoiceListScreenState();
}

class _SalesInvoiceListScreenState extends ConsumerState<SalesInvoiceListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
<<<<<<< Updated upstream
    final sales = db.sales.where((s) {
      return s.invoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.partyName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s.projectName != null && s.projectName!.toLowerCase().contains(_searchQuery.toLowerCase()));
=======
    final currentSection = ref.watch(currentNavSectionProvider);

    // 1. Dashboard summary data calculation
    final totalQuotations = db.sales.where((s) => s.documentType == SalesDocumentType.quotation).length;
    final pendingQuotations = db.sales.where((s) => s.documentType == SalesDocumentType.quotation && (s.quotationStatus == QuotationStatus.sent || s.quotationStatus == QuotationStatus.draft || s.quotationStatus == null)).length;
    final approvedQuotations = db.sales.where((s) => s.documentType == SalesDocumentType.quotation && s.quotationStatus == QuotationStatus.approved).length;

    final totalOrders = db.sales.where((s) => s.documentType == SalesDocumentType.salesOrder).length;
    final pendingOrders = db.sales.where((s) => s.documentType == SalesDocumentType.salesOrder && (s.salesOrderStatus == SalesOrderStatus.pending || s.salesOrderStatus == SalesOrderStatus.confirmed || s.salesOrderStatus == SalesOrderStatus.inProgress)).length;
    final completedOrders = db.sales.where((s) => s.documentType == SalesDocumentType.salesOrder && s.salesOrderStatus == SalesOrderStatus.done).length;

    final totalSalesAmount = db.sales.where((s) => s.documentType == SalesDocumentType.invoice).fold(0.0, (sum, s) => sum + s.totalAmount);
    final paidSalesAmount = db.sales.where((s) => s.documentType == SalesDocumentType.invoice).fold(0.0, (sum, s) => sum + s.paidAmount);
    final outstandingAmount = db.sales.where((s) => s.documentType == SalesDocumentType.invoice).fold(0.0, (sum, s) => sum + s.pendingAmount);

    final totalReturns = db.sales.where((s) => s.documentType == SalesDocumentType.salesReturn).length;

    // 2. Map view configs based on active NavSection
    String pageTitle = 'Sales Module';
    String pageSubtitle = 'Create, approve and manage customers quotations, dispatches and invoice documents';
    Widget? createButton;
    List<ErpColumn> tableColumns = [];
    List<List<Widget>> tableRows = [];

    // Filter local lists
    final activeSalesList = db.sales.where((s) {
      // Document Type Filter
      switch (currentSection) {
        case ErpNavSection.quotations:
          if (s.documentType != SalesDocumentType.quotation) return false;
          break;
        case ErpNavSection.salesOrders:
          if (s.documentType != SalesDocumentType.salesOrder) return false;
          break;
        case ErpNavSection.salesInvoiceList:
          if (s.documentType != SalesDocumentType.invoice) return false;
          break;
        case ErpNavSection.salesReturns:
          if (s.documentType != SalesDocumentType.salesReturn) return false;
          break;
        default:
          return false;
      }

      // Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchNo = s.invoiceNumber.toLowerCase().contains(query);
        final matchParty = s.partyName.toLowerCase().contains(query);
        final matchProduct = s.items.any((i) => i.finishedProductName.toLowerCase().contains(query) || i.finishedProductCode.toLowerCase().contains(query));
        final matchSO = s.salesOrderNumber?.toLowerCase().contains(query) ?? false;
        final matchQuote = s.quotationReferenceId?.toLowerCase().contains(query) ?? false;
        final matchArch = s.architectName?.toLowerCase().contains(query) ?? false;
        final matchPrj = s.projectName?.toLowerCase().contains(query) ?? false;
        final matchNotes = s.notes?.toLowerCase().contains(query) ?? false;
        if (!matchNo && !matchParty && !matchProduct && !matchSO && !matchQuote && !matchArch && !matchPrj && !matchNotes) return false;
      }

      // Status Dropdown Filter
      if (_statusFilter != null) {
        if (currentSection == ErpNavSection.quotations) {
          final qStatus = s.quotationStatus.toString().split('.').last.toLowerCase();
          if (qStatus != _statusFilter!.toLowerCase()) return false;
        } else if (currentSection == ErpNavSection.salesOrders) {
          final soStatus = s.salesOrderStatus.toString().split('.').last.toLowerCase();
          if (soStatus != _statusFilter!.toLowerCase()) return false;
        } else if (currentSection == ErpNavSection.salesInvoiceList) {
          final payStatus = s.status.toString().split('.').last.toLowerCase();
          if (payStatus != _statusFilter!.toLowerCase()) return false;
        } else if (currentSection == ErpNavSection.salesReturns) {
          final retStatus = s.salesReturnStatus.toString().split('.').last.toLowerCase();
          if (retStatus != _statusFilter!.toLowerCase()) return false;
        }
      }

      // Customer Filter
      if (_customerFilter != null && s.partyId != _customerFilter) return false;

      // Date Range Filter
      if (_dateRangeFilter != null) {
        if (s.saleDate.isBefore(_dateRangeFilter!.start) || s.saleDate.isAfter(_dateRangeFilter!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      return true;
>>>>>>> Stashed changes
    }).toList();

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
                  Text('Sales Invoices', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Customer and dealer invoices, project links, and architect commissions', style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'Create Invoice',
                icon: Icons.add,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSale,
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search sales invoice by number, customer/dealer or project...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Invoice No'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Party Name'),
              ErpColumn(title: 'Channel'),
              ErpColumn(title: 'Linked Project'),
              ErpColumn(title: 'Total Amount', isNumeric: true),
              ErpColumn(title: 'Paid', isNumeric: true),
              ErpColumn(title: 'Pending', isNumeric: true),
              ErpColumn(title: 'Commission', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: sales.map((s) {
              ErpStatusBadge badge;
              switch (s.status) {
                case SaleStatus.paid:
                case SaleStatus.completed:
                  badge = ErpStatusBadge.success('PAID');
                  break;
                case SaleStatus.partialPaid:
                  badge = ErpStatusBadge.warning('PARTIAL');
                  break;
                case SaleStatus.active:
                  badge = ErpStatusBadge.info('ACTIVE');
                  break;
                case SaleStatus.draft:
                  badge = ErpStatusBadge.neutral('DRAFT');
                  break;
                case SaleStatus.cancelled:
                  badge = ErpStatusBadge.danger('CANCELLED');
                  break;
              }

              return [
                Text(s.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
                Text(s.partyName, style: AppTextStyles.bodyMedium),
                Text(s.partyType == PartyType.customer ? 'Customer' : 'Dealer', style: AppTextStyles.bodySmall),
                Text(s.projectName ?? '-', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(s.paidAmount), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.successText)),
                Text(
                  Formatters.formatCurrency(s.pendingAmount),
                  style: AppTextStyles.bodyBold.copyWith(
                    color: s.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted,
                  ),
                ),
                Text(
                  s.architectCommissionAmount > 0 ? Formatters.formatCurrency(s.architectCommissionAmount) : '-',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.purple),
                ),
                badge,
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}
