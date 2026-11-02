import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_toast.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/erp_confirm_dialog.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/figma_metric_card.dart';
import '../../../core/widgets/document_ocr_uploader.dart';
import '../../../shared/widgets/whatsapp_quick_chat_dialog.dart';
import 'dart:convert';
import '../../../core/storage/tab_session_storage.dart';
import '../../../core/storage/form_draft_service.dart';
import '../../../shared/providers/app_state_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';
  String _roleFilter = 'ALL';
  String _balanceFilter = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreFilters();
      ref.read(databaseServiceProvider).loadCustomers();
      ref.read(databaseServiceProvider).loadArchitects();
    });
  }

  void _persistFilters() {
    TabSessionStorage.setItem('erp_filter_customers', jsonEncode({
      'search': _searchQuery,
      'role': _roleFilter,
      'balance': _balanceFilter,
      'page': _currentPage,
    }));
  }

  Future<void> _restoreFilters() async {
    try {
      final raw = await TabSessionStorage.getItem('erp_filter_customers');
      if (raw != null && raw.isNotEmpty && mounted) {
        final data = jsonDecode(raw);
        setState(() {
          _searchQuery = data['search'] as String? ?? '';
          _roleFilter = data['role'] as String? ?? 'ALL';
          _balanceFilter = data['balance'] as String? ?? 'ALL';
          _currentPage = data['page'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  /// GST state code derived the same way the backend derives it when the
  /// customer master does not send an explicit code: prefer the GSTIN's
  /// leading state code, then the well-known state name. Prevents the
  /// model's Gujarat ('24') default from overriding an explicitly selected
  /// other state.
  String _deriveCustomerStateCode(String state, String gstNumber) {
    final gst = gstNumber.trim().toUpperCase();
    if (gst.length >= 2) return gst.substring(0, 2);
    final lower = state.trim().toLowerCase();
    if (lower == 'maharashtra') return '27';
    if (lower == 'gujarat') return '24';
    return '';
  }

  void _openAddEditCustomerDialog([Customer? existing]) async {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final draft = await FormDraftService.instance.loadFormDraft(
      module: 'masters',
      formId: 'customer_dialog',
      recordId: existing?.id,
      userId: ref.read(currentUserProvider)?.id,
    );

    final nameCtrl = TextEditingController(text: draft?['name'] as String? ?? existing?.name ?? '');
    final mobileCtrl = TextEditingController(text: draft?['mobile'] as String? ?? existing?.mobile ?? '');
    final emailCtrl = TextEditingController(text: draft?['email'] as String? ?? existing?.email ?? '');
    final gstCtrl = TextEditingController(text: draft?['gst'] as String? ?? existing?.gstNumber ?? '');
    final addressCtrl = TextEditingController(text: draft?['address'] as String? ?? existing?.address ?? '');
    final stateCtrl = TextEditingController(text: draft?['state'] as String? ?? (existing?.state.isNotEmpty ?? false ? existing!.state : 'Gujarat'));
    final pincodeCtrl = TextEditingController(text: draft?['pincode'] as String? ?? existing?.pincode ?? '');
    String? linkedArchitectId = (existing?.linkedArchitectId != null &&
            db.architects.any((a) => a.id == existing!.linkedArchitectId))
        ? existing!.linkedArchitectId
        : null;
    bool isAlsoArchitect = existing?.isAlsoArchitect ?? (existing?.linkedArchitectId != null);
    final formKey = GlobalKey<FormState>();

    void saveDialogDraft() {
      FormDraftService.instance.saveFormDraft(
        module: 'masters',
        formId: 'customer_dialog',
        recordId: existing?.id,
        userId: ref.read(currentUserProvider)?.id,
        data: {
          'name': nameCtrl.text,
          'mobile': mobileCtrl.text,
          'email': emailCtrl.text,
          'gst': gstCtrl.text,
          'address': addressCtrl.text,
          'state': stateCtrl.text,
          'pincode': pincodeCtrl.text,
        },
      );
    }

    nameCtrl.addListener(saveDialogDraft);
    mobileCtrl.addListener(saveDialogDraft);
    emailCtrl.addListener(saveDialogDraft);
    gstCtrl.addListener(saveDialogDraft);
    addressCtrl.addListener(saveDialogDraft);
    stateCtrl.addListener(saveDialogDraft);
    pincodeCtrl.addListener(saveDialogDraft);

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
                  Text(isEdit ? 'Edit Customer' : 'Add Customer Master', style: AppTextStyles.h2),
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
                                mobileCtrl.text = data['Mobile'] ?? mobileCtrl.text;
                                emailCtrl.text = data['Email'] ?? emailCtrl.text;
                                addressCtrl.text = data['Address'] ?? addressCtrl.text;
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
                          validator: (v) => Validators.requiredField(v, 'Customer name required'),
                          decoration: const InputDecoration(
                            labelText: 'Customer Name / Estate *',
                            hintText: 'E.g., Oberoi Sky City Residences',
                          ),
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
                                validator: Validators.requiredEmailAddress,
                                keyboardType: TextInputType.emailAddress,
                                maxLength: Validators.emailMaxLength,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(labelText: 'Email Address *', counterText: ''),
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
                          controller: addressCtrl,
                          maxLines: 2,
                          validator: (v) => Validators.requiredField(v, 'Site / Billing Address required'),
                          decoration: const InputDecoration(labelText: 'Site / Billing Address *'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: stateCtrl,
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
                                validator: (v) => Validators.pincode(v),
                                decoration: const InputDecoration(
                                  labelText: 'PIN Code *',
                                  hintText: 'E.g., 382481',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Dual Entity: Architect-Customer Linking
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: isAlsoArchitect,
                                    activeColor: Colors.purple,
                                    onChanged: isSubmitting ? null : (val) {
                                      setDlgState(() {
                                        isAlsoArchitect = val ?? false;
                                        if (!isAlsoArchitect) linkedArchitectId = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Dual Entity: Is Also an Architect / Specifier?',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple)),
                                        Text('Link this customer to an Architect profile for unified commission and project billing',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isAlsoArchitect) ...[
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String?>(
                                  initialValue: linkedArchitectId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Linked Architect Profile',
                                    hintText: 'Choose existing architect or auto-create',
                                  ),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('(Auto-create / sync with Architect Master)')),
                                    ...db.architects.where((a) => !a.isDeleted).map((a) => DropdownMenuItem(
                                          value: a.id,
                                          child: Text('${a.name} (${a.companyName.isNotEmpty ? a.companyName : "Independent"})'),
                                        )),
                                  ],
                                  onChanged: isSubmitting ? null : (val) => setDlgState(() => linkedArchitectId = val),
                                ),
                              ],
                            ],
                          ),
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
                  text: isEdit ? 'Update Customer' : 'Save Customer',
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

                          final custId = isEdit ? existing.id : IdGenerator.generateId('CUST');
                          final customer = Customer(
                            id: custId,
                            name: nameCtrl.text.trim(),
                            mobile: mobileCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            gstNumber: gstCtrl.text.trim(),
                            address: addressCtrl.text.trim(),
                            state: stateCtrl.text.trim(),
                            pincode: pincodeCtrl.text.trim(),
                            stateCode: _deriveCustomerStateCode(stateCtrl.text.trim(), gstCtrl.text.trim()),
                            outstandingAmount: existing?.outstandingAmount ?? 0.0,
                            isAlsoArchitect: isAlsoArchitect,
                            linkedArchitectId: linkedArchitectId,
                            createdAt: existing?.createdAt ?? DateTime.now(),
                          );

                          try {
                            Customer saved;
                            if (isEdit) {
                              saved = await db.updateCustomerAsync(customer);
                            } else {
                              saved = await db.addCustomerAsync(customer);
                            }

                            // Bi-directional link sync
                            if (isAlsoArchitect && linkedArchitectId != null) {
                              await db.linkArchitectAndCustomerAsync(architectId: linkedArchitectId!, customerId: saved.id);
                            }

                            await FormDraftService.instance.clearFormDraft(
                              module: 'masters',
                              formId: 'customer_dialog',
                              recordId: existing?.id,
                              userId: ref.read(currentUserProvider)?.id,
                            );

                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ErpToast.showSuccess(context, 'Customer "${customer.name}" ${isEdit ? "updated" : "saved"} successfully!');
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

  void _confirmToggleStatus(Customer customer) {
    final willActivate = !customer.isActive;
    showErpStatusConfirmDialog(
      context: context,
      title: willActivate ? 'Activate Customer' : 'Deactivate Customer',
      message: willActivate
          ? 'Activate "${customer.name}"? It will immediately become available in all transaction dropdowns and lookups.'
          : 'Are you sure you want to deactivate "${customer.name}"? This entity will no longer appear in transaction dropdowns for new Sales, Purchases, or Production orders. Historical records will remain intact.',
      itemName: customer.name,
      willActivate: willActivate,
      confirmLabel: willActivate ? 'Activate' : 'Deactivate',
      onConfirm: () async {
        final db = ref.read(databaseServiceProvider);
        try {
          await db.toggleCustomerStatusAsync(customer.id, willActivate);
          if (mounted) {
            ErpToast.showSuccess(
              context,
              'Customer "${customer.name}" ${willActivate ? "activated" : "deactivated"} successfully',
            );
          }
        } catch (e) {
          if (mounted) {
            ErpToast.showError(
              context,
              'Status update failed: ${e.toString().replaceFirst("Exception: ", "")}',
            );
          }
        }
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
                hintText: 'Search customer by name, mobile, GST...',
                initialValue: _searchQuery,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                    _currentPage = 0;
                  });
                  _persistFilters();
                },
              ),
              const SizedBox(height: 10),
              ErpFilterDropdown<String>(
                value: _roleFilter,
                width: double.infinity,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Customer Types')),
                  DropdownMenuItem(value: 'DIRECT', child: Text('Direct Clients Only')),
                  DropdownMenuItem(value: 'ARCHITECT', child: Text('Architect Linked / Dual')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _roleFilter = val;
                      _currentPage = 0;
                    });
                    _persistFilters();
                  }
                },
              ),
              const SizedBox(height: 10),
              ErpFilterDropdown<String>(
                value: _balanceFilter,
                width: double.infinity,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Balances')),
                  DropdownMenuItem(value: 'WITH_BALANCE', child: Text('Has Outstanding')),
                  DropdownMenuItem(value: 'ZERO_BALANCE', child: Text('Zero Balance')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _balanceFilter = val;
                      _currentPage = 0;
                    });
                    _persistFilters();
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
                hintText: 'Search customer by name, mobile, GST...',
                initialValue: _searchQuery,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                    _currentPage = 0;
                  });
                  _persistFilters();
                },
              ),
            ),
            ErpFilterDropdown<String>(
              value: _roleFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Customer Types')),
                DropdownMenuItem(value: 'DIRECT', child: Text('Direct Clients Only')),
                DropdownMenuItem(value: 'ARCHITECT', child: Text('Architect Linked / Dual')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _roleFilter = val;
                    _currentPage = 0;
                  });
                  _persistFilters();
                }
              },
            ),
            ErpFilterDropdown<String>(
              value: _balanceFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Balances')),
                DropdownMenuItem(value: 'WITH_BALANCE', child: Text('Has Outstanding')),
                DropdownMenuItem(value: 'ZERO_BALANCE', child: Text('Zero Balance')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _balanceFilter = val;
                    _currentPage = 0;
                  });
                  _persistFilters();
                }
              },
            ),
            ErpDateFilterBox(
              startDate: _startDate,
              endDate: _endDate,
              onDateRangeSelected: (start, end) {
                setState(() {
                  _startDate = start;
                  _endDate = end;
                  _currentPage = 0;
                });
                _persistFilters();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final customers = db.customers.where((c) {
      if (c.isDeleted) return false;
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matches = c.name.toLowerCase().contains(query) ||
            c.mobile.toLowerCase().contains(query) ||
            c.email.toLowerCase().contains(query) ||
            c.gstNumber.toLowerCase().contains(query) ||
            c.address.toLowerCase().contains(query) ||
            c.state.toLowerCase().contains(query) ||
            c.pincode.toLowerCase().contains(query);
        if (!matches) return false;
      }
      if (_roleFilter == 'DIRECT' && (c.isAlsoArchitect || c.linkedArchitectId != null)) return false;
      if (_roleFilter == 'ARCHITECT' && (!c.isAlsoArchitect && c.linkedArchitectId == null)) return false;
      if (_balanceFilter == 'WITH_BALANCE' && c.outstandingAmount <= 0) return false;
      if (_balanceFilter == 'ZERO_BALANCE' && c.outstandingAmount > 0) return false;
      if (_startDate != null && c.createdAt.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) return false;
      if (_endDate != null && c.createdAt.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) return false;
      return true;
    }).toList();

    final totalRecords = customers.length;
    final safePageSize = _pageSize <= 0 ? 25 : _pageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = _currentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);
    final pagedCustomers = totalRecords == 0 ? <Customer>[] : customers.sublist(startIndex, endIndex);

    final totalCustomersCount = db.customers.where((c) => !c.isDeleted).length;
    final directClientsCount = db.customers.where((c) => !c.isDeleted && !c.isAlsoArchitect && c.linkedArchitectId == null).length;
    final archLinkedCount = db.customers.where((c) => !c.isDeleted && (c.isAlsoArchitect || c.linkedArchitectId != null)).length;
    final withBalanceCount = db.customers.where((c) => !c.isDeleted && c.outstandingAmount > 0).length;
    final totalOutstanding = db.customers.where((c) => !c.isDeleted).fold(0.0, (sum, c) => sum + c.outstandingAmount);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.people_outline,
            title: 'Customers Master',
            badgeText: 'CLIENT DIRECTORY',
            action: ErpButton(
              text: 'Add Customer',
              icon: Icons.add,
              onPressed: () => _openAddEditCustomerDialog(),
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
                      icon: Icons.people_outline,
                      iconColor: AppColors.primary,
                      title: 'Total Customers',
                      value: '${totalCustomersCount}',
                      subtext: 'All Clients',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.person_outline,
                      iconColor: AppColors.success,
                      title: 'Direct Clients',
                      value: '${directClientsCount}',
                      subtext: 'Direct Accounts',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.architecture_outlined,
                      iconColor: AppColors.categoryPurple,
                      title: 'Architect-Linked',
                      value: '${archLinkedCount}',
                      subtext: 'Partner Accounts',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: withBalanceCount > 0 ? AppColors.danger : AppColors.success,
                      title: 'With Balance',
                      value: '$withBalanceCount',
                      subtext: withBalanceCount > 0 ? '$withBalanceCount of $totalCustomersCount with balance' : 'Zero balance pending',
                      subtextColor: withBalanceCount > 0 ? AppColors.danger : AppColors.success,
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
              ErpColumn(title: 'Customer Name'),
              ErpColumn(title: 'Type / Dual Role'),
              ErpColumn(title: 'State'),
              ErpColumn(title: 'Mobile Phone'),
              ErpColumn(title: 'Email Address'),
              ErpColumn(title: 'GST Number'),
              ErpColumn(title: 'Site / Billing Address', width: 220),
              ErpColumn(title: 'Outstanding Balance', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Actions'),
            ],
            rows: pagedCustomers.map((c) {
              final linkedArch = c.linkedArchitectId != null
                  ? db.architects.where((a) => a.id == c.linkedArchitectId).firstOrNull
                  : null;

              return [
                // 1. Customer Name (Clickable -> Customer Detail Page)
                InkWell(
                  onTap: () {
                    ref.read(activeRecordDetailsStackProvider.notifier).push(c.id, 'customer', ErpNavSection.customers);
                  },
                  child: Text(
                    c.name,
                    style: AppTextStyles.bodyBold.copyWith(
                      fontSize: 13,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                // 2. Client Role / Linked Architect (Clickable -> Architect Detail Page if linked)
                linkedArch != null
                    ? InkWell(
                        onTap: () {
                          ref.read(activeRecordDetailsStackProvider.notifier).push(linkedArch.id, 'architect', ErpNavSection.architects);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD8B4FE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.link, size: 12, color: Color(0xFF7E22CE)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Arch: ${linkedArch.name}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7E22CE),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : (c.isAlsoArchitect
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFD8B4FE)),
                            ),
                            child: const Text(
                              'ARCH-CUSTOMER',
                              style: TextStyle(fontSize: 11, color: Color(0xFF7E22CE), fontWeight: FontWeight.w600),
                            ),
                          )
                        : const Text('Direct Client', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                Text(c.state.isNotEmpty ? c.state : '-', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                Text(c.mobile, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
                Text(c.email, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                Text(c.gstNumber.isNotEmpty ? c.gstNumber : '-', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
                  child: Text(
                    c.address.isNotEmpty ? c.address : '-',
                    softWrap: true,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                  ),
                ),
                Text(
                  Formatters.formatCurrency(c.outstandingAmount),
                  style: AppTextStyles.bodyBold.copyWith(
                    fontSize: 13,
                    color: c.outstandingAmount > 0 ? AppColors.danger : const Color(0xFF1E293B),
                  ),
                ),
                c.isActive ? ErpStatusBadge.active() : ErpStatusBadge.inactive(),
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (action) {
                    switch (action) {
                      case 'view':
                        ref.read(activeRecordDetailsStackProvider.notifier).push(c.id, 'customer', ErpNavSection.customers);
                        break;
                      case 'whatsapp':
                        WhatsAppQuickChatDialog.showCustomerQuickChat(
                          context,
                          customerName: c.name,
                          customerPhone: c.mobile,
                        );
                        break;
                      case 'edit':
                        if (!c.isDeleted && c.isActive) {
                          _openAddEditCustomerDialog(c);
                        } else if (!c.isActive) {
                          ErpToast.showWarning(context, 'Cannot edit an inactive record. Activate it first.');
                        }
                        break;
                      case 'toggle_status':
                        _confirmToggleStatus(c);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('View Customer Details'),
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
                      enabled: !c.isDeleted && c.isActive,
                      child: Tooltip(
                        message: (!c.isActive)
                            ? 'Cannot edit an inactive record. Activate it first.'
                            : 'Edit Customer',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: (!c.isActive || c.isDeleted) ? AppColors.textSecondary.withValues(alpha: 0.5) : AppColors.textPrimary),
                            const SizedBox(width: 8),
                            Text('Edit Customer', style: TextStyle(color: (!c.isActive || c.isDeleted) ? AppColors.textSecondary.withValues(alpha: 0.5) : null)),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(
                            c.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                            size: 18,
                            color: c.isActive ? AppColors.warning : AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            c.isActive ? 'Deactivate Customer' : 'Activate Customer',
                            style: TextStyle(
                              color: c.isActive ? AppColors.warning : AppColors.success,
                            ),
                          ),
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
                  onPageChanged: (newPage) {
                    setState(() => _currentPage = newPage);
                    _persistFilters();
                  },
                  onPageSizeChanged: (newSize) {
                    setState(() {
                      _pageSize = newSize;
                      _currentPage = 0;
                    });
                    _persistFilters();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
