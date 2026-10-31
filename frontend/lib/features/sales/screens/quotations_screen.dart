import 'dart:math';
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
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_toast.dart';
import '../../../core/widgets/figma_metric_card.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';
import '../widgets/sales_pdf_generator.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(databaseServiceProvider).loadQuotations());
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
          // 1. Header
          ErpSectionHeaderCard(
            icon: Icons.request_quote_outlined,
            title: 'Quotations & Commercial Estimates',
            badgeText: 'COMMERCIAL QUOTES',
            action: ErpButton(
              text: 'Create Quotation',
              icon: Icons.add,
              onPressed: () {
                ref.read(salesCreateDocTypeProvider.notifier).state = SalesDocumentType.quotation;
                ref.read(salesCreateSourceDocIdProvider.notifier).state = null;
                ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createQuotation;
              },
            ),
          ),
          const SizedBox(height: 18),

          // 2. Summary Metric Cards (Project Theme)
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 850
                  ? (constraints.maxWidth - (3 * 12)) / 4
                  : (constraints.maxWidth > 550 ? (constraints.maxWidth - 12) / 2 : double.infinity);
              final totalPipeline = db.quotations.fold(0.0, (sum, q) => sum + q.totalAmount);
              final sentCount = db.quotations.where((q) => q.quotationStatus == QuotationStatus.sent).length;
              final acceptedCount = db.quotations.where((q) => q.quotationStatus == QuotationStatus.accepted || q.quotationStatus == QuotationStatus.approved).length;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.request_quote_outlined,
                      iconColor: AppColors.primary,
                      title: 'Total Quotations',
                      value: '${db.quotations.length}',
                      subtext: 'Commercial Estimates',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.schedule_outlined,
                      iconColor: AppColors.warning,
                      title: 'Pending Review',
                      value: '$sentCount Quotes',
                      subtext: 'Awaiting Client Decision',
                      subtextColor: AppColors.warning,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppColors.success,
                      title: 'Accepted & Won',
                      value: '$acceptedCount Quotes',
                      subtext: 'Approved Pipeline',
                      subtextColor: AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.currency_rupee,
                      iconColor: AppColors.primary,
                      title: 'Pipeline Valuation',
                      value: Formatters.formatCurrency(totalPipeline),
                      subtext: 'Active Quote Value',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 3. Tabs: All, Draft, Sent, Accepted, Revisions/History, Rejected/Expired
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              onTap: (_) => setState(() {
                _currentPage = 0;
              }),
              tabs: [
                Tab(text: 'All Quotes (${db.quotations.length})'),
                Tab(text: 'Drafts (${db.quotations.where((q) => q.quotationStatus == QuotationStatus.draft).length})'),
                Tab(text: 'Sent / Pending (${db.quotations.where((q) => q.quotationStatus == QuotationStatus.sent).length})'),
                Tab(text: 'Accepted (${db.quotations.where((q) => q.quotationStatus == QuotationStatus.accepted || q.quotationStatus == QuotationStatus.approved).length})'),
                Tab(text: 'Revisions & Superseded (${db.quotations.where((q) => q.quotationStatus == QuotationStatus.superseded).length})'),
                Tab(text: 'Converted / Other (${db.quotations.where((q) => q.quotationStatus == QuotationStatus.converted || q.quotationStatus == QuotationStatus.rejected).length})'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Global Filters
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 450;
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ErpSearchInput(
                      hintText: 'Search quotation, client, project...',
                      initialValue: _searchQuery,
                      onChanged: (val) => setState(() {
                        _searchQuery = val;
                        _currentPage = 0;
                      }),
                    ),
                    const SizedBox(height: 10),
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
                  ],
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: ErpSearchInput(
                      hintText: 'Search quotation, client, project...',
                      initialValue: _searchQuery,
                      onChanged: (val) => setState(() {
                        _searchQuery = val;
                        _currentPage = 0;
                      }),
                    ),
                  ),
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
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 4. Quotations Table
          _buildQuotationsTable(context, ref, db),
        ],
      ),
    );
  }

  Widget _buildQuotationsTable(BuildContext context, WidgetRef ref, MockDatabaseService db) {
    List<Sale> filtered = db.quotations;

    // Filter by tab
    switch (_tabController.index) {
      case 1: // Drafts
        filtered = filtered.where((q) => q.quotationStatus == QuotationStatus.draft).toList();
        break;
      case 2: // Sent
        filtered = filtered.where((q) => q.quotationStatus == QuotationStatus.sent).toList();
        break;
      case 3: // Accepted
        filtered = filtered.where((q) => q.quotationStatus == QuotationStatus.accepted || q.quotationStatus == QuotationStatus.approved).toList();
        break;
      case 4: // Superseded Revisions
        filtered = filtered.where((q) => q.quotationStatus == QuotationStatus.superseded).toList();
        break;
      case 5: // Converted / Other
        filtered = filtered.where((q) => q.quotationStatus == QuotationStatus.converted || q.quotationStatus == QuotationStatus.rejected || q.quotationStatus == QuotationStatus.expired).toList();
        break;
      default:
        break;
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final qLower = _searchQuery.toLowerCase();
      filtered = filtered.where((q) {
        return q.invoiceNumber.toLowerCase().contains(qLower) ||
            q.partyName.toLowerCase().contains(qLower) ||
            (q.projectName != null && q.projectName!.toLowerCase().contains(qLower)) ||
            (q.salesExecutive != null && q.salesExecutive!.toLowerCase().contains(qLower));
      }).toList();
    }

    // Filter by date range
    if (_startDate != null) {
      final startDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      filtered = filtered.where((q) => !q.saleDate.isBefore(startDay)).toList();
    }
    if (_endDate != null) {
      final endDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      filtered = filtered.where((q) => !q.saleDate.isAfter(endDay)).toList();
    }

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgBorderRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.request_quote_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No quotations found matching your criteria', style: AppTextStyles.h3),
            const SizedBox(height: 6),
            Text('Create a new quotation or try adjusting your filter tab.', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }

    final totalCount = filtered.length;
    final maxPage = (totalCount / _pageSize).ceil();
    final effectivePage = maxPage == 0 ? 0 : min(_currentPage, maxPage - 1);
    final startIdx = effectivePage * _pageSize;
    final endIdx = min(startIdx + _pageSize, totalCount);
    final paginatedQuotes = totalCount == 0 ? <Sale>[] : filtered.sublist(startIdx, endIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ErpDataTable(
          columns: const [
            ErpColumn(title: 'Quote Number'),
            ErpColumn(title: 'Date'),
            ErpColumn(title: 'Customer / Client'),
            ErpColumn(title: 'Project'),
            ErpColumn(title: 'Grand Total', isNumeric: true),
            ErpColumn(title: 'Valid Till'),
        ErpColumn(title: 'Status'),
        ErpColumn(title: 'Actions'),
      ],
      rows: paginatedQuotes.map((quote) {
        ErpStatusBadge badge;
        switch (quote.quotationStatus) {
          case QuotationStatus.accepted:
          case QuotationStatus.approved:
            badge = ErpStatusBadge.success('ACCEPTED');
            break;
          case QuotationStatus.sent:
            badge = ErpStatusBadge.info('SENT');
            break;
          case QuotationStatus.draft:
            badge = ErpStatusBadge.neutral('DRAFT');
            break;
          case QuotationStatus.superseded:
            badge = ErpStatusBadge.warning('SUPERSEDED (R${quote.revisionNumber})');
            break;
          case QuotationStatus.converted:
            badge = ErpStatusBadge.success('CONVERTED TO PI');
            break;
          case QuotationStatus.rejected:
            badge = ErpStatusBadge.danger('REJECTED');
            break;
          case QuotationStatus.expired:
            badge = ErpStatusBadge.danger('EXPIRED');
            break;
          default:
            badge = ErpStatusBadge.neutral('DRAFT');
        }

        return [
          InkWell(
            onTap: () {
              SalesPdfGeneratorDialog.show(context, quote, db);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  quote.invoiceNumber,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primary),
                ),
                if (quote.revisionNumber > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text('R${quote.revisionNumber}', style: const TextStyle(color: AppColors.purple, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
          Text(Formatters.formatDate(quote.saleDate), style: AppTextStyles.bodySmall),
          Text(quote.partyName, style: AppTextStyles.bodyMedium),
          Text(quote.projectName ?? '-', style: AppTextStyles.bodySmall),
          Text(Formatters.formatCurrency(quote.totalAmount), style: AppTextStyles.bodyBold),
          Text(
            quote.validUntil != null ? Formatters.formatDate(quote.validUntil!) : '-',
            style: AppTextStyles.bodySmall.copyWith(
              color: quote.validUntil != null && quote.validUntil!.isBefore(DateTime.now()) ? AppColors.dangerText : null,
            ),
          ),
          badge,
          _buildQuoteActionMenu(context, ref, quote, db),
        ];
      }).toList(),
    ),
    if (filtered.isNotEmpty) ...[
      const SizedBox(height: 12),
      ErpPaginationBar(
        totalRecords: totalCount,
        currentPage: effectivePage,
        pageSize: _pageSize,
        onPageChanged: (newPage) => setState(() => _currentPage = newPage),
        onPageSizeChanged: (newSize) => setState(() {
          _pageSize = newSize;
          _currentPage = 0;
        }),
      ),
    ],
  ],
);
  }

  Widget _buildQuoteActionMenu(BuildContext context, WidgetRef ref, Sale quote, MockDatabaseService db) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // IconButton(
        //   icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 18),
        //   tooltip: 'Preview PDF',
        //   onPressed: () => SalesPdfGeneratorDialog.show(context, quote, db),
        // ),
        PopupMenuButton<String>(
          tooltip: 'Actions',
          icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
          onSelected: (action) => _handleAction(context, ref, action, quote, db),
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text('View Details')),
                ],
              ),
            ),
            if (quote.quotationStatus == QuotationStatus.draft)
              const PopupMenuItem(
                value: 'send',
                child: Row(
                  children: [
                    Icon(Icons.send_outlined, size: 16, color: AppColors.info),
                    SizedBox(width: 8),
                    Expanded(child: Text('Mark as Sent')),
                  ],
                ),
              ),
            if (quote.quotationStatus == QuotationStatus.sent) ...[
              const PopupMenuItem(
                value: 'accept',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                    SizedBox(width: 8),
                    Expanded(child: Text('Accept Quote')),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reject',
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
                    SizedBox(width: 8),
                    Expanded(child: Text('Reject Quote')),
                  ],
                ),
              ),
            ],
            if (quote.quotationStatus == QuotationStatus.accepted || quote.quotationStatus == QuotationStatus.approved)
              const PopupMenuItem(
                value: 'proforma',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(child: Text('Convert to Proforma')),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action, Sale quote, MockDatabaseService db) async {
    try {
      switch (action) {
        case 'view':
          SalesPdfGeneratorDialog.show(context, quote, db);
          break;
        case 'send':
          await db.updateQuotationStatusAsync(quote.id, QuotationStatus.sent.name);
          if (!context.mounted) return;
ErpToast.showInfo(context, 'Quotation ${quote.invoiceNumber} marked as SENT to client.');
          break;
        case 'accept':
          await db.updateQuotationStatusAsync(quote.id, QuotationStatus.accepted.name);
          if (!context.mounted) return;
ErpToast.showSuccess(context, 'Quotation ${quote.invoiceNumber} ACCEPTED! You can now generate Proforma Invoice.');
          break;
        case 'reject':
          await db.updateQuotationStatusAsync(quote.id, QuotationStatus.rejected.name);
          if (!context.mounted) return;
          ErpToast.showSuccess(context, 'Quotation ${quote.invoiceNumber} marked as REJECTED.');
          break;
        case 'proforma':
          if (quote.quotationStatus != QuotationStatus.accepted && quote.quotationStatus != QuotationStatus.approved) {
            if (!context.mounted) return;
ErpToast.showWarning(context, 'Only accepted quotations can be converted to a Proforma Invoice. Please accept the quote first.');
            return;
          }
          final proforma = await db.convertQuotationToProformaAsync(quote.id);
          if (!context.mounted) return;
          ErpToast.showSuccess(context, 'Created Proforma Invoice ${proforma.invoiceNumber}!');
          ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.proformaInvoices;
          break;
      }
    } catch (e) {
      if (!context.mounted) return;
      ErpToast.showError(context, 'Action failed: $e');
    }
  }
}
