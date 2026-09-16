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
import '../../../core/widgets/erp_confirm_dialog.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/document_ocr_uploader.dart';
import '../../../shared/widgets/whatsapp_quick_chat_dialog.dart';
import '../../../shared/providers/app_state_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadCustomers();
      ref.read(databaseServiceProvider).loadArchitects();
    });
  }

  void _openAddEditCustomerDialog([Customer? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final mobileCtrl = TextEditingController(text: existing?.mobile ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final gstCtrl = TextEditingController(text: existing?.gstNumber ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    String? linkedArchitectId = existing?.linkedArchitectId;
    bool isAlsoArchitect = existing?.isAlsoArchitect ?? (existing?.linkedArchitectId != null);
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
                          child: SizedBox(
                            width: 800,
                            height: 600,
                            child: DocumentOcrUploader(
                              docType: OcrDocType.customerDoc,
                              onCancel: () => Navigator.of(ocrCtx).pop(),
                              onConfirm: (data) {
                                nameCtrl.text = data['Customer Name'] ?? data['Company Name'] ?? nameCtrl.text;
                                mobileCtrl.text = data['Mobile'] ?? mobileCtrl.text;
                                emailCtrl.text = data['Email'] ?? emailCtrl.text;
                                addressCtrl.text = data['Address'] ?? addressCtrl.text;
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
                                validator: Validators.email,
                                decoration: const InputDecoration(labelText: 'Email Address'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: gstCtrl,
                          validator: Validators.gst,
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
                                  value: linkedArchitectId,
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
                          if (!formKey.currentState!.validate()) return;
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

                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Customer "${customer.name}" ${isEdit ? "updated" : "saved"} successfully!'),
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

  void _confirmDeleteCustomer(Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) {
        return ErpConfirmDeleteDialog(
          title: 'Delete Customer Record',
          message: 'Are you sure you want to deactivate and archive this customer? A mandatory audit reason is required.',
          itemName: '${customer.name} (${customer.id})',
          requireReason: true,
          onConfirm: (reason) async {
            final db = ref.read(databaseServiceProvider);
            try {
              await db.deleteCustomerAsync(customerId: customer.id, reason: reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Customer "${customer.name}" archived with audit reason: $reason'),
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
    final customers = db.customers.where((c) {
      if (c.isDeleted) return false;
      final query = _searchQuery.trim().toLowerCase();
      return query.isEmpty ||
          c.name.toLowerCase().contains(query) ||
          c.mobile.toLowerCase().contains(query) ||
          c.email.toLowerCase().contains(query) ||
          c.address.toLowerCase().contains(query);
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
                  Text('Customers Master', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Direct end-customers, project developers, and dual-entity Architect-Customers with WhatsApp action',
                      style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'Add Customer',
                icon: Icons.add,
                onPressed: () => _openAddEditCustomerDialog(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search customer by name, mobile, email, company, GST, or address...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Customer Name'),
              ErpColumn(title: 'Type / Dual Role'),
              ErpColumn(title: 'Mobile Phone'),
              ErpColumn(title: 'Email Address'),
              ErpColumn(title: 'GST Number'),
              ErpColumn(title: 'Site / Billing Address'),
              ErpColumn(title: 'Outstanding Balance', isNumeric: true),
              ErpColumn(title: 'Actions'),
            ],
            rows: customers.map((c) {
              final linkedArch = c.linkedArchitectId != null
                  ? db.architects.where((a) => a.id == c.linkedArchitectId).firstOrNull
                  : null;

              return [
                // 1. Customer Name (Clickable -> Customer Detail Page)
                InkWell(
                  onTap: () {
                    ref.read(activeRecordDetailsStackProvider.notifier).push(c.id, 'customer', ErpNavSection.customers);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.name,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      if (c.address.isNotEmpty)
                        Text(c.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                    ],
                  ),
                ),
                // 2. Client Role / Linked Architect (Clickable -> Architect Detail Page if linked)
                linkedArch != null
                    ? InkWell(
                        onTap: () {
                          ref.read(activeRecordDetailsStackProvider.notifier).push(linkedArch.id, 'architect', ErpNavSection.architects);
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
                                  'Arch: ${linkedArch.name}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
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
                    : (c.isAlsoArchitect
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                            child: const Text('ARCH-CUSTOMER', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                          )
                        : const Text('Direct Client', style: TextStyle(fontSize: 11, color: Colors.grey))),
                Text(c.mobile, style: AppTextStyles.bodyMedium),
                Text(c.email, style: AppTextStyles.bodySmall),
                Text(c.gstNumber.isNotEmpty ? c.gstNumber : '-', style: AppTextStyles.bodySmall),
                Text(c.address, style: AppTextStyles.bodySmall),
                Text(
                  Formatters.formatCurrency(c.outstandingAmount),
                  style: AppTextStyles.bodyBold.copyWith(
                    color: c.outstandingAmount > 0 ? AppColors.dangerText : AppColors.successText,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 18),
                      tooltip: 'View Complete Customer Detail Page',
                      onPressed: () {
                        ref.read(activeRecordDetailsStackProvider.notifier).push(c.id, 'customer', ErpNavSection.customers);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat, color: Colors.green, size: 18),
                      tooltip: 'Quick WhatsApp Message',
                      onPressed: () => WhatsAppQuickChatDialog.showCustomerQuickChat(
                        context,
                        customerName: c.name,
                        customerPhone: c.mobile,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Customer',
                      onPressed: () => _openAddEditCustomerDialog(c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                      tooltip: 'Delete Customer',
                      onPressed: () => _confirmDeleteCustomer(c),
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
