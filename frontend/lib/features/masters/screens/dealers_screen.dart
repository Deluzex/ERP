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
import '../../../core/widgets/erp_data_table.dart';
import '../../../shared/providers/app_state_providers.dart';

class DealersScreen extends ConsumerStatefulWidget {
  const DealersScreen({super.key});

  @override
  ConsumerState<DealersScreen> createState() => _DealersScreenState();
}

class _DealersScreenState extends ConsumerState<DealersScreen> {
  String _searchQuery = '';

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

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Dealer' : 'Add Dealer Master', style: AppTextStyles.h2),
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
                      controller: addrCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Showroom / Business Address'),
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
              text: isEdit ? 'Update Dealer' : 'Save Dealer',
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                if (isEdit) {
                  db.updateDealer(existing.copyWith(
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
                  db.addDealer(newDealer);
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
    final dealers = db.dealers.where((d) {
      return d.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.contactPerson.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.companyName.toLowerCase().contains(_searchQuery.toLowerCase());
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
                  Text('Dealers & Franchise Network', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Authorized distribution partners, retail showrooms, and channel receivables', style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'Add Dealer',
                icon: Icons.add,
                onPressed: () => _openAddEditDealerDialog(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search dealer by showroom name, contact person or company...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Showroom / Dealer Name'),
              ErpColumn(title: 'Company Entity'),
              ErpColumn(title: 'Contact Person'),
              ErpColumn(title: 'Mobile Phone'),
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
                Text(d.mobile, style: AppTextStyles.bodySmall),
                Text(d.gstNumber.isNotEmpty ? d.gstNumber : '-', style: AppTextStyles.bodySmall),
                Text(d.address, style: AppTextStyles.bodySmall),
                Text(
                  Formatters.formatCurrency(d.outstandingAmount),
                  style: AppTextStyles.bodyBold.copyWith(
                    color: d.outstandingAmount > 0 ? AppColors.dangerText : AppColors.successText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit Dealer',
                  onPressed: () => _openAddEditDealerDialog(d),
                ),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}
