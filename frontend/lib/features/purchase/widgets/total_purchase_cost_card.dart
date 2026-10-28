import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';

/// Compact Total Purchase Cost summary card for the Purchase Summary / Financial & Tax Summary section.
/// Displays dynamically calculated Grand Total (Items + GST + Transportation)
/// and final landed cost per unit for both Raw Material and Finished Goods purchases,
/// allowing users to identify actual cost and determine appropriate selling prices.
class TotalPurchaseCostCard extends StatelessWidget {
  final double totalAmount;
  final double? totalUnits;
  final double? landedCostPerUnit;

  const TotalPurchaseCostCard({
    super.key,
    required this.totalAmount,
    this.totalUnits,
    this.landedCostPerUnit,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnits = totalUnits != null && totalUnits! > 0;
    final effectiveLanded = landedCostPerUnit ?? (hasUnits ? (totalAmount / totalUnits!) : 0.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.smBorderRadius,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasUnits ? 'Total Cost per Product:' : 'Total Purchase Cost',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.primaryDark,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Items + GST + Transportation',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                if (hasUnits) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'Total Purchase Cost',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        ': ${Formatters.formatCurrency(totalAmount)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Formatters.formatCurrency(hasUnits ? effectiveLanded : totalAmount),
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.primaryDark,
                  fontSize: 18,
                ),
              ),
              if (hasUnits && effectiveLanded > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '${Formatters.formatCurrency(effectiveLanded)} / unit',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
