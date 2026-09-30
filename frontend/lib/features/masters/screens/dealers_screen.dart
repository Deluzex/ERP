import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/dealer_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_confirm_dialog.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/document_ocr_uploader.dart';
import '../../../shared/providers/app_state_providers.dart';

class DealersScreen extends ConsumerStatefulWidget {
  const DealersScreen({super.key});

  @override
  ConsumerState<DealersScreen> createState() => _DealersScreenState();
}

class _DealersScreenState extends ConsumerState<DealersScreen> {
  String _searchQuery = '';

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
                          if (!formKey.currentState!.validate()) return;
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
                                outstandingAmount: 0.0,
                                createdAt: DateTime.now(),
                              );
                              await db.addDealerAsync(newDealer);
                            }

                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Dealer "${nameCtrl.text.trim()}" ${isEdit ? "updated" : "saved"} successfully!'),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Dealer "${dealer.name}" archived with audit reason: $reason'),
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
    final dealers = db.dealers.where((d) {
      if (d.isDeleted) return false;
      final query = _searchQuery.trim().toLowerCase();
      return query.isEmpty ||
          d.name.toLowerCase().contains(query) ||
          d.contactPerson.toLowerCase().contains(query) ||
          d.companyName.toLowerCase().contains(query) ||
          d.mobile.toLowerCase().contains(query) ||
          d.email.toLowerCase().contains(query) ||
          d.gstNumber.toLowerCase().contains(query) ||
          d.address.toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 550) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dealers & Franchise Network', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text('Authorized distribution partners, retail showrooms, and channel receivables', style: AppTextStyles.subtitle),
                    const SizedBox(height: 12),
                    ErpButton(
                      text: 'Add Dealer',
                      icon: Icons.add,
                      onPressed: () => _openAddEditDealerDialog(),
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dealers & Franchise Network', style: AppTextStyles.h1),
                        const SizedBox(height: 4),
                        Text('Authorized distribution partners, retail showrooms, and channel receivables', style: AppTextStyles.subtitle),
                      ],
                    ),
                  ),
                  ErpButton(
                    text: 'Add Dealer',
                    icon: Icons.add,
                    onPressed: () => _openAddEditDealerDialog(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search dealer by showroom name, contact person, mobile, email, or company...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Showroom / Dealer Name'),
              ErpColumn(title: 'Company Entity'),
              ErpColumn(title: 'Contact Person'),
              ErpColumn(title: 'Mobile / Email'),
              ErpColumn(title: 'GST Number'),
              ErpColumn(title: 'Showroom Address'),
              ErpColumn(title: 'Outstanding Balance', isNumeric: true),
              ErpColumn(title: 'Actions'),
            ],
            rows: dealers.map((d) {
              return [
                Text(d.name, style: AppTextStyles.bodyBold),
                Text(d.companyName, style: AppTextStyles.bodyMedium),
                Text(d.contactPerson, style: AppTextStyles.bodySmall),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d.mobile, style: AppTextStyles.bodySmall),
                    if (d.email.isNotEmpty)
                      Text(d.email, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                  ],
                ),
                Text(d.gstNumber.isNotEmpty ? d.gstNumber : '-', style: AppTextStyles.bodySmall),
                Text(d.address, style: AppTextStyles.bodySmall),
                Text(
                  Formatters.formatCurrency(d.outstandingAmount),
                  style: AppTextStyles.bodyBold.copyWith(
                    color: d.outstandingAmount > 0 ? AppColors.dangerText : AppColors.successText,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Dealer',
                      onPressed: () => _openAddEditDealerDialog(d),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                      tooltip: 'Delete Dealer',
                      onPressed: () => _confirmDeleteDealer(d),
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
