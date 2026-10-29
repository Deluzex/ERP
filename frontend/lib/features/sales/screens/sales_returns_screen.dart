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

class SalesReturnsScreen extends ConsumerStatefulWidget {
  const SalesReturnsScreen({super.key});

  @override
  ConsumerState<SalesReturnsScreen> createState() => _SalesReturnsScreenState();
}

class _SalesReturnsScreenState extends ConsumerState<SalesReturnsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String? _selectedCustomerFilter;
  ReturnType? _selectedReturnTypeFilter;
  DateTime? _startDate;
  DateTime? _endDate;
  RefundStatus? _selectedRefundStatusFilter;
  int _currentPage = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = ref.read(databaseServiceProvider);
      db.loadSalesReturns();
      db.loadSalesInvoices();

      final sourceId = ref.read(salesCreateSourceDocIdProvider);
      if (sourceId != null) {
        ref.read(salesCreateSourceDocIdProvider.notifier).state = null;
        _showCreateOrEditSalesReturnDialog(context, db, preselectedInvoiceId: sourceId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showCreateOrEditSalesReturnDialog(BuildContext context, MockDatabaseService db, {Sale? initialExistingReturn, String? preselectedInvoiceId}) async {
    if (db.salesInvoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sales invoices available for return.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    // List endpoints omit line items; hydrate every invoice so whichever one gets picked below has items to return.
    await db.hydrateSalesInvoiceItems();
    final Sale? existingReturn = (initialExistingReturn != null && initialExistingReturn.items.isEmpty)
        ? await db.getReturnDetailAsync(initialExistingReturn.id)
        : initialExistingReturn;
    if (!context.mounted) return;

    final isEdit = existingReturn != null;
    String selectedInvoiceId = existingReturn?.originalInvoiceId ?? preselectedInvoiceId ?? (db.salesInvoices.isNotEmpty ? db.salesInvoices.first.id : '');
    if (!db.salesInvoices.any((i) => i.id == selectedInvoiceId)) {
      selectedInvoiceId = db.salesInvoices.isNotEmpty ? db.salesInvoices.first.id : '';
    }
    ReturnFinancialAction financialAction = existingReturn?.returnFinancialAction ?? ReturnFinancialAction.adjustOutstanding;
    final reasonCtrl = TextEditingController(text: existingReturn?.returnReason ?? 'Client requested quantity adjustment');
    final notesCtrl = TextEditingController(text: existingReturn?.notes ?? '');

    // Map of product ID to return quantity text controllers and conditions
    Map<String, TextEditingController> returnQtyCtrls = {};
    Map<String, ReturnCondition> itemConditions = {};

    void initializeControllers(Sale invoice) {
      returnQtyCtrls.clear();
      itemConditions.clear();
      for (final item in invoice.items) {
        final prevReturnedOnOtherDocs = (item.returnedQuantity - (isEdit ? (existingReturn.items.where((i) => i.finishedProductId == item.finishedProductId).firstOrNull?.quantity ?? 0.0) : 0.0)).clamp(0.0, double.infinity);
        final availableToReturn = (item.quantity - prevReturnedOnOtherDocs).clamp(0.0, double.infinity);

        double initialQty = 0.0;
        if (isEdit) {
          final existingItem = existingReturn.items.where((i) => i.finishedProductId == item.finishedProductId).firstOrNull;
          initialQty = existingItem?.quantity ?? 0.0;
          itemConditions[item.finishedProductId] = existingItem?.returnCondition ?? ReturnCondition.resalable;
        } else {
          initialQty = availableToReturn > 0 ? 1.0 : 0.0;
          itemConditions[item.finishedProductId] = ReturnCondition.resalable;
        }

        returnQtyCtrls[item.finishedProductId] = TextEditingController(
          text: initialQty > 0 ? initialQty.toInt().toString() : '0',
        );
      }
    }

    final initialInv = db.salesInvoices.firstWhere((i) => i.id == selectedInvoiceId, orElse: () => db.salesInvoices.first);
    initializeControllers(initialInv);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedInvoice = db.salesInvoices.firstWhere((i) => i.id == selectedInvoiceId, orElse: () => db.salesInvoices.first);

          // Calculate live totals
          double liveSubtotal = 0.0;
          double liveDiscount = 0.0;
          double liveGst = 0.0;
          int totalItemsToReturn = 0;

          for (final item in selectedInvoice.items) {
            final ctrl = returnQtyCtrls[item.finishedProductId];
            final qty = double.tryParse(ctrl?.text.trim() ?? '0') ?? 0.0;
            if (qty > 0) {
              totalItemsToReturn++;
              final itemSub = qty * item.rate;
              final itemDisc = (item.discountAmount / (item.quantity > 0 ? item.quantity : 1.0)) * qty;
              final itemTaxable = (itemSub - itemDisc).clamp(0.0, double.infinity);
              final itemTax = (itemTaxable * (item.gstPercent / 100.0));
              liveSubtotal += itemSub;
              liveDiscount += itemDisc;
              liveGst += itemTax;
            }
          }
          final liveTotal = (liveSubtotal - liveDiscount).clamp(0.0, double.infinity) + liveGst;

          final isMobile = MediaQuery.of(ctx).size.width < 700;

          return AlertDialog(
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 24),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.assignment_return_outlined, color: AppColors.danger, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Sales Return (${existingReturn.invoiceNumber})' : 'Create Sales Return & Credit Note',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Link to sales invoice, inspect product condition & apply audited adjustments',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: isMobile ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 820),
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Invoice & Customer Header Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: db.salesInvoices.any((inv) => inv.id == selectedInvoiceId) ? selectedInvoiceId : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Original Sales Invoice *',
                              prefixIcon: Icon(Icons.receipt_long, size: 18),
                            ),
                            items: db.salesInvoices.map((inv) {
                              return DropdownMenuItem(
                                value: inv.id,
                                child: Text(
                                  '${inv.invoiceNumber} — ${inv.partyName} (Total: ${Formatters.formatCurrency(inv.totalAmount)}, Pending: ${Formatters.formatCurrency(inv.pendingAmount)})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: isEdit ? null : (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedInvoiceId = val;
                                  final inv = db.salesInvoices.firstWhere((i) => i.id == val);
                                  initializeControllers(inv);
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          if (isMobile)
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoTag('Customer', selectedInvoice.partyName, Icons.business),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildInfoTag('Invoice Date', Formatters.formatDate(selectedInvoice.saleDate), Icons.calendar_today),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoTag('Linked Order', selectedInvoice.salesOrderNumber ?? 'Direct Sale', Icons.shopping_bag_outlined),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildInfoTag('Paid Status', selectedInvoice.paidAmount >= selectedInvoice.totalAmount ? 'Fully Paid' : (selectedInvoice.paidAmount > 0 ? 'Partially Paid' : 'Unpaid'), Icons.payment),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoTag('Customer', selectedInvoice.partyName, Icons.business),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildInfoTag('Invoice Date', Formatters.formatDate(selectedInvoice.saleDate), Icons.calendar_today),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildInfoTag('Linked Order', selectedInvoice.salesOrderNumber ?? 'Direct Sale', Icons.shopping_bag_outlined),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildInfoTag('Paid Status', selectedInvoice.paidAmount >= selectedInvoice.totalAmount ? 'Fully Paid' : (selectedInvoice.paidAmount > 0 ? 'Partially Paid' : 'Unpaid'), Icons.payment),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Return Line Items Table with condition selection
                    if (isMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invoiced Line Items & Return Quantities:', style: AppTextStyles.h3.copyWith(fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('Only positive return quantities will be processed', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                        ],
                      )
                    else
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Invoiced Line Items & Return Quantities:', style: AppTextStyles.h3.copyWith(fontSize: 14)),
                          Text('Only positive return quantities will be processed', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: selectedInvoice.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final item = selectedInvoice.items[idx];
                          final prevReturnedOnOtherDocs = (item.returnedQuantity - (isEdit ? (existingReturn.items.where((i) => i.finishedProductId == item.finishedProductId).firstOrNull?.quantity ?? 0.0) : 0.0)).clamp(0.0, double.infinity);
                          final maxReturnable = (item.quantity - prevReturnedOnOtherDocs).clamp(0.0, double.infinity);
                          final ctrl = returnQtyCtrls[item.finishedProductId] ?? TextEditingController(text: '0');
                          final currentCondition = itemConditions[item.finishedProductId] ?? ReturnCondition.resalable;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: isMobile
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.finishedProductName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 3),
                                      Text(
                                        'SKU: ${item.finishedProductCode} | Invoiced: ${item.quantity.toInt()} ${item.unit} | Prev: ${prevReturnedOnOtherDocs.toInt()} ${item.unit} | Rate: ${Formatters.formatCurrency(item.rate)}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              controller: ctrl,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Return Qty',
                                                isDense: true,
                                                helperText: 'Max: ${maxReturnable.toInt()}',
                                                helperStyle: TextStyle(fontSize: 10, color: maxReturnable > 0 ? AppColors.primary : AppColors.danger),
                                              ),
                                              onChanged: (val) => setDialogState(() {}),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            flex: 3,
                                            child: DropdownButtonFormField<ReturnCondition>(
                                              value: currentCondition,
                                              isDense: true,
                                              isExpanded: true,
                                              decoration: const InputDecoration(labelText: 'Condition', isDense: true),
                                              items: const [
                                                DropdownMenuItem(value: ReturnCondition.resalable, child: Text('Resalable (Restock)', style: TextStyle(fontSize: 12))),
                                                DropdownMenuItem(value: ReturnCondition.damaged, child: Text('Damaged (Quarantine)', style: TextStyle(fontSize: 12))),
                                                DropdownMenuItem(value: ReturnCondition.scrap, child: Text('Scrap (Write-off)', style: TextStyle(fontSize: 12))),
                                              ],
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setDialogState(() => itemConditions[item.finishedProductId] = val);
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Item details
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.finishedProductName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(height: 2),
                                            Text(
                                              'SKU: ${item.finishedProductCode} | Invoiced: ${item.quantity.toInt()} ${item.unit} | Prev Returned: ${prevReturnedOnOtherDocs.toInt()} ${item.unit} | Rate: ${Formatters.formatCurrency(item.rate)}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Return quantity input
                                      SizedBox(
                                        width: 110,
                                        child: TextFormField(
                                          controller: ctrl,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Return Qty',
                                            isDense: true,
                                            helperText: 'Max: ${maxReturnable.toInt()}',
                                            helperStyle: TextStyle(fontSize: 10, color: maxReturnable > 0 ? AppColors.primary : AppColors.danger),
                                          ),
                                          onChanged: (val) => setDialogState(() {}),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Item condition dropdown
                                      SizedBox(
                                        width: 185,
                                        child: DropdownButtonFormField<ReturnCondition>(
                                          value: currentCondition,
                                          isDense: true,
                                          isExpanded: true,
                                          decoration: const InputDecoration(labelText: 'Condition', isDense: true),
                                          items: const [
                                            DropdownMenuItem(
                                              value: ReturnCondition.resalable,
                                              child: Text('Resalable (Restock)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                            ),
                                            DropdownMenuItem(
                                              value: ReturnCondition.damaged,
                                              child: Text('Damaged (Quarantine)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                            ),
                                            DropdownMenuItem(
                                              value: ReturnCondition.scrap,
                                              child: Text('Scrap (Write-off)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setDialogState(() => itemConditions[item.finishedProductId] = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Reason & Settlement settings
                    if (isMobile)
                      Column(
                        children: [
                          DropdownButtonFormField<ReturnFinancialAction>(
                            value: financialAction,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Financial Resolution Mode *'),
                            items: const [
                              DropdownMenuItem(value: ReturnFinancialAction.adjustOutstanding, child: Text('Adjust Outstanding Balance (Auto-Calculated)')),
                              DropdownMenuItem(value: ReturnFinancialAction.creditNote, child: Text('Issue Customer Store Credit / Credit Note')),
                              DropdownMenuItem(value: ReturnFinancialAction.refund, child: Text('Disburse Direct Refund (Cash/Bank/UPI)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => financialAction = val);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: reasonCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Reason for Return *',
                              hintText: 'E.g., Client ordered excess, Defective batch',
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<ReturnFinancialAction>(
                              value: financialAction,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Financial Resolution Mode *'),
                              items: const [
                                DropdownMenuItem(value: ReturnFinancialAction.adjustOutstanding, child: Text('Adjust Outstanding Balance (Auto-Calculated)')),
                                DropdownMenuItem(value: ReturnFinancialAction.creditNote, child: Text('Issue Customer Store Credit / Credit Note')),
                                DropdownMenuItem(value: ReturnFinancialAction.refund, child: Text('Disburse Direct Refund (Cash/Bank/UPI)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => financialAction = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: reasonCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Reason for Return *',
                                hintText: 'E.g., Client ordered excess, Defective batch',
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'QA Inspection Remarks / Internal Notes'),
                    ),
                    const SizedBox(height: 16),

                    // 4. Live Financial Summary Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Return Value:', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                                    Text(Formatters.formatCurrency(liveTotal), style: AppTextStyles.h2.copyWith(color: AppColors.danger, fontSize: 18)),
                                  ],
                                ),
                                const Divider(height: 16),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    Text('Items: $totalItemsToReturn products', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                                    Text('Taxable: ${Formatters.formatCurrency(liveSubtotal - liveDiscount)}', style: AppTextStyles.bodySmall),
                                    Text('GST: ${Formatters.formatCurrency(liveGst)}', style: AppTextStyles.bodySmall),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Items Selected: $totalItemsToReturn products', style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text('Taxable: ${Formatters.formatCurrency(liveSubtotal - liveDiscount)} | GST: ${Formatters.formatCurrency(liveGst)}', style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Total Return Value', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                                    Text(Formatters.formatCurrency(liveTotal), style: AppTextStyles.h2.copyWith(color: AppColors.danger)),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
            actions: isMobile
                ? [
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isEdit) ...[
                            ErpButton(
                              text: 'Submit for Inspection',
                              icon: Icons.send_outlined,
                              onPressed: () => _processReturnSubmission(
                                context,
                                db,
                                selectedInvoice,
                                returnQtyCtrls,
                                itemConditions,
                                reasonCtrl.text.trim(),
                                financialAction,
                                notesCtrl.text.trim(),
                                SalesReturnStatus.submitted,
                                ctx,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ErpButton(
                              text: 'Save as Draft',
                              isOutlined: true,
                              icon: Icons.edit_note,
                              onPressed: () => _processReturnSubmission(
                                context,
                                db,
                                selectedInvoice,
                                returnQtyCtrls,
                                itemConditions,
                                reasonCtrl.text.trim(),
                                financialAction,
                                notesCtrl.text.trim(),
                                SalesReturnStatus.draft,
                                ctx,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ] else ...[
                            ErpButton(
                              text: 'Update Return Draft',
                              icon: Icons.save_outlined,
                              onPressed: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sales return updated.'), backgroundColor: AppColors.success),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                          ],
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                          ),
                        ],
                      ),
                    ),
                  ]
                : [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    if (!isEdit) ...[
                      ErpButton(
                        text: 'Save as Draft',
                        isOutlined: true,
                        icon: Icons.edit_note,
                        onPressed: () => _processReturnSubmission(
                          context,
                          db,
                          selectedInvoice,
                          returnQtyCtrls,
                          itemConditions,
                          reasonCtrl.text.trim(),
                          financialAction,
                          notesCtrl.text.trim(),
                          SalesReturnStatus.draft,
                          ctx,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ErpButton(
                        text: 'Submit for Inspection',
                        icon: Icons.send_outlined,
                        onPressed: () => _processReturnSubmission(
                          context,
                          db,
                          selectedInvoice,
                          returnQtyCtrls,
                          itemConditions,
                          reasonCtrl.text.trim(),
                          financialAction,
                          notesCtrl.text.trim(),
                          SalesReturnStatus.submitted,
                          ctx,
                        ),
                      ),
                    ] else ...[
                      ErpButton(
                        text: 'Update Return Draft',
                        icon: Icons.save_outlined,
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sales return updated.'), backgroundColor: AppColors.success),
                          );
                        },
                      ),
                    ],
                  ],
          );
        },
      ),
    );
  }

  Widget _buildInfoTag(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processReturnSubmission(
    BuildContext context,
    MockDatabaseService db,
    Sale invoice,
    Map<String, TextEditingController> returnQtyCtrls,
    Map<String, ReturnCondition> itemConditions,
    String returnReason,
    ReturnFinancialAction financialAction,
    String notes,
    SalesReturnStatus targetStatus,
    BuildContext dialogCtx,
  ) async {
    List<SaleLineItem> returnItems = [];

    for (final item in invoice.items) {
      final ctrl = returnQtyCtrls[item.finishedProductId];
      final qtyToReturn = double.tryParse(ctrl?.text.trim() ?? '0') ?? 0.0;
      final maxReturnable = (item.quantity - item.returnedQuantity).clamp(0.0, double.infinity);

      if (qtyToReturn > maxReturnable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Return quantity for ${item.finishedProductName} exceeds maximum returnable quantity (${maxReturnable.toInt()}).'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      if (qtyToReturn > 0) {
        final condition = itemConditions[item.finishedProductId] ?? ReturnCondition.resalable;
        returnItems.add(item.copyWith(
          quantity: qtyToReturn,
          returnedQuantity: qtyToReturn,
          returnCondition: condition,
          productCondition: condition.name,
          lineTotal: SaleLineItem.calculateLineTotal(
            quantity: qtyToReturn,
            rate: item.rate,
            discountAmount: (item.discountAmount / (item.quantity > 0 ? item.quantity : 1.0)) * qtyToReturn,
            gstPercent: item.gstPercent,
          ),
        ));
      }
    }

    if (returnItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a return quantity greater than 0 for at least one item.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (returnReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for the return.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    try {
      final returnDoc = await db.createSalesReturnAsync(
        originalInvoiceId: invoice.id,
        returnItems: returnItems,
        returnReason: returnReason,
        condition: returnItems.first.returnCondition ?? ReturnCondition.resalable,
        financialAction: financialAction,
        notes: notes,
      );

      Navigator.pop(dialogCtx);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sales Return ${returnDoc.invoiceNumber} created as ${(returnDoc.salesReturnStatus ?? targetStatus).name.toUpperCase()}!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create sales return: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showApproveConfirmationDialog(BuildContext context, Sale returnDoc, MockDatabaseService db) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isMobile = MediaQuery.of(ctx).size.width < 550;
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.success, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text('Approve Sales Return & Process Adjustments'),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to approve Sales Return ${returnDoc.invoiceNumber}?', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Automated Actions Triggered upon Approval:', style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                      const SizedBox(height: 6),
                      _buildBullet('Restock resalable items to finished product inventory'),
                      _buildBullet('Record damaged/scrap adjustment records and stock movement ledgers'),
                      _buildBullet('Adjust customer outstanding balance / generate refund voucher'),
                      _buildBullet('Update Sales Invoice net totals without modifying historical items'),
                      _buildBullet('Adjust Architect Commission & Project Revenue if applicable'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: isMobile
              ? [
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ErpButton(
                          text: 'Approve & Execute Adjustments',
                          icon: Icons.check,
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await db.approveSalesReturnAsync(returnDoc.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Sales Return ${returnDoc.invoiceNumber} approved! Stock and financials updated.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to approve return: $e'), backgroundColor: AppColors.danger),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  ),
                ]
              : [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  ErpButton(
                    text: 'Approve & Execute Adjustments',
                    icon: Icons.check,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await db.approveSalesReturnAsync(returnDoc.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sales Return ${returnDoc.invoiceNumber} approved! Stock and financials updated.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to approve return: $e'), backgroundColor: AppColors.danger),
                        );
                      }
                    },
                  ),
                ],
        );
      },
    );
  }

  void _showRejectConfirmationDialog(BuildContext context, Sale returnDoc, MockDatabaseService db) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isMobile = MediaQuery.of(ctx).size.width < 550;
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: AppColors.danger, size: 24),
              SizedBox(width: 10),
              Expanded(child: Text('Reject Sales Return')),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rejecting ${returnDoc.invoiceNumber} will close this return without making any stock or financial adjustments.', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 14),
                TextFormField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Rejection Reason *', hintText: 'E.g., Outside return policy window, Unauthorized items'),
                ),
              ],
            ),
          ),
          actions: isMobile
              ? [
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ErpButton(
                          text: 'Confirm Rejection',
                          isDanger: true,
                          icon: Icons.close,
                          onPressed: () {
                            if (reasonCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please specify a rejection reason.'), backgroundColor: AppColors.danger),
                              );
                              return;
                            }
                            Navigator.pop(ctx);
                            db.rejectSalesReturn(returnDoc.id, reasonCtrl.text.trim());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Sales Return ${returnDoc.invoiceNumber} rejected.'), backgroundColor: AppColors.neutral),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  ),
                ]
              : [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  ErpButton(
                    text: 'Confirm Rejection',
                    isDanger: true,
                    icon: Icons.close,
                    onPressed: () {
                      if (reasonCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please specify a rejection reason.'), backgroundColor: AppColors.danger),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      db.rejectSalesReturn(returnDoc.id, reasonCtrl.text.trim());
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sales Return ${returnDoc.invoiceNumber} rejected.'), backgroundColor: AppColors.neutral),
                      );
                    },
                  ),
                ],
        );
      },
    );
  }

  void _showProcessRefundDialog(BuildContext context, Sale returnDoc, MockDatabaseService db) {
    PaymentMode refundMode = PaymentMode.bankTransfer;
    bool asCustomerCredit = false;
    final amountCtrl = TextEditingController(text: returnDoc.refundAmount.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isMobile = MediaQuery.of(ctx).size.width < 550;
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.payments_outlined, color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Process Customer Refund / Credit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Return: ${returnDoc.invoiceNumber} | Customer: ${returnDoc.partyName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Approved Return Value:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                                    Text(Formatters.formatCurrency(returnDoc.totalAmount), style: AppTextStyles.bodyBold),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Eligible Refund Amount:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                                    Text(Formatters.formatCurrency(returnDoc.refundAmount > 0 ? returnDoc.refundAmount : returnDoc.totalAmount), style: AppTextStyles.h3.copyWith(color: AppColors.successText)),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Approved Return Value', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                                    Text(Formatters.formatCurrency(returnDoc.totalAmount), style: AppTextStyles.bodyBold),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Eligible Refund Amount', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                                    Text(Formatters.formatCurrency(returnDoc.refundAmount > 0 ? returnDoc.refundAmount : returnDoc.totalAmount), style: AppTextStyles.h3.copyWith(color: AppColors.successText)),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Settlement Mode Switcher
                    CheckboxListTile(
                      title: const Text('Issue as Customer Store Credit (Credit Note)'),
                      subtitle: const Text('Add balance to customer credit account for future sales invoices'),
                      value: asCustomerCredit,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setDialogState(() => asCustomerCredit = val ?? false);
                      },
                    ),
                    const SizedBox(height: 10),

                    if (!asCustomerCredit) ...[
                      DropdownButtonFormField<PaymentMode>(
                        value: refundMode,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Disbursement Mode *'),
                        items: const [
                          DropdownMenuItem(value: PaymentMode.bankTransfer, child: Text('Bank Transfer (NEFT / RTGS)')),
                          DropdownMenuItem(value: PaymentMode.upi, child: Text('UPI / QR Instant Transfer')),
                          DropdownMenuItem(value: PaymentMode.cheque, child: Text('Account Payee Cheque')),
                          DropdownMenuItem(value: PaymentMode.cash, child: Text('Cash Payout')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => refundMode = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Refund / Credit Amount (₹) *'),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: refCtrl,
                      decoration: InputDecoration(
                        labelText: asCustomerCredit ? 'Credit Note Document Reference' : 'Transaction Reference / Cheque No / UTR *',
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Accounting Remarks / Notes'),
                    ),
                  ],
                ),
              ),
            ),
            actions: isMobile
                ? [
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ErpButton(
                            text: asCustomerCredit ? 'Issue Store Credit' : 'Disburse Refund',
                            icon: Icons.check,
                            onPressed: () async {
                              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                              if (amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid refund amount.'), backgroundColor: AppColors.danger),
                                );
                                return;
                              }

                              try {
                                await db.disburseRefundAsync(
                                  returnId: returnDoc.id,
                                  paymentMode: asCustomerCredit ? PaymentMode.creditNote : refundMode,
                                  amount: amount,
                                  transactionRef: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                                  notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                );

                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Refund of ${Formatters.formatCurrency(amount)} processed for ${returnDoc.invoiceNumber}!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to process refund: $e'), backgroundColor: AppColors.danger),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                          ),
                        ],
                      ),
                    ),
                  ]
                : [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ErpButton(
                      text: asCustomerCredit ? 'Issue Store Credit' : 'Disburse Refund',
                      icon: Icons.check,
                      onPressed: () async {
                        final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid refund amount.'), backgroundColor: AppColors.danger),
                          );
                          return;
                        }

                        try {
                          await db.disburseRefundAsync(
                            returnId: returnDoc.id,
                            paymentMode: asCustomerCredit ? PaymentMode.creditNote : refundMode,
                            amount: amount,
                            transactionRef: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                            notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                          );

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Refund of ${Formatters.formatCurrency(amount)} processed for ${returnDoc.invoiceNumber}!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to process refund: $e'), backgroundColor: AppColors.danger),
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

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5, color: Colors.black87))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);

    // Apply Filters
    List<Sale> filtered = db.salesReturns;

    // Tab Filter
    switch (_tabController.index) {
      case 1: // Draft & Submitted
        filtered = filtered.where((r) => r.salesReturnStatus == SalesReturnStatus.draft || r.salesReturnStatus == SalesReturnStatus.submitted).toList();
        break;
      case 2: // Received & Inspection
        filtered = filtered.where((r) => r.salesReturnStatus == SalesReturnStatus.itemsReceived || r.salesReturnStatus == SalesReturnStatus.inspection).toList();
        break;
      case 3: // Approved & Completed
        filtered = filtered.where((r) => r.salesReturnStatus == SalesReturnStatus.approved || r.salesReturnStatus == SalesReturnStatus.completed).toList();
        break;
      case 4: // Rejected
        filtered = filtered.where((r) => r.salesReturnStatus == SalesReturnStatus.rejected).toList();
        break;
      default:
        break;
    }

    // Customer Filter
    if (_selectedCustomerFilter != null && _selectedCustomerFilter!.isNotEmpty) {
      filtered = filtered.where((r) => r.partyId == _selectedCustomerFilter).toList();
    }

    // Return Type Filter
    if (_selectedReturnTypeFilter != null) {
      filtered = filtered.where((r) => r.returnType == _selectedReturnTypeFilter).toList();
    }

    // Refund Status Filter
    if (_selectedRefundStatusFilter != null) {
      filtered = filtered.where((r) => r.refundStatus == _selectedRefundStatusFilter).toList();
    }

    // Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final qLower = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.invoiceNumber.toLowerCase().contains(qLower) ||
            r.partyName.toLowerCase().contains(qLower) ||
            (r.originalInvoiceNumber != null && r.originalInvoiceNumber!.toLowerCase().contains(qLower)) ||
            (r.returnReason != null && r.returnReason!.toLowerCase().contains(qLower));
      }).toList();
    }

    // Date Range Filter
    if (_startDate != null) {
      final startDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      filtered = filtered.where((r) => !r.saleDate.isBefore(startDay)).toList();
    }
    if (_endDate != null) {
      final endDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      filtered = filtered.where((r) => !r.saleDate.isAfter(endDay)).toList();
    }

    final draftCount = db.salesReturns.where((r) => r.salesReturnStatus == SalesReturnStatus.draft || r.salesReturnStatus == SalesReturnStatus.submitted).length;
    final inspectionCount = db.salesReturns.where((r) => r.salesReturnStatus == SalesReturnStatus.itemsReceived || r.salesReturnStatus == SalesReturnStatus.inspection).length;
    final approvedCount = db.salesReturns.where((r) => r.salesReturnStatus == SalesReturnStatus.approved || r.salesReturnStatus == SalesReturnStatus.completed).length;
    final rejectedCount = db.salesReturns.where((r) => r.salesReturnStatus == SalesReturnStatus.rejected).length;

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          ErpSectionHeaderCard(
            icon: Icons.assignment_return_outlined,
            title: 'Sales Returns & Credit Notes',
            badgeText: 'RETURN VERIFICATION',
            action: ErpButton(
              text: 'Create Sales Return',
              icon: Icons.assignment_return_outlined,
              onPressed: () => _showCreateOrEditSalesReturnDialog(context, db),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Summary Metric Cards (Responsive: 100% vertical on mobile, 2x2 on tablet, 4 in a row on desktop)
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final isTablet = constraints.maxWidth < 950;
              final totalReturnVal = db.salesReturns.fold(0.0, (sum, r) => sum + r.totalAmount);

              final card1 = FigmaMetricCard(
                icon: Icons.assignment_return_outlined,
                iconColor: AppColors.primary,
                title: 'Total Sales Returns',
                value: '${db.salesReturns.length}',
                subtext: '₹${Formatters.formatNumber(totalReturnVal)} Total Return Value',
              );
              final card2 = FigmaMetricCard(
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.success,
                title: 'Approved & Restocked',
                value: '$approvedCount',
                subtext: Formatters.formatCurrency(db.totalSalesReturnsAmount),
                subtextColor: AppColors.success,
              );
              final card3 = FigmaMetricCard(
                icon: Icons.pending_actions_outlined,
                iconColor: AppColors.warning,
                title: 'In Inspection & Review',
                value: '$inspectionCount',
                subtext: '$draftCount drafts pending submission',
                subtextColor: AppColors.warning,
              );
              final card4 = FigmaMetricCard(
                icon: Icons.payments_outlined,
                iconColor: AppColors.danger,
                title: 'Pending Refunds',
                value: '${db.pendingRefundsCount}',
                subtext: 'Customer payout or credit required',
                subtextColor: AppColors.danger,
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    card1,
                    const SizedBox(height: 10),
                    card2,
                    const SizedBox(height: 10),
                    card3,
                    const SizedBox(height: 10),
                    card4,
                  ],
                );
              }

              if (isTablet) {
                final halfWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(width: halfWidth, child: card1),
                    SizedBox(width: halfWidth, child: card2),
                    SizedBox(width: halfWidth, child: card3),
                    SizedBox(width: halfWidth, child: card4),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 12),
                  Expanded(child: card2),
                  const SizedBox(width: 12),
                  Expanded(child: card3),
                  const SizedBox(width: 12),
                  Expanded(child: card4),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 3. Tab Filter Bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => setState(() {
                _currentPage = 0;
              }),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: 'All Returns (${db.salesReturns.length})'),
                Tab(text: 'Draft & Submitted ($draftCount)'),
                Tab(text: 'Inspection / Review ($inspectionCount)'),
                Tab(text: 'Approved / Completed ($approvedCount)'),
                Tab(text: 'Rejected ($rejectedCount)'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Search and Dropdown Filter Row
          LayoutBuilder(
            builder: (context, filterBox) {
              final isMobile = filterBox.maxWidth < 650;
              final isTablet = filterBox.maxWidth < 950;

              final searchField = ErpSearchInput(
                hintText: 'Search return no, customer, reason...',
                initialValue: _searchQuery,
                onChanged: (val) => setState(() {
                  _searchQuery = val;
                  _currentPage = 0;
                }),
              );

              final customerDropdown = ErpFilterDropdown<String?>(
                value: (_selectedCustomerFilter != null && db.customers.any((c) => c.id == _selectedCustomerFilter)) ? _selectedCustomerFilter : null,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Customers')),
                  ...db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (val) => setState(() {
                  _selectedCustomerFilter = val;
                  _currentPage = 0;
                }),
              );

              final typeDropdown = ErpFilterDropdown<ReturnType?>(
                value: _selectedReturnTypeFilter,
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Return Types')),
                  DropdownMenuItem(value: ReturnType.fullReturn, child: Text('Full Return')),
                  DropdownMenuItem(value: ReturnType.partialReturn, child: Text('Partial Return')),
                ],
                onChanged: (val) => setState(() {
                  _selectedReturnTypeFilter = val;
                  _currentPage = 0;
                }),
              );

              final dateBox = ErpDateFilterBox(
                startDate: _startDate,
                endDate: _endDate,
                onDateRangeSelected: (start, end) {
                  setState(() {
                    _startDate = start;
                    _endDate = end;
                    _currentPage = 0;
                  });
                },
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    customerDropdown,
                    const SizedBox(height: 10),
                    typeDropdown,
                    const SizedBox(height: 10),
                    dateBox,
                  ],
                );
              }

              if (isTablet) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 12),
                        dateBox,
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: customerDropdown),
                        const SizedBox(width: 12),
                        Expanded(child: typeDropdown),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: customerDropdown),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: typeDropdown),
                  const SizedBox(width: 12),
                  dateBox,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 5. Returns Data View (Responsive: vertical card list on mobile, ErpDataTable on desktop)
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.assignment_return_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No sales returns matching filters', style: AppTextStyles.h3),
                  const SizedBox(height: 6),
                  Text('Create a sales return against delivered sales invoices.', style: AppTextStyles.bodySmall),
                ],
              ),
            )
          else
            Builder(
              builder: (context) {
                final totalCount = filtered.length;
                final maxPage = (totalCount / _pageSize).ceil();
                final effectivePage = maxPage == 0 ? 0 : min(_currentPage, maxPage - 1);
                final startIdx = effectivePage * _pageSize;
                final endIdx = min(startIdx + _pageSize, totalCount);
                final paginatedReturns = totalCount == 0 ? <Sale>[] : filtered.sublist(startIdx, endIdx);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, tableConstraints) {
                        final isMobileView = tableConstraints.maxWidth < 750;

                        if (isMobileView) {
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: paginatedReturns.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, idx) {
                              final ret = paginatedReturns[idx];
                      final statusBadge = _getStatusBadge(ret.salesReturnStatus ?? SalesReturnStatus.draft);
                      final refundBadge = _getRefundBadge(ret.refundStatus ?? RefundStatus.notRequired);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x05000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row: Return Number + Date + Action Menu
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    ref.read(activeRecordDetailsStackProvider.notifier).push(ret.id, 'salesReturn', ErpNavSection.salesReturns);
                                  },
                                  child: Text(
                                    ret.invoiceNumber,
                                    style: AppTextStyles.bodyBold.copyWith(fontSize: 13.5, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  Formatters.formatDate(ret.saleDate),
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                ),
                                const Spacer(),
                                _buildRowActionMenu(context, ret, db),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Customer Name
                            Text(
                              ret.partyName,
                              style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: const Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),

                            // Original Invoice Link
                            if (ret.originalInvoiceNumber != null && ret.originalInvoiceNumber!.isNotEmpty) ...[
                              Row(
                                children: [
                                  Text(
                                    'Original Inv: ',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      if (ret.originalInvoiceId != null) {
                                        ref.read(activeRecordDetailsStackProvider.notifier).push(ret.originalInvoiceId!, 'invoice', ErpNavSection.salesReturns);
                                      }
                                    },
                                    child: Text(
                                      ret.originalInvoiceNumber!,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Return Value & Badges
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      statusBadge,
                                      refundBadge,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Formatters.formatCurrency(ret.totalAmount),
                                      style: AppTextStyles.bodyBold.copyWith(fontSize: 15, color: AppColors.danger),
                                    ),
                                    Text(
                                      ret.returnType == ReturnType.fullReturn ? 'Full Return' : 'Partial Return',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: ret.returnType == ReturnType.fullReturn ? AppColors.dangerText : AppColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                return ErpDataTable(
                  columns: const [
                    ErpColumn(title: 'Return No'),
                    ErpColumn(title: 'Date'),
                    ErpColumn(title: 'Customer / Party'),
                    ErpColumn(title: 'Original Invoice'),
                    ErpColumn(title: 'Return Type'),
                    ErpColumn(title: 'Return Value', isNumeric: true),
                    ErpColumn(title: 'Refund Status'),
                    ErpColumn(title: 'Return Status'),
                    // ErpColumn(title: 'Created By'),
                    ErpColumn(title: 'Actions', width: 90),
                  ],
                  rows: paginatedReturns.map((ret) {
                    final statusBadge = _getStatusBadge(ret.salesReturnStatus ?? SalesReturnStatus.draft);
                    final refundBadge = _getRefundBadge(ret.refundStatus ?? RefundStatus.notRequired);

                    return [
                      InkWell(
                        onTap: () => SalesPdfGeneratorDialog.show(context, ret, db),
                        child: Text(
                          ret.invoiceNumber,
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 12,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text(Formatters.formatDate(ret.saleDate), style: AppTextStyles.bodySmall),
                      Text(ret.partyName, style: AppTextStyles.bodyMedium),
                      InkWell(
                        onTap: () {
                          if (ret.originalInvoiceId != null) {
                            ref.read(activeRecordDetailsStackProvider.notifier).push(ret.originalInvoiceId!, 'invoice', ErpNavSection.salesReturns);
                          }
                        },
                        child: Text(
                          ret.originalInvoiceNumber ?? '-',
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 11.5, color: AppColors.primary, decoration: TextDecoration.underline),
                        ),
                      ),
                      Text(
                        ret.returnType == ReturnType.fullReturn ? 'Full Return' : 'Partial',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: ret.returnType == ReturnType.fullReturn ? AppColors.dangerText : AppColors.primaryDark,
                        ),
                      ),
                      Text(Formatters.formatCurrency(ret.totalAmount), style: AppTextStyles.bodyBold),
                      refundBadge,
                      statusBadge,
                      // Text(ret.createdBy ?? 'Staff', style: AppTextStyles.bodySmall),
                      _buildRowActionMenu(context, ret, db),
                    ];
                  }).toList(),
                );
              },
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
      },
    ),
        ],
      ),
    );
  }

  ErpStatusBadge _getStatusBadge(SalesReturnStatus status) {
    switch (status) {
      case SalesReturnStatus.approved:
      case SalesReturnStatus.completed:
        return ErpStatusBadge.success('COMPLETED');
      case SalesReturnStatus.inspection:
        return ErpStatusBadge.warning('INSPECTION');
      case SalesReturnStatus.itemsReceived:
        return ErpStatusBadge.info('RECEIVED');
      case SalesReturnStatus.submitted:
        return ErpStatusBadge.purple('SUBMITTED');
      case SalesReturnStatus.draft:
        return ErpStatusBadge.neutral('DRAFT');
      case SalesReturnStatus.rejected:
        return ErpStatusBadge.danger('REJECTED');
      default:
        return ErpStatusBadge.neutral('PENDING');
    }
  }

  ErpStatusBadge _getRefundBadge(RefundStatus status) {
    switch (status) {
      case RefundStatus.processed:
        return ErpStatusBadge.success('REFUNDED');
      case RefundStatus.pending:
        return ErpStatusBadge.danger('REFUND DUE');
      case RefundStatus.approved:
        return ErpStatusBadge.warning('REFUND APPR');
      case RefundStatus.notRequired:
        return ErpStatusBadge.neutral('NOT REQ');
      case RefundStatus.cancelled:
        return ErpStatusBadge.neutral('CANCELLED');
    }
  }

  Widget _buildRowActionMenu(BuildContext context, Sale ret, MockDatabaseService db) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
      onSelected: (val) {
        switch (val) {
          case 'view':
          case 'pdf':
            SalesPdfGeneratorDialog.show(context, ret, db);
            break;
          case 'edit':
            _showCreateOrEditSalesReturnDialog(context, db, initialExistingReturn: ret);
            break;
          case 'submit':
            db.updateSalesReturnStatus(ret.id, SalesReturnStatus.submitted);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return submitted for review.'), backgroundColor: AppColors.primary));
            break;
          case 'receive':
            db.updateSalesReturnStatus(ret.id, SalesReturnStatus.itemsReceived);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Items marked as received at warehouse.'), backgroundColor: AppColors.info));
            break;
          case 'inspect':
            db.updateSalesReturnStatus(ret.id, SalesReturnStatus.inspection);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return moved to QA inspection.'), backgroundColor: AppColors.warning));
            break;
          case 'approve':
            _showApproveConfirmationDialog(context, ret, db);
            break;
          case 'reject':
            _showRejectConfirmationDialog(context, ret, db);
            break;
          case 'refund':
            _showProcessRefundDialog(context, ret, db);
            break;
          case 'view_invoice':
            if (ret.originalInvoiceId != null) {
              final inv = db.salesInvoices.where((i) => i.id == ret.originalInvoiceId).firstOrNull;
              if (inv != null) {
                SalesPdfGeneratorDialog.show(context, inv, db);
              } else {
                ref.read(activeRecordDetailsStackProvider.notifier).push(ret.originalInvoiceId!, 'invoice', ErpNavSection.salesReturns);
              }
            }
            break;
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(child: Text('View Details')),
            ],
          ),
        ),
        if (ret.salesReturnStatus == SalesReturnStatus.draft) ...[
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Edit Draft')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'submit',
            child: Row(
              children: [
                Icon(Icons.send_outlined, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(child: Text('Submit for Review')),
              ],
            ),
          ),
        ],
        if (ret.salesReturnStatus == SalesReturnStatus.submitted)
          const PopupMenuItem(
            value: 'receive',
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.info),
                SizedBox(width: 8),
                Expanded(child: Text('Mark Items Received')),
              ],
            ),
          ),
        if (ret.salesReturnStatus == SalesReturnStatus.itemsReceived)
          const PopupMenuItem(
            value: 'inspect',
            child: Row(
              children: [
                Icon(Icons.find_in_page_outlined, size: 16, color: AppColors.warning),
                SizedBox(width: 8),
                Expanded(child: Text('Start QA Inspection')),
              ],
            ),
          ),
        if (ret.salesReturnStatus != SalesReturnStatus.approved &&
            ret.salesReturnStatus != SalesReturnStatus.completed &&
            ret.salesReturnStatus != SalesReturnStatus.rejected) ...[
          const PopupMenuItem(
            value: 'approve',
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                SizedBox(width: 8),
                Expanded(child: Text('Approve & Restock')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'reject',
            child: Row(
              children: [
                Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
                SizedBox(width: 8),
                Expanded(child: Text('Reject Return')),
              ],
            ),
          ),
        ],
        if (ret.refundStatus == RefundStatus.pending || ret.refundStatus == RefundStatus.approved)
          const PopupMenuItem(
            value: 'refund',
            child: Row(
              children: [
                Icon(Icons.payments_outlined, size: 16, color: AppColors.success),
                SizedBox(width: 8),
                Expanded(child: Text('Process Refund / Credit')),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'view_invoice',
          child: Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('View Original Invoice')),
            ],
          ),
        ),
      ],
    );
  }
}
