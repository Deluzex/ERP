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
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';
import '../widgets/sales_pdf_generator.dart';

class ProformaInvoicesScreen extends ConsumerStatefulWidget {
  const ProformaInvoicesScreen({super.key});

  @override
  ConsumerState<ProformaInvoicesScreen> createState() => _ProformaInvoicesScreenState();
}

class _ProformaInvoicesScreenState extends ConsumerState<ProformaInvoicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
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
                  decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to record payment: $e'), backgroundColor: AppColors.danger),
                    );
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 650;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Proforma Invoices', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text(
                    'Commercial advance billing (Not a Tax Invoice) & milestone payment receipts',
                    style: AppTextStyles.subtitle,
                  ),
                ],
              );

              final actionBtn = ErpButton(
                text: 'Create Proforma from Quote',
                icon: Icons.receipt_long_outlined,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.quotations,
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

          // 2. Tabs: All, Issued, Partially Paid, Paid, Converted
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
                Tab(text: 'All Proformas (${db.proformaInvoices.length})'),
                Tab(text: 'Issued / Pending (${db.proformaInvoices.where((p) => p.proformaStatus == ProformaStatus.issued).length})'),
                Tab(text: 'Partially Paid (${db.proformaInvoices.where((p) => p.proformaStatus == ProformaStatus.partialPaid).length})'),
                Tab(text: 'Fully Paid (${db.proformaInvoices.where((p) => p.proformaStatus == ProformaStatus.paid).length})'),
                Tab(text: 'Converted to SO (${db.proformaInvoices.where((p) => p.proformaStatus == ProformaStatus.converted).length})'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search proforma invoice by number, customer, project or quotation reference...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
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

    return ErpDataTable(
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
      rows: filtered.map((proforma) {
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
              ref.read(activeRecordDetailsStackProvider.notifier).push(proforma.id, 'proformaInvoice', ErpNavSection.proformaInvoices);
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 18),
                tooltip: 'Preview Proforma PDF',
                onPressed: () => SalesPdfGeneratorDialog.show(context, proforma, db),
              ),
              if (proforma.pendingAmount > 0)
                IconButton(
                  icon: const Icon(Icons.add_card, color: AppColors.success, size: 18),
                  tooltip: 'Record Advance Payment',
                  onPressed: () => _showRecordAdvancePaymentDialog(context, proforma, db),
                ),
              if (proforma.proformaStatus != ProformaStatus.converted)
                IconButton(
                  icon: const Icon(Icons.shopping_cart_checkout, color: AppColors.purple, size: 18),
                  tooltip: 'Convert to Sales Order',
                  onPressed: () async {
                    // Convert Proforma to Sales Order. List rows omit line items, so hydrate first —
                    // otherwise the new order would be posted with an empty items array.
                    final hydratedProforma = proforma.items.isEmpty
                        ? await db.getProformaDetailAsync(proforma.id)
                        : proforma;
                    if (!context.mounted) return;
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Created Sales Order ${createdSO.invoiceNumber} with automated stock allocation!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesOrders;
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to create sales order: $e'), backgroundColor: AppColors.danger),
                      );
                    }
                  },
                ),
            ],
          ),
        ];
      }).toList(),
    );
  }
}
