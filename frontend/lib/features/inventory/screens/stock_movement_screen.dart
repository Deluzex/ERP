import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/stock_movement_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/figma_metric_card.dart';
import '../../../core/widgets/stock_movement_icons.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadStockMovements();
    });
  }

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
          ErpSectionHeaderCard(
            icon: Icons.swap_horiz_rounded,
            title: 'Stock Movement Ledger',
            badgeText: 'AUDIT TRAIL',
            subtitle: 'Immutable audit trail of all inventory inward, outward, consumption and adjustment events',
            action: LayoutBuilder(
              builder: (context, actionBox) {
                final isMobile = actionBox.maxWidth < 520;
                return SizedBox(
                  width: isMobile ? double.infinity : null,
                  child: ErpButton(
                    text: 'Refresh Ledger',
                    icon: Icons.refresh,
                    isOutlined: true,
                    onPressed: () => db.loadStockMovements(forceRefresh: true),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // 4 Key Metrics
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 850
                  ? (constraints.maxWidth - (3 * 12)) / 4
                  : (constraints.maxWidth > 550 ? (constraints.maxWidth - 12) / 2 : double.infinity);
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.swap_horiz_rounded,
                      iconColor: AppColors.primary,
                      title: 'Total Movements',
                      value: '${allMovements.length}',
                      subtext: 'Audited Ledger Entries',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      iconWidget: const StockInIcon(size: 16, color: Color(0xFF16A34A)),
                      title: 'Stock In Events',
                      value: '$inCount',
                      subtext: 'Inward Receipts',
                      subtextColor: const Color(0xFF16A34A),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      iconWidget: const StockOutIcon(size: 16, color: Color(0xFFEF4444)),
                      title: 'Stock Out Events',
                      value: '$outCount',
                      subtext: 'Dispatch & Usage',
                      subtextColor: const Color(0xFFEF4444),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.tune_rounded,
                      iconColor: AppColors.primary,
                      title: 'Stock Adjustments',
                      value: '$adjCount',
                      subtext: 'Audited Discrepancies',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Primary Filter Tabs (Responsive: vertical stack on mobile, horizontal wrap on desktop)
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCategoryTab(
                      label: 'All Movements',
                      count: allMovements.length,
                      category: StockLedgerCategory.all,
                      icon: Icons.all_inclusive,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 8),
                    _buildCategoryTab(
                      label: 'Stock In',
                      count: inCount,
                      category: StockLedgerCategory.stockIn,
                      iconWidget: StockInIcon(
                        size: 16,
                        color: _selectedCategory == StockLedgerCategory.stockIn
                            ? const Color(0xFF16A34A)
                            : AppColors.textSecondary,
                      ),
                      activeColor: AppColors.successText,
                      badgeBg: AppColors.successLight,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 8),
                    _buildCategoryTab(
                      label: 'Stock Out',
                      count: outCount,
                      category: StockLedgerCategory.stockOut,
                      iconWidget: StockOutIcon(
                        size: 16,
                        color: _selectedCategory == StockLedgerCategory.stockOut
                            ? const Color(0xFFEF4444)
                            : AppColors.textSecondary,
                      ),
                      activeColor: AppColors.dangerText,
                      badgeBg: AppColors.dangerLight,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 8),
                    _buildCategoryTab(
                      label: 'Stock Adjustments',
                      count: adjCount,
                      category: StockLedgerCategory.stockAdjustments,
                      icon: Icons.tune_rounded,
                      activeColor: AppColors.primary,
                      badgeBg: AppColors.primaryLight,
                      isFullWidth: true,
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCategoryTab(
                    label: 'All Movements',
                    count: allMovements.length,
                    category: StockLedgerCategory.all,
                    icon: Icons.all_inclusive,
                  ),
                  _buildCategoryTab(
                    label: 'Stock In',
                    count: inCount,
                    category: StockLedgerCategory.stockIn,
                    iconWidget: StockInIcon(
                      size: 16,
                      color: _selectedCategory == StockLedgerCategory.stockIn
                          ? const Color(0xFF16A34A)
                          : AppColors.textSecondary,
                    ),
                    activeColor: AppColors.successText,
                    badgeBg: AppColors.successLight,
                  ),
                  _buildCategoryTab(
                    label: 'Stock Out',
                    count: outCount,
                    category: StockLedgerCategory.stockOut,
                    iconWidget: StockOutIcon(
                      size: 16,
                      color: _selectedCategory == StockLedgerCategory.stockOut
                          ? const Color(0xFFEF4444)
                          : AppColors.textSecondary,
                    ),
                    activeColor: AppColors.dangerText,
                    badgeBg: AppColors.dangerLight,
                  ),
                  _buildCategoryTab(
                    label: 'Stock Adjustments',
                    count: adjCount,
                    category: StockLedgerCategory.stockAdjustments,
                    icon: Icons.tune_rounded,
                    activeColor: AppColors.primary,
                    badgeBg: AppColors.primaryLight,
                  ),
                ],
              );
            },
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    m.stockIn > 0
                        ? const StockInIcon(size: 16, color: Color(0xFF16A34A))
                        : const StockOutIcon(size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Text(m.transactionTypeLabel, style: AppTextStyles.bodyBold),
                  ],
                ),
                Text(m.referenceNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                m.stockIn > 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const StockInIcon(size: 13, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Text(
                            '+${Formatters.formatNumber(m.stockIn)} ${m.unit}',
                            style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText),
                          ),
                        ],
                      )
                    : const Text('-', style: TextStyle(color: AppColors.textSecondary)),
                m.stockOut > 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const StockOutIcon(size: 13, color: Color(0xFFEF4444)),
                          const SizedBox(width: 4),
                          Text(
                            '-${Formatters.formatNumber(m.stockOut)} ${m.unit}',
                            style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText),
                          ),
                        ],
                      )
                    : const Text('-', style: TextStyle(color: AppColors.textSecondary)),
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
    IconData? icon,
    Widget? iconWidget,
    Color? activeColor,
    Color? badgeBg,
    bool isFullWidth = false,
  }) {
    final isSelected = _selectedCategory == category;
    final color = activeColor ?? AppColors.primary;
    final bg = badgeBg ?? AppColors.primaryLight;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = category),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconWidget != null)
                  iconWidget
                else if (icon != null)
                  Icon(icon, size: 16, color: isSelected ? color : AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isSelected ? color : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (!isFullWidth) const SizedBox(width: 8),
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
