import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
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
import '../widgets/convert_proforma_dialog.dart';
import '../widgets/sales_pdf_generator.dart';

class ProformaInvoicesScreen extends ConsumerStatefulWidget {
  const ProformaInvoicesScreen({super.key});

  @override
  ConsumerState<ProformaInvoicesScreen> createState() => _ProformaInvoicesScreenState();
}

class _ProformaInvoicesScreenState extends ConsumerState<ProformaInvoicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(databaseServiceProvider).loadProforma(forceRefresh: true));
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(databaseServiceProvider).loadProforma());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRecordAdvancePaymentDialog(BuildContext context, Sale proforma, MockDatabaseService db) {
    final amountCtrl = TextEditingController(text: proforma.pendingAmount.toStringAsFixed(0));
    final transactionRefCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    PaymentMode paymentMode = PaymentMode.bankTransfer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final enteredAmount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final remainingAfter = (proforma.pendingAmount - enteredAmount).clamp(0.0, double.infinity);

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.payments_outlined, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Record Advance Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Against Proforma: ${proforma.invoiceNumber}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Balance Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Proforma Total', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                              Text(Formatters.formatCurrency(proforma.totalAmount), style: AppTextStyles.bodyBold),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Already Received', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                              Text(Formatters.formatCurrency(proforma.paidAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Current Balance Due', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                              Text(Formatters.formatCurrency(proforma.pendingAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Received Amount (₹) *',
                        helperText: 'Balance remaining after receipt: ${Formatters.formatCurrency(remainingAfter)}',
                      ),
                      onChanged: (val) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<PaymentMode>(
                      value: paymentMode,
                      decoration: const InputDecoration(labelText: 'Payment Mode *'),
                      items: PaymentMode.values.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m.name.toUpperCase()));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => paymentMode = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: transactionRefCtrl,
                      decoration: const InputDecoration(labelText: 'Transaction / UTR / Cheque Ref No.'),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Payment Notes / Bank Account'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ErpButton(
                text: 'Record Advance Receipt',
                icon: Icons.check,
                onPressed: () async {
                  if (enteredAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid payment amount.'), backgroundColor: AppColors.danger),
                    );
                    return;
                  }
                  if (enteredAmount > proforma.pendingAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Recorded payment cannot exceed the remaining balance.'), backgroundColor: AppColors.danger),
                    );
                    return;
                  }

                  try {
                    await db.recordProformaAdvancePaymentAsync(
                      proformaId: proforma.id,
                      amount: enteredAmount,
                      paymentMode: paymentMode,
                      transactionRef: transactionRefCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                    );

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Advance of ${Formatters.formatCurrency(enteredAmount)} recorded against ${proforma.invoiceNumber}!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } catch (e) {
                    ErpToast.showError(context, 'Failed to record payment: $e');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
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
            icon: Icons.receipt_long_outlined,
            title: 'Proforma Invoices',
            badgeText: 'COMMERCIAL BILLING',
            actions: [
              IconButton(
                icon: db.isLoadingProforma
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, color: AppColors.primary, size: 20),
                tooltip: 'Refresh from Database',
                onPressed: db.isLoadingProforma ? null : () => ref.read(databaseServiceProvider).loadProforma(forceRefresh: true),
              ),
              ErpButton(
                text: 'Create Proforma from Quote',
                icon: Icons.receipt_long_outlined,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.quotations,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 2. Summary Metric Cards (Project Theme)
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 850
                  ? (constraints.maxWidth - (3 * 12)) / 4
                  : (constraints.maxWidth > 550 ? (constraints.maxWidth - 12) / 2 : double.infinity);
              final totalValue = db.proformaInvoices.fold(0.0, (sum, p) => sum + p.totalAmount);
              final totalPaid = db.proformaInvoices.fold(0.0, (sum, p) => sum + p.paidAmount);
              final totalPending = db.proformaInvoices.fold(0.0, (sum, p) => sum + p.pendingAmount);

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.receipt_outlined,
                      iconColor: AppColors.primary,
                      title: 'Total Proformas',
                      value: '${db.proformaInvoices.length}',
                      subtext: 'Commercial Advance Notes',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.currency_rupee,
                      iconColor: AppColors.primary,
                      title: 'Total Billed Value',
                      value: Formatters.formatCurrency(totalValue),
                      subtext: 'Cumulative Proforma Total',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppColors.success,
                      title: 'Advances Received',
                      value: Formatters.formatCurrency(totalPaid),
                      subtext: 'Realized Advance Cash',
                      subtextColor: AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.warning,
                      title: 'Pending Balance',
                      value: Formatters.formatCurrency(totalPending),
                      subtext: 'Outstanding Advance',
                      subtextColor: AppColors.warning,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 3. Tabs: All, Issued, Partially Paid, Paid, Converted
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
                Tab(text: 'All Proformas (${db.proformaInvoices.length})'),
                Tab(text: 'Issued / Pending (${db.proformaInvoices.where((p) => p.proformaStatus == ProformaStatus.issued).length})'),
                Tab(text: 'Partially Paid (${db.proformaInvoices.where((p) => p.proformaStatus == ProformaStatus.partialPaid).length})'),
                Tab(text: 'Fully Paid (${db.proformaInvoices.where((p) => p.proformaStatus == ProformaStatus.paid).length})'),
                Tab(text: 'Converted to SO (${db.proformaInvoices.where((p) => p.proformaStatus == ProformaStatus.converted).length})'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Search and Date Filter Bar
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ErpSearchInput(
                hintText: 'Search proforma invoice by number, customer, project or quote...',
                value: _searchQuery,
                onChanged: (val) => setState(() {
                  _searchQuery = val;
                  _currentPage = 0;
                }),
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
          ),
          const SizedBox(height: 16),

          // 4. Proformas Table
          _buildProformasTable(context, ref, db),
        ],
      ),
    );
  }

  Widget _buildProformasTable(BuildContext context, WidgetRef ref, MockDatabaseService db) {
    List<Sale> filtered = db.proformaInvoices;

    // Filter by tab
    switch (_tabController.index) {
      case 1:
        filtered = filtered.where((p) => p.proformaStatus == ProformaStatus.issued).toList();
        break;
      case 2:
        filtered = filtered.where((p) => p.proformaStatus == ProformaStatus.partialPaid).toList();
        break;
      case 3:
        filtered = filtered.where((p) => p.proformaStatus == ProformaStatus.paid).toList();
        break;
      case 4:
        filtered = filtered.where((p) => p.proformaStatus == ProformaStatus.converted).toList();
        break;
      default:
        break;
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final qLower = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.invoiceNumber.toLowerCase().contains(qLower) ||
            p.partyName.toLowerCase().contains(qLower) ||
            (p.projectName != null && p.projectName!.toLowerCase().contains(qLower)) ||
            (p.parentQuotationNumber != null && p.parentQuotationNumber!.toLowerCase().contains(qLower));
      }).toList();
    }

    // Filter by date range
    if (_startDate != null) {
      final startDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      filtered = filtered.where((p) => !p.saleDate.isBefore(startDay)).toList();
    }
    if (_endDate != null) {
      final endDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      filtered = filtered.where((p) => !p.saleDate.isAfter(endDay)).toList();
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
            Icon(Icons.receipt_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No Proforma Invoices found', style: AppTextStyles.h3),
            const SizedBox(height: 6),
            Text('Convert an accepted quotation to generate a Proforma Invoice.', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }

    final totalCount = filtered.length;
    final maxPage = (totalCount / _pageSize).ceil();
    final effectivePage = maxPage == 0 ? 0 : min(_currentPage, maxPage - 1);
    final startIdx = effectivePage * _pageSize;
    final endIdx = min(startIdx + _pageSize, totalCount);
    final paginatedProformas = totalCount == 0 ? <Sale>[] : filtered.sublist(startIdx, endIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ErpDataTable(
          columns: const [
            ErpColumn(title: 'Proforma No'),
            ErpColumn(title: 'Date'),
            ErpColumn(title: 'Customer / Party'),
            ErpColumn(title: 'Quote Ref'),
            ErpColumn(title: 'Total Amount', isNumeric: true),
            ErpColumn(title: 'Advance Paid', isNumeric: true),
            ErpColumn(title: 'Balance Due', isNumeric: true),
            ErpColumn(title: 'Status'),
            ErpColumn(title: 'Actions'),
          ],
          rows: paginatedProformas.map((proforma) {
        ErpStatusBadge badge;
        switch (proforma.proformaStatus) {
          case ProformaStatus.paid:
            badge = ErpStatusBadge.success('FULLY PAID');
            break;
          case ProformaStatus.partialPaid:
            badge = ErpStatusBadge.warning('PARTIALLY PAID');
            break;
          case ProformaStatus.issued:
            badge = ErpStatusBadge.info('ISSUED');
            break;
          case ProformaStatus.converted:
            badge = ErpStatusBadge.success('CONVERTED TO SO');
            break;
          default:
            badge = ErpStatusBadge.neutral('DRAFT');
        }

        return [
          InkWell(
            onTap: () {
              SalesPdfGeneratorDialog.show(context, proforma, db);
            },
            child: Text(
              proforma.invoiceNumber,
              style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primary),
            ),
          ),
          Text(Formatters.formatDate(proforma.saleDate), style: AppTextStyles.bodySmall),
          Text(proforma.partyName, style: AppTextStyles.bodyMedium),
          Text(proforma.parentQuotationNumber ?? '-', style: AppTextStyles.bodySmall),
          Text(Formatters.formatCurrency(proforma.totalAmount), style: AppTextStyles.bodyBold),
          Text(Formatters.formatCurrency(proforma.paidAmount), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.successText)),
          Text(
            Formatters.formatCurrency(proforma.pendingAmount),
            style: AppTextStyles.bodyBold.copyWith(color: proforma.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted),
          ),
          badge,
          PopupMenuButton<String>(
            tooltip: 'Actions',
            icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
            onSelected: (action) async {
              switch (action) {
                case 'view':
                  SalesPdfGeneratorDialog.show(context, proforma, db);
                  break;
                case 'payment':
                  _showRecordAdvancePaymentDialog(context, proforma, db);
                  break;
                case 'convert':
                  await _convertToSalesOrder(context, ref, proforma, db);
                  break;
              }
            },
            itemBuilder: (context) => [
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
              if (proforma.pendingAmount > 0)
                const PopupMenuItem(
                  value: 'payment',
                  child: Row(
                    children: [
                      Icon(Icons.add_card, size: 16, color: AppColors.success),
                      SizedBox(width: 8),
                      Expanded(child: Text('Record Advance Payment')),
                    ],
                  ),
                ),
              if (proforma.proformaStatus != ProformaStatus.converted)
                const PopupMenuItem(
                  value: 'convert',
                  child: Row(
                    children: [
                      Icon(Icons.shopping_cart_checkout, size: 16, color: AppColors.purple),
                      SizedBox(width: 8),
                      Expanded(child: Text('Convert to Sales Order')),
                    ],
                  ),
                ),
            ],
          ),
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

  Future<void> _convertToSalesOrder(BuildContext context, WidgetRef ref, Sale proforma, MockDatabaseService db) async {
    if (proforma.proformaStatus == ProformaStatus.converted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This Proforma Invoice has already been converted to a Sales Order.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final hydratedProforma = proforma.items.isEmpty
        ? await db.getProformaDetailAsync(proforma.id)
        : proforma;
    if (!context.mounted) return;

    final hasShortage = hydratedProforma.items.any((item) {
      final fp = db.finishedProducts
          .where((p) => p.id == item.finishedProductId || p.itemCode == item.finishedProductCode)
          .firstOrNull;
      final available = fp?.availableStock ?? 0.0;
      return item.quantity > available;
    });

    if (hasShortage) {
      await ConvertProformaDialog.show(context, hydratedProforma);
      if (mounted) setState(() {});
      return;
    }

    final soNumber = 'DLZ/SO/2026/${(db.nextSalesOrderNumber).toString().padLeft(4, '0')}';
    final so = Sale(
      id: IdGenerator.generateId('SO'),
      invoiceNumber: soNumber,
      documentType: SalesDocumentType.salesOrder,
      partyType: hydratedProforma.partyType,
      partyId: hydratedProforma.partyId,
      partyName: hydratedProforma.partyName,
      customerContactPerson: hydratedProforma.customerContactPerson,
      customerMobile: hydratedProforma.customerMobile,
      customerEmail: hydratedProforma.customerEmail,
      customerGstNumber: hydratedProforma.customerGstNumber,
      billingAddress: hydratedProforma.billingAddress,
      shippingAddress: hydratedProforma.shippingAddress,
      projectId: hydratedProforma.projectId,
      projectName: hydratedProforma.projectName,
      architectId: hydratedProforma.architectId,
      architectName: hydratedProforma.architectName,
      salesExecutive: hydratedProforma.salesExecutive,
      salesOrderNumber: soNumber,
      proformaReferenceId: hydratedProforma.id,
      proformaNumber: hydratedProforma.invoiceNumber,
      quotationReferenceId: hydratedProforma.quotationReferenceId,
      saleDate: DateTime.now(),
      deliveryDate: DateTime.now().add(const Duration(days: 14)),
      items: hydratedProforma.items.map((i) => i.copyWith()).toList(),
      subtotalAmount: hydratedProforma.subtotalAmount,
      discountAmount: hydratedProforma.discountAmount,
      taxableAmount: hydratedProforma.taxableAmount,
      cgstAmount: hydratedProforma.cgstAmount,
      sgstAmount: hydratedProforma.sgstAmount,
      igstAmount: hydratedProforma.igstAmount,
      gstAmount: hydratedProforma.gstAmount,
      totalAmount: hydratedProforma.totalAmount,
      paidAmount: hydratedProforma.paidAmount,
      pendingAmount: hydratedProforma.pendingAmount,
      paymentMode: hydratedProforma.paymentMode,
      status: SaleStatus.active,
      createdAt: DateTime.now(),
    );

    try {
      final createdSO = await db.createSalesOrderAsync(so, autoAllocate: true);
      final piIdx = db.sales.indexWhere((s) => s.id == proforma.id);
      if (piIdx != -1) {
        db.sales[piIdx] = db.sales[piIdx].copyWith(
          proformaStatus: ProformaStatus.converted,
          salesOrderReferenceId: createdSO.id,
          salesOrderNumber: createdSO.invoiceNumber,
        );
      }
      if (mounted) setState(() {});

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created Sales Order ${createdSO.invoiceNumber} with automated stock allocation!'),
          backgroundColor: AppColors.success,
        ),
      );
      ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesOrders;
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create sales order: $e'), backgroundColor: AppColors.danger),
      );
    }
  }
}
