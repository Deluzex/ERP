import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
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

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final orders = db.productionOrders.where((o) {
      return o.productionNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          o.finishedProductName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          o.finishedProductCode.toLowerCase().contains(_searchQuery.toLowerCase());
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
