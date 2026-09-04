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

enum StockLedgerCategory {
  all,
  stockIn,
  stockOut,
  stockAdjustments,
}

class StockMovementScreen extends ConsumerStatefulWidget {
  const StockMovementScreen({super.key});

  @override
  ConsumerState<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends ConsumerState<StockMovementScreen> {
  String _searchQuery = '';
  StockLedgerCategory _selectedCategory = StockLedgerCategory.all;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);

    final allMovements = db.stockMovements;
    final inCount = allMovements.where((m) => m.stockIn > 0 && m.transactionType != StockMovementType.adjustment).length;
    final outCount = allMovements.where((m) => m.stockOut > 0 && m.transactionType != StockMovementType.adjustment).length;
    final adjCount = allMovements.where((m) => m.transactionType == StockMovementType.adjustment || m.transactionType == StockMovementType.damage).length;

    final movements = allMovements.where((m) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          m.itemName.toLowerCase().contains(query) ||
          m.itemCode.toLowerCase().contains(query) ||
          m.referenceNumber.toLowerCase().contains(query) ||
          m.transactionTypeLabel.toLowerCase().contains(query) ||
          m.performedBy.toLowerCase().contains(query) ||
          (m.notes != null && m.notes!.toLowerCase().contains(query));

      bool matchesCategory = true;
      switch (_selectedCategory) {
        case StockLedgerCategory.all:
          matchesCategory = true;
          break;
        case StockLedgerCategory.stockIn:
          matchesCategory = m.stockIn > 0 && m.transactionType != StockMovementType.adjustment;
          break;
        case StockLedgerCategory.stockOut:
          matchesCategory = m.stockOut > 0 && m.transactionType != StockMovementType.adjustment;
          break;
        case StockLedgerCategory.stockAdjustments:
          matchesCategory = m.transactionType == StockMovementType.adjustment || m.transactionType == StockMovementType.damage;
          break;
      }

      return matchesSearch && matchesCategory;
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
          const SizedBox(height: 20),

          // Primary Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryTab(
                  label: 'All Movements',
                  count: allMovements.length,
                  category: StockLedgerCategory.all,
                  icon: Icons.all_inclusive,
                ),
                const SizedBox(width: 8),
                _buildCategoryTab(
                  label: 'Stock In',
                  count: inCount,
                  category: StockLedgerCategory.stockIn,
                  icon: Icons.arrow_downward_rounded,
                  activeColor: AppColors.successText,
                  badgeBg: AppColors.successLight,
                ),
                const SizedBox(width: 8),
                _buildCategoryTab(
                  label: 'Stock Out',
                  count: outCount,
                  category: StockLedgerCategory.stockOut,
                  icon: Icons.arrow_upward_rounded,
                  activeColor: AppColors.dangerText,
                  badgeBg: AppColors.dangerLight,
                ),
                const SizedBox(width: 8),
                _buildCategoryTab(
                  label: 'Stock Adjustments',
                  count: adjCount,
                  category: StockLedgerCategory.stockAdjustments,
                  icon: Icons.tune_rounded,
                  activeColor: AppColors.primary,
                  badgeBg: AppColors.primaryLight,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search by item code, name, reference number, notes, or user...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
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
                Text(m.performedBy, style: AppTextStyles.bodySmall),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab({
    required String label,
    required int count,
    required StockLedgerCategory category,
    required IconData icon,
    Color? activeColor,
    Color? badgeBg,
  }) {
    final isSelected = _selectedCategory == category;
    final color = activeColor ?? AppColors.primary;
    final bg = badgeBg ?? AppColors.primaryLight;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = category),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isSelected ? color : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? bg : AppColors.neutralLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
