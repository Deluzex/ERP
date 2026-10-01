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
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 650;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quotations & Commercial Estimates', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text(
                    'Manage quotes, revision branches, client approval & proforma conversion',
                    style: AppTextStyles.subtitle,
                  ),
                ],
              );

              final actionBtn = ErpButton(
                text: 'Create Quotation',
                icon: Icons.add,
                onPressed: () {
                  ref.read(salesCreateDocTypeProvider.notifier).state = SalesDocumentType.quotation;
                  ref.read(salesCreateSourceDocIdProvider.notifier).state = null;
                  ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createQuotation;
                },
              );

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 12),
                    actionBtn,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  actionBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 2. Tabs: All, Draft, Sent, Accepted, Revisions/History, Rejected/Expired
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
              onTap: (_) => setState(() {}),
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

          // 3. Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search quotations by number, customer, project or executive...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
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

    return ErpDataTable(
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
      rows: filtered.map((quote) {
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
              ref.read(activeRecordDetailsStackProvider.notifier).push(quote.id, 'quotation', ErpNavSection.quotations);
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
                    decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
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
    );
  }

  Widget _buildQuoteActionMenu(BuildContext context, WidgetRef ref, Sale quote, MockDatabaseService db) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 18),
          tooltip: 'Preview PDF',
          onPressed: () => SalesPdfGeneratorDialog.show(context, quote, db),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
          onSelected: (action) => _handleAction(context, ref, action, quote, db),
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility_outlined, size: 16), SizedBox(width: 8), Text('View Details')])),
            if (quote.quotationStatus == QuotationStatus.draft)
              const PopupMenuItem(value: 'send', child: Row(children: [Icon(Icons.send_outlined, size: 16, color: AppColors.info), SizedBox(width: 8), Text('Mark as Sent')])),
            if (quote.quotationStatus == QuotationStatus.sent) ...[
              const PopupMenuItem(value: 'accept', child: Row(children: [Icon(Icons.check_circle_outline, size: 16, color: AppColors.success), SizedBox(width: 8), Text('Accept Quote')])),
              const PopupMenuItem(value: 'reject', child: Row(children: [Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger), SizedBox(width: 8), Text('Reject Quote')])),
            ],
            if (quote.quotationStatus != QuotationStatus.superseded) ...[
              const PopupMenuItem(value: 'revision', child: Row(children: [Icon(Icons.difference_outlined, size: 16, color: AppColors.purple), SizedBox(width: 8), Text('Create Revision')])),
              const PopupMenuItem(value: 'proforma', child: Row(children: [Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.primary), SizedBox(width: 8), Text('Convert to Proforma')])),
            ],
            const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_outlined, size: 16), SizedBox(width: 8), Text('Duplicate Quote')])),
          ],
        ),
      ],
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action, Sale quote, MockDatabaseService db) async {
    try {
      switch (action) {
        case 'view':
          ref.read(activeRecordDetailsStackProvider.notifier).push(quote.id, 'quotation', ErpNavSection.quotations);
          break;
        case 'send':
          await db.updateQuotationStatusAsync(quote.id, QuotationStatus.sent.name);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Quotation ${quote.invoiceNumber} marked as SENT to client.'), backgroundColor: AppColors.info),
          );
          break;
        case 'accept':
          await db.updateQuotationStatusAsync(quote.id, QuotationStatus.accepted.name);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Quotation ${quote.invoiceNumber} ACCEPTED! You can now generate Proforma Invoice.'), backgroundColor: AppColors.success),
          );
          break;
        case 'reject':
          await db.updateQuotationStatusAsync(quote.id, QuotationStatus.rejected.name);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Quotation ${quote.invoiceNumber} marked as REJECTED.'), backgroundColor: AppColors.danger),
          );
          break;
        case 'revision':
          ref.read(salesCreateDocTypeProvider.notifier).state = SalesDocumentType.quotation;
          ref.read(salesCreateSourceDocIdProvider.notifier).state = quote.id;
          ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createQuotation;
          break;
        case 'proforma':
          final proforma = await db.convertQuotationToProformaAsync(quote.id);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Created Proforma Invoice ${proforma.invoiceNumber}!'), backgroundColor: AppColors.success),
          );
          ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.proformaInvoices;
          break;
        case 'duplicate':
          ref.read(salesCreateDocTypeProvider.notifier).state = SalesDocumentType.quotation;
          ref.read(salesCreateSourceDocIdProvider.notifier).state = quote.id;
          ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createQuotation;
          break;
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e'), backgroundColor: AppColors.danger),
      );
    }
  }
}
