import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/dealer_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_toast.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/erp_confirm_dialog.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/figma_metric_card.dart';
import '../../../core/widgets/document_ocr_uploader.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/widgets/whatsapp_quick_chat_dialog.dart';

class DealersScreen extends ConsumerStatefulWidget {
  const DealersScreen({super.key});

  @override
  ConsumerState<DealersScreen> createState() => _DealersScreenState();
}

class _DealersScreenState extends ConsumerState<DealersScreen> {
  String _searchQuery = '';
  String _balanceFilter = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadDealers();
    });
  }

  void _openAddEditDealerDialog([Dealer? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final compCtrl = TextEditingController(text: existing?.companyName ?? '');
    final contactCtrl = TextEditingController(text: existing?.contactPerson ?? '');
    final mobileCtrl = TextEditingController(text: existing?.mobile ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final gstCtrl = TextEditingController(text: existing?.gstNumber ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final stateCtrl = TextEditingController(text: existing?.state ?? '');
    final pincodeCtrl = TextEditingController(text: existing?.pincode ?? '');
    final formKey = GlobalKey<FormState>();

    bool isSubmitting = false;
    String? serverError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dlgCtx, setDlgState) {
            return AlertDialog(
              title: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(isEdit ? 'Edit Dealer' : 'Add Dealer Master', style: AppTextStyles.h2),
                  ErpButton(
                    text: 'Scan & Upload (OCR)',
                    icon: Icons.document_scanner_outlined,
                    isOutlined: true,
                    onPressed: isSubmitting ? null : () {
                      showDialog(
                        context: context,
                        builder: (ocrCtx) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
                            width: double.infinity,
                            height: MediaQuery.of(context).size.height * 0.88,
                            child: DocumentOcrUploader(
                              docType: OcrDocType.customerDoc,
                              onCancel: () => Navigator.of(ocrCtx).pop(),
                              onConfirm: (data) {
                                nameCtrl.text = data['Customer Name'] ?? data['Company Name'] ?? nameCtrl.text;
                                compCtrl.text = data['Company Name'] ?? compCtrl.text;
                                contactCtrl.text = data['Contact Person'] ?? contactCtrl.text;
                                mobileCtrl.text = data['Mobile'] ?? mobileCtrl.text;
                                emailCtrl.text = data['Email'] ?? emailCtrl.text;
                                addrCtrl.text = data['Address'] ?? addrCtrl.text;
                                if (data.containsKey('State')) stateCtrl.text = data['State']!;
                                if (data.containsKey('Pincode')) pincodeCtrl.text = data['Pincode']!;
                                Navigator.of(ocrCtx).pop();
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 540),
                width: double.infinity,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (serverError != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(serverError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        TextFormField(
                          controller: nameCtrl,
                          validator: (v) => Validators.requiredField(v, 'Dealer trading name required'),
                          decoration: const InputDecoration(labelText: 'Dealer Trading Name *', hintText: 'E.g., Luxe Lightings & Decor Studio'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: compCtrl,
                                decoration: const InputDecoration(labelText: 'Registered Entity Name'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: contactCtrl,
                                validator: (v) => Validators.requiredField(v, 'Contact person required'),
                                decoration: const InputDecoration(labelText: 'Contact Person *'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: mobileCtrl,
                                validator: Validators.mobile,
                                decoration: const InputDecoration(labelText: 'Mobile Number *'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: emailCtrl,
                                validator: Validators.email,
                                decoration: const InputDecoration(labelText: 'Email Address *'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: gstCtrl,
                          validator: (v) => Validators.gst(v, false),
                          decoration: const InputDecoration(
                            labelText: 'GST Number (Optional, 15 chars)',
                            hintText: '24AAAAA0000A1Z5',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addrCtrl,
                          maxLines: 2,
                          validator: (v) => Validators.requiredField(v, 'Showroom / Business address required'),
                          decoration: const InputDecoration(labelText: 'Showroom / Business Address *'),
                        ),
                        const SizedBox(height: 12),
                       
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: stateCtrl,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'State is required';
                                  }
                                  return null;
                                },
                                decoration: const InputDecoration(
                                  labelText: 'State *',
                                  hintText: 'E.g., Gujarat',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: pincodeCtrl,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'PIN Code is required';
                                  }

                                  if (!RegExp(r'^[1-9][0-9]{5}$')
                                      .hasMatch(value.trim())) {
                                    return 'Enter a valid 6-digit PIN Code';
                                  }

                                  return null;
                                },
                                decoration: const InputDecoration(
                                  labelText: 'PIN Code *',
                                  hintText: 'E.g., 382481',
                                ),
                              ),
                            ),
                          ],
                        ),

                        ],
                      ),
                    ),
                  ),
                ),
              actions: [
                ErpButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: isEdit ? 'Update Dealer' : 'Save Dealer',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            ErpToast.showError(ctx, 'Please fill in all required fields marked with *');
                            return;
                          }
                          setDlgState(() {
                            isSubmitting = true;
                            serverError = null;
                          });

                          try {
                            if (isEdit) {
                              await db.updateDealerAsync(existing.copyWith(
                                name: nameCtrl.text.trim(),
                                companyName: compCtrl.text.trim(),
                                contactPerson: contactCtrl.text.trim(),
                                mobile: mobileCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                gstNumber: gstCtrl.text.trim(),
                                address: addrCtrl.text.trim(),
                                state: stateCtrl.text.trim(),
                                pincode: pincodeCtrl.text.trim(),
                              ));
                            } else {
                              final newDealer = Dealer(
                                id: IdGenerator.generateId('DLR'),
                                name: nameCtrl.text.trim(),
                                companyName: compCtrl.text.trim(),
                                contactPerson: contactCtrl.text.trim(),
                                mobile: mobileCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                gstNumber: gstCtrl.text.trim(),
                                address: addrCtrl.text.trim(),
                                state: stateCtrl.text.trim(),
                                pincode: pincodeCtrl.text.trim(),
                                outstandingAmount: 0.0,
                                createdAt: DateTime.now(),
                              );
                              await db.addDealerAsync(newDealer);
                            }

                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ErpToast.showSuccess(context, 'Dealer "${nameCtrl.text.trim()}" ${isEdit ? "updated" : "saved"} successfully!');
                            }
                          } catch (e) {
                            setDlgState(() {
                              serverError = e.toString().replaceFirst('Exception: ', '');
                              isSubmitting = false;
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteDealer(Dealer dealer) {
    showDialog(
      context: context,
      builder: (ctx) {
        return ErpConfirmDeleteDialog(
          title: 'Delete Dealer Record',
          message: 'Are you sure you want to deactivate and archive this dealer? A mandatory audit reason is required.',
          itemName: '${dealer.name} (${dealer.id})',
          requireReason: true,
          onConfirm: (reason) async {
            final db = ref.read(databaseServiceProvider);
            try {
              await db.deleteDealerAsync(dealerId: dealer.id, reason: reason);
              if (mounted) {
                ErpToast.showSuccess(context, 'Dealer "${dealer.name}" archived with audit reason: $reason');
              }
            } catch (e) {
              if (mounted) {
                ErpToast.showError(context, 'Delete failed: ${e.toString().replaceFirst("Exception: ", "")}');
              }
            }
          },
        );
      },
    );
  }

  Widget _buildControlsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 450;
        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ErpSearchInput(
                hintText: 'Search dealer by name, showroom, GST...',
                initialValue: _searchQuery,
                onChanged: (val) => setState(() {
                  _searchQuery = val;
                  _currentPage = 0;
                }),
              ),
              const SizedBox(height: 10),
              ErpFilterDropdown<String>(
                value: _balanceFilter,
                width: double.infinity,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Balances')),
                  DropdownMenuItem(value: 'WITH_BALANCE', child: Text('Has Receivables / Balance')),
                  DropdownMenuItem(value: 'ZERO_BALANCE', child: Text('Zero Balance / Settled')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _balanceFilter = val;
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
              width: 280,
              child: ErpSearchInput(
                hintText: 'Search dealer by name, showroom, GST...',
                initialValue: _searchQuery,
                onChanged: (val) => setState(() {
                  _searchQuery = val;
                  _currentPage = 0;
                }),
              ),
            ),
            ErpFilterDropdown<String>(
              value: _balanceFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Balances')),
                DropdownMenuItem(value: 'WITH_BALANCE', child: Text('Has Receivables / Balance')),
                DropdownMenuItem(value: 'ZERO_BALANCE', child: Text('Zero Balance / Settled')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _balanceFilter = val;
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final dealers = db.dealers.where((d) {
      if (d.isDeleted) return false;
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matches = d.name.toLowerCase().contains(query) ||
            d.contactPerson.toLowerCase().contains(query) ||
            d.companyName.toLowerCase().contains(query) ||
            d.mobile.toLowerCase().contains(query) ||
            d.email.toLowerCase().contains(query) ||
            d.gstNumber.toLowerCase().contains(query) ||
            d.address.toLowerCase().contains(query) ||
            d.state.toLowerCase().contains(query) ||
            d.pincode.toLowerCase().contains(query);
        if (!matches) return false;
      }
      if (_balanceFilter == 'WITH_BALANCE' && d.outstandingAmount <= 0) return false;
      if (_balanceFilter == 'ZERO_BALANCE' && d.outstandingAmount > 0) return false;
      if (_startDate != null && d.createdAt.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) return false;
      if (_endDate != null && d.createdAt.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) return false;
      return true;
    }).toList();

    final totalRecords = dealers.length;
    final safePageSize = _pageSize <= 0 ? 25 : _pageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = _currentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);
    final pagedDealers = totalRecords == 0 ? <Dealer>[] : dealers.sublist(startIndex, endIndex);

    final totalDealersCount = db.dealers.where((d) => !d.isDeleted).length;
    final withBalanceCount = db.dealers.where((d) => !d.isDeleted && d.outstandingAmount > 0).length;
    final zeroBalanceCount = db.dealers.where((d) => !d.isDeleted && d.outstandingAmount <= 0).length;
    final totalOutstanding = db.dealers.where((d) => !d.isDeleted).fold(0.0, (sum, d) => sum + d.outstandingAmount);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.store_mall_directory_outlined,
            title: 'Dealers & Franchise Network',
            badgeText: 'DISTRIBUTION NETWORK',
            action: ErpButton(
              text: 'Add Dealer',
              icon: Icons.add,
              onPressed: () => _openAddEditDealerDialog(),
            ),
          ),
          const SizedBox(height: 18),

          // 5 Summary Metric Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 850
                  ? (constraints.maxWidth - (4 * 12)) / 5
                  : (constraints.maxWidth > 550 ? (constraints.maxWidth - 12) / 2 : double.infinity);
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.store_outlined,
                      iconColor: AppColors.primary,
                      title: 'Total Dealers',
                      value: '${totalDealersCount}',
                      subtext: 'Network Partners',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.storefront_outlined,
                      iconColor: AppColors.success,
                      title: 'Showrooms',
                      value: '${totalDealersCount}',
                      subtext: 'Operational',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: withBalanceCount > 0 ? AppColors.danger : AppColors.success,
                      title: 'With Balance',
                      value: '$withBalanceCount',
                      subtext: withBalanceCount > 0 ? '$withBalanceCount of $totalDealersCount with balance' : 'Zero balance pending',
                      subtextColor: withBalanceCount > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.verified_outlined,
                      iconColor: AppColors.categoryTeal,
                      title: 'Zero Balance',
                      value: '${zeroBalanceCount}',
                      subtext: 'Fully Cleared',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.currency_rupee,
                      iconColor: AppColors.categoryGold,
                      title: 'Total Outstanding',
                      value: Formatters.formatCurrency(totalOutstanding),
                      subtext: 'Total Receivables',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(16),
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
                _buildControlsRow(),
                const SizedBox(height: 16),
                ErpDataTable(
            columns: const [
              ErpColumn(title: 'Showroom / Dealer Name'),
              ErpColumn(title: 'Company Entity'),
              ErpColumn(title: 'Contact Person'),
              ErpColumn(title: 'State'),
              ErpColumn(title: 'Mobile / Email'),
              ErpColumn(title: 'GST Number'),
              ErpColumn(title: 'Outstanding Balance', isNumeric: true),
              ErpColumn(title: 'Actions'),
            ],
            rows: pagedDealers.map((d) {
              return [
                InkWell(
                  onTap: () {
                    ref.read(activeRecordDetailsStackProvider.notifier).push(d.id, 'dealer', ErpNavSection.dealers);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        d.name,
                        style: AppTextStyles.bodyBold.copyWith(
                          fontSize: 13,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      if (d.address.isNotEmpty || d.state.isNotEmpty || d.pincode.isNotEmpty)
                        Text(
                          [
                            if (d.address.isNotEmpty) d.address,
                            if (d.state.isNotEmpty) d.state,
                            if (d.pincode.isNotEmpty) d.pincode,
                          ].join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
                Text(d.companyName, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                Text(d.contactPerson, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                Text(d.state.isNotEmpty ? d.state : '-', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d.mobile, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
                    if (d.email.isNotEmpty)
                      Text(d.email, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                Text(d.gstNumber.isNotEmpty ? d.gstNumber : '-', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                Text(
                  Formatters.formatCurrency(d.outstandingAmount),
                  style: AppTextStyles.bodyBold.copyWith(
                    fontSize: 13,
                    color: d.outstandingAmount > 0 ? AppColors.danger : const Color(0xFF1E293B),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (action) {
                    switch (action) {
                      case 'view':
                        ref.read(activeRecordDetailsStackProvider.notifier).push(d.id, 'dealer', ErpNavSection.dealers);
                        break;
                      case 'whatsapp':
                        WhatsAppQuickChatDialog.showCustomerQuickChat(
                          context,
                          customerName: d.name,
                          customerPhone: d.mobile,
                        );
                        break;
                      case 'edit':
                        _openAddEditDealerDialog(d);
                        break;
                      case 'delete':
                        _confirmDeleteDealer(d);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('View Dealer Profile'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'whatsapp',
                      child: Row(
                        children: [
                          Icon(Icons.chat, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('WhatsApp Chat'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Dealer'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                          SizedBox(width: 8),
                          Text('Delete Dealer', style: TextStyle(color: AppColors.danger)),
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
        ],
      ),
    );
  }
}
