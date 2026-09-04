import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/document_ocr_uploader.dart';
import '../../../shared/providers/app_state_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';

  void _openAddEditCustomerDialog([Customer? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final mobileCtrl = TextEditingController(text: existing?.mobile ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final gstCtrl = TextEditingController(text: existing?.gstNumber ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isEdit ? 'Edit Customer' : 'Add Customer Master', style: AppTextStyles.h2),
              ErpButton(
                text: 'Scan & Upload (OCR)',
                icon: Icons.document_scanner_outlined,
                isOutlined: true,
                onPressed: () {
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
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      validator: (v) => Validators.requiredField(v, 'Customer name required'),
                      decoration: const InputDecoration(labelText: 'Customer Name / Estate *', hintText: 'E.g., Oberoi Sky City Residences'),
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
                      decoration: const InputDecoration(labelText: 'GST Number'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Site / Billing Address'),
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
              text: isEdit ? 'Update Customer' : 'Save Customer',
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                if (isEdit) {
                  db.updateCustomer(existing.copyWith(
                    name: nameCtrl.text.trim(),
                    mobile: mobileCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    gstNumber: gstCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                  ));
                } else {
                  final newCust = Customer(
                    id: IdGenerator.generateId('CUST'),
                    name: nameCtrl.text.trim(),
                    mobile: mobileCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    gstNumber: gstCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    outstandingAmount: 0.0,
                    createdAt: DateTime.now(),
                  );
                  db.addCustomer(newCust);
                }
                Navigator.of(ctx).pop();
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
                  Text('Direct end-customers, project developers, and their outstanding receivables', style: AppTextStyles.subtitle),
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
              ErpColumn(title: 'Mobile Phone'),
              ErpColumn(title: 'Email Address'),
              ErpColumn(title: 'GST Number'),
              ErpColumn(title: 'Site / Billing Address'),
              ErpColumn(title: 'Outstanding Balance', isNumeric: true),
              ErpColumn(title: 'Actions'),
            ],
            rows: customers.map((c) {
              return [
                Text(c.name, style: AppTextStyles.bodyBold),
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
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit Customer',
                  onPressed: () => _openAddEditCustomerDialog(c),
                ),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}
