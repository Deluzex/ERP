import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/vendor_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_confirm_dialog.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  String _searchQuery = '';

  void _openAddEditVendorDialog([Vendor? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final contactCtrl = TextEditingController(text: existing?.contactPerson ?? '');
    final mobileCtrl = TextEditingController(text: existing?.mobile ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final gstCtrl = TextEditingController(text: existing?.gstNumber ?? '');
    final panCtrl = TextEditingController(text: existing?.panNumber ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final termsCtrl = TextEditingController(text: existing?.paymentTerms ?? 'Net 30 Days');
    final creditCtrl = TextEditingController(text: existing?.creditLimit.toString() ?? '500000');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Vendor' : 'Add Vendor Master', style: AppTextStyles.h2),
          content: SizedBox(
            width: 560,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      validator: (v) => Validators.requiredField(v, 'Vendor company name required'),
                      decoration: const InputDecoration(labelText: 'Vendor Name *', hintText: 'E.g., Apex Aluminum Extrusions Ltd'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: contactCtrl,
                            validator: (v) => Validators.requiredField(v, 'Contact person required'),
                            decoration: const InputDecoration(labelText: 'Contact Person *'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: mobileCtrl,
                            validator: Validators.mobile,
                            decoration: const InputDecoration(labelText: 'Mobile Number *'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: emailCtrl,
                            validator: Validators.email,
                            decoration: const InputDecoration(labelText: 'Email Address'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: gstCtrl,
                            decoration: const InputDecoration(labelText: 'GST Number'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: panCtrl,
                            decoration: const InputDecoration(labelText: 'PAN Number'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: termsCtrl,
                            decoration: const InputDecoration(labelText: 'Payment Terms'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: creditCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Credit Limit (₹)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Factory / Registered Address'),
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
              text: isEdit ? 'Update Vendor' : 'Save Vendor',
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final creditVal = double.tryParse(creditCtrl.text.trim()) ?? 0.0;

                if (isEdit) {
                  db.updateVendor(existing.copyWith(
                    name: nameCtrl.text.trim(),
                    contactPerson: contactCtrl.text.trim(),
                    mobile: mobileCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    gstNumber: gstCtrl.text.trim(),
                    panNumber: panCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    paymentTerms: termsCtrl.text.trim(),
                    creditLimit: creditVal,
                  ));
                } else {
                  final newVendor = Vendor(
                    id: IdGenerator.generateId('VEN'),
                    name: nameCtrl.text.trim(),
                    contactPerson: contactCtrl.text.trim(),
                    mobile: mobileCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    gstNumber: gstCtrl.text.trim(),
                    panNumber: panCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    paymentTerms: termsCtrl.text.trim(),
                    creditLimit: creditVal,
                    outstandingBalance: 0.0,
                    createdAt: DateTime.now(),
                  );
                  db.addVendor(newVendor);
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteVendor(Vendor vendor) {
    showDialog(
      context: context,
      builder: (ctx) {
        return ErpConfirmDeleteDialog(
          title: 'Delete Vendor Record',
          message: 'Are you sure you want to deactivate and archive this vendor? A mandatory audit reason is required.',
          itemName: '${vendor.name} (${vendor.id})',
          requireReason: true,
          onConfirm: (reason) {
            final db = ref.read(databaseServiceProvider);
            db.deleteVendor(vendorId: vendor.id, reason: reason);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Vendor ${vendor.name} deleted with reason: $reason')),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final vendors = db.vendors.where((v) {
      return v.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.contactPerson.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.mobile.toLowerCase().contains(_searchQuery.toLowerCase());
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
                  Text('Vendors Master', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Raw material suppliers, payment terms, credit limits, and outstanding balances', style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'Add Vendor',
                icon: Icons.add,
                onPressed: () => _openAddEditVendorDialog(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search vendors by company, contact person or phone...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Vendor Name'),
              ErpColumn(title: 'Contact Person'),
              ErpColumn(title: 'Mobile / Email'),
              ErpColumn(title: 'GST Number'),
              ErpColumn(title: 'Payment Terms'),
              ErpColumn(title: 'Credit Limit', isNumeric: true),
              ErpColumn(title: 'Outstanding Balance', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Actions'),
            ],
            rows: vendors.map((v) {
              return [
                Text(v.name, style: AppTextStyles.bodyBold),
                Text(v.contactPerson, style: AppTextStyles.bodyMedium),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v.mobile, style: AppTextStyles.bodySmall),
                    Text(v.email, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                  ],
                ),
                Text(v.gstNumber, style: AppTextStyles.bodySmall),
                Text(v.paymentTerms, style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(v.creditLimit), style: AppTextStyles.bodySmall),
                Text(
                  Formatters.formatCurrency(v.outstandingBalance),
                  style: AppTextStyles.bodyBold.copyWith(
                    color: v.outstandingBalance > 0 ? AppColors.dangerText : AppColors.textMuted,
                  ),
                ),
                v.isDeleted
                    ? ErpStatusBadge.danger('DELETED (${v.deleteReason ?? "Reason not specified"})')
                    : ErpStatusBadge.success('ACTIVE'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Vendor',
                      onPressed: v.isDeleted ? null : () => _openAddEditVendorDialog(v),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                      tooltip: 'Delete with Reason',
                      onPressed: v.isDeleted ? null : () => _confirmDeleteVendor(v),
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
