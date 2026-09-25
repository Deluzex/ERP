import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class PurchaseListScreen extends ConsumerStatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  ConsumerState<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends ConsumerState<PurchaseListScreen> {
  String _searchQuery = '';
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadPurchases();
    });
  }

  Future<void> _confirmCancelPurchase(Purchase p) async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              const SizedBox(width: 8),
              Text('Cancel Purchase ${p.purchaseNumber}?', style: AppTextStyles.h3),
            ],
          ),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cancelling this purchase will automatically rollback all inwarded stock from inventory and reduce vendor outstanding balances.',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Cancellation reason is required';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Cancellation Reason *',
                      hintText: 'E.g., Wrong invoice received / Goods returned to vendor',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ErpButton(
              text: isSubmitting ? 'Cancelling...' : 'Confirm Cancellation',
              isDanger: true,
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        final db = ref.read(databaseServiceProvider);
                        await db.updatePurchaseStatusAsync(
                          p.id,
                          status: 'cancelled',
                          cancelReason: reasonCtrl.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Purchase cancelled and stock rolled back successfully'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (err) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $err'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseDetailsDialog(Purchase p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PO Details: ${p.purchaseNumber}', style: AppTextStyles.h3),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vendor: ${p.vendorName}', style: AppTextStyles.bodyBold),
                        Text('Invoice #: ${p.vendorInvoiceNumber}', style: AppTextStyles.bodySmall),
                        Text('Date: ${Formatters.formatDate(p.purchaseDate)}', style: AppTextStyles.bodySmall),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Type: ${p.purchaseTypeLabel}', style: AppTextStyles.bodyBold),
                        Text('Payment Mode: ${p.paymentMode.name.toUpperCase()}', style: AppTextStyles.bodySmall),
                        Text('Status: ${p.statusLabel}', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text('Line Items (${p.items.length})', style: AppTextStyles.bodyBold),
                const SizedBox(height: 8),
                Table(
                  border: TableBorder.all(color: AppColors.border),
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: AppColors.surfaceMuted),
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text('Item', style: AppTextStyles.bodyBold)),
                        Padding(padding: const EdgeInsets.all(8), child: Text('Qty', style: AppTextStyles.bodyBold)),
                        Padding(padding: const EdgeInsets.all(8), child: Text('Rate', style: AppTextStyles.bodyBold)),
                        Padding(padding: const EdgeInsets.all(8), child: Text('GST', style: AppTextStyles.bodyBold)),
                        Padding(padding: const EdgeInsets.all(8), child: Text('Total', style: AppTextStyles.bodyBold)),
                      ],
                    ),
                    ...p.items.map(
                      (item) => TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('${item.displayName} (${item.displayCode})', style: AppTextStyles.bodySmall),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('${item.quantity} ${item.unit}', style: AppTextStyles.bodySmall),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(Formatters.formatCurrency(item.rate), style: AppTextStyles.bodySmall),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('${item.gstPercent}%', style: AppTextStyles.bodySmall),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(Formatters.formatCurrency(item.lineTotal), style: AppTextStyles.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Subtotal: ${Formatters.formatCurrency(p.subtotalAmount)}', style: AppTextStyles.bodySmall),
                      Text('GST Tax: ${Formatters.formatCurrency(p.gstAmount)}', style: AppTextStyles.bodySmall),
                      Text('Total Amount: ${Formatters.formatCurrency(p.totalAmount)}', style: AppTextStyles.bodyBold),
                      Text('Paid Amount: ${Formatters.formatCurrency(p.paidAmount)}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText)),
                      Text('Pending Amount: ${Formatters.formatCurrency(p.pendingAmount)}',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: p.pendingAmount > 0 ? AppColors.dangerText : AppColors.successText,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final purchases = db.purchases.where((p) {
      if (_selectedStatusFilter != 'all' && p.status.name.toLowerCase() != _selectedStatusFilter) {
        return false;
      }
      final query = _searchQuery.trim().toLowerCase();
      return query.isEmpty ||
          p.purchaseNumber.toLowerCase().contains(query) ||
          p.vendorName.toLowerCase().contains(query) ||
          p.vendorInvoiceNumber.toLowerCase().contains(query) ||
          (p.notes != null && p.notes!.toLowerCase().contains(query)) ||
          p.status.toString().toLowerCase().contains(query) ||
          p.items.any((item) => item.displayName.toLowerCase().contains(query));
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
                  Text('Purchase Orders', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Vendor purchase orders, incoming invoices, and payment statuses', style: AppTextStyles.subtitle),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: db.isLoadingPurchases
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: 'Refresh Purchases',
                    onPressed: () => db.loadPurchases(forceRefresh: true),
                  ),
                  const SizedBox(width: 8),
                  ErpButton(
                    text: 'Create Purchase',
                    icon: Icons.add,
                    onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search and Filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search purchase by PO number, vendor name or invoice number...',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedStatusFilter == 'all',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedStatusFilter = 'all');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Saved / Inward'),
                    selected: _selectedStatusFilter == 'saved',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedStatusFilter = 'saved');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Partial'),
                    selected: _selectedStatusFilter == 'partialpaid',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedStatusFilter = 'partialpaid');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Paid'),
                    selected: _selectedStatusFilter == 'paid',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedStatusFilter = 'paid');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Cancelled'),
                    selected: _selectedStatusFilter == 'cancelled',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedStatusFilter = 'cancelled');
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'PO Number'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Vendor Name'),
              ErpColumn(title: 'Vendor Invoice'),
              ErpColumn(title: 'Items Count', isNumeric: true),
              ErpColumn(title: 'Total Amount', isNumeric: true),
              ErpColumn(title: 'Paid Amount', isNumeric: true),
              ErpColumn(title: 'Pending Amount', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Actions'),
            ],
            rows: purchases.map((p) {
              ErpStatusBadge badge;
              switch (p.status) {
                case PurchaseStatus.paid:
                  badge = ErpStatusBadge.success('PAID');
                  break;
                case PurchaseStatus.partialPaid:
                  badge = ErpStatusBadge.warning('PARTIAL');
                  break;
                case PurchaseStatus.saved:
                  badge = ErpStatusBadge.info('SAVED');
                  break;
                case PurchaseStatus.draft:
                  badge = ErpStatusBadge.neutral('DRAFT');
                  break;
                case PurchaseStatus.cancelled:
                  badge = ErpStatusBadge.danger('CANCELLED');
                  break;
              }

              return [
                Text(p.purchaseNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                Text(Formatters.formatDate(p.purchaseDate), style: AppTextStyles.bodySmall),
                Text(p.vendorName, style: AppTextStyles.bodyMedium),
                Text(p.vendorInvoiceNumber, style: AppTextStyles.bodySmall),
                Text('${p.items.length} items', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(p.totalAmount), style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(p.paidAmount), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.successText)),
                Text(
                  Formatters.formatCurrency(p.pendingAmount),
                  style: AppTextStyles.bodyBold.copyWith(
                    color: p.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted,
                  ),
                ),
                badge,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      tooltip: 'View Purchase Details',
                      onPressed: () => _showPurchaseDetailsDialog(p),
                    ),
                    if (p.status != PurchaseStatus.cancelled)
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
                        tooltip: 'Cancel Purchase Order',
                        onPressed: () => _confirmCancelPurchase(p),
                      ),
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
