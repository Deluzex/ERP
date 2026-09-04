import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/production_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class ProductionOrdersScreen extends ConsumerStatefulWidget {
  const ProductionOrdersScreen({super.key});

  @override
  ConsumerState<ProductionOrdersScreen> createState() => _ProductionOrdersScreenState();
}

class _ProductionOrdersScreenState extends ConsumerState<ProductionOrdersScreen> {
  String _searchQuery = '';

  void _confirmDelete(ProductionOrder o) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Production Order'),
        content: Text('Are you sure you want to delete draft order ${o.productionNumber}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              final db = ref.read(databaseServiceProvider);
              db.deleteProductionOrder(orderId: o.id, reason: 'Draft deletion');
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Order ${o.productionNumber} deleted successfully.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmCancelAndSoftDelete(ProductionOrder o) {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel & Soft-Delete Production Order'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('You are cancelling/deactivating production run ${o.productionNumber}. Please specify the reason below:'),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtrl,
                validator: (v) => v == null || v.trim().isEmpty ? 'Cancellation reason is required' : null,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Reason *',
                  hintText: 'E.g., Client request, machine breakdown...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final db = ref.read(databaseServiceProvider);
              db.deleteProductionOrder(orderId: o.id, reason: reasonCtrl.text.trim());
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Order ${o.productionNumber} cancelled & soft-deleted.')),
              );
            },
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final orders = db.productionOrders.where((o) => !o.isDeleted).where((o) {
      final query = _searchQuery.trim().toLowerCase();
      return query.isEmpty ||
          o.productionNumber.toLowerCase().contains(query) ||
          o.finishedProductName.toLowerCase().contains(query) ||
          o.finishedProductCode.toLowerCase().contains(query) ||
          o.statusLabel.toLowerCase().contains(query) ||
          (o.notes != null && o.notes!.toLowerCase().contains(query)) ||
          o.rawMaterialsUsed.any((rm) => rm.rawMaterialName.toLowerCase().contains(query));
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
                  Text('Production Orders & Batches', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Manufacturing work orders, raw material consumption, and unit costing', style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'New Production Order',
                icon: Icons.precision_manufacturing_outlined,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createProduction,
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search production by batch number, product name or code...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Order No'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Finished Product'),
              ErpColumn(title: 'Planned Qty', isNumeric: true),
              ErpColumn(title: 'Actual Output', isNumeric: true),
              ErpColumn(title: 'RM Cost', isNumeric: true),
              ErpColumn(title: 'Labour & Overheads', isNumeric: true),
              ErpColumn(title: 'Total Batch Cost', isNumeric: true),
              ErpColumn(title: 'Cost Per Unit', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: orders.map((o) {
              return [
                Text(o.productionNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                Text(Formatters.formatDate(o.productionDate), style: AppTextStyles.bodySmall),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(o.finishedProductCode, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                    Text(o.finishedProductName, style: AppTextStyles.bodySmall),
                  ],
                ),
                Text('${Formatters.formatNumber(o.plannedQuantity)} ${o.unit}', style: AppTextStyles.bodySmall),
                Text(
                  '${Formatters.formatNumber(o.actualQuantityProduced)} ${o.unit}',
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText),
                ),
                Text(Formatters.formatCurrency(o.rawMaterialCost), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(o.labourCost + o.otherExpenses), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(o.totalProductionCost), style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(o.costPerUnit), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                ErpStatusBadge.success(o.statusLabel.toUpperCase()),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}
