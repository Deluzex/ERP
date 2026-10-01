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
    final isAdminOrManager = user.hasPermission(ErpModule.settings, ErpAction.edit, db.roles);

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 850;

              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('System Configuration & Access Control', style: AppTextStyles.h1),
                  const SizedBox(height: 2),
                  Text('Configure company profile, security matrices, and user account credentials', style: AppTextStyles.subtitle),
                ],
              );


              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    if (isAdminOrManager) ...[
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          tabs: const [
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune_rounded, size: 16),
                                  SizedBox(width: 8),
                                  Text('System & Company Preferences'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.admin_panel_settings_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('User Management & RBAC'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleBlock),
                  if (isAdminOrManager)
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded, size: 16),
                              SizedBox(width: 8),
                              Text('System & Company Preferences'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
              );
            },
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              Text(user.name, style: AppTextStyles.h2),
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
                          const SizedBox(height: 4),
                          Text('${user.email} • Mobile: ${user.mobile}', style: AppTextStyles.subtitle),
                        ],
                      ),
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
                LayoutBuilder(
                  builder: (context, box) {
                    final isCompact = box.maxWidth < 600;

                    final nameField = TextFormField(
                      initialValue: AppConstants.companyName,
                      decoration: const InputDecoration(labelText: 'Company Legal Name'),
                    );

                    final gstinField = TextFormField(
                      initialValue: '27AABCD1234F1Z8',
                      decoration: const InputDecoration(labelText: 'Company GSTIN'),
                    );

                    final emailField = TextFormField(
                      initialValue: 'accounting@deluxex.com',
                      decoration: const InputDecoration(labelText: 'Official Billing Email'),
                    );

                    final phoneField = TextFormField(
                      initialValue: '+91 (022) 2899-4400',
                      decoration: const InputDecoration(labelText: 'Support Phone'),
                    );

                    if (isCompact) {
                      return Column(
                        children: [
                          nameField,
                          const SizedBox(height: 14),
                          gstinField,
                          const SizedBox(height: 14),
                          emailField,
                          const SizedBox(height: 14),
                          phoneField,
                        ],
                      );
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: nameField),
                            const SizedBox(width: 16),
                            Expanded(child: gstinField),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: emailField),
                            const SizedBox(width: 16),
                            Expanded(child: phoneField),
                          ],
                        ),
                      ],
                    );
                  },
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
            child: LayoutBuilder(
              builder: (context, box) {
                final isNarrow = box.maxWidth < 500;
                final info = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('de luxex ERP Platform', style: AppTextStyles.bodyBold),
                    Text('${AppConstants.appVersion} • Enterprise Edition', style: AppTextStyles.bodySmall),
                  ],
                );
                final btn = ErpButton(
                  text: 'Save Preferences',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Preferences saved successfully!'), backgroundColor: AppColors.success),
                    );
                  },
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      info,
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: btn),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 12),
                    btn,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
