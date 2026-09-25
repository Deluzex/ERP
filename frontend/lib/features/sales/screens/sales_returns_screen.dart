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
import '../../../core/widgets/stat_card.dart';
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
  RefundStatus? _selectedRefundStatusFilter;

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
    ReturnCondition returnCondition = existingReturn?.returnCondition ?? ReturnCondition.resalable;
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

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.assignment_return_outlined, color: AppColors.danger, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEdit ? 'Edit Sales Return (${existingReturn.invoiceNumber})' : 'Create Sales Return & Credit Note', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Text('Link to sales invoice, inspect product condition & apply audited adjustments', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 820,
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
                                child: Text('${inv.invoiceNumber} — ${inv.partyName} (Total: ${Formatters.formatCurrency(inv.totalAmount)}, Pending: ${Formatters.formatCurrency(inv.pendingAmount)})'),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            child: Row(
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
                                  width: 160,
                                  child: DropdownButtonFormField<ReturnCondition>(
                                    value: currentCondition,
                                    isDense: true,
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
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Reason & Settlement settings
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<ReturnFinancialAction>(
                            value: financialAction,
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
                        color: AppColors.primarySoft.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Items Selected: $totalItemsToReturn products', style: AppTextStyles.bodyBold),
                              const SizedBox(height: 2),
                              Text('Taxable: ${Formatters.formatCurrency(liveSubtotal - liveDiscount)} | GST: ${Formatters.formatCurrency(liveGst)}', style: AppTextStyles.bodySmall),
                            ],
                          ),
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
            actions: [
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
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success, size: 24),
            SizedBox(width: 10),
            Text('Approve Sales Return & Process Adjustments'),
          ],
        ),
        content: SizedBox(
          width: 500,
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
        actions: [
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
      ),
    );
  }

  void _showRejectConfirmationDialog(BuildContext context, Sale returnDoc, MockDatabaseService db) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.danger, size: 24),
            SizedBox(width: 10),
            Text('Reject Sales Return'),
          ],
        ),
        content: SizedBox(
          width: 450,
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
        actions: [
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
      ),
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
                    const Text('Process Customer Refund / Credit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Return: ${returnDoc.invoiceNumber} | Customer: ${returnDoc.partyName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
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
            actions: [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales Returns & Credit Notes', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text(
                      'Multi-stage return verification: QA Inspection, Condition Routing (Resalable/Damaged/Scrap), Ledger Adjustments & Refunds',
                      style: AppTextStyles.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ErpButton(
                text: 'Create Sales Return',
                icon: Icons.assignment_return_outlined,
                onPressed: () => _showCreateOrEditSalesReturnDialog(context, db),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Stat Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1200
                  ? 4
                  : constraints.maxWidth >= 750
                      ? 2
                      : 1;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                children: [
                  StatCard(
                    title: 'Total Sales Returns',
                    value: '${db.salesReturns.length}',
                    trendText: '₹${Formatters.formatNumber(db.salesReturns.fold(0.0, (sum, r) => sum + r.totalAmount))} total return value',
                    icon: const Icon(Icons.assignment_return_outlined, color: AppColors.primary, size: 20),
                  ),
                  StatCard(
                    title: 'Approved & Restocked',
                    value: '$approvedCount',
                    trendText: Formatters.formatCurrency(db.totalSalesReturnsAmount),
                    icon: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                  ),
                  StatCard(
                    title: 'In Inspection & Review',
                    value: '$inspectionCount',
                    trendText: '$draftCount drafts pending submission',
                    icon: const Icon(Icons.pending_actions_outlined, color: AppColors.warning, size: 20),
                  ),
                  StatCard(
                    title: 'Pending Refunds',
                    value: '${db.pendingRefundsCount}',
                    trendText: 'Customer payout or credit required',
                    icon: const Icon(Icons.payments_outlined, color: AppColors.danger, size: 20),
                  ),
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
              onTap: (_) => setState(() {}),
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
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search by return number, customer, invoice ref, or reason...',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String?>(
                  value: (_selectedCustomerFilter != null && db.customers.any((c) => c.id == _selectedCustomerFilter)) ? _selectedCustomerFilter : null,
                  decoration: const InputDecoration(labelText: 'Filter Customer', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Customers')),
                    ...db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (val) => setState(() => _selectedCustomerFilter = val),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<ReturnType?>(
                  value: _selectedReturnTypeFilter,
                  decoration: const InputDecoration(labelText: 'Return Type', isDense: true),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Return Types')),
                    DropdownMenuItem(value: ReturnType.fullReturn, child: Text('Full Return')),
                    DropdownMenuItem(value: ReturnType.partialReturn, child: Text('Partial Return')),
                  ],
                  onChanged: (val) => setState(() => _selectedReturnTypeFilter = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 5. Returns Data Table
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
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'Return No'),
                ErpColumn(title: 'Date'),
                ErpColumn(title: 'Customer / Party'),
                ErpColumn(title: 'Original Invoice'),
                ErpColumn(title: 'Return Type'),
                ErpColumn(title: 'Return Value', isNumeric: true),
                ErpColumn(title: 'Refund Status'),
                ErpColumn(title: 'Return Status'),
                ErpColumn(title: 'Created By'),
                ErpColumn(title: 'Actions'),
              ],
              rows: filtered.map((ret) {
                // Status Badges
                ErpStatusBadge statusBadge;
                switch (ret.salesReturnStatus ?? SalesReturnStatus.draft) {
                  case SalesReturnStatus.approved:
                  case SalesReturnStatus.completed:
                    statusBadge = ErpStatusBadge.success('COMPLETED');
                    break;
                  case SalesReturnStatus.inspection:
                    statusBadge = ErpStatusBadge.warning('INSPECTION');
                    break;
                  case SalesReturnStatus.itemsReceived:
                    statusBadge = ErpStatusBadge.info('RECEIVED');
                    break;
                  case SalesReturnStatus.submitted:
                    statusBadge = ErpStatusBadge.purple('SUBMITTED');
                    break;
                  case SalesReturnStatus.draft:
                    statusBadge = ErpStatusBadge.neutral('DRAFT');
                    break;
                  case SalesReturnStatus.rejected:
                    statusBadge = ErpStatusBadge.danger('REJECTED');
                    break;
                  default:
                    statusBadge = ErpStatusBadge.neutral('PENDING');
                }

                ErpStatusBadge refundBadge;
                switch (ret.refundStatus ?? RefundStatus.notRequired) {
                  case RefundStatus.processed:
                    refundBadge = ErpStatusBadge.success('REFUNDED');
                    break;
                  case RefundStatus.pending:
                    refundBadge = ErpStatusBadge.danger('REFUND DUE');
                    break;
                  case RefundStatus.approved:
                    refundBadge = ErpStatusBadge.warning('REFUND APPR');
                    break;
                  case RefundStatus.notRequired:
                    refundBadge = ErpStatusBadge.neutral('NOT REQ');
                    break;
                  case RefundStatus.cancelled:
                    refundBadge = ErpStatusBadge.neutral('CANCELLED');
                    break;
                }

                return [
                  InkWell(
                    onTap: () {
                      ref.read(activeRecordDetailsStackProvider.notifier).push(ret.id, 'salesReturn', ErpNavSection.salesReturns);
                    },
                    child: Text(
                      ret.invoiceNumber,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primary),
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
                  Text(ret.createdBy ?? 'Staff', style: AppTextStyles.bodySmall),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    tooltip: 'Workflow Actions',
                    onSelected: (val) {
                      switch (val) {
                        case 'view':
                          ref.read(activeRecordDetailsStackProvider.notifier).push(ret.id, 'salesReturn', ErpNavSection.salesReturns);
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
                        case 'pdf':
                          SalesPdfGeneratorDialog.show(context, ret, db);
                          break;
                        case 'view_invoice':
                          if (ret.originalInvoiceId != null) {
                            ref.read(activeRecordDetailsStackProvider.notifier).push(ret.originalInvoiceId!, 'invoice', ErpNavSection.salesReturns);
                          }
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility_outlined, size: 16), SizedBox(width: 8), Text('View Full Details')])),
                      if (ret.salesReturnStatus == SalesReturnStatus.draft) ...[
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit Draft')])),
                        const PopupMenuItem(value: 'submit', child: Row(children: [Icon(Icons.send_outlined, size: 16, color: AppColors.primary), SizedBox(width: 8), Text('Submit for Review')])),
                      ],
                      if (ret.salesReturnStatus == SalesReturnStatus.submitted)
                        const PopupMenuItem(value: 'receive', child: Row(children: [Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.info), SizedBox(width: 8), Text('Mark Items Received')])),
                      if (ret.salesReturnStatus == SalesReturnStatus.itemsReceived)
                        const PopupMenuItem(value: 'inspect', child: Row(children: [Icon(Icons.find_in_page_outlined, size: 16, color: AppColors.warning), SizedBox(width: 8), Text('Start QA Inspection')])),
                      if (ret.salesReturnStatus != SalesReturnStatus.approved && ret.salesReturnStatus != SalesReturnStatus.completed && ret.salesReturnStatus != SalesReturnStatus.rejected) ...[
                        const PopupMenuItem(value: 'approve', child: Row(children: [Icon(Icons.check_circle_outline, size: 16, color: AppColors.success), SizedBox(width: 8), Text('Approve & Restock')])),
                        const PopupMenuItem(value: 'reject', child: Row(children: [Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger), SizedBox(width: 8), Text('Reject Return')])),
                      ],
                      if (ret.refundStatus == RefundStatus.pending || ret.refundStatus == RefundStatus.approved)
                        const PopupMenuItem(value: 'refund', child: Row(children: [Icon(Icons.payments_outlined, size: 16, color: AppColors.success), SizedBox(width: 8), Text('Process Refund / Credit')])),
                      const PopupMenuItem(value: 'view_invoice', child: Row(children: [Icon(Icons.receipt_long_outlined, size: 16), SizedBox(width: 8), Text('View Original Invoice')])),
                      const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, size: 16, color: AppColors.primary), SizedBox(width: 8), Text('Credit Note PDF')])),
                    ],
                  ),
                ];
              }).toList(),
            ),
        ],
      ),
    );
  }
}
