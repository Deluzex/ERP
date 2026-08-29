import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';
import '../../shared/providers/app_state_providers.dart';

class ErpHeader extends ConsumerWidget {
  final VoidCallback? onMenuToggle;

  const ErpHeader({
    super.key,
    this.onMenuToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textPrimary),
              onPressed: onMenuToggle,
            ),
            const SizedBox(width: 8),
          ],

          // Search Field pill with filter icon
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.mdBorderRadius,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (val) {
                        ref.read(globalSearchQueryProvider.notifier).state = val;
                      },
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Search product , SKU, barcode',
                        hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textDisabled),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        filled: false,
                      ),
                    ),
                  ),
                  Container(
                    height: 20,
                    width: 1,
                    color: AppColors.border,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Search filter active: All categories')),
                      );
                    },
                    child: const Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Notification Bell with unread dot
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textSecondary, size: 22),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You have 3 unread stock notifications')),
                  );
                },
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),

          // Message/Chat icon
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textSecondary, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support & Feedback Channel')),
              );
            },
          ),
        ],
      ),
    );
  }
}
