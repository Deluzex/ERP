import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';
import '../../shared/providers/app_state_providers.dart';
import '../../shared/widgets/low_stock_whatsapp_alert_dialog.dart';

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

          // Low Stock Alert Quick Button if low stock exists
          Builder(
            builder: (context) {
              final db = ref.watch(databaseServiceProvider);
              final lowCount = db.totalLowStockCount;
              if (lowCount == 0) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => LowStockWhatsAppAlertDialog.show(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$lowCount Low Stock Alerts',
                          style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, color: AppColors.danger, size: 10),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Notification Bell with unread dot
          Stack(
            children: [
              IconButton(
                tooltip: 'Low Stock & Production Alerts',
                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textSecondary, size: 22),
                onPressed: () => LowStockWhatsAppAlertDialog.show(context),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // User Profile Popup Menu
          _buildUserProfileMenu(context, ref),
        ],
      ),
    );
  }

  Widget _buildUserProfileMenu(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    final user = ref.watch(currentUserProvider) ?? db.currentUser;
    final role = db.getUserRole(user);

    return PopupMenuButton<String>(
      tooltip: 'User Profile & Session',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Text(
                user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  role.name,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
      onSelected: (action) {
        if (action == 'profile') {
          _showMyProfileDialog(context, user, role);
        } else if (action == 'password') {
          _showChangePasswordDialog(context, ref, user);
        } else if (action == 'switch_role') {
          _showSwitchRoleDialog(context, ref, db);
        } else if (action == 'logout') {
          ref.read(authStateProvider.notifier).logout();
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: AppTextStyles.bodyBold),
              Text(user.email, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(role.name.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
              const Divider(height: 16),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18),
              SizedBox(width: 10),
              Text('My Profile'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'password',
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18),
              SizedBox(width: 10),
              Text('Change Password'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'switch_role',
          child: Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.purple),
              SizedBox(width: 10),
              Text('Switch Demo Role', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: Colors.red),
              SizedBox(width: 10),
              Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  void _showMyProfileDialog(BuildContext context, dynamic user, dynamic role) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('My Operator Profile'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildProfileRow('Full Name', user.name),
              _buildProfileRow('Work Email', user.email),
              _buildProfileRow('Mobile Phone', user.mobile),
              _buildProfileRow('Primary Role', role.name),
              _buildProfileRow('Status', user.isActive ? 'Active (Verified)' : 'Deactivated'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref, dynamic user) {
    final pwdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Account Password'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your new secure password below.', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
              const SizedBox(height: 16),
              TextFormField(
                controller: pwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password *', prefixIcon: Icon(Icons.lock)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (pwdCtrl.text.trim().isNotEmpty) {
                ref.read(databaseServiceProvider).resetUserPassword(user.id, pwdCtrl.text.trim());
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated successfully!'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Save Password'),
          ),
        ],
      ),
    );
  }

  void _showSwitchRoleDialog(BuildContext context, WidgetRef ref, dynamic db) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick Switch Demo Role'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select an authorized demo user to immediately test that role-specific dashboard and permissions matrix.', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
              const SizedBox(height: 16),
              ...db.users.map((u) {
                final r = db.getUserRole(u);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text(u.name.substring(0, 1)),
                  ),
                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${r.name} • ${u.email}', style: const TextStyle(fontSize: 11)),
                  onTap: () {
                    ref.read(authStateProvider.notifier).switchUser(u);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        ],
      ),
    );
  }
}
