import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
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
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Architect' : 'Add Architect Master', style: AppTextStyles.h2),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      validator: (v) => Validators.requiredField(v, 'Architect name required'),
                      decoration: const InputDecoration(labelText: 'Architect Name *', hintText: 'E.g., Ar. Sanjay Puri'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: compCtrl,
                      decoration: const InputDecoration(labelText: 'Studio / Company Name', hintText: 'E.g., Sanjay Puri Architects'),
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
                            decoration: const InputDecoration(labelText: 'GST Number'),
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
                      decoration: const InputDecoration(labelText: 'Studio Address'),
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
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ErpButton(
              text: isEdit ? 'Update Architect' : 'Save Architect',
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final rateVal = double.tryParse(rateCtrl.text.trim()) ?? 5.0;

                if (isEdit) {
                  db.updateArchitect(existing.copyWith(
                    name: nameCtrl.text.trim(),
                    companyName: compCtrl.text.trim(),
                    mobile: mobileCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    gstNumber: gstCtrl.text.trim(),
                    address: addrCtrl.text.trim(),
                    defaultCommissionRate: rateVal,
                  ));
                } else {
                  final newArch = Architect(
                    id: IdGenerator.generateId('ARCH'),
                    name: nameCtrl.text.trim(),
                    companyName: compCtrl.text.trim(),
                    mobile: mobileCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    gstNumber: gstCtrl.text.trim(),
                    address: addrCtrl.text.trim(),
                    defaultCommissionRate: rateVal,
                    createdAt: DateTime.now(),
                  );
                  db.addArchitect(newArch);
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
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
      return a.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.companyName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.mobile.toLowerCase().contains(_searchQuery.toLowerCase());
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
                  Text('Architect profiles, associated project sales, and commission lifecycle (Generated → Review → Approved → Paid)', style: AppTextStyles.subtitle),
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
                          return [
                            Text(a.name, style: AppTextStyles.bodyBold),
                            Text(a.companyName, style: AppTextStyles.bodyMedium),
                            Text(a.mobile, style: AppTextStyles.bodySmall),
                            Text('${a.defaultCommissionRate}%', style: AppTextStyles.bodyMedium),
                            Text(Formatters.formatCurrency(a.totalCommissionEarned), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
                            Text(Formatters.formatCurrency(a.pendingCommission), style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningText)),
                            Text(Formatters.formatCurrency(a.approvedCommission), style: AppTextStyles.bodySmall.copyWith(color: AppColors.infoText)),
                            Text(Formatters.formatCurrency(a.paidCommission), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit Architect',
                              onPressed: () => _openAddEditArchitectDialog(a),
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
