import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/architect_model.dart';
import '../../../core/models/commission_model.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/erp_confirm_dialog.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/figma_metric_card.dart';
import '../../../core/widgets/document_ocr_uploader.dart';
import '../../../shared/widgets/whatsapp_quick_chat_dialog.dart';
import '../../../shared/providers/app_state_providers.dart';

class ArchitectsScreen extends ConsumerStatefulWidget {
  const ArchitectsScreen({super.key});

  @override
  ConsumerState<ArchitectsScreen> createState() => _ArchitectsScreenState();
}

class _ArchitectsScreenState extends ConsumerState<ArchitectsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _archSearchQuery = '';
  String _archCustomerFilter = 'ALL';
  DateTime? _archStartDate;
  DateTime? _archEndDate;
  int _archCurrentPage = 0;
  int _archPageSize = 25;

  String _commSearchQuery = '';
  String _commStatusFilter = 'ALL';
  DateTime? _commStartDate;
  DateTime? _commEndDate;
  int _commCurrentPage = 0;
  int _commPageSize = 25;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadArchitects();
      ref.read(databaseServiceProvider).loadCustomers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddEditArchitectDialog([Architect? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final compCtrl = TextEditingController(text: existing?.companyName ?? '');
    final mobileCtrl = TextEditingController(text: existing?.mobile ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final gstCtrl = TextEditingController(text: existing?.gstNumber ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final stateCtrl = TextEditingController(text: (existing?.state.isNotEmpty ?? false) ? existing!.state : 'Gujarat');
    final pincodeCtrl = TextEditingController(text: existing?.pincode ?? '');
    final rateCtrl = TextEditingController(text: existing?.defaultCommissionRate.toString() ?? '5.0');
    String? linkedCustomerId = (existing?.linkedCustomerId != null &&
            db.customers.any((c) => c.id == existing!.linkedCustomerId))
        ? existing!.linkedCustomerId
        : null;
    bool isAlsoCustomer = existing?.isAlsoCustomer ?? (existing?.linkedCustomerId != null);
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
                  Text(isEdit ? 'Edit Architect' : 'Add Architect Master', style: AppTextStyles.h2),
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
                              docType: OcrDocType.architectDoc,
                              onCancel: () => Navigator.of(ocrCtx).pop(),
                              onConfirm: (data) {
                                nameCtrl.text = data['Architect Name'] ?? data['Firm Name'] ?? nameCtrl.text;
                                compCtrl.text = data['Firm Name'] ?? compCtrl.text;
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
                          validator: (v) => Validators.requiredField(v, 'Architect name required'),
                          decoration: const InputDecoration(
                            labelText: 'Architect Name *',
                            hintText: 'E.g., Ar. Sanjay Puri',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: compCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Studio / Company Name *',
                            hintText: 'E.g., Sanjay Puri Architects',
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
                                validator: Validators.email,
                                decoration: const InputDecoration(labelText: 'Email Address'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: gstCtrl,
                                validator: (v) => Validators.gst(v, false),
                                decoration: const InputDecoration(
                                  labelText: 'GST Number (Optional, 15 chars)',
                                  hintText: '24AAAAA0000A1Z5',
                                  errorMaxLines: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: rateCtrl,
                                keyboardType: TextInputType.number,
                                validator: (v) => Validators.percentage(v, 'Must be between 0% and 100%'),
                                decoration: const InputDecoration(
                                  labelText: 'Default Commission Rate (%) *',
                                  errorMaxLines: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addrCtrl,
                          maxLines: 2,
                          validator: (v) => Validators.requiredField(v, 'Studio address required'),
                          decoration: const InputDecoration(labelText: 'Studio Address *'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: stateCtrl,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
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
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'PIN Code is required';
                                  }
                                  if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(v.trim())) {
                                    return 'Enter a valid 6-digit PIN Code';
                                  }
                                  return null;
                                },
                                decoration: const InputDecoration(
                                  labelText: 'PIN Code *',
                                  hintText: 'E.g., 395006',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Dual Entity: Architect as Customer
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
                                    value: isAlsoCustomer || linkedCustomerId != null,
                                    activeColor: Colors.purple,
                                    onChanged: isSubmitting ? null : (val) {
                                      setDlgState(() {
                                        isAlsoCustomer = val ?? false;
                                        if (!isAlsoCustomer) linkedCustomerId = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Architect-Customer Linkage (Dual Entity)',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple)),
                                        Text('Link this Architect with a Customer account for unified billing, quotations, and projects',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isAlsoCustomer || linkedCustomerId != null) ...[
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String?>(
                                  initialValue: linkedCustomerId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Architect-Customer Name (Customer Master)',
                                    hintText: 'Select existing Customer account',
                                  ),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('(Not Linked / Separate Entity)')),
                                    ...db.customers.where((c) => !c.isDeleted).map((c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text('${c.name} (${c.mobile})'),
                                        )),
                                  ],
                                  onChanged: isSubmitting ? null : (val) => setDlgState(() {
                                    linkedCustomerId = val;
                                    isAlsoCustomer = val != null;
                                  }),
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
                  text: isEdit ? 'Update Architect' : 'Save Architect',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDlgState(() {
                            isSubmitting = true;
                            serverError = null;
                          });

                          final rateVal = double.tryParse(rateCtrl.text.trim()) ?? 5.0;
                          final archId = isEdit ? existing.id : IdGenerator.generateId('ARCH');

                          final architect = Architect(
                            id: archId,
                            name: nameCtrl.text.trim(),
                            companyName: compCtrl.text.trim(),
                            mobile: mobileCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            gstNumber: gstCtrl.text.trim(),
                            address: addrCtrl.text.trim(),
                            state: stateCtrl.text.trim(),
                            pincode: pincodeCtrl.text.trim(),
                            defaultCommissionRate: rateVal,
                            isAlsoCustomer: isAlsoCustomer || linkedCustomerId != null,
                            linkedCustomerId: linkedCustomerId,
                            totalCommissionEarned: existing?.totalCommissionEarned ?? 0.0,
                            pendingCommission: existing?.pendingCommission ?? 0.0,
                            approvedCommission: existing?.approvedCommission ?? 0.0,
                            paidCommission: existing?.paidCommission ?? 0.0,
                            createdAt: existing?.createdAt ?? DateTime.now(),
                          );

                          try {
                            Architect saved;
                            if (isEdit) {
                              saved = await db.updateArchitectAsync(architect);
                            } else {
                              saved = await db.addArchitectAsync(architect);
                            }

                            // Bi-directional link sync
                            if (isAlsoCustomer && linkedCustomerId != null) {
                              await db.linkArchitectAndCustomerAsync(architectId: saved.id, customerId: linkedCustomerId!);
                            }

                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Architect "${architect.name}" ${isEdit ? "updated" : "saved"} successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
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

  void _confirmDeleteArchitect(Architect architect) {
    showDialog(
      context: context,
      builder: (ctx) {
        return ErpConfirmDeleteDialog(
          title: 'Delete Architect Record',
          message: 'Are you sure you want to deactivate and archive this architect? A mandatory audit reason is required.',
          itemName: '${architect.name} (${architect.id})',
          requireReason: true,
          onConfirm: (reason) async {
            final db = ref.read(databaseServiceProvider);
            try {
              await db.deleteArchitectAsync(architectId: architect.id, reason: reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Architect "${architect.name}" archived with audit reason: $reason'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Delete failed: ${e.toString().replaceFirst("Exception: ", "")}'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  void _openPayCommissionDialog(ArchitectCommission comm) {
    final refCtrl = TextEditingController();
    PaymentMode selectedMode = PaymentMode.bankTransfer;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Pay Commission', style: AppTextStyles.h2),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payout Details:', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                Text('Architect: ${comm.architectName}', style: AppTextStyles.bodyMedium),
                Text('Invoice: ${comm.saleInvoiceNumber} | Project: ${comm.projectName ?? "Direct"}', style: AppTextStyles.bodySmall),
                Text('Commission Amount: ${Formatters.formatCurrency(comm.commissionAmount)}', style: AppTextStyles.h2),
                const SizedBox(height: 16),
                DropdownButtonFormField<PaymentMode>(
                  initialValue: selectedMode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: PaymentMode.values.map((mode) {
                    return DropdownMenuItem(value: mode, child: Text(mode.toString().split('.').last.toUpperCase()));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) selectedMode = v;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: refCtrl,
                  decoration: const InputDecoration(labelText: 'Transaction Reference / UTR Number', hintText: 'E.g., NEFT-HDFC-992144'),
                ),
              ],
            ),
          ),
          actions: [
            ErpButton(
              text: 'Cancel',
              isOutlined: true,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ErpButton(
              text: 'Record Payout',
              onPressed: () async {
                final db = ref.read(databaseServiceProvider);
                final payRef = refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : 'COMM-PAY-${DateTime.now().millisecondsSinceEpoch}';
                try {
                  await db.disburseCommissionAsync(
                    commissionId: comm.id,
                    paymentMode: selectedMode,
                    transactionRef: payRef,
                  );
                } catch (e) {
                  db.payCommission(
                    commissionId: comm.id,
                    paymentMode: selectedMode,
                    ref: payRef,
                  );
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Commission Paid & Ledger Updated!'), backgroundColor: AppColors.success),
                  );
                }
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

    // Tab 1: Architects filtering & pagination
    final architects = db.architects.where((a) {
      if (a.isDeleted) return false;
      final query = _archSearchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matches = a.name.toLowerCase().contains(query) ||
            a.companyName.toLowerCase().contains(query) ||
            a.mobile.toLowerCase().contains(query) ||
            a.email.toLowerCase().contains(query) ||
            a.address.toLowerCase().contains(query) ||
            a.state.toLowerCase().contains(query) ||
            a.pincode.toLowerCase().contains(query);
        if (!matches) return false;
      }
      if (_archCustomerFilter == 'DUAL_CUSTOMER' && (!a.isAlsoCustomer && a.linkedCustomerId == null)) return false;
      if (_archCustomerFilter == 'INDEPENDENT' && (a.isAlsoCustomer || a.linkedCustomerId != null)) return false;
      if (_archStartDate != null && a.createdAt.isBefore(DateTime(_archStartDate!.year, _archStartDate!.month, _archStartDate!.day))) return false;
      if (_archEndDate != null && a.createdAt.isAfter(DateTime(_archEndDate!.year, _archEndDate!.month, _archEndDate!.day, 23, 59, 59))) return false;
      return true;
    }).toList();

    final archTotalRecords = architects.length;
    final archSafePageSize = _archPageSize <= 0 ? 25 : _archPageSize;
    final archTotalPages = (archTotalRecords <= 0) ? 1 : (archTotalRecords / archSafePageSize).ceil();
    final archMaxPage = archTotalPages > 0 ? archTotalPages - 1 : 0;
    final archSafeCurrentPage = _archCurrentPage.clamp(0, archMaxPage);
    final archStartIndex = archSafeCurrentPage * archSafePageSize;
    final archEndIndex = (archStartIndex + archSafePageSize).clamp(0, archTotalRecords);
    final pagedArchitects = archTotalRecords == 0 ? <Architect>[] : architects.sublist(archStartIndex, archEndIndex);

    // Tab 2: Commissions filtering & pagination
    final commissions = db.commissions.where((comm) {
      final query = _commSearchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matches = comm.commissionNumber.toLowerCase().contains(query) ||
            comm.architectName.toLowerCase().contains(query) ||
            comm.saleInvoiceNumber.toLowerCase().contains(query) ||
            (comm.projectName != null && comm.projectName!.toLowerCase().contains(query));
        if (!matches) return false;
      }
      if (_commStatusFilter == 'PENDING' && comm.status != CommissionStatus.generated) return false;
      if (_commStatusFilter == 'APPROVED' && comm.status != CommissionStatus.approved) return false;
      if (_commStatusFilter == 'PAID' && comm.status != CommissionStatus.paid) return false;
      if (_commStatusFilter == 'REJECTED' && comm.status != CommissionStatus.rejected) return false;
      if (_commStartDate != null && comm.generatedDate.isBefore(DateTime(_commStartDate!.year, _commStartDate!.month, _commStartDate!.day))) return false;
      if (_commEndDate != null && comm.generatedDate.isAfter(DateTime(_commEndDate!.year, _commEndDate!.month, _commEndDate!.day, 23, 59, 59))) return false;
      return true;
    }).toList();

    final commTotalRecords = commissions.length;
    final commSafePageSize = _commPageSize <= 0 ? 25 : _commPageSize;
    final commTotalPages = (commTotalRecords <= 0) ? 1 : (commTotalRecords / commSafePageSize).ceil();
    final commMaxPage = commTotalPages > 0 ? commTotalPages - 1 : 0;
    final commSafeCurrentPage = _commCurrentPage.clamp(0, commMaxPage);
    final commStartIndex = commSafeCurrentPage * commSafePageSize;
    final commEndIndex = (commStartIndex + commSafePageSize).clamp(0, commTotalRecords);
    final pagedCommissions = commTotalRecords == 0 ? <ArchitectCommission>[] : commissions.sublist(commStartIndex, commEndIndex);

    final totalArchitectsCount = db.architects.where((a) => !a.isDeleted).length;
    final dualCustomerCount = db.architects.where((a) => !a.isDeleted && (a.isAlsoCustomer || a.linkedCustomerId != null)).length;
    final independentCount = db.architects.where((a) => !a.isDeleted && !a.isAlsoCustomer && a.linkedCustomerId == null).length;
    final unpaidCommissions = db.commissions.where((c) => c.status != CommissionStatus.paid && c.status != CommissionStatus.rejected).length;
    final totalCommissionPaid = db.commissions.where((c) => c.status == CommissionStatus.paid).fold(0.0, (sum, c) => sum + c.commissionAmount);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.architecture_rounded,
            title: 'Architects & Commission Hub',
            badgeText: 'SPECIFIER PARTNERS',
            action: ErpButton(
              text: 'Add Architect',
              icon: Icons.add,
              onPressed: () => _openAddEditArchitectDialog(),
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
                      icon: Icons.architecture_outlined,
                      iconColor: AppColors.primary,
                      title: 'Total Architects',
                      value: '${totalArchitectsCount}',
                      subtext: 'Design Partners',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.people_outline,
                      iconColor: AppColors.categoryPurple,
                      title: 'Dual Entities',
                      value: '${dualCustomerCount}',
                      subtext: 'Architect-Customer',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.person_outline,
                      iconColor: AppColors.success,
                      title: 'Independent',
                      value: '${independentCount}',
                      subtext: 'Consultants',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.pending_actions_outlined,
                      iconColor: AppColors.warning,
                      title: 'Pending Comms',
                      value: '${unpaidCommissions}',
                      subtext: 'Awaiting Payout',
                      subtextColor: AppColors.warning,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.currency_rupee,
                      iconColor: AppColors.categoryGold,
                      title: 'Total Paid',
                      value: Formatters.formatCurrency(totalCommissionPaid),
                      subtext: 'Disbursed',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Tabs: Architect Directory & Commission Ledger
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Architect Directory'),
              Tab(text: 'Commission Ledger & Approvals'),
            ],
          ),
          const SizedBox(height: 20),

          if (_tabController.index == 0)
            // Tab 1: Architect Directory
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: ErpSearchInput(
                        hintText: 'Search architect by name, studio...',
                        initialValue: _archSearchQuery,
                        onChanged: (val) => setState(() {
                          _archSearchQuery = val;
                          _archCurrentPage = 0;
                        }),
                      ),
                    ),
                    ErpFilterDropdown<String>(
                      value: _archCustomerFilter,
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Architects')),
                        DropdownMenuItem(value: 'DUAL_CUSTOMER', child: Text('Dual Arch-Customer / Linked')),
                        DropdownMenuItem(value: 'INDEPENDENT', child: Text('Independent Studios')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _archCustomerFilter = val;
                            _archCurrentPage = 0;
                          });
                        }
                      },
                    ),
                    ErpDateFilterBox(
                      startDate: _archStartDate,
                      endDate: _archEndDate,
                      onDateRangeSelected: (start, end) => setState(() {
                        _archStartDate = start;
                        _archEndDate = end;
                        _archCurrentPage = 0;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ErpDataTable(
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 72,
                  columns: const [
                          ErpColumn(title: 'Architect Name'),
                          ErpColumn(title: 'Architect-Customer Name'),
                          ErpColumn(title: 'Studio / Company'),
                          ErpColumn(title: 'State'),
                          ErpColumn(title: 'Contact'),
                          ErpColumn(title: 'Default Rate (%)', isNumeric: true),
                          ErpColumn(title: 'Total Earned', isNumeric: true),
                          ErpColumn(title: 'Pending Review', isNumeric: true),
                          ErpColumn(title: 'Approved', isNumeric: true),
                          ErpColumn(title: 'Paid to Date', isNumeric: true),
                          ErpColumn(title: 'Actions'),
                        ],
                        rows: pagedArchitects.map((a) {
                          final linkedCust = a.linkedCustomerId != null
                              ? db.customers.where((c) => c.id == a.linkedCustomerId).firstOrNull
                              : null;

                          final aComms = db.commissions.where((c) => c.architectId == a.id).toList();
                          final commEarned = aComms.where((c) => c.status != CommissionStatus.rejected).fold(0.0, (s, c) => s + c.commissionAmount);
                          final commPending = aComms.where((c) => c.status == CommissionStatus.generated).fold(0.0, (s, c) => s + c.commissionAmount);
                          final commApproved = aComms.where((c) => c.status == CommissionStatus.approved).fold(0.0, (s, c) => s + c.commissionAmount);
                          final commPaid = aComms.where((c) => c.status == CommissionStatus.paid).fold(0.0, (s, c) => s + c.commissionAmount);

                          final invComms = db.sales
                              .where((s) => s.architectId == a.id && s.documentType == SalesDocumentType.invoice && s.status != SaleStatus.cancelled)
                              .fold(0.0, (s, sale) => s + sale.architectCommissionAmount);

                          final displayEarned = commEarned > 0 ? commEarned : (a.totalCommissionEarned > 0 ? a.totalCommissionEarned : invComms);
                          final displayPending = commPending > 0 ? commPending : (a.pendingCommission > 0 ? a.pendingCommission : (commEarned == 0 ? invComms : 0.0));
                          final displayApproved = commApproved > 0 ? commApproved : a.approvedCommission;
                          final displayPaid = commPaid > 0 ? commPaid : a.paidCommission;

                          return [
                            // 1. Architect Name (Clickable -> Architect Detail Page)
                            InkWell(
                              onTap: () {
                                ref.read(activeRecordDetailsStackProvider.notifier).push(a.id, 'architect', ErpNavSection.architects);
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    a.name,
                                    style: AppTextStyles.bodyBold.copyWith(
                                      fontSize: 13,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (a.address.isNotEmpty || a.state.isNotEmpty || a.pincode.isNotEmpty)
                                    Text(
                                      [
                                        if (a.address.isNotEmpty) a.address,
                                        if (a.state.isNotEmpty) a.state,
                                        if (a.pincode.isNotEmpty) a.pincode,
                                      ].join(', '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    )
                                  else
                                    Text('ID: ${a.id}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            // 2. Architect-Customer Name (Clickable -> Customer Detail Page or Not Linked)
                            linkedCust != null
                                ? InkWell(
                                    onTap: () {
                                      ref.read(activeRecordDetailsStackProvider.notifier).push(linkedCust.id, 'customer', ErpNavSection.customers);
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
                                              linkedCust.name,
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
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Not Linked', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ),
                            Text(a.companyName.isNotEmpty ? a.companyName : '-', style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                            Text(a.state.isNotEmpty ? a.state : '-', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                            Text(a.mobile, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
                            Text('${a.defaultCommissionRate}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                            Text(Formatters.formatCurrency(displayEarned), style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.purple)),
                            Text(Formatters.formatCurrency(displayPending), style: const TextStyle(fontSize: 12, color: AppColors.warningText)),
                            Text(Formatters.formatCurrency(displayApproved), style: const TextStyle(fontSize: 12, color: AppColors.infoText)),
                            Text(Formatters.formatCurrency(displayPaid), style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.successText)),
                            PopupMenuButton<String>(
                              tooltip: 'Actions',
                              icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onSelected: (action) {
                                switch (action) {
                                  case 'view':
                                    ref.read(activeRecordDetailsStackProvider.notifier).push(a.id, 'architect', ErpNavSection.architects);
                                    break;
                                  case 'whatsapp':
                                    WhatsAppQuickChatDialog.showArchitectQuickChat(
                                      context,
                                      architectName: a.name,
                                      architectPhone: a.mobile,
                                      firmName: a.companyName,
                                    );
                                    break;
                                  case 'edit':
                                    _openAddEditArchitectDialog(a);
                                    break;
                                  case 'delete':
                                    _confirmDeleteArchitect(a);
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
                                      Text('View Architect Profile'),
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
                                      Text('Edit Architect'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                                      SizedBox(width: 8),
                                      Text('Delete Architect', style: TextStyle(color: AppColors.danger)),
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
                        currentPage: archSafeCurrentPage,
                        pageSize: archSafePageSize,
                        totalRecords: archTotalRecords,
                        onPageChanged: (newPage) => setState(() => _archCurrentPage = newPage),
                        onPageSizeChanged: (newSize) => setState(() {
                          _archPageSize = newSize;
                          _archCurrentPage = 0;
                        }),
                      ),
                    ],
                  )
          else
            // Tab 2: Commission Ledger & Approvals Lifecycle
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: ErpSearchInput(
                        hintText: 'Search voucher, architect, invoice...',
                        initialValue: _commSearchQuery,
                        onChanged: (val) => setState(() {
                          _commSearchQuery = val;
                          _commCurrentPage = 0;
                        }),
                      ),
                    ),
                    ErpFilterDropdown<String>(
                      value: _commStatusFilter,
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'PENDING', child: Text('Pending Review')),
                        DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                        DropdownMenuItem(value: 'PAID', child: Text('Paid')),
                        DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _commStatusFilter = val;
                            _commCurrentPage = 0;
                          });
                        }
                      },
                    ),
                    ErpDateFilterBox(
                      startDate: _commStartDate,
                      endDate: _commEndDate,
                      onDateRangeSelected: (start, end) => setState(() {
                        _commStartDate = start;
                        _commEndDate = end;
                        _commCurrentPage = 0;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ErpDataTable(
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 72,
                  columns: const [
                          ErpColumn(title: 'Commission No'),
                          ErpColumn(title: 'Date'),
                          ErpColumn(title: 'Architect'),
                          ErpColumn(title: 'Sale Invoice'),
                          ErpColumn(title: 'Project'),
                          ErpColumn(title: 'Sale Value', isNumeric: true),
                          ErpColumn(title: 'Rate', isNumeric: true),
                          ErpColumn(title: 'Commission (₹)', isNumeric: true),
                          ErpColumn(title: 'Status'),
                          ErpColumn(title: 'Workflow Actions'),
                        ],
                        rows: pagedCommissions.map((comm) {
                          ErpStatusBadge badge;
                          switch (comm.status) {
                            case CommissionStatus.generated:
                              badge = ErpStatusBadge.warning('PENDING REVIEW');
                              break;
                            case CommissionStatus.approved:
                              badge = ErpStatusBadge.info('APPROVED');
                              break;
                            case CommissionStatus.paid:
                              badge = ErpStatusBadge.success('PAID');
                              break;
                            case CommissionStatus.rejected:
                              badge = ErpStatusBadge.danger('REJECTED');
                              break;
                          }

                          return [
                            Text(comm.commissionNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                            Text(Formatters.formatDate(comm.generatedDate), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            Text(comm.architectName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                            Text(comm.saleInvoiceNumber, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                            Text(comm.projectName ?? 'Direct Sale', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            Text(Formatters.formatCurrency(comm.saleAmount), style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                            Text('${comm.commissionRate}%', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                            Text(Formatters.formatCurrency(comm.commissionAmount), style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.purple)),
                            badge,
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (comm.status == CommissionStatus.generated) ...[
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                                    tooltip: 'Approve Commission Voucher',
                                    onPressed: () async {
                                      try {
                                        await db.approveCommissionAsync(comm.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text('Commission Voucher ${comm.commissionNumber} Approved!'),
                                            backgroundColor: AppColors.success,
                                          ));
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text('Failed to approve: $e'),
                                            backgroundColor: AppColors.danger,
                                          ));
                                        }
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                    tooltip: 'Reject Commission Voucher',
                                    onPressed: () async {
                                      try {
                                        await db.rejectCommissionAsync(comm.id, reason: 'Declined during partner audit');
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text('Commission Voucher ${comm.commissionNumber} Rejected.'),
                                            backgroundColor: AppColors.danger,
                                          ));
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text('Failed to reject: $e'),
                                            backgroundColor: AppColors.danger,
                                          ));
                                        }
                                      }
                                    },
                                  ),
                                ],
                                if (comm.status == CommissionStatus.approved) ...[
                                  IconButton(
                                    icon: const Icon(Icons.payments_outlined, color: Colors.purple, size: 18),
                                    tooltip: 'Disburse / Pay Commission',
                                    onPressed: () => _openPayCommissionDialog(comm),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                    tooltip: 'Reject / Cancel Commission Voucher',
                                    onPressed: () async {
                                      try {
                                        await db.rejectCommissionAsync(comm.id, reason: 'Declined after approval');
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text('Commission Voucher ${comm.commissionNumber} Rejected.'),
                                            backgroundColor: AppColors.danger,
                                          ));
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text('Failed to reject: $e'),
                                            backgroundColor: AppColors.danger,
                                          ));
                                        }
                                      }
                                    },
                                  ),
                                ],
                                if (comm.status == CommissionStatus.paid)
                                  Text('Ref: ${comm.paymentReference ?? "Paid"}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText)),
                                if (comm.status == CommissionStatus.rejected)
                                  Text('Rejected', style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                              ],
                            ),
                          ];
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      ErpPaginationBar(
                        currentPage: commSafeCurrentPage,
                        pageSize: commSafePageSize,
                        totalRecords: commTotalRecords,
                        onPageChanged: (newPage) => setState(() => _commCurrentPage = newPage),
                        onPageSizeChanged: (newSize) => setState(() {
                          _commPageSize = newSize;
                          _commCurrentPage = 0;
                        }),
                      ),
                    ],
                  ),
        ],
      ),
    );
  }
}
