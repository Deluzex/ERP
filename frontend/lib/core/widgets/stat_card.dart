import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';

class StatCard extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String value;
  final String? trendText;
  final bool? isPositiveTrend;
  final String? actionText;
  final VoidCallback? onActionTap;
  final Color? iconColor;
  final Color? iconBgColor;

  const StatCard({
    super.key,
    this.icon,
    required this.title,
    required this.value,
    this.trendText,
    this.isPositiveTrend,
    this.actionText,
    this.onActionTap,
    this.iconColor,
    this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorderRadius,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.metricValue,
          ),
          const SizedBox(height: 10),
          if (trendText != null)
            Row(
              children: [
                if (isPositiveTrend != null) ...[
                  Icon(
                    isPositiveTrend! ? Icons.trending_up : Icons.trending_down,
                    size: 14,
                    color: isPositiveTrend! ? AppColors.successText : AppColors.dangerText,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  trendText!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isPositiveTrend == true
                        ? AppColors.successText
                        : isPositiveTrend == false
                            ? AppColors.dangerText
                            : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else if (actionText != null)
            InkWell(
              onTap: onActionTap,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionText!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.iconBrown,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward,
                    size: 13,
                    color: AppColors.iconBrown,
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 18),
        ],
      ),
    );
  }
}
