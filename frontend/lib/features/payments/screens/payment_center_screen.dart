import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/commission_model.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/models/dealer_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/models/vendor_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';

class PaymentCenterScreen extends ConsumerStatefulWidget {
  final PaymentType? initialTab;

  const PaymentCenterScreen({super.key, this.initialTab});

  @override
  ConsumerState<PaymentCenterScreen> createState() => _PaymentCenterScreenState();
}

class _PaymentCenterScreenState extends ConsumerState<PaymentCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  TextEditingController? _customerSearchCtrl;
  TextEditingController get _safeCustomerSearchCtrl => _customerSearchCtrl ??= TextEditingController();
  String _customerSearchQuery = '';
  int _customerPageSize = 10;
  int _customerCurrentPage = 0;
  int get _safeCustomerPageSize => _safeInt(_customerPageSize, 10);
  int get _safeCustomerCurrentPage => _safeInt(_customerCurrentPage, 0);

  TextEditingController? _dealerSearchCtrl;
  TextEditingController get _safeDealerSearchCtrl => _dealerSearchCtrl ??= TextEditingController();
  String _dealerSearchQuery = '';
  int _dealerPageSize = 10;
  int _dealerCurrentPage = 0;
  int get _safeDealerPageSize => _safeInt(_dealerPageSize, 10);
  int get _safeDealerCurrentPage => _safeInt(_dealerCurrentPage, 0);

  TextEditingController? _vendorSearchCtrl;
  TextEditingController get _safeVendorSearchCtrl => _vendorSearchCtrl ??= TextEditingController();
  String _vendorSearchQuery = '';
  int _vendorPageSize = 10;
  int _vendorCurrentPage = 0;
  int get _safeVendorPageSize => _safeInt(_vendorPageSize, 10);
  int get _safeVendorCurrentPage => _safeInt(_vendorCurrentPage, 0);

  @override
  void initState() {
    super.initState();
    _customerSearchCtrl ??= TextEditingController();
    _dealerSearchCtrl ??= TextEditingController();
    _vendorSearchCtrl ??= TextEditingController();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialTab != null) {
      _tabController.index = widget.initialTab!.index;
    }
    _tabController.addListener(_handleTabChange);
    Future.microtask(() {
      final db = ref.read(databaseServiceProvider);
      db.loadPayments();
      db.loadCommissions();
      db.loadCustomers();
      db.loadDealers();
      db.loadSalesInvoices();
      db.loadVendors();
      db.loadPurchases();
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
      final targetSection = _getSectionForIndex(_tabController.index);
      if (ref.read(currentNavSectionProvider) != targetSection) {
        ref.read(currentNavSectionProvider.notifier).state = targetSection;
      }
    }
  }

  ErpNavSection _getSectionForIndex(int index) {
    switch (index) {
      case 0:
        return ErpNavSection.customerPayments;
      case 1:
        return ErpNavSection.dealerPayments;
      case 2:
        return ErpNavSection.vendorPaymentsSection;
      case 3:
        return ErpNavSection.commissionPayments;
      default:
        return ErpNavSection.customerPayments;
    }
  }

  @override
  void didUpdateWidget(PaymentCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != null && widget.initialTab != oldWidget.initialTab) {
      if (_tabController.index != widget.initialTab!.index) {
        _tabController.animateTo(widget.initialTab!.index);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _customerSearchCtrl?.dispose();
    _dealerSearchCtrl?.dispose();
    _vendorSearchCtrl?.dispose();
    super.dispose();
  }

  void _openRecordPaymentDialog(PaymentType type, {String? preselectedPartyId}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RecordPaymentDialog(
        type: type,
        preselectedPartyId: preselectedPartyId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);

    ref.listen<ErpNavSection>(currentNavSectionProvider, (previous, next) {
      int? targetIndex;
      if (next == ErpNavSection.customerPayments) {
        targetIndex = 0;
      } else if (next == ErpNavSection.dealerPayments) {
        targetIndex = 1;
      } else if (next == ErpNavSection.vendorPayments || next == ErpNavSection.vendorPaymentsSection) {
        targetIndex = 2;
      } else if (next == ErpNavSection.commissionPayments) {
        targetIndex = 3;
      }

      if (targetIndex != null && _tabController.index != targetIndex) {
        _tabController.animateTo(targetIndex);
        setState(() {});
      }
    });

    final (buttonLabel, currentPaymentType) = switch (_tabController.index) {
      0 => ('Record Customer Receipt', PaymentType.customerPayment),
      1 => ('Record Dealer Receipt', PaymentType.dealerPayment),
      2 => ('Record Vendor Payment', PaymentType.vendorPayment),
      3 => ('Record Commission Payout', PaymentType.commissionPayment),
      _ => ('Record Payment', PaymentType.customerPayment),
    };

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isSmall ? double.infinity : constraints.maxWidth - 240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payments & Treasury Center', style: AppTextStyles.h1),
                        const SizedBox(height: 4),
                        Text(
                          'Manual payment entry (Full & Partial), invoice balance auto-reconciliation, and treasury tracking',
                          style: AppTextStyles.subtitle,
                        ),
                      ],
                    ),
                  ),
                  ErpButton(
                    text: buttonLabel,
                    icon: Icons.add,
                    onPressed: () => _openRecordPaymentDialog(currentPaymentType),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            onTap: (index) {
              setState(() {});
              final targetSection = _getSectionForIndex(index);
              if (ref.read(currentNavSectionProvider) != targetSection) {
                ref.read(currentNavSectionProvider.notifier).state = targetSection;
              }
            },
            tabs: const [
              Tab(text: 'Customer Collections'),
              Tab(text: 'Dealer Receipts'),
              Tab(text: 'Vendor Disbursements'),
              Tab(text: 'Commission Payouts'),
            ],
          ),
          const SizedBox(height: 16),

          if (_tabController.index > 2) ...[
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search payments by payment no, party name, ref doc, UTR, or notes...',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
            ),
            const SizedBox(height: 20),
          ],

          SizedBox(
            height: 680,
            child: IndexedStack(
              index: _tabController.index,
              children: [
                _buildCustomerCollectionsTab(db),
                _buildDealerReceiptsTab(db),
                _buildVendorDisbursementsTab(db),
                _buildPaymentTable(_filterPayments(db.payments.where((p) => p.paymentType == PaymentType.commissionPayment).toList())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _safeStr(Object? val) => (val == null) ? '' : val.toString().trim();
  static String _safeLower(Object? val) => (val == null) ? '' : val.toString().trim().toLowerCase();
  static int _safeInt(Object? val, int fallback) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? fallback;
  }
  static double _safeDouble(Object? val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? fallback;
  }

  Widget _buildCustomerCollectionsTab(MockDatabaseService db) {
    final allSummaries = _computeCustomerSummaries(db);
    final query = _safeLower(_customerSearchQuery);
    final filtered = query.isEmpty
        ? allSummaries
        : allSummaries.where((s) {
            final c = s.customer;
            return _safeLower(c.name).contains(query) ||
                _safeLower(c.mobile).contains(query) ||
                _safeLower(c.gstNumber).contains(query) ||
                _safeLower(c.address).contains(query);
          }).toList();

    final totalCount = filtered.length;
    final pageSize = _safeCustomerPageSize;
    final currentPage = _safeCustomerCurrentPage;
    final startIndex = currentPage * pageSize;
    final endIndex = min(startIndex + pageSize, totalCount);
    final pageSummaries = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <CustomerAccountSummary>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage customer accounts and track balances',
            style: AppTextStyles.subtitle.copyWith(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _buildCustomerControlsRow(totalCount, pageSummaries.length),
          const SizedBox(height: 16),
          _buildCustomerAccountsTable(pageSummaries),
        ],
      ),
    );
  }

  Widget _buildCustomerControlsRow(int totalCount, int shownCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final ctrl = _safeCustomerSearchCtrl;
        final pageSize = _safeCustomerPageSize;
        final currentPage = _safeCustomerCurrentPage;

        final searchBox = SizedBox(
          width: isNarrow ? double.infinity : 320,
          height: 42,
          child: TextField(
            controller: ctrl,
            onChanged: (val) {
              setState(() {
                _customerSearchQuery = val;
                _customerCurrentPage = 0;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search customers...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        );

        final paginationControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Show:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: (pageSize == 5 || pageSize == 10 || pageSize == 25 || pageSize == 50) ? pageSize : 10,
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _customerPageSize = val;
                        _customerCurrentPage = 0;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Showing $shownCount of $totalCount customers',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            if (totalCount > pageSize) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: currentPage > 0
                    ? () => setState(() => _customerCurrentPage = currentPage - 1)
                    : null,
              ),
              Text(
                '${currentPage + 1}/${max(1, (totalCount / pageSize).ceil())}',
                style: AppTextStyles.bodySmall,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: (currentPage + 1) * pageSize < totalCount
                    ? () => setState(() => _customerCurrentPage = currentPage + 1)
                    : null,
              ),
            ],
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              searchBox,
              const SizedBox(height: 10),
              paginationControls,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            searchBox,
            paginationControls,
          ],
        );
      },
    );
  }

  Widget _buildCustomerAccountsTable(List<CustomerAccountSummary> summaries) {
    if (summaries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No matching customers found', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 900),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: AppTextStyles.tableHeader,
                dataTextStyle: AppTextStyles.tableCell,
                dividerThickness: 1,
                horizontalMargin: 20,
                columnSpacing: 28,
                headingRowHeight: 46,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 64,
                columns: [
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('CUSTOMER NAME', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.currency_rupee, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('SALE TOTAL', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.currency_rupee, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text('PAID AMOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.percent, size: 14, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 4),
                        Text('DISCOUNT GIVEN', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED))),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('PENDING AMOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('ACTIONS', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
                rows: summaries.map((summary) {
                  return DataRow(
                    cells: [
                      // CUSTOMER NAME
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person, color: Color(0xFF0284C7), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  summary.customer.name.isNotEmpty ? summary.customer.name : 'Unnamed Customer',
                                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.description_outlined, size: 11, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${summary.transactionCount} transactions',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // SALE TOTAL
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.saleTotal),
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                        ),
                      ),
                      // PAID AMOUNT
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.paidAmount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      // DISCOUNT GIVEN
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.discountGiven),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      // PENDING AMOUNT
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.pendingAmount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: summary.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      // ACTIONS
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_note_rounded, size: 16),
                              label: const Text('Transaction', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0284C7),
                                side: const BorderSide(color: Color(0xFFBAE6FD)),
                                backgroundColor: const Color(0xFFF0F9FF),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _openRecordPaymentDialog(
                                PaymentType.customerPayment,
                                preselectedPartyId: summary.customer.id,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.visibility_outlined, size: 15),
                              label: const Text('History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _openCustomerHistoryDialog(summary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openCustomerHistoryDialog(CustomerAccountSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1140, maxHeight: 680),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.customer.name.isNotEmpty ? summary.customer.name : 'Unnamed Customer',
                              style: AppTextStyles.h2.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Customer Ledger & Transaction Statement (${summary.entries.length} Transactions)',
                              style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary Cards
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildHistoryStatCard('Sale Total', Formatters.formatCurrency(summary.saleTotal), Colors.black87),
                    _buildHistoryStatCard('Paid Amount', Formatters.formatCurrency(summary.paidAmount), const Color(0xFF16A34A)),
                    _buildHistoryStatCard('Discount Given', Formatters.formatCurrency(summary.discountGiven), const Color(0xFF7C3AED)),
                    _buildHistoryStatCard(
                      'Net Pending',
                      Formatters.formatCurrency(summary.pendingAmount),
                      summary.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // 9-Column Ledger Table (Sheet 2)
                Expanded(
                  child: summary.entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text('No transactions recorded yet for this customer.', style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        )
                      : ErpDataTable(
                          enableVerticalScroll: true,
                          fixedHeader: true,
                          columnSpacing: 14,
                          horizontalMargin: 16,
                          columns: const [
                            ErpColumn(title: 'Doc / Name', width: 145),
                            ErpColumn(title: 'Total Pending', isNumeric: true, width: 105),
                            ErpColumn(title: 'Type', width: 85),
                            ErpColumn(title: 'Date', width: 95),
                            ErpColumn(title: 'Mode', width: 120),
                            ErpColumn(title: 'Payment Amount', isNumeric: true, width: 125),
                            ErpColumn(title: 'Discount', isNumeric: true, width: 85),
                            ErpColumn(title: 'New Pending', isNumeric: true, width: 105),
                            ErpColumn(title: 'Remarks', width: 160),
                          ],
                          rows: summary.entries.map((entry) {
                            return [
                              Text(entry.docNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primary)),
                              Text(Formatters.formatCurrency(entry.openingPending), style: AppTextStyles.bodySmall),
                              entry.type == 'Sale Invoice'
                                  ? ErpStatusBadge.info('SALE')
                                  : ErpStatusBadge.success('RECEIPT'),
                              Text(Formatters.formatDate(entry.date), style: AppTextStyles.bodySmall),
                              ErpStatusBadge.neutral(entry.paymentMode),
                              Text(
                                Formatters.formatCurrency(entry.amount),
                                style: AppTextStyles.bodyBold.copyWith(
                                  fontSize: 12,
                                  color: entry.type == 'Sale Invoice' ? Colors.black87 : const Color(0xFF16A34A),
                                ),
                              ),
                              Text(Formatters.formatCurrency(entry.discount), style: AppTextStyles.bodySmall),
                              Text(
                                Formatters.formatCurrency(entry.closingPending),
                                style: AppTextStyles.bodyBold.copyWith(
                                  fontSize: 12,
                                  color: entry.closingPending > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                                ),
                              ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Tooltip(
                                  message: entry.remarks,
                                  child: Text(
                                    entry.remarks.isNotEmpty ? entry.remarks : '—',
                                    style: AppTextStyles.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ];
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),

                // Action buttons footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ErpButton(
                      text: 'Close',
                      isOutlined: true,
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                      },
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Record Transaction',
                      icon: Icons.edit_note_rounded,
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                        _openRecordPaymentDialog(PaymentType.customerPayment, preselectedPartyId: summary.customer.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDealerReceiptsTab(MockDatabaseService db) {
    final allSummaries = _computeDealerSummaries(db);
    final query = _safeLower(_dealerSearchQuery);
    final filtered = query.isEmpty
        ? allSummaries
        : allSummaries.where((s) {
            final d = s.dealer;
            return _safeLower(d.name).contains(query) ||
                _safeLower(d.companyName).contains(query) ||
                _safeLower(d.mobile).contains(query) ||
                _safeLower(d.gstNumber).contains(query) ||
                _safeLower(d.address).contains(query);
          }).toList();

    final totalCount = filtered.length;
    final pageSize = _safeDealerPageSize;
    final currentPage = _safeDealerCurrentPage;
    final startIndex = currentPage * pageSize;
    final endIndex = min(startIndex + pageSize, totalCount);
    final pageSummaries = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <DealerAccountSummary>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage dealer accounts and track balances (Sheet 2)',
            style: AppTextStyles.subtitle.copyWith(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _buildDealerControlsRow(totalCount, pageSummaries.length),
          const SizedBox(height: 16),
          _buildDealerAccountsTable(pageSummaries),
        ],
      ),
    );
  }

  Widget _buildDealerControlsRow(int totalCount, int shownCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final ctrl = _safeDealerSearchCtrl;
        final pageSize = _safeDealerPageSize;
        final currentPage = _safeDealerCurrentPage;

        final searchBox = SizedBox(
          width: isNarrow ? double.infinity : 320,
          height: 42,
          child: TextField(
            controller: ctrl,
            onChanged: (val) {
              setState(() {
                _dealerSearchQuery = val;
                _dealerCurrentPage = 0;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search dealers...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        );

        final paginationControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Show:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: (pageSize == 5 || pageSize == 10 || pageSize == 25 || pageSize == 50) ? pageSize : 10,
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _dealerPageSize = val;
                        _dealerCurrentPage = 0;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Showing $shownCount of $totalCount dealers',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            if (totalCount > pageSize) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: currentPage > 0
                    ? () => setState(() => _dealerCurrentPage = currentPage - 1)
                    : null,
              ),
              Text(
                '${currentPage + 1}/${max(1, (totalCount / pageSize).ceil())}',
                style: AppTextStyles.bodySmall,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: (currentPage + 1) * pageSize < totalCount
                    ? () => setState(() => _dealerCurrentPage = currentPage + 1)
                    : null,
              ),
            ],
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              searchBox,
              const SizedBox(height: 10),
              paginationControls,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            searchBox,
            paginationControls,
          ],
        );
      },
    );
  }

  Widget _buildDealerAccountsTable(List<DealerAccountSummary> summaries) {
    if (summaries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No matching dealers found', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 900),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: AppTextStyles.tableHeader,
                dataTextStyle: AppTextStyles.tableCell,
                dividerThickness: 1,
                horizontalMargin: 20,
                columnSpacing: 28,
                headingRowHeight: 46,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 64,
                columns: [
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('DEALER NAME', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.currency_rupee, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('SALE TOTAL', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.currency_rupee, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text('PAID AMOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.percent, size: 14, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 4),
                        Text('DISCOUNT GIVEN', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED))),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('PENDING AMOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('ACTIONS', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
                rows: summaries.map((summary) {
                  return DataRow(
                    cells: [
                      // DEALER NAME
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.storefront_outlined, color: Color(0xFF16A34A), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  summary.dealer.name.isNotEmpty ? summary.dealer.name : 'Unnamed Dealer',
                                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.description_outlined, size: 11, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      (summary.dealer.companyName.isNotEmpty)
                                          ? '${summary.dealer.companyName} • ${summary.transactionCount} transactions'
                                          : '${summary.transactionCount} transactions',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // SALE TOTAL
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.saleTotal),
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                        ),
                      ),
                      // PAID AMOUNT
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.paidAmount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      // DISCOUNT GIVEN
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.discountGiven),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      // PENDING AMOUNT
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.pendingAmount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: summary.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      // ACTIONS
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_note_rounded, size: 16),
                              label: const Text('Transaction', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0284C7),
                                side: const BorderSide(color: Color(0xFFBAE6FD)),
                                backgroundColor: const Color(0xFFF0F9FF),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _openRecordPaymentDialog(
                                PaymentType.dealerPayment,
                                preselectedPartyId: summary.dealer.id,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.visibility_outlined, size: 15),
                              label: const Text('History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _openDealerHistoryDialog(summary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openDealerHistoryDialog(DealerAccountSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1140, maxHeight: 680),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.storefront_outlined, color: Color(0xFF16A34A)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.dealer.name.isNotEmpty ? summary.dealer.name : 'Unnamed Dealer',
                              style: AppTextStyles.h2.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dealer Ledger & Transaction Statement (${summary.entries.length} Transactions)',
                              style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary Cards
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildHistoryStatCard('Sale Total', Formatters.formatCurrency(summary.saleTotal), Colors.black87),
                    _buildHistoryStatCard('Paid Amount', Formatters.formatCurrency(summary.paidAmount), const Color(0xFF16A34A)),
                    _buildHistoryStatCard('Discount Given', Formatters.formatCurrency(summary.discountGiven), const Color(0xFF7C3AED)),
                    _buildHistoryStatCard(
                      'Net Pending',
                      Formatters.formatCurrency(summary.pendingAmount),
                      summary.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // 9-Column Ledger Table (Sheet 2)
                Expanded(
                  child: summary.entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text('No transactions recorded yet for this dealer.', style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        )
                      : ErpDataTable(
                          enableVerticalScroll: true,
                          fixedHeader: true,
                          columnSpacing: 14,
                          horizontalMargin: 16,
                          columns: const [
                            ErpColumn(title: 'Doc / Name', width: 145),
                            ErpColumn(title: 'Total Pending', isNumeric: true, width: 105),
                            ErpColumn(title: 'Type', width: 85),
                            ErpColumn(title: 'Date', width: 95),
                            ErpColumn(title: 'Mode', width: 120),
                            ErpColumn(title: 'Payment Amount', isNumeric: true, width: 125),
                            ErpColumn(title: 'Discount', isNumeric: true, width: 85),
                            ErpColumn(title: 'New Pending', isNumeric: true, width: 105),
                            ErpColumn(title: 'Remarks', width: 160),
                          ],
                          rows: summary.entries.map((entry) {
                            return [
                              Text(entry.docNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primary)),
                              Text(Formatters.formatCurrency(entry.openingPending), style: AppTextStyles.bodySmall),
                              entry.type == 'Sale Invoice'
                                  ? ErpStatusBadge.info('SALE')
                                  : ErpStatusBadge.success('RECEIPT'),
                              Text(Formatters.formatDate(entry.date), style: AppTextStyles.bodySmall),
                              ErpStatusBadge.neutral(entry.paymentMode),
                              Text(
                                Formatters.formatCurrency(entry.amount),
                                style: AppTextStyles.bodyBold.copyWith(
                                  fontSize: 12,
                                  color: entry.type == 'Sale Invoice' ? Colors.black87 : const Color(0xFF16A34A),
                                ),
                              ),
                              Text(Formatters.formatCurrency(entry.discount), style: AppTextStyles.bodySmall),
                              Text(
                                Formatters.formatCurrency(entry.closingPending),
                                style: AppTextStyles.bodyBold.copyWith(
                                  fontSize: 12,
                                  color: entry.closingPending > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                                ),
                              ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Tooltip(
                                  message: entry.remarks,
                                  child: Text(
                                    entry.remarks.isNotEmpty ? entry.remarks : '—',
                                    style: AppTextStyles.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ];
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),

                // Action buttons footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ErpButton(
                      text: 'Close',
                      isOutlined: true,
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                      },
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Record Transaction',
                      icon: Icons.edit_note_rounded,
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                        _openRecordPaymentDialog(PaymentType.dealerPayment, preselectedPartyId: summary.dealer.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<DealerAccountSummary> _computeDealerSummaries(MockDatabaseService db) {
    final summaries = <DealerAccountSummary>[];

    for (final dealer in db.dealers) {
      if (dealer.isDeleted) continue;

      final String dId = _safeStr(dealer.id);
      final String dName = _safeLower(dealer.name);
      final String dComp = _safeLower(dealer.companyName);

      final dealerSales = db.sales.where((s) {
        final sPartyId = _safeStr(s.partyId);
        final sPartyName = _safeLower(s.partyName);
        final matchesId = dId.isNotEmpty && sPartyId == dId;
        final matchesName = (dName.isNotEmpty && sPartyName == dName) || (dComp.isNotEmpty && sPartyName == dComp);
        final isRelevantType = s.documentType == SalesDocumentType.invoice || s.documentType == SalesDocumentType.salesOrder;
        return (matchesId || matchesName) && isRelevantType;
      }).toList();

      final dealerPayments = db.payments.where((p) {
        final pPartyId = _safeStr(p.partyId);
        final pPartyName = _safeLower(p.partyName);
        final matchesId = dId.isNotEmpty && pPartyId == dId;
        final matchesName = (dName.isNotEmpty && pPartyName == dName) || (dComp.isNotEmpty && pPartyName == dComp);
        final isDealerPayment = p.paymentType == PaymentType.dealerPayment;
        return (matchesId || matchesName) && isDealerPayment;
      }).toList();

      final events = <_LedgerRawEvent>[];
      for (final s in dealerSales) {
        events.add(_LedgerRawEvent(
          docNumber: _safeStr(s.invoiceNumber).isNotEmpty ? s.invoiceNumber : 'INV-UNTITLED',
          isSale: true,
          date: s.saleDate,
          amount: s.totalAmount,
          discount: s.discountAmount,
          mode: 'INVOICE',
          notes: (s.notes != null && s.notes!.isNotEmpty) ? s.notes! : 'Tax Invoice',
        ));
      }
      for (final p in dealerPayments) {
        final modeLabel = p.paymentMode.name.toUpperCase();
        events.add(_LedgerRawEvent(
          docNumber: _safeStr(p.paymentNumber).isNotEmpty ? p.paymentNumber : 'PAY-UNTITLED',
          isSale: false,
          date: p.paymentDate,
          amount: p.amount,
          discount: p.discount,
          mode: modeLabel,
          notes: (p.transactionReference != null && p.transactionReference!.isNotEmpty)
              ? '${p.notes != null && p.notes!.isNotEmpty ? p.notes : "Payment"} (Ref: ${p.transactionReference})'
              : (p.notes != null && p.notes!.isNotEmpty ? p.notes! : 'Dealer Receipt'),
        ));
      }
      events.sort((a, b) {
        final cmp = a.date.compareTo(b.date);
        if (cmp != 0) return cmp;
        return a.docNumber.compareTo(b.docNumber);
      });

      final double saleTotal = dealerSales.fold(0.0, (acc, s) => acc + _safeDouble(s.totalAmount));
      final double paidAmount = dealerPayments.fold(0.0, (acc, p) => acc + _safeDouble(p.amount));
      final double paymentDiscounts = dealerPayments.fold(0.0, (acc, p) => acc + _safeDouble(p.discount));
      final double invoiceDiscountsOnly = dealerSales.fold(0.0, (acc, s) {
        final linkedPaymentsDiscount = dealerPayments
            .where((p) => p.referenceDocumentId != null && p.referenceDocumentId!.isNotEmpty && p.referenceDocumentId == s.id)
            .fold(0.0, (pAcc, p) => pAcc + _safeDouble(p.discount));
        return acc + (s.discountAmount - linkedPaymentsDiscount).clamp(0.0, double.infinity);
      });
      final double discountGiven = paymentDiscounts + invoiceDiscountsOnly;
      final double dealerOutstanding = _safeDouble(dealer.outstandingAmount);

      final double pendingAmount = dealerOutstanding;
      final double effectiveSaleTotal = (dealerSales.isEmpty && dealerOutstanding > 0)
          ? (dealerOutstanding + paidAmount + discountGiven)
          : saleTotal;

      double runningPending = dealerSales.isEmpty ? effectiveSaleTotal : 0.0;
      final entries = <CustomerLedgerEntry>[];
      for (final ev in events) {
        final opening = runningPending;
        if (ev.isSale) {
          runningPending = opening + ev.amount;
        } else {
          runningPending = (opening - (ev.amount + ev.discount)).clamp(0.0, double.infinity);
        }
        entries.add(CustomerLedgerEntry(
          docNumber: ev.docNumber,
          openingPending: opening,
          type: ev.isSale ? 'Sale Invoice' : 'Dealer Receipt',
          date: ev.date,
          paymentMode: ev.mode,
          amount: ev.amount,
          discount: ev.discount,
          closingPending: runningPending,
          remarks: ev.notes,
        ));
      }

      // Present transactions newest to oldest (descending date, then descending docNumber)
      entries.sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        if (cmp != 0) return cmp;
        return b.docNumber.compareTo(a.docNumber);
      });

      summaries.add(DealerAccountSummary(
        dealer: dealer,
        saleTotal: effectiveSaleTotal,
        paidAmount: paidAmount,
        discountGiven: discountGiven,
        pendingAmount: pendingAmount,
        transactionCount: events.length,
        entries: entries,
      ));
    }

    return summaries;
  }

  Widget _buildVendorDisbursementsTab(MockDatabaseService db) {
    final allSummaries = _computeVendorSummaries(db);
    final query = _safeLower(_vendorSearchQuery);
    final filtered = query.isEmpty
        ? allSummaries
        : allSummaries.where((s) {
            final v = s.vendor;
            return _safeLower(v.name).contains(query) ||
                _safeLower(v.contactPerson).contains(query) ||
                _safeLower(v.mobile).contains(query) ||
                _safeLower(v.email).contains(query) ||
                _safeLower(v.gstNumber).contains(query) ||
                _safeLower(v.panNumber).contains(query) ||
                _safeLower(v.address).contains(query);
          }).toList();

    final totalCount = filtered.length;
    final pageSize = _safeVendorPageSize;
    final currentPage = _safeVendorCurrentPage;
    final startIndex = currentPage * pageSize;
    final endIndex = min(startIndex + pageSize, totalCount);
    final pageSummaries = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <VendorAccountSummary>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage vendor accounts and track balances',
            style: AppTextStyles.subtitle.copyWith(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _buildVendorControlsRow(totalCount, pageSummaries.length),
          const SizedBox(height: 16),
          _buildVendorAccountsTable(pageSummaries),
        ],
      ),
    );
  }

  Widget _buildVendorControlsRow(int totalCount, int shownCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final ctrl = _safeVendorSearchCtrl;
        final pageSize = _safeVendorPageSize;
        final currentPage = _safeVendorCurrentPage;

        final searchBox = SizedBox(
          width: isNarrow ? double.infinity : 320,
          height: 42,
          child: TextField(
            controller: ctrl,
            onChanged: (val) {
              setState(() {
                _vendorSearchQuery = val;
                _vendorCurrentPage = 0;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search vendors...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        );

        final paginationControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Show:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: (pageSize == 5 || pageSize == 10 || pageSize == 25 || pageSize == 50) ? pageSize : 10,
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                  ],
                  onChanged: (newSize) {
                    if (newSize != null) {
                      setState(() {
                        _vendorPageSize = newSize;
                        _vendorCurrentPage = 0;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Showing $shownCount of $totalCount vendors',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            if (totalCount > pageSize) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: currentPage > 0
                    ? () => setState(() => _vendorCurrentPage = currentPage - 1)
                    : null,
              ),
              Text(
                '${currentPage + 1} / ${((totalCount - 1) ~/ pageSize) + 1}',
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: (currentPage + 1) * pageSize < totalCount
                    ? () => setState(() => _vendorCurrentPage = currentPage + 1)
                    : null,
              ),
            ],
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              searchBox,
              const SizedBox(height: 10),
              paginationControls,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            searchBox,
            paginationControls,
          ],
        );
      },
    );
  }

  Widget _buildVendorAccountsTable(List<VendorAccountSummary> summaries) {
    if (summaries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No matching vendors found', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 900),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: AppTextStyles.tableHeader,
                dataTextStyle: AppTextStyles.tableCell,
                dividerThickness: 1,
                horizontalMargin: 20,
                columnSpacing: 28,
                headingRowHeight: 46,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 64,
                columns: [
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('VENDOR NAME', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.currency_rupee, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('PURCHASE TOTAL', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.currency_rupee, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text('PAID AMOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.percent, size: 14, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 4),
                        Text('DISCOUNT GIVEN', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED))),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('PENDING AMOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('ACTIONS', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
                rows: summaries.map((summary) {
                  return DataRow(
                    cells: [
                      // VENDOR NAME
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  summary.vendor.name.isNotEmpty ? summary.vendor.name : 'Unnamed Vendor',
                                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.description_outlined, size: 11, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      (summary.vendor.contactPerson.isNotEmpty)
                                          ? '${summary.vendor.contactPerson} • ${summary.transactionCount} transactions'
                                          : '${summary.transactionCount} transactions',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // PURCHASE TOTAL
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.purchaseTotal),
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                        ),
                      ),
                      // PAID AMOUNT
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.paidAmount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      // DISCOUNT GIVEN
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.discountGiven),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      // PENDING AMOUNT
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.pendingAmount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: summary.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      // ACTIONS
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_note_rounded, size: 16),
                              label: const Text('Transaction', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                backgroundColor: const Color(0xFFEFF6FF),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _openRecordPaymentDialog(
                                PaymentType.vendorPayment,
                                preselectedPartyId: summary.vendor.id,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.visibility_outlined, size: 15),
                              label: const Text('History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _openVendorHistoryDialog(summary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openVendorHistoryDialog(VendorAccountSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1140, maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.vendor.name.isNotEmpty ? summary.vendor.name : 'Unnamed Vendor',
                              style: AppTextStyles.h2.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vendor Ledger & Transaction Statement (${summary.entries.length} Transactions)',
                              style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary Cards
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildHistoryStatCard('Purchase Total', Formatters.formatCurrency(summary.purchaseTotal), Colors.black87),
                    _buildHistoryStatCard('Paid Amount', Formatters.formatCurrency(summary.paidAmount), const Color(0xFF16A34A)),
                    _buildHistoryStatCard('Discount Given', Formatters.formatCurrency(summary.discountGiven), const Color(0xFF7C3AED)),
                    _buildHistoryStatCard(
                      'Net Pending',
                      Formatters.formatCurrency(summary.pendingAmount),
                      summary.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // 8-Column Ledger Table (Sheet 2)
                Expanded(
                  child: summary.entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text('No ledger entries recorded yet', style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        )
                      : ErpDataTable(
                          enableVerticalScroll: true,
                          fixedHeader: true,
                          columnSpacing: 14,
                          horizontalMargin: 16,
                          columns: const [
                            ErpColumn(title: 'Doc / Name', width: 145),
                            ErpColumn(title: 'Total Pending (Opening)', isNumeric: true, width: 110),
                            ErpColumn(title: 'Type', width: 85),
                            ErpColumn(title: 'Date', width: 95),
                            ErpColumn(title: 'Mode', width: 120),
                            ErpColumn(title: 'Payment Amount', isNumeric: true, width: 125),
                            ErpColumn(title: 'Discount', isNumeric: true, width: 85),
                            ErpColumn(title: 'New Pending (Closing)', isNumeric: true, width: 110),
                            ErpColumn(title: 'Remarks', width: 160),
                          ],
                          rows: summary.entries.map((entry) {
                            final isPurchase = entry.type.toLowerCase().contains('purchase') || entry.type.toLowerCase().contains('invoice');
                            return [
                              Text(
                                entry.docNumber,
                                style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primary),
                              ),
                              Text(Formatters.formatCurrency(entry.openingPending), style: AppTextStyles.bodySmall),
                              isPurchase
                                  ? ErpStatusBadge.neutral(entry.type)
                                  : ErpStatusBadge.success(entry.type),
                              Text(Formatters.formatDate(entry.date), style: AppTextStyles.bodySmall),
                              ErpStatusBadge.neutral(entry.paymentMode),
                              Text(
                                Formatters.formatCurrency(entry.amount),
                                style: AppTextStyles.bodyBold.copyWith(
                                  fontSize: 12,
                                  color: isPurchase ? Colors.black87 : const Color(0xFF16A34A),
                                ),
                              ),
                              Text(Formatters.formatCurrency(entry.discount), style: AppTextStyles.bodySmall),
                              Text(
                                Formatters.formatCurrency(entry.closingPending),
                                style: AppTextStyles.bodyBold.copyWith(
                                  fontSize: 12,
                                  color: entry.closingPending > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                                ),
                              ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Tooltip(
                                  message: entry.remarks,
                                  child: Text(
                                    entry.remarks.isNotEmpty ? entry.remarks : '—',
                                    style: AppTextStyles.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ];
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),

                // Action buttons footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ErpButton(
                      text: 'Close',
                      isOutlined: true,
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                      },
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Record Transaction',
                      icon: Icons.edit_note_rounded,
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                        _openRecordPaymentDialog(PaymentType.vendorPayment, preselectedPartyId: summary.vendor.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<VendorAccountSummary> _computeVendorSummaries(MockDatabaseService db) {
    final summaries = <VendorAccountSummary>[];

    for (final vendor in db.vendors) {
      if (vendor.isDeleted) continue;

      final String vId = _safeStr(vendor.id);
      final String vName = _safeLower(vendor.name);

      final vendorPurchases = db.purchases.where((p) {
        final pVendorId = _safeStr(p.vendorId);
        final pVendorName = _safeLower(p.vendorName);
        final matchesId = vId.isNotEmpty && pVendorId == vId;
        final matchesName = vName.isNotEmpty && pVendorName == vName;
        final isNotCancelled = p.status != PurchaseStatus.cancelled;
        return (matchesId || matchesName) && isNotCancelled;
      }).toList();

      final vendorPayments = db.payments.where((p) {
        final pPartyId = _safeStr(p.partyId);
        final pPartyName = _safeLower(p.partyName);
        final matchesId = vId.isNotEmpty && pPartyId == vId;
        final matchesName = vName.isNotEmpty && pPartyName == vName;
        final isVendorPayment = p.paymentType == PaymentType.vendorPayment;
        return (matchesId || matchesName) && isVendorPayment;
      }).toList();

      final events = <_LedgerRawEvent>[];
      for (final p in vendorPurchases) {
        final docNum = _safeStr(p.purchaseNumber).isNotEmpty
            ? p.purchaseNumber
            : (_safeStr(p.vendorInvoiceNumber).isNotEmpty ? p.vendorInvoiceNumber : 'PUR-UNTITLED');
        events.add(_LedgerRawEvent(
          docNumber: docNum,
          isSale: true,
          date: p.purchaseDate,
          amount: p.totalAmount,
          discount: p.discountAmount,
          mode: 'PURCHASE',
          notes: (p.notes != null && p.notes!.isNotEmpty) ? p.notes! : 'Purchase Invoice',
        ));
      }

      for (final p in vendorPayments) {
        final modeLabel = p.paymentMode.name.toUpperCase();
        events.add(_LedgerRawEvent(
          docNumber: _safeStr(p.paymentNumber).isNotEmpty ? p.paymentNumber : 'PAY-UNTITLED',
          isSale: false,
          date: p.paymentDate,
          amount: p.amount,
          discount: p.discount,
          mode: modeLabel,
          notes: (p.transactionReference != null && p.transactionReference!.isNotEmpty)
              ? '${p.notes != null && p.notes!.isNotEmpty ? p.notes : "Payment"} (Ref: ${p.transactionReference})'
              : (p.notes != null && p.notes!.isNotEmpty ? p.notes! : 'Vendor Payment'),
        ));
      }

      events.sort((a, b) {
        final cmp = a.date.compareTo(b.date);
        if (cmp != 0) return cmp;
        return a.docNumber.compareTo(b.docNumber);
      });

      final double purchaseTotal = vendorPurchases.fold(0.0, (acc, p) => acc + _safeDouble(p.totalAmount));
      final double paidAmount = vendorPayments.fold(0.0, (acc, p) => acc + _safeDouble(p.amount));
      final double paymentDiscounts = vendorPayments.fold(0.0, (acc, p) => acc + _safeDouble(p.discount));
      final double invoiceDiscountsOnly = vendorPurchases.fold(0.0, (acc, p) {
        final linkedPaymentsDiscount = vendorPayments
            .where((pay) => pay.referenceDocumentId != null && pay.referenceDocumentId!.isNotEmpty && pay.referenceDocumentId == p.id)
            .fold(0.0, (pAcc, pay) => pAcc + _safeDouble(pay.discount));
        return acc + (p.discountAmount - linkedPaymentsDiscount).clamp(0.0, double.infinity);
      });
      final double discountGiven = paymentDiscounts + invoiceDiscountsOnly;
      final double vendorOutstanding = _safeDouble(vendor.outstandingBalance);

      final double pendingAmount = vendorOutstanding;
      final double effectivePurchaseTotal = (vendorPurchases.isEmpty && vendorOutstanding > 0)
          ? (vendorOutstanding + paidAmount + discountGiven)
          : purchaseTotal;

      double runningPending = vendorPurchases.isEmpty ? effectivePurchaseTotal : 0.0;
      final entries = <CustomerLedgerEntry>[];
      for (final ev in events) {
        final opening = runningPending;
        if (ev.isSale) {
          runningPending = opening + ev.amount;
        } else {
          runningPending = (opening - (ev.amount + ev.discount)).clamp(0.0, double.infinity);
        }
        entries.add(CustomerLedgerEntry(
          docNumber: ev.docNumber,
          openingPending: opening,
          type: ev.isSale ? 'Purchase Invoice' : 'Vendor Payment',
          date: ev.date,
          paymentMode: ev.mode,
          amount: ev.amount,
          discount: ev.discount,
          closingPending: runningPending,
          remarks: ev.notes,
        ));
      }

      // Present transactions newest to oldest (descending date, then descending docNumber)
      entries.sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        if (cmp != 0) return cmp;
        return b.docNumber.compareTo(a.docNumber);
      });

      summaries.add(VendorAccountSummary(
        vendor: vendor,
        purchaseTotal: effectivePurchaseTotal,
        paidAmount: paidAmount,
        discountGiven: discountGiven,
        pendingAmount: pendingAmount,
        transactionCount: events.length,
        entries: entries,
      ));
    }

    return summaries;
  }

  Widget _buildHistoryStatCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  List<CustomerAccountSummary> _computeCustomerSummaries(MockDatabaseService db) {
    final summaries = <CustomerAccountSummary>[];

    for (final customer in db.customers) {
      if (customer.isDeleted) continue;

      final String cId = _safeStr(customer.id);
      final String cName = _safeLower(customer.name);

      final customerSales = db.sales.where((s) {
        final sPartyId = _safeStr(s.partyId);
        final sPartyName = _safeLower(s.partyName);
        final matchesId = cId.isNotEmpty && sPartyId == cId;
        final matchesName = cName.isNotEmpty && sPartyName == cName;
        final isRelevantType = s.documentType == SalesDocumentType.invoice || s.documentType == SalesDocumentType.salesOrder;
        return (matchesId || matchesName) && isRelevantType;
      }).toList();

      final customerPayments = db.payments.where((p) {
        final pPartyId = _safeStr(p.partyId);
        final pPartyName = _safeLower(p.partyName);
        final matchesId = cId.isNotEmpty && pPartyId == cId;
        final matchesName = cName.isNotEmpty && pPartyName == cName;
        final isCustomerPayment = p.paymentType == PaymentType.customerPayment;
        return (matchesId || matchesName) && isCustomerPayment;
      }).toList();

      final events = <_LedgerRawEvent>[];
      for (final s in customerSales) {
        events.add(_LedgerRawEvent(
          docNumber: _safeStr(s.invoiceNumber).isNotEmpty ? s.invoiceNumber : 'INV-UNTITLED',
          isSale: true,
          date: s.saleDate,
          amount: s.totalAmount,
          discount: s.discountAmount,
          mode: 'INVOICE',
          notes: (s.notes != null && s.notes!.isNotEmpty) ? s.notes! : 'Tax Invoice',
        ));
      }
      for (final p in customerPayments) {
        final modeLabel = p.paymentMode.name.toUpperCase();
        events.add(_LedgerRawEvent(
          docNumber: _safeStr(p.paymentNumber).isNotEmpty ? p.paymentNumber : 'PAY-UNTITLED',
          isSale: false,
          date: p.paymentDate,
          amount: p.amount,
          discount: p.discount,
          mode: modeLabel,
          notes: (p.transactionReference != null && p.transactionReference!.isNotEmpty)
              ? '${p.notes != null && p.notes!.isNotEmpty ? p.notes : "Payment"} (Ref: ${p.transactionReference})'
              : (p.notes != null && p.notes!.isNotEmpty ? p.notes! : 'Customer Receipt'),
        ));
      }
      events.sort((a, b) {
        final cmp = a.date.compareTo(b.date);
        if (cmp != 0) return cmp;
        return a.docNumber.compareTo(b.docNumber);
      });

      final double saleTotal = customerSales.fold(0.0, (acc, s) => acc + _safeDouble(s.totalAmount));
      final double paidAmount = customerPayments.fold(0.0, (acc, p) => acc + _safeDouble(p.amount));
      final double paymentDiscounts = customerPayments.fold(0.0, (acc, p) => acc + _safeDouble(p.discount));
      final double invoiceDiscountsOnly = customerSales.fold(0.0, (acc, s) {
        final linkedPaymentsDiscount = customerPayments
            .where((p) => p.referenceDocumentId != null && p.referenceDocumentId!.isNotEmpty && p.referenceDocumentId == s.id)
            .fold(0.0, (pAcc, p) => pAcc + _safeDouble(p.discount));
        return acc + (s.discountAmount - linkedPaymentsDiscount).clamp(0.0, double.infinity);
      });
      final double discountGiven = paymentDiscounts + invoiceDiscountsOnly;
      final double custOutstanding = _safeDouble(customer.outstandingAmount);

      final double pendingAmount = custOutstanding;
      final double effectiveSaleTotal = (customerSales.isEmpty && custOutstanding > 0)
          ? (custOutstanding + paidAmount + discountGiven)
          : saleTotal;

      double runningPending = customerSales.isEmpty ? effectiveSaleTotal : 0.0;
      final entries = <CustomerLedgerEntry>[];
      for (final ev in events) {
        final opening = runningPending;
        if (ev.isSale) {
          runningPending = opening + ev.amount;
        } else {
          runningPending = (opening - (ev.amount + ev.discount)).clamp(0.0, double.infinity);
        }
        entries.add(CustomerLedgerEntry(
          docNumber: ev.docNumber,
          openingPending: opening,
          type: ev.isSale ? 'Sale Invoice' : 'Customer Receipt',
          date: ev.date,
          paymentMode: ev.mode,
          amount: ev.amount,
          discount: ev.discount,
          closingPending: runningPending,
          remarks: ev.notes,
        ));
      }

      // Present transactions newest to oldest (descending date, then descending docNumber)
      entries.sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        if (cmp != 0) return cmp;
        return b.docNumber.compareTo(a.docNumber);
      });

      summaries.add(CustomerAccountSummary(
        customer: customer,
        saleTotal: effectiveSaleTotal,
        paidAmount: paidAmount,
        discountGiven: discountGiven,
        pendingAmount: pendingAmount,
        transactionCount: events.length,
        entries: entries,
      ));
    }

    return summaries;
  }

  List<ErpPayment> _filterPayments(List<ErpPayment> list) {
    final query = _safeLower(_searchQuery);
    if (query.isEmpty) return list;
    return list.where((p) {
      return _safeLower(p.paymentNumber).contains(query) ||
          _safeLower(p.partyName).contains(query) ||
          _safeLower(p.referenceDocumentNumber).contains(query) ||
          _safeLower(p.transactionReference).contains(query) ||
          _safeLower(p.paymentMode.name).contains(query) ||
          _safeLower(p.notes).contains(query);
    }).toList();
  }

  Widget _buildPaymentTable(List<ErpPayment> payments) {
    return ErpDataTable(
      columns: const [
        ErpColumn(title: 'Payment No'),
        ErpColumn(title: 'Date'),
        ErpColumn(title: 'Party / Beneficiary'),
        ErpColumn(title: 'Reference Doc'),
        ErpColumn(title: 'Amount (₹)', isNumeric: true),
        ErpColumn(title: 'Settlement'),
        ErpColumn(title: 'Remaining (₹)', isNumeric: true),
        ErpColumn(title: 'Payment Mode'),
        ErpColumn(title: 'UTR / Ref No'),
      ],
      rows: payments.map((p) {
        final parentSection = switch (p.paymentType) {
          PaymentType.customerPayment => ErpNavSection.customerPayments,
          PaymentType.dealerPayment => ErpNavSection.dealerPayments,
          PaymentType.vendorPayment => ErpNavSection.vendorPaymentsSection,
          PaymentType.commissionPayment => ErpNavSection.commissionPayments,
        };

        return [
          InkWell(
            onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'payment', parentSection),
            child: Text(
              p.paymentNumber,
              style: AppTextStyles.bodyBold.copyWith(
                fontSize: 12,
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(Formatters.formatDate(p.paymentDate), style: AppTextStyles.bodySmall),
          Text(p.partyName, style: AppTextStyles.bodyMedium),
          Text(p.referenceDocumentNumber ?? '-', style: AppTextStyles.bodySmall),
          Text(
            Formatters.formatCurrency(p.amount),
            style: AppTextStyles.bodyBold.copyWith(
              color: (p.paymentType == PaymentType.customerPayment || p.paymentType == PaymentType.dealerPayment)
                  ? AppColors.successText
                  : AppColors.textPrimary,
            ),
          ),
          p.isFullPayment ? ErpStatusBadge.success('FULL') : ErpStatusBadge.warning('PARTIAL'),
          Text(
            p.remainingAmount != null ? Formatters.formatCurrency(p.remainingAmount!) : '-',
            style: AppTextStyles.bodySmall.copyWith(
              color: (p.remainingAmount ?? 0) > 0 ? AppColors.warningText : AppColors.successText,
              fontWeight: FontWeight.w600,
            ),
          ),
          ErpStatusBadge.neutral(p.paymentMode.toString().split('.').last.toUpperCase()),
          Text(p.transactionReference ?? '-', style: AppTextStyles.bodySmall),
        ];
      }).toList(),
    );
  }
}

class CustomerAccountSummary {
  final Customer customer;
  final double saleTotal;
  final double paidAmount;
  final double discountGiven;
  final double pendingAmount;
  final int transactionCount;
  final List<CustomerLedgerEntry> entries;

  CustomerAccountSummary({
    required this.customer,
    required this.saleTotal,
    required this.paidAmount,
    required this.discountGiven,
    required this.pendingAmount,
    required this.transactionCount,
    required this.entries,
  });
}

class DealerAccountSummary {
  final Dealer dealer;
  final double saleTotal;
  final double paidAmount;
  final double discountGiven;
  final double pendingAmount;
  final int transactionCount;
  final List<CustomerLedgerEntry> entries;

  DealerAccountSummary({
    required this.dealer,
    required this.saleTotal,
    required this.paidAmount,
    required this.discountGiven,
    required this.pendingAmount,
    required this.transactionCount,
    required this.entries,
  });
}

class VendorAccountSummary {
  final Vendor vendor;
  final double purchaseTotal;
  final double paidAmount;
  final double discountGiven;
  final double pendingAmount;
  final int transactionCount;
  final List<CustomerLedgerEntry> entries;

  VendorAccountSummary({
    required this.vendor,
    required this.purchaseTotal,
    required this.paidAmount,
    required this.discountGiven,
    required this.pendingAmount,
    required this.transactionCount,
    required this.entries,
  });
}

class CustomerLedgerEntry {
  final String docNumber;
  final double openingPending;
  final String type;
  final DateTime date;
  final String paymentMode;
  final double amount;
  final double discount;
  final double closingPending;
  final String remarks;

  CustomerLedgerEntry({
    required this.docNumber,
    required this.openingPending,
    required this.type,
    required this.date,
    required this.paymentMode,
    required this.amount,
    required this.discount,
    required this.closingPending,
    required this.remarks,
  });
}

class _LedgerRawEvent {
  final String docNumber;
  final bool isSale;
  final DateTime date;
  final double amount;
  final double discount;
  final String mode;
  final String notes;

  _LedgerRawEvent({
    required this.docNumber,
    required this.isSale,
    required this.date,
    required this.amount,
    required this.discount,
    required this.mode,
    required this.notes,
  });
}

class _MaxAmountTextInputFormatter extends TextInputFormatter {
  final double Function() maxAllowed;

  _MaxAmountTextInputFormatter(this.maxAllowed);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final textToParse = newValue.text.endsWith('.')
        ? newValue.text.substring(0, newValue.text.length - 1)
        : newValue.text;
    if (textToParse.isEmpty) return newValue;

    final val = double.tryParse(textToParse);
    if (val == null) return oldValue;
    final max = maxAllowed();
    if (max > 0 && val > (max + 0.001)) {
      return oldValue;
    }
    return newValue;
  }
}

class _RecordPaymentDialog extends ConsumerStatefulWidget {
  final PaymentType type;
  final String? preselectedPartyId;

  const _RecordPaymentDialog({
    required this.type,
    this.preselectedPartyId,
  });

  @override
  ConsumerState<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _notesCtrl;
  final _formKey = GlobalKey<FormState>();

  String? _selectedPartyId;
  String? _selectedLinkedDocId;
  String _transactionType = 'Payment with Discount';
  DateTime _selectedDate = DateTime.now();
  PaymentMode? _selectedMode;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _discountCtrl = TextEditingController();
    _refCtrl = TextEditingController();
    _notesCtrl = TextEditingController();

    final db = ref.read(databaseServiceProvider);
    if (widget.preselectedPartyId != null) {
      _selectedPartyId = widget.preselectedPartyId;
    } else if (widget.type == PaymentType.customerPayment && db.customers.isNotEmpty) {
      _selectedPartyId = db.customers.first.id;
    } else if (widget.type == PaymentType.dealerPayment && db.dealers.isNotEmpty) {
      _selectedPartyId = db.dealers.first.id;
    } else if (widget.type == PaymentType.vendorPayment && db.vendors.isNotEmpty) {
      _selectedPartyId = db.vendors.first.id;
    } else if (widget.type == PaymentType.commissionPayment && db.architects.isNotEmpty) {
      _selectedPartyId = db.architects.first.id;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _discountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    double outstanding = 0.0;
    String partyName = '';
    List<DropdownMenuItem<String>> linkedDocItems = [];
    double selectedDocPending = 0.0;
    double selectedDocTotal = 0.0;
    String? selectedDocNumber;
    String? selectedProjectId;
    String? selectedProjectName;

    if (widget.type == PaymentType.customerPayment && _selectedPartyId != null) {
      final c = db.customers.firstWhere((cust) => cust.id == _selectedPartyId, orElse: () => db.customers.first);
      outstanding = c.outstandingAmount;
      partyName = c.name;
      final sales = db.sales.where((s) => s.partyId == _selectedPartyId && s.pendingAmount > 0);
      linkedDocItems = sales.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.invoiceNumber} (Pending: ${Formatters.formatCurrency(s.pendingAmount)})'))).toList();

      if (_selectedLinkedDocId != null) {
        final sale = db.sales.where((s) => s.id == _selectedLinkedDocId).firstOrNull;
        if (sale != null) {
          selectedDocPending = sale.pendingAmount;
          selectedDocTotal = sale.totalAmount;
          selectedDocNumber = sale.invoiceNumber;
          selectedProjectId = sale.projectId;
          selectedProjectName = sale.projectName;
        }
      }
    } else if (widget.type == PaymentType.dealerPayment && _selectedPartyId != null) {
      final d = db.dealers.firstWhere((dlr) => dlr.id == _selectedPartyId, orElse: () => db.dealers.first);
      outstanding = d.outstandingAmount;
      partyName = d.name;
      final sales = db.sales.where((s) => s.partyId == _selectedPartyId && s.pendingAmount > 0);
      linkedDocItems = sales.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.invoiceNumber} (Pending: ${Formatters.formatCurrency(s.pendingAmount)})'))).toList();

      if (_selectedLinkedDocId != null) {
        final sale = db.sales.where((s) => s.id == _selectedLinkedDocId).firstOrNull;
        if (sale != null) {
          selectedDocPending = sale.pendingAmount;
          selectedDocTotal = sale.totalAmount;
          selectedDocNumber = sale.invoiceNumber;
          selectedProjectId = sale.projectId;
          selectedProjectName = sale.projectName;
        }
      }
    } else if (widget.type == PaymentType.vendorPayment && _selectedPartyId != null) {
      final v = db.vendors.firstWhere((ven) => ven.id == _selectedPartyId, orElse: () => db.vendors.first);
      outstanding = v.outstandingBalance;
      partyName = v.name;
      final purchases = db.purchases.where((p) => p.vendorId == _selectedPartyId && p.pendingAmount > 0);
      linkedDocItems = purchases.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.purchaseNumber} (Pending: ${Formatters.formatCurrency(p.pendingAmount)})'))).toList();

      if (_selectedLinkedDocId != null) {
        final pur = db.purchases.where((p) => p.id == _selectedLinkedDocId).firstOrNull;
        if (pur != null) {
          selectedDocPending = pur.pendingAmount;
          selectedDocTotal = pur.totalAmount;
          selectedDocNumber = pur.purchaseNumber;
          selectedProjectId = pur.projectId;
          selectedProjectName = pur.projectName;
        }
      }
    } else if (widget.type == PaymentType.commissionPayment && _selectedPartyId != null) {
      final a = db.architects.firstWhere((arc) => arc.id == _selectedPartyId, orElse: () => db.architects.first);
      outstanding = a.pendingCommission;
      partyName = a.name;

      final commissions = db.commissions.where((cm) => cm.architectId == _selectedPartyId && cm.status != CommissionStatus.paid);
      linkedDocItems = commissions.map((cm) => DropdownMenuItem(value: cm.id, child: Text('${cm.commissionNumber} (Amt: ${Formatters.formatCurrency(cm.commissionAmount)})'))).toList();

      if (_selectedLinkedDocId != null) {
        final comm = db.commissions.where((c) => c.id == _selectedLinkedDocId).firstOrNull;
        if (comm != null) {
          selectedDocPending = comm.commissionAmount;
          selectedDocTotal = comm.commissionAmount;
          selectedDocNumber = comm.commissionNumber;
          selectedProjectId = comm.projectId;
          selectedProjectName = comm.projectName;
        }
      }
    }

    final double basePending = (_selectedLinkedDocId != null && selectedDocPending > 0)
        ? selectedDocPending
        : outstanding;

    final currentEnteredAmt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final currentEnteredDisc = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    final totalDeduction = currentEnteredAmt + currentEnteredDisc;
    final calculatedRemaining = (basePending - totalDeduction).clamp(0.0, double.infinity);

    String title;
    String partyRoleLabel;
    switch (widget.type) {
      case PaymentType.customerPayment:
        title = 'Add Customer Transaction';
        partyRoleLabel = 'Customer';
        break;
      case PaymentType.dealerPayment:
        title = 'Add Dealer Transaction';
        partyRoleLabel = 'Dealer';
        break;
      case PaymentType.vendorPayment:
        title = 'Add Vendor Transaction';
        partyRoleLabel = 'Vendor';
        break;
      case PaymentType.commissionPayment:
        title = 'Add Commission Payout';
        partyRoleLabel = 'Architect / Partner';
        break;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with close button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.h2.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Record payment amount, apply discount, and track live balance',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Close',
                      splashRadius: 18,
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Party Selector / Display
                if (widget.preselectedPartyId != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text('$partyRoleLabel: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Expanded(
                          child: Text(partyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  if (widget.type == PaymentType.customerPayment) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedPartyId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Customer *',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                      items: db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPartyId = val;
                          _selectedLinkedDocId = null;
                          _amountCtrl.clear();
                          _discountCtrl.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                  ] else if (widget.type == PaymentType.dealerPayment) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedPartyId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Dealer *',
                        prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                      ),
                      items: db.dealers.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPartyId = val;
                          _selectedLinkedDocId = null;
                          _amountCtrl.clear();
                          _discountCtrl.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                  ] else if (widget.type == PaymentType.vendorPayment) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedPartyId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Vendor *',
                        prefixIcon: Icon(Icons.business_outlined, size: 20),
                      ),
                      items: db.vendors.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPartyId = val;
                          _selectedLinkedDocId = null;
                          _amountCtrl.clear();
                          _discountCtrl.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                  ] else if (widget.type == PaymentType.commissionPayment) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedPartyId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Architect / Partner *',
                        prefixIcon: Icon(Icons.handshake_outlined, size: 20),
                      ),
                      items: db.architects.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPartyId = val;
                          _selectedLinkedDocId = null;
                          _amountCtrl.clear();
                          _discountCtrl.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                ],

                // Linked Document Selection
                if (linkedDocItems.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedLinkedDocId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Link to Unpaid Invoice / Document',
                      prefixIcon: Icon(Icons.receipt_outlined, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('On Account / Advance Payment (General)')),
                      ...linkedDocItems,
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedLinkedDocId = val;
                        _amountCtrl.clear();
                        _discountCtrl.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // 🔴 Current Outstanding Amount Card (Soft Red)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedLinkedDocId != null && selectedDocNumber != null
                                        ? 'Invoice Pending ($selectedDocNumber):'
                                        : 'Current Outstanding Amount (On Account):',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF991B1B),
                                    ),
                                  ),
                                  if (_selectedLinkedDocId != null && selectedDocNumber != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Total $partyRoleLabel Outstanding: ${Formatters.formatCurrency(outstanding)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.formatCurrency(calculatedRemaining),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Transaction Type & Transaction Date
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 460;
                    final typeWidget = DropdownButtonFormField<String>(
                      value: _transactionType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Type',
                        prefixIcon: Icon(Icons.swap_horiz, size: 20),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Payment with Discount', child: Text('Payment with Discount')),
                        DropdownMenuItem(value: 'Payment Receipt', child: Text('Payment Receipt')),
                        DropdownMenuItem(value: 'Discount Only', child: Text('Discount Only')),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _transactionType = val;
                          if (_transactionType == 'Discount Only') {
                            _amountCtrl.clear();
                          } else if (_transactionType == 'Payment Receipt') {
                            _discountCtrl.clear();
                          }
                        });
                      },
                    );

                    final dateWidget = InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Transaction Date',
                          prefixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(
                          Formatters.formatDate(_selectedDate),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: typeWidget),
                          const SizedBox(width: 12),
                          Expanded(child: dateWidget),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        typeWidget,
                        const SizedBox(height: 12),
                        dateWidget,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Payment Mode & Reference Number (Hidden if 'Discount Only')
                if (_transactionType != 'Discount Only') ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 460;
                      final modeWidget = DropdownButtonFormField<PaymentMode>(
                        value: _selectedMode,
                        isExpanded: true,
                        hint: const Text('Select Paymode'),
                        decoration: const InputDecoration(
                          labelText: 'Payment Mode *',
                          prefixIcon: Icon(Icons.payment, size: 20),
                        ),
                        items: PaymentMode.values.map((mode) {
                          return DropdownMenuItem(
                            value: mode,
                            child: Text(mode.toString().split('.').last.toUpperCase(), overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        validator: (val) {
                          if (_transactionType != 'Discount Only' && val == null) {
                            return 'Select Paymode';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          setState(() => _selectedMode = val);
                        },
                      );

                      final refWidget = TextFormField(
                        controller: _refCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Reference / UTR / Cheque No',
                          hintText: 'e.g. UTR84910284',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          prefixIcon: Icon(Icons.tag, size: 18),
                        ),
                      );

                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(child: modeWidget),
                            const SizedBox(width: 12),
                            Expanded(child: refWidget),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          modeWidget,
                          const SizedBox(height: 12),
                          refWidget,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // 💰 Payment Amount & Discount Amount
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 460;

                    final paymentAmtWidget = TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        _MaxAmountTextInputFormatter(() {
                          final currentDisc = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
                          return (basePending - currentDisc).clamp(0.0, double.infinity);
                        }),
                      ],
                      enabled: _transactionType != 'Discount Only',
                      decoration: InputDecoration(
                        labelText: _transactionType == 'Discount Only'
                            ? 'Payment Amount (₹)'
                            : 'Payment Amount (₹) *',
                        hintText: '0',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        filled: _transactionType == 'Discount Only',
                        fillColor: _transactionType == 'Discount Only' ? const Color(0xFFF3F4F6) : null,
                        prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                        suffixIcon: (basePending > 0 && _transactionType != 'Discount Only')
                            ? TextButton(
                                onPressed: () {
                                  final currentDisc = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
                                  final fullAmt = (basePending - currentDisc).clamp(0.0, double.infinity);
                                  final formatted = fullAmt == 0
                                      ? ''
                                      : (fullAmt % 1 == 0
                                          ? fullAmt.toInt().toString()
                                          : fullAmt.toStringAsFixed(2));
                                  _amountCtrl.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(offset: formatted.length),
                                  );
                                  setState(() {});
                                },
                                child: const Text('Full Pay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        if (_transactionType == 'Discount Only') return null;
                        if (val == null || val.trim().isEmpty) {
                          return 'Enter payment amount';
                        }
                        final payAmt = double.tryParse(val.trim());
                        if (payAmt == null || payAmt <= 0) {
                          return 'Enter a valid payment amount';
                        }
                        final discAmt = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
                        final total = payAmt + discAmt;
                        if (basePending > 0 && total > (basePending + 0.01)) {
                          return 'Cannot exceed ${Formatters.formatCurrency(basePending)}';
                        }
                        return null;
                      },
                    );

                    final discountAmtWidget = TextFormField(
                      controller: _discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        _MaxAmountTextInputFormatter(() {
                          final currentPay = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
                          return (basePending - currentPay).clamp(0.0, double.infinity);
                        }),
                      ],
                      decoration: InputDecoration(
                        labelText: _transactionType == 'Discount Only'
                            ? 'Discount Amount (₹) *'
                            : 'Discount Amount (₹)',
                        hintText: '0',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        prefixIcon: const Icon(Icons.discount_outlined, size: 18),
                      ),
                      onChanged: (val) {
                        if (val.trim().isNotEmpty && (double.tryParse(val.trim()) ?? 0) > 0 && _transactionType == 'Payment Receipt') {
                          _transactionType = 'Payment with Discount';
                        }
                        setState(() {});
                      },
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          if (_transactionType == 'Discount Only') {
                            return 'Enter discount amount';
                          }
                          return null; // Empty discount defaults to 0
                        }
                        final discAmt = double.tryParse(val.trim());
                        if (discAmt == null || discAmt < 0) {
                          return 'Enter a valid non-negative number';
                        }
                        if (_transactionType == 'Discount Only' && discAmt <= 0) {
                          return 'Enter discount amount';
                        }
                        final payAmt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
                        final total = payAmt + discAmt;
                        if (basePending > 0 && total > (basePending + 0.01)) {
                          return 'Cannot exceed ${Formatters.formatCurrency(basePending)}';
                        }
                        return null;
                      },
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: paymentAmtWidget),
                          const SizedBox(width: 12),
                          Expanded(child: discountAmtWidget),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        paymentAmtWidget,
                        const SizedBox(height: 12),
                        discountAmtWidget,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 📝 Remarks / Notes (Right after Amount fields)
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Notes',
                    hintText: 'Enter reason for discount, transaction note, or remarks...',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: Icon(Icons.notes, size: 18),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ErpButton(
                      text: 'Cancel',
                      isOutlined: true,
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Add Transaction',
                      icon: Icons.check,
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        if (_transactionType != 'Discount Only' && _selectedMode == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a payment mode.')),
                          );
                          return;
                        }
                        final payAmt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
                        final discAmt = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
                        final total = payAmt + discAmt;

                        if (_transactionType != 'Discount Only' && payAmt <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a payment amount.')),
                          );
                          return;
                        }

                        if (total <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a payment or discount amount.')),
                          );
                          return;
                        }

                        final isFull = (basePending > 0 && total >= (basePending - 0.01));

                        final payment = ErpPayment(
                          id: IdGenerator.generateId('PAY'),
                          paymentNumber: IdGenerator.generateDocNumber('PAY', db.nextAdjustmentNumber + 100),
                          paymentType: widget.type,
                          partyId: _selectedPartyId!,
                          partyName: partyName,
                          referenceDocumentId: _selectedLinkedDocId,
                          referenceDocumentNumber: selectedDocNumber,
                          amount: payAmt,
                          discount: discAmt,
                          paymentMode: _transactionType == 'Discount Only' ? PaymentMode.cash : (_selectedMode ?? PaymentMode.bankTransfer),
                          paymentDate: _selectedDate,
                          transactionReference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
                          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                          isFullPayment: isFull,
                          totalDocumentAmount: selectedDocTotal > 0 ? selectedDocTotal : (basePending > 0 ? basePending : total),
                          remainingAmount: calculatedRemaining,
                          projectId: selectedProjectId,
                          projectName: selectedProjectName,
                          createdAt: DateTime.now(),
                        );

                        db.addPaymentAsync(payment).catchError((_) {
                          db.addManualPayment(payment);
                          return payment;
                        });
                        FocusScope.of(context).unfocus();
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Transaction ${payment.paymentNumber} added! Settled: ${Formatters.formatCurrency(total)}.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

