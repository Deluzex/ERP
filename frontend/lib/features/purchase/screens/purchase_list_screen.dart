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
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../shared/providers/app_state_providers.dart';
import 'create_purchase_screen.dart';

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
          final isMobile = MediaQuery.of(ctx).size.width < 768;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Invoice Details: ${p.purchaseNumber}',
                          style: AppTextStyles.h2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusBadge(p.status),
                if (p.status != PurchaseStatus.cancelled) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Edit / Reopen Purchase',
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreatePurchaseScreen(existingPurchase: p),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            content: SizedBox(
              width: 720,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.78,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(),
                      const SizedBox(height: 12),

                      // Header Info Grid
                      Wrap(
                        spacing: isMobile ? 16 : 24,
                        runSpacing: 12,
                        children: [
                          _buildDetailField('Vendor Name', p.vendorName),
                          _buildDetailField('Vendor Invoice', p.vendorInvoiceNumber.isNotEmpty ? p.vendorInvoiceNumber : 'N/A'),
                          _buildDetailField('Purchase Date', Formatters.formatDate(p.purchaseDate)),
                          if (p.isModified && p.updatedAt != null)
                            _buildDetailField('Modified Date', Formatters.formatDateTime(p.updatedAt!)),
                          _buildDetailField('Purchase Type', p.purchaseTypeLabel),
                          _buildDetailField('Payment Mode', p.paymentMode.name.toUpperCase()),
                          if (p.projectName != null && p.projectName!.isNotEmpty)
                            _buildDetailField('Project', p.projectName!),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Purchased Items Table Heading
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Purchased Items & Materials (${p.items.length})',
                              style: AppTextStyles.h3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLoading) ...[
                            const SizedBox(width: 8),
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Items Breakdown Table
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: p.items.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: isLoading
                                      ? const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                            SizedBox(width: 10),
                                            Text(
                                              'Loading items from server...',
                                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'No line items recorded for this purchase order.',
                                          style: TextStyle(color: AppColors.textMuted),
                                        ),
                                ),
                              )
                            : isMobile
                                ? SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: 540,
                                      child: _buildPurchaseItemsTable(p),
                                    ),
                                  )
                                : _buildPurchaseItemsTable(p),
                      ),
                      const SizedBox(height: 20),

                      // Financial Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            _buildCostRow('Taxable Subtotal:', Formatters.formatCurrency(p.subtotalAmount)),
                            const SizedBox(height: 6),
                            if (p.isInterStateTax)
                              _buildCostRow('IGST Tax:', Formatters.formatCurrency(p.igstAmount))
                            else ...[
                              _buildCostRow('CGST Tax:', Formatters.formatCurrency(p.cgstAmount)),
                              const SizedBox(height: 6),
                              _buildCostRow('SGST Tax:', Formatters.formatCurrency(p.sgstAmount)),
                            ],
                            if (p.transportationCharges > 0) ...[
                              const SizedBox(height: 6),
                              _buildCostRow('Transportation Charges:', Formatters.formatCurrency(p.transportationCharges), highlight: true),
                            ],
                            const Divider(height: 16),
                            _buildCostRow('Total Invoice Amount:', Formatters.formatCurrency(p.totalAmount), isBold: true),
                            const SizedBox(height: 6),
                            _buildCostRow('Amount Paid:', Formatters.formatCurrency(p.paidAmount), valueColor: AppColors.successText),
                            const SizedBox(height: 6),
                            _buildCostRow(
                              'Balance Pending:',
                              Formatters.formatCurrency(p.pendingAmount),
                              isBold: true,
                              highlight: p.pendingAmount > 0,
                              valueColor: p.pendingAmount > 0 ? AppColors.dangerText : AppColors.successText,
                            ),
                          ],
                        ),
                      ),

                      if (p.notes != null && p.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Purchase Notes / Remarks:', style: AppTextStyles.bodyBold),
                        const SizedBox(height: 4),
                        Text(p.notes!, style: AppTextStyles.bodySmall),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actions: isMobile
                ? [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (p.status != PurchaseStatus.cancelled) ...[
                          ErpButton(
                            text: 'Edit Purchase',
                            icon: Icons.edit_outlined,
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreatePurchaseScreen(existingPurchase: p),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                        ErpButton(
                          text: 'Close',
                          isOutlined: true,
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ]
                : [
                    if (p.status != PurchaseStatus.cancelled) ...[
                      ErpButton(
                        text: 'Edit Purchase',
                        icon: Icons.edit_outlined,
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreatePurchaseScreen(existingPurchase: p),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    ErpButton(
                      text: 'Close',
                      isOutlined: true,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
          );
        },
      ),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
      ],
    );
  }

  Widget _tableHeaderCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(text, textAlign: align, style: AppTextStyles.bodyBold.copyWith(fontSize: 11, color: AppColors.textSecondary)),
    );
  }

  Widget _buildPurchaseItemsTable(Purchase p) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(4),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(2.2),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.surfaceMuted),
          children: [
            _tableHeaderCell('Item / Material'),
            _tableHeaderCell('Qty'),
            _tableHeaderCell('Unit Rate'),
            _tableHeaderCell('GST'),
            _tableHeaderCell('Total'),
          ],
        ),
        ...p.items.map((item) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                    ),
                    if (item.displayCode.isNotEmpty)
                      Text(
                        item.displayCode,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  Formatters.formatQuantity(item.quantity, item.unit),
                  style: AppTextStyles.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  Formatters.formatCurrency(item.rate),
                  style: AppTextStyles.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  '${Formatters.formatNumber(item.gstPercent)}%',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  Formatters.formatCurrency(item.lineTotal),
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildCostRow(
    String title,
    String amount, {
    bool isBold = false,
    bool highlight = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: isBold
                ? AppTextStyles.bodyBold.copyWith(
                    color: highlight ? AppColors.primaryDark : AppColors.textPrimary,
                  )
                : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          amount,
          style: isBold
              ? AppTextStyles.bodyBold.copyWith(
                  color: valueColor ?? (highlight ? AppColors.primaryDark : AppColors.textPrimary),
                  fontSize: highlight ? 15 : 13,
                )
              : AppTextStyles.bodySmall.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                ),
        ),
      ],
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
          // Header enclosed in Figma card container
          ErpSectionHeaderCard(
            icon: Icons.shopping_bag_outlined,
            title: 'Purchase Invoices',
            badgeText: 'PURCHASE MANAGEMENT',
            actions: [
              ErpButton(
                text: 'Create Direct Purchase',
                icon: Icons.add,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase,
              ),
              // ErpButton(
              //   text: 'Refresh',
              //   icon: Icons.refresh,
              //   isOutlined: true,
              //   isLoading: db.isLoadingPurchases,
              //   onPressed: () => db.loadPurchases(forceRefresh: true),
              // ),
            ],
          ),
          const SizedBox(height: 20),

          // KPI Metric Strip
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final cards = [
                _buildMetricCard(
                  title: 'TOTAL INVOICES',
                  value: '${db.purchases.length}',
                  subtitle: 'All-time purchase invoices',
                  icon: Icons.receipt_long_outlined,
                  color: Colors.purple,
                ),
                _buildMetricCard(
                  title: 'TOTAL PURCHASES',
                  value: Formatters.formatCurrency(db.totalPurchaseAmount),
                  subtitle: 'Cumulative purchases value',
                  icon: Icons.shopping_bag_outlined,
                  color: Colors.indigo,
                ),
                _buildMetricCard(
                  title: 'PAID INVOICES',
                  value: '${db.purchases.where((p) => p.status == PurchaseStatus.paid).length}',
                  subtitle: 'Fully settled bills',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
                _buildMetricCard(
                  title: 'VENDOR PAYABLES',
                  value: Formatters.formatCurrency(db.pendingVendorPayments),
                  subtitle: '${db.vendors.where((v) => !v.isDeleted && v.outstandingBalance > 0).length} Vendors pending payment',
                  icon: Icons.account_balance_outlined,
                  color: Colors.red,
                ),
              ];

              if (width >= 1100) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: cards.asMap().entries.map((entry) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: entry.key == 0 ? 0 : 16),
                          child: entry.value,
                        ),
                      );
                    }).toList(),
                  ),
                );
              } else if (width >= 600) {
                final halfWidth = (width - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: cards.map((c) => SizedBox(width: halfWidth, child: c)).toList(),
                );
              } else {
                return Column(
                  children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // Table enclosed in Figma card container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modern Filter Controls Bar (Responsive: vertical stack on mobile, horizontal wrap on desktop)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 650;
                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ErpSearchInput(
                            hintText: 'Search by invoice no, vendor, bills...',
                            initialValue: _searchQuery,
                            onChanged: (val) => setState(() {
                              _searchQuery = val;
                              _currentPage = 0;
                            }),
                          ),
                          const SizedBox(height: 10),
                          ErpFilterDropdown<String>(
                            value: _selectedStatusFilter,
                            width: double.infinity,
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
                          const SizedBox(height: 10),
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
                    );
                  },
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
                    return [
                      Text(p.purchaseNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Formatters.formatDate(p.displayDate), style: AppTextStyles.bodySmall),
                          if (p.isModified && p.updatedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Modified',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
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
                      _buildStatusBadge(p.status),
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
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.paid:
        return ErpStatusBadge.paid('PAID');
      case PurchaseStatus.partialPaid:
        return ErpStatusBadge.partial('PARTIAL');
      case PurchaseStatus.saved:
        return ErpStatusBadge.saved('SAVED');
      case PurchaseStatus.draft:
        return ErpStatusBadge.draft('DRAFT');
      case PurchaseStatus.cancelled:
        return ErpStatusBadge.cancelled('CANCELLED');
    }
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
