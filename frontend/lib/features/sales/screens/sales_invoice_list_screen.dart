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
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';
import '../widgets/sales_pdf_generator.dart';

class SalesInvoiceListScreen extends ConsumerStatefulWidget {
  const SalesInvoiceListScreen({super.key});

  @override
  ConsumerState<SalesInvoiceListScreen> createState() => _SalesInvoiceListScreenState();
}

class _SalesInvoiceListScreenState extends ConsumerState<SalesInvoiceListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRecordPaymentDialog(BuildContext context, Sale invoice, MockDatabaseService db) {
    final amountCtrl = TextEditingController(text: invoice.pendingAmount.toStringAsFixed(0));
    final transactionRefCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    PaymentMode paymentMode = PaymentMode.bankTransfer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final enteredAmount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final remainingAfter = (invoice.pendingAmount - enteredAmount).clamp(0.0, double.infinity);

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.payments_outlined, color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Record Customer Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Invoice: ${invoice.invoiceNumber} | Party: ${invoice.partyName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              Text('Total Invoiced', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                              Text(Formatters.formatCurrency(invoice.totalAmount), style: AppTextStyles.bodyBold),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Paid to Date', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                              Text(Formatters.formatCurrency(invoice.paidAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Pending Due', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                              Text(Formatters.formatCurrency(invoice.pendingAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText)),
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
                        labelText: 'Payment Received (₹) *',
                        helperText: 'Outstanding after receipt: ${Formatters.formatCurrency(remainingAfter)}',
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
                      decoration: const InputDecoration(labelText: 'Transaction / Cheque / UTR Ref No.'),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Receipt Remarks / Bank Account'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ErpButton(
                text: 'Save Payment Receipt',
                icon: Icons.check,
                onPressed: () {
                  if (enteredAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid receipt amount.'), backgroundColor: AppColors.danger),
                    );
                    return;
                  }
                  if (enteredAmount > invoice.pendingAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Receipt amount cannot exceed pending due.'), backgroundColor: AppColors.danger),
                    );
                    return;
                  }

                  db.recordCustomerInvoicePayment(
                    invoiceId: invoice.id,
                    amount: enteredAmount,
                    paymentMode: paymentMode,
                    transactionRef: transactionRefCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                  );

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Payment of ${Formatters.formatCurrency(enteredAmount)} recorded! Customer outstanding balance reduced.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales Invoices & Revenue', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text(
                      'Tax invoices created from delivered goods, payment receipts & customer outstanding balances',
                      style: AppTextStyles.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                children: [
                  ErpButton(
                    text: 'Invoice from Delivery',
                    icon: Icons.local_shipping_outlined,
                    isOutlined: true,
                    onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesDeliveries,
                  ),
                  ErpButton(
                    text: 'Create Direct Sale',
                    icon: Icons.point_of_sale_outlined,
                    onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSale,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Tabs: All, Unpaid/Active, Partially Paid, Fully Paid, Overdue
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
                Tab(text: 'All Invoices (${db.salesInvoices.length})'),
                Tab(text: 'Pending Due (${db.salesInvoices.where((i) => i.pendingAmount > 0).length})'),
                Tab(text: 'Partially Paid (${db.salesInvoices.where((i) => i.status == SaleStatus.partialPaid).length})'),
                Tab(text: 'Fully Paid (${db.salesInvoices.where((i) => i.status == SaleStatus.paid).length})'),
                Tab(text: 'Draft / Other (${db.salesInvoices.where((i) => i.status == SaleStatus.draft || i.status == SaleStatus.cancelled).length})'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search sales invoices by invoice number, customer/dealer, or project...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Invoices Table
          _buildInvoicesTable(context, ref, db),
        ],
      ),
    );
  }

  Widget _buildInvoicesTable(BuildContext context, WidgetRef ref, MockDatabaseService db) {
    List<Sale> filtered = db.salesInvoices;

    // Filter by tab
    switch (_tabController.index) {
      case 1:
        filtered = filtered.where((i) => i.pendingAmount > 0).toList();
        break;
      case 2:
        filtered = filtered.where((i) => i.status == SaleStatus.partialPaid).toList();
        break;
      case 3:
        filtered = filtered.where((i) => i.status == SaleStatus.paid).toList();
        break;
      case 4:
        filtered = filtered.where((i) => i.status == SaleStatus.draft || i.status == SaleStatus.cancelled).toList();
        break;
      default:
        break;
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final qLower = _searchQuery.toLowerCase();
      filtered = filtered.where((i) {
        return i.invoiceNumber.toLowerCase().contains(qLower) ||
            i.partyName.toLowerCase().contains(qLower) ||
            (i.projectName != null && i.projectName!.toLowerCase().contains(qLower));
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
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No sales invoices found in this category', style: AppTextStyles.h3),
            const SizedBox(height: 6),
            Text('Generate tax invoices from completed deliveries or create direct sales.', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }

    return ErpDataTable(
      columns: const [
        ErpColumn(title: 'Invoice No'),
        ErpColumn(title: 'Date'),
        ErpColumn(title: 'Customer / Party'),
        ErpColumn(title: 'Channel'),
        ErpColumn(title: 'Total Amount', isNumeric: true),
        ErpColumn(title: 'Paid Amount', isNumeric: true),
        ErpColumn(title: 'Pending Due', isNumeric: true),
        ErpColumn(title: 'Return Status'),
        ErpColumn(title: 'Payment Status'),
        ErpColumn(title: 'Actions'),
      ],
      rows: filtered.map((s) {
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
          default:
            badge = ErpStatusBadge.neutral('ISSUED');
        }

        ErpStatusBadge returnBadge;
        switch (s.invoiceReturnStatus) {
          case InvoiceReturnIndicator.fullyReturned:
            returnBadge = ErpStatusBadge.danger('FULLY RETURNED');
            break;
          case InvoiceReturnIndicator.partiallyReturned:
            returnBadge = ErpStatusBadge.warning('PARTIAL RETURN');
            break;
          case InvoiceReturnIndicator.noReturn:
          default:
            returnBadge = ErpStatusBadge.neutral('NO RETURN');
            break;
        }

        return [
          InkWell(
            onTap: () {
              ref.read(activeRecordDetailsStackProvider.notifier).push(s.id, 'invoice', ErpNavSection.salesInvoiceList);
            },
            child: Text(s.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primary)),
          ),
          Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
          Text(s.partyName, style: AppTextStyles.bodyMedium),
          Text(s.partyType == PartyType.customer ? 'Customer' : (s.partyType == PartyType.dealer ? 'Dealer' : 'Architect'), style: AppTextStyles.bodySmall),
          Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold),
          Text(Formatters.formatCurrency(s.paidAmount), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.successText)),
          Text(
            Formatters.formatCurrency(s.pendingAmount),
            style: AppTextStyles.bodyBold.copyWith(
              color: s.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted,
            ),
          ),
          returnBadge,
          badge,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 18),
                tooltip: 'Preview Invoice PDF',
                onPressed: () => SalesPdfGeneratorDialog.show(context, s, db),
              ),
              if (s.invoiceReturnStatus != InvoiceReturnIndicator.fullyReturned && s.status != SaleStatus.cancelled)
                IconButton(
                  icon: const Icon(Icons.assignment_return_outlined, color: AppColors.primary, size: 18),
                  tooltip: 'Create Sales Return',
                  onPressed: () {
                    ref.read(salesCreateDocTypeProvider.notifier).state = SalesDocumentType.salesReturn;
                    ref.read(salesCreateSourceDocIdProvider.notifier).state = s.id;
                    ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSalesReturn;
                  },
                ),
              if (s.pendingAmount > 0)
                IconButton(
                  icon: const Icon(Icons.add_card, color: AppColors.success, size: 18),
                  tooltip: 'Record Payment',
                  onPressed: () => _showRecordPaymentDialog(context, s, db),
                ),
            ],
          ),
        ];
      }).toList(),
    );
  }
}
