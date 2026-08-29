import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/stock_movement_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class StockMovementScreen extends ConsumerStatefulWidget {
  const StockMovementScreen({super.key});

  @override
  ConsumerState<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends ConsumerState<StockMovementScreen> {
  String _searchQuery = '';
  StockMovementType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final movements = db.stockMovements.where((m) {
      final matchesSearch = m.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.itemCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.referenceNumber.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedType == null || m.transactionType == _selectedType;
      return matchesSearch && matchesType;
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stock Movement Ledger', style: AppTextStyles.h1),
          const SizedBox(height: 4),
          Text(
            'Immutable audit trail of all inventory inward, outward, consumption and adjustment events',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 24),

          // Filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search by item code, product name, or reference number...',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<StockMovementType?>(
                value: _selectedType,
                hint: const Text('All Transaction Types'),
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Transaction Types')),
                  ...StockMovementType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(t.toString().split('.').last.toUpperCase()),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _selectedType = val),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Data Table
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Date & Time'),
              ErpColumn(title: 'Item Details'),
              ErpColumn(title: 'Item Type'),
              ErpColumn(title: 'Transaction Type'),
              ErpColumn(title: 'Reference No'),
              ErpColumn(title: 'Stock In', isNumeric: true),
              ErpColumn(title: 'Stock Out', isNumeric: true),
              ErpColumn(title: 'Balance After', isNumeric: true),
              ErpColumn(title: 'Audited Notes'),
              ErpColumn(title: 'User'),
            ],
            rows: movements.map((m) {
              return [
                Text(Formatters.formatDateTime(m.date), style: AppTextStyles.bodySmall),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m.itemCode, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                    Text(m.itemName, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
                Text(
                  m.itemType == ItemType.rawMaterial ? 'Raw Material' : 'Finished Product',
                  style: AppTextStyles.bodySmall,
                ),
                ErpStatusBadge(
                  label: m.transactionTypeLabel,
                  backgroundColor: m.stockIn > 0 ? AppColors.successLight : AppColors.dangerLight,
                  textColor: m.stockIn > 0 ? AppColors.successText : AppColors.dangerText,
                ),
                Text(m.referenceNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                Text(
                  m.stockIn > 0 ? '+${Formatters.formatNumber(m.stockIn)} ${m.unit}' : '-',
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText),
                ),
                Text(
                  m.stockOut > 0 ? '-${Formatters.formatNumber(m.stockOut)} ${m.unit}' : '-',
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText),
                ),
                Text(
                  '${Formatters.formatNumber(m.currentBalance)} ${m.unit}',
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.textPrimary),
                ),
                Text(m.notes ?? '-', style: AppTextStyles.bodySmall),
                Text(m.performedBy, style: AppTextStyles.bodySmall),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}
