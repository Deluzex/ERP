import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';

class LowStockBanner extends StatelessWidget {
  final int count;
  final VoidCallback onViewDetails;

  const LowStockBanner({
    super.key,
    required this.count,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEECEB), // Soft red background from reference
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: const Color(0xFFFCD3D1), width: 1),
      ),
      child: Row(
        children: [
          // Warning Icon in square rounded container
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFDBEB9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.dangerText,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count items are running low on stock.',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Take action to avoid running out of stock',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Action Button
          ElevatedButton(
            onPressed: onViewDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE54D42), // Red button from screenshot
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.smBorderRadius,
              ),
            ),
            child: Text(
              'View Low Stock Items',
              style: AppTextStyles.button.copyWith(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
