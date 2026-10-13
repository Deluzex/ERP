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
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../shared/providers/app_state_providers.dart';

class PurchaseListScreen extends ConsumerStatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  ConsumerState<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends ConsumerState<PurchaseListScreen> {
  String _searchQuery = '';
  String _selectedStatusFilter = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  int _pageSize = 25;

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
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Cancel Purchase ${p.purchaseNumber}?', style: AppTextStyles.h3),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            width: double.infinity,
            child: Form(
              key: formKey,
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

  void _showPurchaseDetailsDialog(Purchase initialPurchase) {
    Purchase currentPurchase = initialPurchase;
    bool isLoading = initialPurchase.items.isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          if (isLoading) {
            ref.read(databaseServiceProvider).getPurchaseDetailAsync(initialPurchase.id).then((full) {
              if (ctx.mounted) {
                setDlgState(() {
                  currentPurchase = full;
                  isLoading = false;
                });
              }
            }).catchError((_) {
              if (ctx.mounted) {
                setDlgState(() => isLoading = false);
              }
            });
          }

          final p = currentPurchase;

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('PO Details: ${p.purchaseNumber}', style: AppTextStyles.h3),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 650),
              width: double.infinity,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Line Items (${p.items.length})', style: AppTextStyles.bodyBold),
                        if (isLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (p.items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'No line items recorded for this purchase order.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      )
                    else
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
                                  child: Text(
                                    item.displayCode.isNotEmpty
                                        ? '${item.displayName} (${item.displayCode})'
                                        : item.displayName,
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    Formatters.formatQuantity(item.quantity, item.unit),
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(Formatters.formatCurrency(item.rate), style: AppTextStyles.bodySmall),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text('${Formatters.formatNumber(item.gstPercent)}%', style: AppTextStyles.bodySmall),
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final purchases = db.purchases.where((p) {
      if (_selectedStatusFilter != 'ALL') {
        switch (_selectedStatusFilter) {
          case 'SAVED':
            if (p.status != PurchaseStatus.saved) return false;
            break;
          case 'PARTIAL':
            if (p.status != PurchaseStatus.partialPaid) return false;
            break;
          case 'PAID':
            if (p.status != PurchaseStatus.paid) return false;
            break;
          case 'DRAFT':
            if (p.status != PurchaseStatus.draft) return false;
            break;
          case 'CANCELLED':
            if (p.status != PurchaseStatus.cancelled) return false;
            break;
        }
      }
      if (_startDate != null && p.purchaseDate.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) {
        return false;
      }
      if (_endDate != null && p.purchaseDate.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) {
        return false;
      }
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matches = p.purchaseNumber.toLowerCase().contains(query) ||
            p.vendorName.toLowerCase().contains(query) ||
            p.vendorInvoiceNumber.toLowerCase().contains(query) ||
            (p.notes != null && p.notes!.toLowerCase().contains(query)) ||
            p.status.name.toLowerCase().contains(query) ||
            p.items.any((item) => item.displayName.toLowerCase().contains(query));
        if (!matches) return false;
      }
      return true;
    }).toList();

    final totalRecords = purchases.length;
    final safePageSize = _pageSize <= 0 ? 25 : _pageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = _currentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);
    final pagedPurchases = totalRecords == 0 ? <Purchase>[] : purchases.sublist(startIndex, endIndex);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 600;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Purchase Invoices', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text(
                    'Vendor purchase invoices, incoming bills, and payment statuses',
                    style: AppTextStyles.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );

              final actionBlock = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ErpButton(
                    text: 'Refresh',
                    icon: Icons.refresh,
                    isOutlined: true,
                    isLoading: db.isLoadingPurchases,
                    onPressed: () => db.loadPurchases(forceRefresh: true),
                  ),
                  ErpButton(
                    text: 'Create Direct Purchase',
                    icon: Icons.add,
                    onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase,
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
                  const SizedBox(width: 12),
                  actionBlock,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Modern Filter Controls Bar
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: ErpSearchInput(
                  hintText: 'Search by invoice no, vendor, bills...',
                  initialValue: _searchQuery,
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _currentPage = 0;
                  }),
                ),
              ),
              ErpFilterDropdown<String>(
                value: _selectedStatusFilter,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'SAVED', child: Text('Saved / Inward')),
                  DropdownMenuItem(value: 'PARTIAL', child: Text('Partial Paid')),
                  DropdownMenuItem(value: 'PAID', child: Text('Paid')),
                  DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                  DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedStatusFilter = val;
                      _currentPage = 0;
                    });
                  }
                },
              ),
              ErpDateFilterBox(
                startDate: _startDate,
                endDate: _endDate,
                onDateRangeSelected: (start, end) => setState(() {
                  _startDate = start;
                  _endDate = end;
                  _currentPage = 0;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Invoice Number'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Vendor Name'),
              ErpColumn(title: 'Vendor Invoice'),
              ErpColumn(title: 'Items Count', isNumeric: true),
              ErpColumn(title: 'Total Amount', isNumeric: true),
              ErpColumn(title: 'Paid Amount', isNumeric: true),
              ErpColumn(title: 'Pending Amount', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Actions', width: 90, alignment: Alignment.center),
            ],
            rows: pagedPurchases.map((p) {
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
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (action) {
                    switch (action) {
                      case 'view':
                        _showPurchaseDetailsDialog(p);
                        break;
                      case 'cancel':
                        _confirmCancelPurchase(p);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('View Purchase Details'),
                        ],
                      ),
                    ),
                    if (p.status != PurchaseStatus.cancelled)
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
                            SizedBox(width: 8),
                            Text('Cancel Purchase'),
                          ],
                        ),
                      ),
                  ],
                ),
              ];
            }).toList(),
          ),
          const SizedBox(height: 16),
          ErpPaginationBar(
            currentPage: safeCurrentPage,
            pageSize: safePageSize,
            totalRecords: totalRecords,
            onPageChanged: (newPage) => setState(() => _currentPage = newPage),
            onPageSizeChanged: (newSize) => setState(() {
              _pageSize = newSize;
              _currentPage = 0;
            }),
          ),
        ],
      ),
    );
  }
}
