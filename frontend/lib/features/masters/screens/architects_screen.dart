import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/architect_model.dart';
import '../../../core/models/commission_model.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_confirm_dialog.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          child: SizedBox(
                            width: 800,
                            height: 600,
                            child: DocumentOcrUploader(
                              docType: OcrDocType.architectDoc,
                              onCancel: () => Navigator.of(ocrCtx).pop(),
                              onConfirm: (data) {
                                nameCtrl.text = data['Architect Name'] ?? data['Firm Name'] ?? nameCtrl.text;
                                compCtrl.text = data['Firm Name'] ?? compCtrl.text;
                                mobileCtrl.text = data['Mobile'] ?? mobileCtrl.text;
                                emailCtrl.text = data['Email'] ?? emailCtrl.text;
                                addrCtrl.text = data['Address'] ?? addrCtrl.text;
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
              content: SizedBox(
                width: 520,
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
                            labelText: 'Studio / Company Name',
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
                                validator: Validators.gst,
                                decoration: const InputDecoration(
                                  labelText: 'GST Number (Optional, 15 chars)',
                                  hintText: '24AAAAA0000A1Z5',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: rateCtrl,
                                keyboardType: TextInputType.number,
                                validator: Validators.nonNegativeNumber,
                                decoration: const InputDecoration(labelText: 'Default Commission Rate (%) *'),
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
                                  value: linkedCustomerId,
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
                  value: selectedMode,
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
              onPressed: () {
                final db = ref.read(databaseServiceProvider);
                db.payCommission(
                  commissionId: comm.id,
                  paymentMode: selectedMode,
                  ref: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : 'COMM-PAY-${DateTime.now().millisecondsSinceEpoch}',
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Commission Paid & Ledger Updated!'), backgroundColor: AppColors.success),
                );
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
    final architects = db.architects.where((a) {
      if (a.isDeleted) return false;
      final query = _searchQuery.trim().toLowerCase();
      return query.isEmpty ||
          a.name.toLowerCase().contains(query) ||
          a.companyName.toLowerCase().contains(query) ||
          a.mobile.toLowerCase().contains(query) ||
          a.email.toLowerCase().contains(query) ||
          (a.address != null && a.address!.toLowerCase().contains(query));
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
                  Text('Architects & Commission Hub', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Architect profiles, dual Architect-Customer entities, and commission lifecycle (Generated → Review → Approved → Paid)',
                      style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'Add Architect',
                icon: Icons.add,
                onPressed: () => _openAddEditArchitectDialog(),
              ),
            ],
          ),
          const SizedBox(height: 20),

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

          SizedBox(
            height: 600,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Architect Directory
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Search architect by name, studio or mobile...',
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ErpDataTable(
                        columns: const [
                          ErpColumn(title: 'Architect Name'),
                          ErpColumn(title: 'Architect-Customer Name'),
                          ErpColumn(title: 'Studio / Company'),
                          ErpColumn(title: 'Contact'),
                          ErpColumn(title: 'Default Rate (%)', isNumeric: true),
                          ErpColumn(title: 'Total Earned', isNumeric: true),
                          ErpColumn(title: 'Pending Review', isNumeric: true),
                          ErpColumn(title: 'Approved', isNumeric: true),
                          ErpColumn(title: 'Paid to Date', isNumeric: true),
                          ErpColumn(title: 'Actions'),
                        ],
                        rows: architects.map((a) {
                          final linkedCust = a.linkedCustomerId != null
                              ? db.customers.where((c) => c.id == a.linkedCustomerId).firstOrNull
                              : null;

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
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  Text('ID: ${a.id}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.purple.withValues(alpha: 0.25)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.link, size: 12, color: Colors.purple),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              linkedCust.name,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple,
                                                decoration: TextDecoration.underline,
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
                                    child: const Text('Not Linked', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                  ),
                            Text(a.companyName.isNotEmpty ? a.companyName : '-', style: AppTextStyles.bodyMedium),
                            Text(a.mobile, style: AppTextStyles.bodySmall),
                            Text('${a.defaultCommissionRate}%', style: AppTextStyles.bodyMedium),
                            Text(Formatters.formatCurrency(a.totalCommissionEarned), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
                            Text(Formatters.formatCurrency(a.pendingCommission), style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningText)),
                            Text(Formatters.formatCurrency(a.approvedCommission), style: AppTextStyles.bodySmall.copyWith(color: AppColors.infoText)),
                            Text(Formatters.formatCurrency(a.paidCommission), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 18),
                                  tooltip: 'View Complete Architect Detail Page',
                                  onPressed: () {
                                    ref.read(activeRecordDetailsStackProvider.notifier).push(a.id, 'architect', ErpNavSection.architects);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat, color: Colors.green, size: 18),
                                  tooltip: 'Quick WhatsApp Message',
                                  onPressed: () => WhatsAppQuickChatDialog.showArchitectQuickChat(
                                    context,
                                    architectName: a.name,
                                    architectPhone: a.mobile,
                                    firmName: a.companyName,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Edit Architect',
                                  onPressed: () => _openAddEditArchitectDialog(a),
                                ),
                              ],
                            ),
                          ];
                        }).toList(),
                      ),
                    ),
                  ],
                ),

                // Tab 2: Commission Ledger & Approvals Lifecycle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Commission Transactions & Approval Center', style: AppTextStyles.h3),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ErpDataTable(
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
                        rows: db.commissions.map((comm) {
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
                            Text(comm.commissionNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                            Text(Formatters.formatDate(comm.generatedDate), style: AppTextStyles.bodySmall),
                            Text(comm.architectName, style: AppTextStyles.bodyMedium),
                            Text(comm.saleInvoiceNumber, style: AppTextStyles.bodySmall),
                            Text(comm.projectName ?? 'Direct Sale', style: AppTextStyles.bodySmall),
                            Text(Formatters.formatCurrency(comm.saleAmount), style: AppTextStyles.bodySmall),
                            Text('${comm.commissionRate}%', style: AppTextStyles.bodySmall),
                            Text(Formatters.formatCurrency(comm.commissionAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
                            badge,
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (comm.status == CommissionStatus.generated)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.info,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    ),
                                    onPressed: () => db.approveCommission(comm.id),
                                    child: const Text('Approve', style: TextStyle(fontSize: 11)),
                                  ),
                                if (comm.status == CommissionStatus.approved)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    ),
                                    onPressed: () => _openPayCommissionDialog(comm),
                                    child: const Text('Pay Commission', style: TextStyle(fontSize: 11)),
                                  ),
                                if (comm.status == CommissionStatus.paid)
                                  Text('Ref: ${comm.paymentReference ?? "Paid"}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText)),
                              ],
                            ),
                          ];
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
