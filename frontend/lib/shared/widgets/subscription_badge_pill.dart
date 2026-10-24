import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../providers/subscription_provider.dart';
import 'subscription_details_sheet.dart';

class SubscriptionBadgePill extends ConsumerWidget {
  const SubscriptionBadgePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(subscriptionProvider);
    final days = status.daysRemaining;
    final isWarning = status.showRenewalWarning;
    final isExpired = status.isExpired;

    final Color primaryColor;
    final Color bgColor;
    final IconData icon;
    final String label;

    if (isExpired) {
      primaryColor = AppColors.danger;
      bgColor = AppColors.danger.withValues(alpha: 0.12);
      icon = Icons.lock_clock_rounded;
      label = 'Expired';
    } else if (isWarning) {
      primaryColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.14);
      icon = Icons.warning_amber_rounded;
      label = '$days Days Left';
    } else {
      primaryColor = const Color(0xFF16A34A);
      bgColor = const Color(0xFF16A34A).withValues(alpha: 0.12);
      icon = Icons.verified_rounded;
      label = '${days}d Left';
    }

    return Tooltip(
      message: 'Subscription Status: $label (Click for details)',
      child: InkWell(
        onTap: () => SubscriptionDetailsSheet.show(context, status),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryColor.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: primaryColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
