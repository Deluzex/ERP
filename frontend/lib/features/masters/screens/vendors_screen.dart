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
import '../../../core/widgets/document_ocr_uploader.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/providers/app_state_providers.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadVendors();
    });
  }

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

    bool isSubmitting = false;
    String? serverError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDlgState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEdit ? 'Edit Vendor' : 'Add Vendor Master', style: AppTextStyles.h2),
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
                              docType: OcrDocType.vendorDoc,
                              onCancel: () => Navigator.of(ocrCtx).pop(),
                              onConfirm: (data) {
                                nameCtrl.text = data['Vendor Name'] ?? data['Company Name'] ?? nameCtrl.text;
                                contactCtrl.text = data['Contact Person'] ?? contactCtrl.text;
                                mobileCtrl.text = data['Mobile'] ?? mobileCtrl.text;
                                emailCtrl.text = data['Email'] ?? emailCtrl.text;
                                addressCtrl.text = data['Address'] ?? addressCtrl.text;
                                if (data.containsKey('Payment Terms')) {
                                  termsCtrl.text = data['Payment Terms']!;
                                }
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
                width: 560,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (serverError != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    serverError!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                                validator: Validators.requiredMobile,
                                decoration: const InputDecoration(labelText: 'Mobile Number *', hintText: '9876543210'),
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
                                validator: Validators.requiredEmail,
                                decoration: const InputDecoration(labelText: 'Email Address *', hintText: 'vendor@domain.com'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: gstCtrl,
                                validator: (v) => Validators.gst(v, true),
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(labelText: 'GST Number *', hintText: '24AAATE1234F1Z5'),
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
                                validator: (v) => Validators.pan(v, true),
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(labelText: 'PAN Number *', hintText: 'AAATE1234F'),
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
                                validator: Validators.nonNegativeNumber,
                                decoration: const InputDecoration(labelText: 'Credit Limit (₹) *'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressCtrl,
                          validator: (v) => Validators.requiredField(v, 'Registered factory address required'),
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Factory / Registered Address *'),
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
                  text: isEdit ? 'Update Vendor' : 'Save Vendor',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDlgState(() {
                            isSubmitting = true;
                            serverError = null;
                          });

                          final creditVal = double.tryParse(creditCtrl.text.trim()) ?? 0.0;
                          try {
                            if (isEdit) {
                              await db.updateVendorAsync(existing.copyWith(
                                name: nameCtrl.text.trim(),
                                contactPerson: contactCtrl.text.trim(),
                                mobile: mobileCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                gstNumber: gstCtrl.text.trim().toUpperCase(),
                                panNumber: panCtrl.text.trim().toUpperCase(),
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
                                gstNumber: gstCtrl.text.trim().toUpperCase(),
                                panNumber: panCtrl.text.trim().toUpperCase(),
                                address: addressCtrl.text.trim(),
                                paymentTerms: termsCtrl.text.trim(),
                                creditLimit: creditVal,
                                outstandingBalance: 0.0,
                                createdAt: DateTime.now(),
                              );
                              await db.addVendorAsync(newVendor);
                            }

                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Vendor "${nameCtrl.text.trim()}" ${isEdit ? "updated" : "saved"} successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } on ApiException catch (e) {
                            setDlgState(() {
                              serverError = e.message;
                              isSubmitting = false;
                            });
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

  void _confirmDeleteVendor(Vendor vendor) {
    showDialog(
      context: context,
      builder: (ctx) {
        return ErpConfirmDeleteDialog(
          title: 'Delete Vendor Record',
          message: 'Are you sure you want to deactivate and archive this vendor? A mandatory audit reason is required.',
          itemName: '${vendor.name} (${vendor.id})',
          requireReason: true,
          onConfirm: (reason) async {
            final db = ref.read(databaseServiceProvider);
            try {
              await db.deleteVendorAsync(vendorId: vendor.id, reason: reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Vendor "${vendor.name}" archived with audit reason: $reason'),
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

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final vendors = db.vendors.where((v) {
      final query = _searchQuery.trim().toLowerCase();
      return query.isEmpty ||
          v.name.toLowerCase().contains(query) ||
          v.contactPerson.toLowerCase().contains(query) ||
          v.mobile.toLowerCase().contains(query) ||
          v.email.toLowerCase().contains(query) ||
          v.gstNumber.toLowerCase().contains(query) ||
          v.panNumber.toLowerCase().contains(query) ||
          v.address.toLowerCase().contains(query) ||
          v.paymentTerms.toLowerCase().contains(query);
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
              hintText: 'Search vendors by name, contact person, mobile, email, GST, or PAN...',
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
