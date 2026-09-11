import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/constants/app_constants.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/rbac_models.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../shared/providers/app_state_providers.dart';
import 'user_management_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final user = ref.watch(currentUserProvider) ?? db.currentUser;
    final role = db.getUserRole(user);
    final isAdminOrManager = user.primaryRoleId == 'admin' || user.hasPermission(ErpModule.settings, ErpAction.edit, db.roles);

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('System Configuration & Access Control', style: AppTextStyles.h1),
                  const SizedBox(height: 2),
                  Text('Configure company profile, security matrices, and user account credentials', style: AppTextStyles.subtitle),
                ],
              ),
              if (isAdminOrManager)
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('System & Company Preferences'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.admin_panel_settings_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('User Management & RBAC'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: isAdminOrManager
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGeneralSettings(context, db, user, role),
                    const UserManagementScreen(),
                  ],
                )
              : _buildGeneralSettings(context, db, user, role),
        ),
      ],
    );
  }

  Widget _buildGeneralSettings(BuildContext context, dynamic db, AppUser user, Role role) {
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current User Profile Card
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Authenticated Session', style: AppTextStyles.h3),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U',
                        style: const TextStyle(color: AppColors.sidebarBackground, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(user.name, style: AppTextStyles.h2),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                role.name.toUpperCase(),
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        Text('${user.email} • Mobile: ${user.mobile}', style: AppTextStyles.subtitle),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Company Details Card
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Company Legal & Tax Profile', style: AppTextStyles.h3),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: AppConstants.companyName,
                        decoration: const InputDecoration(labelText: 'Company Legal Name'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: '27AABCD1234F1Z8',
                        decoration: const InputDecoration(labelText: 'Company GSTIN'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: 'accounting@deluxex.com',
                        decoration: const InputDecoration(labelText: 'Official Billing Email'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: '+91 (022) 2899-4400',
                        decoration: const InputDecoration(labelText: 'Support Phone'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Application Version Card
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('de luxex ERP Platform', style: AppTextStyles.bodyBold),
                    Text('${AppConstants.appVersion} • Enterprise Edition', style: AppTextStyles.bodySmall),
                  ],
                ),
                ErpButton(
                  text: 'Save Preferences',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Preferences saved successfully!'), backgroundColor: AppColors.success),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
