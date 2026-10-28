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
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/erp_toast.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';
import '../../../shared/widgets/whatsapp_quick_chat_dialog.dart';

class PaymentCenterScreen extends ConsumerStatefulWidget {
  final PaymentType? initialTab;

  const PaymentCenterScreen({super.key, this.initialTab});

  @override
  ConsumerState<PaymentCenterScreen> createState() => _PaymentCenterScreenState();
}

class _PaymentCenterScreenState extends ConsumerState<PaymentCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  // Customer Payments Tab
  String? _customerSearchQuery = '';
  String? _customerBalanceFilter = 'ALL';
  DateTime? _customerStartDate;
  DateTime? _customerEndDate;
  int? _customerPageSize = 10;
  int? _customerCurrentPage = 0;
  String get _safeCustomerSearchQuery => _customerSearchQuery ?? '';
  String get _safeCustomerBalanceFilter => _customerBalanceFilter ?? 'ALL';
  int get _safeCustomerPageSize => _safeInt(_customerPageSize, 10);
  int get _safeCustomerCurrentPage => _safeInt(_customerCurrentPage, 0);

  // Dealer Payments Tab
  String? _dealerSearchQuery = '';
  String? _dealerBalanceFilter = 'ALL';
  DateTime? _dealerStartDate;
  DateTime? _dealerEndDate;
  int? _dealerPageSize = 10;
  int? _dealerCurrentPage = 0;
  String get _safeDealerSearchQuery => _dealerSearchQuery ?? '';
  String get _safeDealerBalanceFilter => _dealerBalanceFilter ?? 'ALL';
  int get _safeDealerPageSize => _safeInt(_dealerPageSize, 10);
  int get _safeDealerCurrentPage => _safeInt(_dealerCurrentPage, 0);

  // Vendor Payments Tab
  String? _vendorSearchQuery = '';
  String? _vendorBalanceFilter = 'ALL';
  DateTime? _vendorStartDate;
  DateTime? _vendorEndDate;
  int? _vendorPageSize = 10;
  int? _vendorCurrentPage = 0;
  String get _safeVendorSearchQuery => _vendorSearchQuery ?? '';
  String get _safeVendorBalanceFilter => _vendorBalanceFilter ?? 'ALL';
  int get _safeVendorPageSize => _safeInt(_vendorPageSize, 10);
  int get _safeVendorCurrentPage => _safeInt(_vendorCurrentPage, 0);

  // Commission Payouts Tab
  String? _commissionSearchQuery = '';
  String? _commissionModeFilter = 'ALL';
  String? _commissionSettlementFilter = 'ALL';
  DateTime? _commissionStartDate;
  DateTime? _commissionEndDate;
  int? _commissionPageSize = 10;
  int? _commissionCurrentPage = 0;
  String get _safeCommissionSearchQuery => _commissionSearchQuery ?? '';
  String get _safeCommissionModeFilter => _commissionModeFilter ?? 'ALL';
  String get _safeCommissionSettlementFilter => _commissionSettlementFilter ?? 'ALL';
  int get _safeCommissionPageSize => _safeInt(_commissionPageSize, 10);
  int get _safeCommissionCurrentPage => _safeInt(_commissionCurrentPage, 0);

  @override
  void initState() {
    super.initState();
    _customerSearchQuery ??= '';
    _customerBalanceFilter ??= 'ALL';
    _customerPageSize ??= 10;
    _customerCurrentPage ??= 0;
    _dealerSearchQuery ??= '';
    _dealerBalanceFilter ??= 'ALL';
    _dealerPageSize ??= 10;
    _dealerCurrentPage ??= 0;
    _vendorSearchQuery ??= '';
    _vendorBalanceFilter ??= 'ALL';
    _vendorPageSize ??= 10;
    _vendorCurrentPage ??= 0;
    _commissionSearchQuery ??= '';
    _commissionModeFilter ??= 'ALL';
    _commissionSettlementFilter ??= 'ALL';
    _commissionPageSize ??= 10;
    _commissionCurrentPage ??= 0;
    int initialIdx = 0;
    final currentNav = ref.read(currentNavSectionProvider);
    if (currentNav == ErpNavSection.dealerPayments) {
      initialIdx = 1;
    } else if (currentNav == ErpNavSection.vendorPayments || currentNav == ErpNavSection.vendorPaymentsSection) {
      initialIdx = 2;
    } else if (currentNav == ErpNavSection.commissionPayments) {
      initialIdx = 3;
    } else if (widget.initialTab != null) {
      initialIdx = widget.initialTab!.index;
    }
    _currentTabIndex = initialIdx;
    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIdx);
    _tabController.addListener(_handleTabChange);
    Future.microtask(() {
      final db = ref.read(databaseServiceProvider);
      if (db.payments.isEmpty) db.loadPayments();
      if (db.commissions.isEmpty) db.loadCommissions();
      if (db.customers.isEmpty) db.loadCustomers();
      if (db.dealers.isEmpty) db.loadDealers();
      if (db.salesInvoices.isEmpty) db.loadSalesInvoices();
      if (db.vendors.isEmpty) db.loadVendors();
      if (db.purchases.isEmpty) db.loadPurchases();
    });
  }

  void _handleTabChange() {
    if (!mounted) return;
    if (_currentTabIndex != _tabController.index) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
    if (!_tabController.indexIsChanging) {
      final targetSection = _getSectionForIndex(_tabController.index);
      if (ref.read(currentNavSectionProvider) != targetSection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ref.read(currentNavSectionProvider) != targetSection) {
            ref.read(currentNavSectionProvider.notifier).state = targetSection;
          }
        });
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
      final newIndex = widget.initialTab!.index;
      if (_currentTabIndex != newIndex) {
        setState(() {
          _currentTabIndex = newIndex;
        });
        if (_tabController.index != newIndex) {
          _tabController.animateTo(newIndex);
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
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
      if (previous == next) return;
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

      if (targetIndex != null && _currentTabIndex != targetIndex) {
        setState(() {
          _currentTabIndex = targetIndex!;
        });
        if (_tabController.index != targetIndex) {
          _tabController.animateTo(targetIndex);
        }
      }
    });

    final (headerTitle, badgeText, buttonLabel, currentPaymentType) = switch (_currentTabIndex) {
      0 => ('Customer Payments', 'ACCOUNTS RECEIVABLE', 'Record Customer Payment', PaymentType.customerPayment),
      1 => ('Dealer Payments', 'CHANNEL RECEIPTS', 'Record Dealer Payment', PaymentType.dealerPayment),
      2 => ('Vendor Payments', 'ACCOUNTS PAYABLE', 'Record Vendor Payment', PaymentType.vendorPayment),
      3 => ('Commission Payouts', 'SPECIFIER COMMISSIONS', 'Record Commission Payout', PaymentType.commissionPayment),
      _ => ('Customer Payments', 'ACCOUNTS RECEIVABLE', 'Record Customer Payment', PaymentType.customerPayment),
    };

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.payments_rounded,
            title: headerTitle,
            badgeText: badgeText,
            action: ErpButton(
              text: buttonLabel,
              icon: Icons.add,
              onPressed: () => _openRecordPaymentDialog(currentPaymentType),
            ),
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
              if (_currentTabIndex != index) {
                setState(() {
                  _currentTabIndex = index;
                });
              }
            },
            tabs: const [
              Tab(text: 'Customer Payments'),
              Tab(text: 'Dealer Payments'),
              Tab(text: 'Vendor Payments'),
              Tab(text: 'Commission Payouts'),
            ],
          ),
          const SizedBox(height: 16),

          switch (_currentTabIndex) {
            0 => _buildCustomerCollectionsTab(db),
            1 => _buildDealerReceiptsTab(db),
            2 => _buildVendorDisbursementsTab(db),
            3 => _buildCommissionPayoutsTab(db),
            _ => _buildCustomerCollectionsTab(db),
          },
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
    final query = _safeLower(_safeCustomerSearchQuery);
    final hasDateFilter = _customerStartDate != null || _customerEndDate != null;
    final start = _customerStartDate != null ? DateTime(_customerStartDate!.year, _customerStartDate!.month, _customerStartDate!.day) : null;
    final end = _customerEndDate != null ? DateTime(_customerEndDate!.year, _customerEndDate!.month, _customerEndDate!.day, 23, 59, 59) : null;

    final filtered = allSummaries.where((s) {
      if (query.isNotEmpty) {
        final c = s.customer;
        final matchesQuery = _safeLower(c.name).contains(query) ||
            _safeLower(c.mobile).contains(query) ||
            _safeLower(c.gstNumber).contains(query) ||
            _safeLower(c.address).contains(query);
        if (!matchesQuery) return false;
      }
      if (_safeCustomerBalanceFilter == 'PENDING' && s.pendingAmount <= 0) return false;
      if (_safeCustomerBalanceFilter == 'ZERO' && s.pendingAmount > 0) return false;

      if (hasDateFilter) {
        final matchesDate = s.entries.any((entry) {
          if (start != null && entry.date.isBefore(start)) return false;
          if (end != null && entry.date.isAfter(end)) return false;
          return true;
        });
        if (!matchesDate) return false;
      }
      return true;
    }).toList();

    final totalCount = filtered.length;
    final pageSize = _safeCustomerPageSize;
    final currentPage = _safeCustomerCurrentPage;
    final startIndex = currentPage * pageSize;
    final endIndex = min(startIndex + pageSize, totalCount);
    final pageSummaries = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <CustomerAccountSummary>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCustomerControlsRow(),
        const SizedBox(height: 16),
        _buildCustomerAccountsTable(pageSummaries),
        const SizedBox(height: 16),
        ErpPaginationBar(
          currentPage: _safeCustomerCurrentPage,
          pageSize: _safeCustomerPageSize,
          totalRecords: totalCount,
          onPageChanged: (newPage) => setState(() => _customerCurrentPage = newPage),
          onPageSizeChanged: (newSize) => setState(() {
            _customerPageSize = newSize;
            _customerCurrentPage = 0;
          }),
        ),
      ],
    );
  }

  Widget _buildCustomerControlsRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: ErpSearchInput(
            hintText: 'Search customer name, mobile, GST...',
            initialValue: _safeCustomerSearchQuery,
            onChanged: (val) => setState(() {
              _customerSearchQuery = val;
              _customerCurrentPage = 0;
            }),
          ),
        ),
        ErpFilterDropdown<String>(
          value: _safeCustomerBalanceFilter,
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Balances')),
            DropdownMenuItem(value: 'PENDING', child: Text('Has Pending Balance')),
            DropdownMenuItem(value: 'ZERO', child: Text('Zero Balance / Settled')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _customerBalanceFilter = val;
                _customerCurrentPage = 0;
              });
            }
          },
        ),
        ErpDateFilterBox(
          startDate: _customerStartDate,
          endDate: _customerEndDate,
          onDateRangeSelected: (start, end) => setState(() {
            _customerStartDate = start;
            _customerEndDate = end;
            _customerCurrentPage = 0;
          }),
        ),
      ],
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
                                  _safeStr(summary.customer.name).isNotEmpty ? summary.customer.name : 'Unnamed Customer',
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
                        PopupMenuButton<String>(
                          tooltip: 'Actions',
                          icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (val) {
                            if (val == 'transaction') {
                              _openRecordPaymentDialog(
                                PaymentType.customerPayment,
                                preselectedPartyId: summary.customer.id,
                              );
                            } else if (val == 'history') {
                              _openCustomerHistoryDialog(summary);
                            } else if (val == 'whatsapp') {
                              _openCustomerWhatsAppReminder(summary);
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(
                              value: 'transaction',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF0284C7)),
                                  SizedBox(width: 8),
                                  Text('Transaction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'history',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF475569)),
                                  SizedBox(width: 8),
                                  Text('History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'whatsapp',
                              child: Row(
                                children: [
                                  Icon(Icons.chat, size: 18, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('WhatsApp Chat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
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

  void _openCustomerWhatsAppReminder(CustomerAccountSummary summary) {
    DateTime? oldestInvoiceDate;
    String? oldestDocNumber;
    final saleEntries = summary.entries.where((e) => e.type == 'Sale Invoice').toList();
    if (saleEntries.isNotEmpty) {
      for (final entry in saleEntries) {
        if (oldestInvoiceDate == null || entry.date.isBefore(oldestInvoiceDate)) {
          oldestInvoiceDate = entry.date;
          oldestDocNumber = entry.docNumber;
        }
      }
    }

    if (oldestInvoiceDate == null && summary.entries.isNotEmpty) {
      oldestInvoiceDate = summary.entries.last.date;
      oldestDocNumber = summary.entries.last.docNumber;
    }

    final now = DateTime.now();
    final pendingDays = oldestInvoiceDate != null
        ? now.difference(oldestInvoiceDate).inDays
        : (summary.pendingAmount > 0 ? 30 : 0);

    WhatsAppQuickChatDialog.showCustomerQuickChat(
      context,
      customerName: summary.customer.name,
      customerPhone: summary.customer.mobile,
      docNumber: oldestDocNumber,
      pendingAmount: summary.pendingAmount,
      saleTotal: summary.saleTotal,
      paidAmount: summary.paidAmount,
      pendingDays: pendingDays,
      oldestInvoiceDate: oldestInvoiceDate,
    );
  }

  void _openCustomerHistoryDialog(CustomerAccountSummary summary) {
    DateTime? historyStartDate;
    DateTime? historyEndDate;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final isMobile = MediaQuery.of(dialogCtx).size.width < 750;
            final hasDateFilter = historyStartDate != null || historyEndDate != null;
            final start = historyStartDate != null
                ? DateTime(historyStartDate!.year, historyStartDate!.month, historyStartDate!.day)
                : null;
            final end = historyEndDate != null
                ? DateTime(historyEndDate!.year, historyEndDate!.month, historyEndDate!.day, 23, 59, 59)
                : null;

            final filteredEntries = summary.entries.where((entry) {
              if (hasDateFilter) {
                if (start != null && entry.date.isBefore(start)) return false;
                if (end != null && entry.date.isAfter(end)) return false;
              }
              return true;
            }).toList();

            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                constraints: BoxConstraints(maxWidth: 1140, maxHeight: isMobile ? MediaQuery.of(dialogCtx).size.height * 0.88 : 680),
                padding: EdgeInsets.all(isMobile ? 14 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.person, color: Color(0xFF0284C7), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _safeStr(summary.customer.name).isNotEmpty ? summary.customer.name : 'Unnamed Customer',
                                      style: AppTextStyles.h2.copyWith(fontSize: isMobile ? 15 : 18),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isMobile
                                          ? (hasDateFilter
                                              ? 'Customer Ledger (${filteredEntries.length}/${summary.entries.length} txns)'
                                              : 'Customer Ledger (${summary.entries.length} txns)')
                                          : (hasDateFilter
                                              ? 'Customer Ledger & Transaction Statement (${filteredEntries.length} of ${summary.entries.length} Transactions)'
                                              : 'Customer Ledger & Transaction Statement (${summary.entries.length} Transactions)'),
                                      style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            FocusScope.of(ctx).unfocus();
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Summary Cards & Date Filter
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Wrap(
                            spacing: 8,
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
                          ErpDateFilterBox(
                            startDate: historyStartDate,
                            endDate: historyEndDate,
                            onDateRangeSelected: (start, end) {
                              setModalState(() {
                                historyStartDate = start;
                                historyEndDate = end;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // 9-Column Ledger Table (Desktop) or Card List (Mobile)
                    Expanded(
                      child: filteredEntries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    hasDateFilter
                                        ? 'No transactions found for the selected date range.'
                                        : 'No transactions recorded yet for this customer.',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                            )
                          : isMobile
                              ? ListView.separated(
                                  itemCount: filteredEntries.length,
                                  separatorBuilder: (c, i) => const SizedBox(height: 8),
                                  itemBuilder: (context, idx) => _buildMobileLedgerCard(filteredEntries[idx]),
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
                                  rows: filteredEntries.map((entry) {
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
                    const SizedBox(height: 14),

                    // Action buttons footer
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ErpButton(
                          text: 'Close',
                          isOutlined: true,
                          onPressed: () {
                            FocusScope.of(ctx).unfocus();
                            Navigator.of(ctx).pop();
                          },
                        ),
                        ErpButton(
                          text: 'WhatsApp Chat',
                          icon: Icons.chat,
                          isOutlined: true,
                          onPressed: () {
                            _openCustomerWhatsAppReminder(summary);
                          },
                        ),
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
      },
    );
  }

  Widget _buildDealerReceiptsTab(MockDatabaseService db) {
    final allSummaries = _computeDealerSummaries(db);
    final query = _safeLower(_safeDealerSearchQuery);
    final hasDateFilter = _dealerStartDate != null || _dealerEndDate != null;
    final start = _dealerStartDate != null ? DateTime(_dealerStartDate!.year, _dealerStartDate!.month, _dealerStartDate!.day) : null;
    final end = _dealerEndDate != null ? DateTime(_dealerEndDate!.year, _dealerEndDate!.month, _dealerEndDate!.day, 23, 59, 59) : null;

    final filtered = allSummaries.where((s) {
      if (query.isNotEmpty) {
        final d = s.dealer;
        final matchesQuery = _safeLower(d.name).contains(query) ||
            _safeLower(d.companyName).contains(query) ||
            _safeLower(d.mobile).contains(query) ||
            _safeLower(d.gstNumber).contains(query) ||
            _safeLower(d.address).contains(query);
        if (!matchesQuery) return false;
      }
      if (_safeDealerBalanceFilter == 'PENDING' && s.pendingAmount <= 0) return false;
      if (_safeDealerBalanceFilter == 'ZERO' && s.pendingAmount > 0) return false;

      if (hasDateFilter) {
        final matchesDate = s.entries.any((entry) {
          if (start != null && entry.date.isBefore(start)) return false;
          if (end != null && entry.date.isAfter(end)) return false;
          return true;
        });
        if (!matchesDate) return false;
      }
      return true;
    }).toList();

    final totalCount = filtered.length;
    final pageSize = _safeDealerPageSize;
    final currentPage = _safeDealerCurrentPage;
    final startIndex = currentPage * pageSize;
    final endIndex = min(startIndex + pageSize, totalCount);
    final pageSummaries = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <DealerAccountSummary>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDealerControlsRow(),
        const SizedBox(height: 16),
        _buildDealerAccountsTable(pageSummaries),
        const SizedBox(height: 16),
        ErpPaginationBar(
          currentPage: _safeDealerCurrentPage,
          pageSize: _safeDealerPageSize,
          totalRecords: totalCount,
          onPageChanged: (newPage) => setState(() => _dealerCurrentPage = newPage),
          onPageSizeChanged: (newSize) => setState(() {
            _dealerPageSize = newSize;
            _dealerCurrentPage = 0;
          }),
        ),
      ],
    );
  }

  Widget _buildDealerControlsRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: ErpSearchInput(
            hintText: 'Search dealer name, company, GST...',
            initialValue: _safeDealerSearchQuery,
            onChanged: (val) => setState(() {
              _dealerSearchQuery = val;
              _dealerCurrentPage = 0;
            }),
          ),
        ),
        ErpFilterDropdown<String>(
          value: _safeDealerBalanceFilter,
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Balances')),
            DropdownMenuItem(value: 'PENDING', child: Text('Has Pending Balance')),
            DropdownMenuItem(value: 'ZERO', child: Text('Zero Balance / Settled')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _dealerBalanceFilter = val;
                _dealerCurrentPage = 0;
              });
            }
          },
        ),
        ErpDateFilterBox(
          startDate: _dealerStartDate,
          endDate: _dealerEndDate,
          onDateRangeSelected: (start, end) => setState(() {
            _dealerStartDate = start;
            _dealerEndDate = end;
            _dealerCurrentPage = 0;
          }),
        ),
      ],
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
                                  _safeStr(summary.dealer.name).isNotEmpty ? summary.dealer.name : 'Unnamed Dealer',
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
                                      (_safeStr(summary.dealer.companyName).isNotEmpty)
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
                        PopupMenuButton<String>(
                          tooltip: 'Actions',
                          icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (val) {
                            if (val == 'transaction') {
                              _openRecordPaymentDialog(
                                PaymentType.dealerPayment,
                                preselectedPartyId: summary.dealer.id,
                              );
                            } else if (val == 'history') {
                              _openDealerHistoryDialog(summary);
                            } else if (val == 'whatsapp') {
                              WhatsAppQuickChatDialog.showCustomerQuickChat(
                                context,
                                customerName: summary.dealer.name,
                                customerPhone: summary.dealer.mobile,
                              );
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(
                              value: 'transaction',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF0284C7)),
                                  SizedBox(width: 8),
                                  Text('Transaction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'history',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF475569)),
                                  SizedBox(width: 8),
                                  Text('History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'whatsapp',
                              child: Row(
                                children: [
                                  Icon(Icons.chat, size: 18, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('WhatsApp Chat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
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
    DateTime? historyStartDate;
    DateTime? historyEndDate;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final isMobile = MediaQuery.of(dialogCtx).size.width < 750;
            final hasDateFilter = historyStartDate != null || historyEndDate != null;
            final start = historyStartDate != null
                ? DateTime(historyStartDate!.year, historyStartDate!.month, historyStartDate!.day)
                : null;
            final end = historyEndDate != null
                ? DateTime(historyEndDate!.year, historyEndDate!.month, historyEndDate!.day, 23, 59, 59)
                : null;

            final filteredEntries = summary.entries.where((entry) {
              if (hasDateFilter) {
                if (start != null && entry.date.isBefore(start)) return false;
                if (end != null && entry.date.isAfter(end)) return false;
              }
              return true;
            }).toList();

            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                constraints: BoxConstraints(maxWidth: 1140, maxHeight: isMobile ? MediaQuery.of(dialogCtx).size.height * 0.88 : 680),
                padding: EdgeInsets.all(isMobile ? 14 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.storefront_outlined, color: Color(0xFF16A34A), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _safeStr(summary.dealer.name).isNotEmpty ? summary.dealer.name : 'Unnamed Dealer',
                                      style: AppTextStyles.h2.copyWith(fontSize: isMobile ? 15 : 18),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isMobile
                                          ? (hasDateFilter
                                              ? 'Dealer Ledger (${filteredEntries.length}/${summary.entries.length} txns)'
                                              : 'Dealer Ledger (${summary.entries.length} txns)')
                                          : (hasDateFilter
                                              ? 'Dealer Ledger & Transaction Statement (${filteredEntries.length} of ${summary.entries.length} Transactions)'
                                              : 'Dealer Ledger & Transaction Statement (${summary.entries.length} Transactions)'),
                                      style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            FocusScope.of(ctx).unfocus();
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Summary Cards & Date Filter
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Wrap(
                            spacing: 8,
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
                          ErpDateFilterBox(
                            startDate: historyStartDate,
                            endDate: historyEndDate,
                            onDateRangeSelected: (start, end) {
                              setModalState(() {
                                historyStartDate = start;
                                historyEndDate = end;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // 9-Column Ledger Table (Desktop) or Card List (Mobile)
                    Expanded(
                      child: filteredEntries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    hasDateFilter
                                        ? 'No transactions found for the selected date range.'
                                        : 'No transactions recorded yet for this dealer.',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                            )
                          : isMobile
                              ? ListView.separated(
                                  itemCount: filteredEntries.length,
                                  separatorBuilder: (c, i) => const SizedBox(height: 8),
                                  itemBuilder: (context, idx) => _buildMobileLedgerCard(filteredEntries[idx]),
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
                                  rows: filteredEntries.map((entry) {
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
                    const SizedBox(height: 14),

                    // Action buttons footer
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ErpButton(
                          text: 'Close',
                          isOutlined: true,
                          onPressed: () {
                            FocusScope.of(ctx).unfocus();
                            Navigator.of(ctx).pop();
                          },
                        ),
                        ErpButton(
                          text: 'WhatsApp Chat',
                          icon: Icons.chat,
                          isOutlined: true,
                          onPressed: () {
                            WhatsAppQuickChatDialog.showCustomerQuickChat(
                              context,
                              customerName: summary.dealer.name,
                              customerPhone: summary.dealer.mobile,
                            );
                          },
                        ),
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
      },
    );
  }

  List<DealerAccountSummary> _computeDealerSummaries(MockDatabaseService db) {
    final summaries = <DealerAccountSummary>[];
    final seenKeys = <String>{};

    for (final dealer in db.dealers) {
      if (dealer.isDeleted) continue;

      final String dId = _safeStr(dealer.id);
      final String dName = _safeLower(dealer.name);
      final String dComp = _safeLower(dealer.companyName);
      final key = dName.isNotEmpty ? dName : (dComp.isNotEmpty ? dComp : dId);
      if (key.isEmpty || seenKeys.contains(key)) continue;
      seenKeys.add(key);

      final duplicates = db.dealers.where((d) {
        if (d.isDeleted) return false;
        final dn = _safeLower(d.name);
        final dc = _safeLower(d.companyName);
        final di = _safeStr(d.id);
        final dk = dn.isNotEmpty ? dn : (dc.isNotEmpty ? dc : di);
        return dk == key;
      }).toList();

      final activeDealer = duplicates.firstWhere(
        (d) => _safeDouble(d.outstandingAmount) > 0 || _safeStr(d.mobile).isNotEmpty || _safeStr(d.email).isNotEmpty,
        orElse: () => dealer,
      );

      final matchingIds = duplicates.map((d) => _safeStr(d.id)).where((id) => id.isNotEmpty).toSet();

      final dealerSales = db.sales.where((s) {
        final sPartyId = _safeStr(s.partyId);
        final sPartyName = _safeLower(s.partyName);
        final matchesId = (dId.isNotEmpty && sPartyId == dId) || matchingIds.contains(sPartyId);
        final matchesName = (dName.isNotEmpty && sPartyName == dName) || (dComp.isNotEmpty && sPartyName == dComp);
        final isRelevantType = s.documentType == SalesDocumentType.invoice || s.documentType == SalesDocumentType.salesOrder;
        return (matchesId || matchesName) && isRelevantType;
      }).toList();

      final dealerPayments = db.payments.where((p) {
        final pPartyId = _safeStr(p.partyId);
        final pPartyName = _safeLower(p.partyName);
        final matchesId = (dId.isNotEmpty && pPartyId == dId) || matchingIds.contains(pPartyId);
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
      final double dealerOutstanding = duplicates.fold(0.0, (maxVal, d) => max(maxVal, _safeDouble(d.outstandingAmount)));

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
        dealer: activeDealer,
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
    final query = _safeLower(_safeVendorSearchQuery);
    final hasDateFilter = _vendorStartDate != null || _vendorEndDate != null;
    final start = _vendorStartDate != null ? DateTime(_vendorStartDate!.year, _vendorStartDate!.month, _vendorStartDate!.day) : null;
    final end = _vendorEndDate != null ? DateTime(_vendorEndDate!.year, _vendorEndDate!.month, _vendorEndDate!.day, 23, 59, 59) : null;

    final filtered = allSummaries.where((s) {
      if (query.isNotEmpty) {
        final v = s.vendor;
        final matchesQuery = _safeLower(v.name).contains(query) ||
            _safeLower(v.contactPerson).contains(query) ||
            _safeLower(v.mobile).contains(query) ||
            _safeLower(v.email).contains(query) ||
            _safeLower(v.gstNumber).contains(query) ||
            _safeLower(v.panNumber).contains(query) ||
            _safeLower(v.address).contains(query);
        if (!matchesQuery) return false;
      }
      if (_safeVendorBalanceFilter == 'PENDING' && s.pendingAmount <= 0) return false;
      if (_safeVendorBalanceFilter == 'ZERO' && s.pendingAmount > 0) return false;

      if (hasDateFilter) {
        final matchesDate = s.entries.any((entry) {
          if (start != null && entry.date.isBefore(start)) return false;
          if (end != null && entry.date.isAfter(end)) return false;
          return true;
        });
        if (!matchesDate) return false;
      }
      return true;
    }).toList();

    final totalCount = filtered.length;
    final pageSize = _safeVendorPageSize;
    final currentPage = _safeVendorCurrentPage;
    final startIndex = currentPage * pageSize;
    final endIndex = min(startIndex + pageSize, totalCount);
    final pageSummaries = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <VendorAccountSummary>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVendorControlsRow(),
        const SizedBox(height: 16),
        _buildVendorAccountsTable(pageSummaries),
        const SizedBox(height: 16),
        ErpPaginationBar(
          currentPage: _safeVendorCurrentPage,
          pageSize: _safeVendorPageSize,
          totalRecords: totalCount,
          onPageChanged: (newPage) => setState(() => _vendorCurrentPage = newPage),
          onPageSizeChanged: (newSize) => setState(() {
            _vendorPageSize = newSize;
            _vendorCurrentPage = 0;
          }),
        ),
      ],
    );
  }

  Widget _buildVendorControlsRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: ErpSearchInput(
            hintText: 'Search vendor name, contact, GST...',
            initialValue: _safeVendorSearchQuery,
            onChanged: (val) => setState(() {
              _vendorSearchQuery = val;
              _vendorCurrentPage = 0;
            }),
          ),
        ),
        ErpFilterDropdown<String>(
          value: _safeVendorBalanceFilter,
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Balances')),
            DropdownMenuItem(value: 'PENDING', child: Text('Has Payable Balance')),
            DropdownMenuItem(value: 'ZERO', child: Text('Zero Balance / Settled')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _vendorBalanceFilter = val;
                _vendorCurrentPage = 0;
              });
            }
          },
        ),
        ErpDateFilterBox(
          startDate: _vendorStartDate,
          endDate: _vendorEndDate,
          onDateRangeSelected: (start, end) => setState(() {
            _vendorStartDate = start;
            _vendorEndDate = end;
            _vendorCurrentPage = 0;
          }),
        ),
      ],
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
                                  _safeStr(summary.vendor.name).isNotEmpty ? summary.vendor.name : 'Unnamed Vendor',
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
                                      (_safeStr(summary.vendor.contactPerson).isNotEmpty)
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
                        PopupMenuButton<String>(
                          tooltip: 'Actions',
                          icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (val) {
                            if (val == 'transaction') {
                              _openRecordPaymentDialog(
                                PaymentType.vendorPayment,
                                preselectedPartyId: summary.vendor.id,
                              );
                            } else if (val == 'history') {
                              _openVendorHistoryDialog(summary);
                            } else if (val == 'whatsapp') {
                              WhatsAppQuickChatDialog.showCustomerQuickChat(
                                context,
                                customerName: summary.vendor.name,
                                customerPhone: summary.vendor.mobile,
                              );
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(
                              value: 'transaction',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF2563EB)),
                                  SizedBox(width: 8),
                                  Text('Transaction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'history',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF475569)),
                                  SizedBox(width: 8),
                                  Text('History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'whatsapp',
                              child: Row(
                                children: [
                                  Icon(Icons.chat, size: 18, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('WhatsApp Chat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
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
    DateTime? historyStartDate;
    DateTime? historyEndDate;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final isMobile = MediaQuery.of(dialogCtx).size.width < 750;
            final hasDateFilter = historyStartDate != null || historyEndDate != null;
            final start = historyStartDate != null
                ? DateTime(historyStartDate!.year, historyStartDate!.month, historyStartDate!.day)
                : null;
            final end = historyEndDate != null
                ? DateTime(historyEndDate!.year, historyEndDate!.month, historyEndDate!.day, 23, 59, 59)
                : null;

            final filteredEntries = summary.entries.where((entry) {
              if (hasDateFilter) {
                if (start != null && entry.date.isBefore(start)) return false;
                if (end != null && entry.date.isAfter(end)) return false;
              }
              return true;
            }).toList();

            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                constraints: BoxConstraints(maxWidth: 1140, maxHeight: isMobile ? MediaQuery.of(dialogCtx).size.height * 0.88 : 700),
                padding: EdgeInsets.all(isMobile ? 14 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _safeStr(summary.vendor.name).isNotEmpty ? summary.vendor.name : 'Unnamed Vendor',
                                      style: AppTextStyles.h2.copyWith(fontSize: isMobile ? 15 : 18),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isMobile
                                          ? (hasDateFilter
                                              ? 'Vendor Ledger (${filteredEntries.length}/${summary.entries.length} txns)'
                                              : 'Vendor Ledger (${summary.entries.length} txns)')
                                          : (hasDateFilter
                                              ? 'Vendor Ledger & Transaction Statement (${filteredEntries.length} of ${summary.entries.length} Transactions)'
                                              : 'Vendor Ledger & Transaction Statement (${summary.entries.length} Transactions)'),
                                      style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            FocusScope.of(ctx).unfocus();
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Summary Cards & Date Filter
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Wrap(
                            spacing: 8,
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
                          ErpDateFilterBox(
                            startDate: historyStartDate,
                            endDate: historyEndDate,
                            onDateRangeSelected: (start, end) {
                              setModalState(() {
                                historyStartDate = start;
                                historyEndDate = end;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // 8-Column Ledger Table (Desktop) or Card List (Mobile)
                    Expanded(
                      child: filteredEntries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text(
                                    hasDateFilter
                                        ? 'No transactions found for the selected date range.'
                                        : 'No ledger entries recorded yet',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                            )
                          : isMobile
                              ? ListView.separated(
                                  itemCount: filteredEntries.length,
                                  separatorBuilder: (c, i) => const SizedBox(height: 8),
                                  itemBuilder: (context, idx) => _buildMobileLedgerCard(filteredEntries[idx], isVendor: true),
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
                                  rows: filteredEntries.map((entry) {
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
                    const SizedBox(height: 14),

                    // Action buttons footer
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ErpButton(
                          text: 'Close',
                          isOutlined: true,
                          onPressed: () {
                            FocusScope.of(ctx).unfocus();
                            Navigator.of(ctx).pop();
                          },
                        ),
                        ErpButton(
                          text: 'WhatsApp Chat',
                          icon: Icons.chat,
                          isOutlined: true,
                          onPressed: () {
                            WhatsAppQuickChatDialog.showCustomerQuickChat(
                              context,
                              customerName: summary.vendor.name,
                              customerPhone: summary.vendor.mobile,
                            );
                          },
                        ),
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
      },
    );
  }

  List<VendorAccountSummary> _computeVendorSummaries(MockDatabaseService db) {
    final summaries = <VendorAccountSummary>[];
    final seenKeys = <String>{};

    for (final vendor in db.vendors) {
      if (vendor.isDeleted) continue;

      final String vId = _safeStr(vendor.id);
      final String vName = _safeLower(vendor.name);
      final key = vName.isNotEmpty ? vName : vId;
      if (key.isEmpty || seenKeys.contains(key)) continue;
      seenKeys.add(key);

      final duplicates = db.vendors.where((v) {
        if (v.isDeleted) return false;
        final vn = _safeLower(v.name);
        final vi = _safeStr(v.id);
        final vk = vn.isNotEmpty ? vn : vi;
        return vk == key;
      }).toList();

      final activeVendor = duplicates.firstWhere(
        (v) => _safeDouble(v.outstandingBalance) > 0 || _safeStr(v.mobile).isNotEmpty || _safeStr(v.email).isNotEmpty,
        orElse: () => vendor,
      );

      final matchingIds = duplicates.map((v) => _safeStr(v.id)).where((id) => id.isNotEmpty).toSet();

      final vendorPurchases = db.purchases.where((p) {
        final pVendorId = _safeStr(p.vendorId);
        final pVendorName = _safeLower(p.vendorName);
        final matchesId = (vId.isNotEmpty && pVendorId == vId) || matchingIds.contains(pVendorId);
        final matchesName = vName.isNotEmpty && pVendorName == vName;
        final isNotCancelled = p.status != PurchaseStatus.cancelled;
        return (matchesId || matchesName) && isNotCancelled;
      }).toList();

      final vendorPayments = db.payments.where((p) {
        final pPartyId = _safeStr(p.partyId);
        final pPartyName = _safeLower(p.partyName);
        final matchesId = (vId.isNotEmpty && pPartyId == vId) || matchingIds.contains(pPartyId);
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
      final double vendorOutstanding = duplicates.fold(0.0, (maxVal, v) => max(maxVal, _safeDouble(v.outstandingBalance)));

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
        vendor: activeVendor,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildMobileLedgerCard(CustomerLedgerEntry entry, {bool isVendor = false}) {
    final isPurchase = entry.type.toLowerCase().contains('purchase') || entry.type.toLowerCase().contains('invoice');
    final isCredit = isVendor ? isPurchase : (entry.type == 'Sale Invoice');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Doc Number + Type badge + Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        entry.docNumber,
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isVendor)
                      (isPurchase ? ErpStatusBadge.neutral(entry.type) : ErpStatusBadge.success(entry.type))
                    else
                      (entry.type == 'Sale Invoice' ? ErpStatusBadge.info('SALE') : ErpStatusBadge.success('RECEIPT')),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.formatDate(entry.date),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Amount + Mode
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Amount: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  Text(
                    Formatters.formatCurrency(entry.amount),
                    style: AppTextStyles.bodyBold.copyWith(
                      fontSize: 13,
                      color: isCredit ? Colors.black87 : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              ErpStatusBadge.neutral(entry.paymentMode),
            ],
          ),
          const SizedBox(height: 6),

          // Row 3: Opening -> Closing Balances + Discount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Bal: ${Formatters.formatCurrency(entry.openingPending)} → ${Formatters.formatCurrency(entry.closingPending)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: entry.closingPending > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entry.discount > 0) ...[
                const SizedBox(width: 8),
                Text(
                  'Disc: ${Formatters.formatCurrency(entry.discount)}',
                  style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF7C3AED), fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),

          // Row 4: Remarks (if any)
          if (entry.remarks.isNotEmpty && entry.remarks != '—' && entry.remarks != '-') ...[
            const SizedBox(height: 6),
            Text(
              'Remarks: ${entry.remarks}',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  List<CustomerAccountSummary> _computeCustomerSummaries(MockDatabaseService db) {
    final summaries = <CustomerAccountSummary>[];
    final seenKeys = <String>{};

    for (final customer in db.customers) {
      if (customer.isDeleted) continue;

      final String cId = _safeStr(customer.id);
      final String cName = _safeLower(customer.name);
      final key = cName.isNotEmpty ? cName : cId;
      if (key.isEmpty || seenKeys.contains(key)) continue;
      seenKeys.add(key);

      final duplicates = db.customers.where((c) {
        if (c.isDeleted) return false;
        final dName = _safeLower(c.name);
        final dId = _safeStr(c.id);
        final dKey = dName.isNotEmpty ? dName : dId;
        return dKey == key;
      }).toList();

      final activeCustomer = duplicates.firstWhere(
        (c) => _safeDouble(c.outstandingAmount) > 0 || _safeStr(c.mobile).isNotEmpty || _safeStr(c.email).isNotEmpty,
        orElse: () => customer,
      );

      final matchingIds = duplicates.map((c) => _safeStr(c.id)).where((id) => id.isNotEmpty).toSet();

      final customerSales = db.sales.where((s) {
        final sPartyId = _safeStr(s.partyId);
        final sPartyName = _safeLower(s.partyName);
        final matchesId = (cId.isNotEmpty && sPartyId == cId) || matchingIds.contains(sPartyId);
        final matchesName = cName.isNotEmpty && sPartyName == cName;
        final isRelevantType = s.documentType == SalesDocumentType.invoice || s.documentType == SalesDocumentType.salesOrder;
        return (matchesId || matchesName) && isRelevantType;
      }).toList();

      final customerPayments = db.payments.where((p) {
        final pPartyId = _safeStr(p.partyId);
        final pPartyName = _safeLower(p.partyName);
        final matchesId = (cId.isNotEmpty && pPartyId == cId) || matchingIds.contains(pPartyId);
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
      final double custOutstanding = duplicates.fold(0.0, (maxVal, c) => max(maxVal, _safeDouble(c.outstandingAmount)));

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
        customer: activeCustomer,
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

  Widget _buildCommissionPayoutsTab(MockDatabaseService db) {
    final allPayments = db.payments.where((p) => p.paymentType == PaymentType.commissionPayment).toList();
    final query = _safeLower(_safeCommissionSearchQuery);
    final hasDateFilter = _commissionStartDate != null || _commissionEndDate != null;
    final start = _commissionStartDate != null ? DateTime(_commissionStartDate!.year, _commissionStartDate!.month, _commissionStartDate!.day) : null;
    final end = _commissionEndDate != null ? DateTime(_commissionEndDate!.year, _commissionEndDate!.month, _commissionEndDate!.day, 23, 59, 59) : null;

    final filtered = allPayments.where((p) {
      if (query.isNotEmpty) {
        final matches = _safeLower(p.paymentNumber).contains(query) ||
            _safeLower(p.partyName).contains(query) ||
            _safeLower(p.referenceDocumentNumber).contains(query) ||
            _safeLower(p.transactionReference).contains(query) ||
            _safeLower(p.paymentMode.name).contains(query) ||
            _safeLower(p.notes).contains(query);
        if (!matches) return false;
      }
      if (_safeCommissionModeFilter != 'ALL') {
        final mode = p.paymentMode.name.toUpperCase();
        if (mode != _safeCommissionModeFilter) return false;
      }
      if (_safeCommissionSettlementFilter == 'FULL' && !p.isFullPayment) return false;
      if (_safeCommissionSettlementFilter == 'PARTIAL' && p.isFullPayment) return false;
      if (hasDateFilter) {
        if (start != null && p.paymentDate.isBefore(start)) return false;
        if (end != null && p.paymentDate.isAfter(end)) return false;
      }
      return true;
    }).toList();

    final totalCount = filtered.length;
    final pageSize = _safeCommissionPageSize;
    final currentPage = _safeCommissionCurrentPage;
    final startIndex = currentPage * pageSize;
    final endIndex = min(startIndex + pageSize, totalCount);
    final pagePayments = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <ErpPayment>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommissionControlsRow(),
        const SizedBox(height: 16),
        _buildPaymentTable(pagePayments, db),
        const SizedBox(height: 16),
        ErpPaginationBar(
          currentPage: _safeCommissionCurrentPage,
          pageSize: _safeCommissionPageSize,
          totalRecords: totalCount,
          onPageChanged: (newPage) => setState(() => _commissionCurrentPage = newPage),
          onPageSizeChanged: (newSize) => setState(() {
            _commissionPageSize = newSize;
            _commissionCurrentPage = 0;
          }),
        ),
      ],
    );
  }

  Widget _buildCommissionControlsRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: ErpSearchInput(
            hintText: 'Search payments by party, ref, UTR...',
            initialValue: _safeCommissionSearchQuery,
            onChanged: (val) => setState(() {
              _commissionSearchQuery = val;
              _commissionCurrentPage = 0;
            }),
          ),
        ),
        ErpFilterDropdown<String>(
          value: _safeCommissionModeFilter,
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Payment Modes')),
            DropdownMenuItem(value: 'CASH', child: Text('Cash')),
            DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer / NEFT')),
            DropdownMenuItem(value: 'UPI', child: Text('UPI')),
            DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _commissionModeFilter = val;
                _commissionCurrentPage = 0;
              });
            }
          },
        ),
        ErpFilterDropdown<String>(
          value: _safeCommissionSettlementFilter,
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Settlements')),
            DropdownMenuItem(value: 'FULL', child: Text('Full Payment')),
            DropdownMenuItem(value: 'PARTIAL', child: Text('Partial Payment')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _commissionSettlementFilter = val;
                _commissionCurrentPage = 0;
              });
            }
          },
        ),
        ErpDateFilterBox(
          startDate: _commissionStartDate,
          endDate: _commissionEndDate,
          onDateRangeSelected: (start, end) => setState(() {
            _commissionStartDate = start;
            _commissionEndDate = end;
            _commissionCurrentPage = 0;
          }),
        ),
      ],
    );
  }

  Widget _buildPaymentTable(List<ErpPayment> payments, MockDatabaseService db) {
    final isMobile = MediaQuery.of(context).size.width < 750;

    if (payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.payments_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No payment records found', style: AppTextStyles.h3),
            const SizedBox(height: 4),
            Text('Try adjusting your search query or filters', style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
          ],
        ),
      );
    }

    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: payments.length,
        separatorBuilder: (c, i) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          final p = payments[idx];
          final parentSection = switch (p.paymentType) {
            PaymentType.customerPayment => ErpNavSection.customerPayments,
            PaymentType.dealerPayment => ErpNavSection.dealerPayments,
            PaymentType.vendorPayment => ErpNavSection.vendorPaymentsSection,
            PaymentType.commissionPayment => ErpNavSection.commissionPayments,
          };

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'payment', parentSection),
                      child: Text(
                        p.paymentNumber,
                        style: AppTextStyles.bodyBold.copyWith(
                          fontSize: 13,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Formatters.formatCurrency(p.amount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: (p.paymentType == PaymentType.customerPayment || p.paymentType == PaymentType.dealerPayment)
                                ? AppColors.successText
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          tooltip: 'Actions',
                          icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (val) {
                            if (val == 'view') {
                              ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'payment', parentSection);
                            } else if (val == 'whatsapp') {
                              final architect = db.architects.where((a) => a.id == p.partyId).firstOrNull;
                              WhatsAppQuickChatDialog.showArchitectQuickChat(
                                context,
                                architectName: architect?.name ?? p.partyName,
                                architectPhone: architect?.mobile ?? '',
                                firmName: architect?.companyName,
                                projectName: p.projectName,
                                commissionNumber: p.referenceDocumentNumber,
                              );
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF475569)),
                                  SizedBox(width: 8),
                                  Text('View Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'whatsapp',
                              child: Row(
                                children: [
                                  Icon(Icons.chat, size: 18, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('WhatsApp Chat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        p.partyName,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    p.isFullPayment ? ErpStatusBadge.success('FULL') : ErpStatusBadge.warning('PARTIAL'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(Formatters.formatDate(p.paymentDate), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                    ErpStatusBadge.neutral(p.paymentMode.toString().split('.').last.toUpperCase()),
                  ],
                ),
                if (p.referenceDocumentNumber != null && p.referenceDocumentNumber!.isNotEmpty && p.referenceDocumentNumber != '-') ...[
                  const SizedBox(height: 4),
                  Text('Ref Doc: ${p.referenceDocumentNumber}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
                if (p.transactionReference != null && p.transactionReference!.isNotEmpty && p.transactionReference != '-') ...[
                  const SizedBox(height: 2),
                  Text('UTR/Ref: ${p.transactionReference}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                ],
              ],
            ),
          );
        },
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
                key: const ValueKey('commission_payments_table'),
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: AppTextStyles.tableHeader,
                dataTextStyle: AppTextStyles.tableCell,
                dividerThickness: 1,
                horizontalMargin: 20,
                columnSpacing: 24,
                headingRowHeight: 46,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 60,
                columns: [
                  DataColumn(label: Text('PAYMENT NO', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                  DataColumn(label: Text('DATE', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                  DataColumn(label: Text('PARTY / BENEFICIARY', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                  DataColumn(label: Text('REFERENCE DOC', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                  DataColumn(label: Text('AMOUNT (₹)', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                  DataColumn(label: Text('SETTLEMENT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                  DataColumn(label: Text('REMAINING (₹)', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                  DataColumn(label: Text('PAYMENT MODE', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                  DataColumn(label: Text('UTR / REF NO', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_note, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('ACTIONS', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
                rows: payments.map((p) {
                  final parentSection = switch (p.paymentType) {
                    PaymentType.customerPayment => ErpNavSection.customerPayments,
                    PaymentType.dealerPayment => ErpNavSection.dealerPayments,
                    PaymentType.vendorPayment => ErpNavSection.vendorPaymentsSection,
                    PaymentType.commissionPayment => ErpNavSection.commissionPayments,
                  };

                  return DataRow(
                    cells: [
                      DataCell(
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
                      ),
                      DataCell(Text(Formatters.formatDate(p.paymentDate), style: AppTextStyles.bodySmall)),
                      DataCell(Text(p.partyName, style: AppTextStyles.bodyMedium)),
                      DataCell(Text(p.referenceDocumentNumber ?? '-', style: AppTextStyles.bodySmall)),
                      DataCell(
                        Text(
                          Formatters.formatCurrency(p.amount),
                          style: AppTextStyles.bodyBold.copyWith(
                            color: (p.paymentType == PaymentType.customerPayment || p.paymentType == PaymentType.dealerPayment)
                                ? AppColors.successText
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(p.isFullPayment ? ErpStatusBadge.success('FULL') : ErpStatusBadge.warning('PARTIAL')),
                      DataCell(
                        Text(
                          p.remainingAmount != null ? Formatters.formatCurrency(p.remainingAmount!) : '-',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: (p.remainingAmount ?? 0) > 0 ? AppColors.warningText : AppColors.successText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(ErpStatusBadge.neutral(p.paymentMode.toString().split('.').last.toUpperCase())),
                      DataCell(Text(p.transactionReference ?? '-', style: AppTextStyles.bodySmall)),
                      DataCell(
                        PopupMenuButton<String>(
                          tooltip: 'Actions',
                          icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (val) {
                            if (val == 'view') {
                              ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'payment', parentSection);
                            } else if (val == 'whatsapp') {
                              final architect = db.architects.where((a) => a.id == p.partyId).firstOrNull;
                              WhatsAppQuickChatDialog.showArchitectQuickChat(
                                context,
                                architectName: architect?.name ?? p.partyName,
                                architectPhone: architect?.mobile ?? '',
                                firmName: architect?.companyName,
                                projectName: p.projectName,
                                commissionNumber: p.referenceDocumentNumber,
                              );
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF475569)),
                                  SizedBox(width: 8),
                                  Text('View Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'whatsapp',
                              child: Row(
                                children: [
                                  Icon(Icons.chat, size: 18, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('WhatsApp Chat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
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
                          ErpToast.showWarning(context, 'Please select a payment mode.');
                          return;
                        }
                        final payAmt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
                        final discAmt = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
                        final total = payAmt + discAmt;

                        if (_transactionType != 'Discount Only' && payAmt <= 0) {
                          ErpToast.showWarning(context, 'Please enter a payment amount.');
                          return;
                        }

                        if (total <= 0) {
                          ErpToast.showWarning(context, 'Please enter a payment or discount amount.');
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
                        ErpToast.showSuccess(
                          context,
                          'Transaction ${payment.paymentNumber} added! Settled: ${Formatters.formatCurrency(total)}.',
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

