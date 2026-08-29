import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/category_unit_model.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../shared/providers/app_state_providers.dart';

class CategoriesUnitsScreen extends ConsumerStatefulWidget {
  const CategoriesUnitsScreen({super.key});

  @override
  ConsumerState<CategoriesUnitsScreen> createState() => _CategoriesUnitsScreenState();
}

class _CategoriesUnitsScreenState extends ConsumerState<CategoriesUnitsScreen> {
  void _openAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Add Item Category', style: AppTextStyles.h2),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    validator: (v) => Validators.requiredField(v, 'Category name required'),
                    decoration: const InputDecoration(labelText: 'Category Name *', hintText: 'E.g., Chandeliers & Pendants'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description', hintText: 'Category scope and details'),
                  ),
                ],
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
              text: 'Save Category',
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final db = ref.read(databaseServiceProvider);
                db.addCategory(ItemCategory(
                  id: IdGenerator.generateId('CAT'),
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                ));
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _openAddUnitDialog() {
    final nameCtrl = TextEditingController();
    final symbolCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Add Measurement Unit', style: AppTextStyles.h2),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    validator: (v) => Validators.requiredField(v, 'Unit name required'),
                    decoration: const InputDecoration(labelText: 'Unit Name *', hintText: 'E.g., Meters / Pieces / Kilograms'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: symbolCtrl,
                    validator: (v) => Validators.requiredField(v, 'Symbol required'),
                    decoration: const InputDecoration(labelText: 'Symbol *', hintText: 'E.g., MTR / PCS / KG'),
                  ),
                ],
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
              text: 'Save Unit',
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final db = ref.read(databaseServiceProvider);
                db.addUnit(MeasurementUnit(
                  id: IdGenerator.generateId('U'),
                  name: nameCtrl.text.trim(),
                  symbol: symbolCtrl.text.trim().toUpperCase(),
                ));
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

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Categories & Measurement Units', style: AppTextStyles.h1),
          const SizedBox(height: 4),
          Text('Configure product classifications and standardized measurement units (PCS, MTR, KG, etc.)', style: AppTextStyles.subtitle),
          const SizedBox(height: 24),

          // Side by side cards on desktop
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categories Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Item Categories', style: AppTextStyles.h3),
                        ErpButton(
                          text: 'Add Category',
                          icon: Icons.add,
                          isOutlined: true,
                          onPressed: _openAddCategoryDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ErpDataTable(
                      columns: const [
                        ErpColumn(title: 'Category Name'),
                        ErpColumn(title: 'Description'),
                      ],
                      rows: db.categories.map((c) {
                        return [
                          Text(c.name, style: AppTextStyles.bodyBold),
                          Text(c.description, style: AppTextStyles.bodySmall),
                        ];
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Units Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Units of Measure (UOM)', style: AppTextStyles.h3),
                        ErpButton(
                          text: 'Add Unit',
                          icon: Icons.add,
                          isOutlined: true,
                          onPressed: _openAddUnitDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ErpDataTable(
                      columns: const [
                        ErpColumn(title: 'Unit Name'),
                        ErpColumn(title: 'Standard Symbol'),
                      ],
                      rows: db.units.map((u) {
                        return [
                          Text(u.name, style: AppTextStyles.bodyBold),
                          Text(u.symbol, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                        ];
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
