import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/rbac_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/api/roles_api_service.dart';
import '../../../shared/providers/app_state_providers.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _userSearchQuery = '';
  String _roleSearchQuery = '';
  String _auditSearchQuery = '';
  String _auditFilterStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadUsers();
      ref.read(databaseServiceProvider).loadRoles();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Add / Edit User Modal ---
  void _openAddEditUserDialog([AppUser? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final mobileCtrl = TextEditingController(text: existing?.mobile ?? '');
    final passwordCtrl = TextEditingController(text: '');
    String selectedPrimaryRoleId = existing?.primaryRoleId ?? 'data_entry';
    List<String> assignedRoleIds = List.from(existing?.assignedRoleIds ?? []);
    bool isActive = existing?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEdit ? 'Edit ERP User' : 'Add New ERP User', style: AppTextStyles.h2),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: nameCtrl,
                                validator: (v) => Validators.requiredField(v, 'Full Name required'),
                                decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline, size: 18)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: mobileCtrl,
                                validator: (v) => Validators.requiredField(v, 'Mobile required'),
                                decoration: const InputDecoration(labelText: 'Mobile Number *', prefixIcon: Icon(Icons.phone_outlined, size: 18)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: emailCtrl,
                          validator: Validators.email,
                          decoration: const InputDecoration(labelText: 'Work Email Address *', prefixIcon: Icon(Icons.email_outlined, size: 18)),
                        ),
                        if (!isEdit) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: passwordCtrl,
                            obscureText: true,
                            validator: (v) => Validators.requiredField(v, 'Initial Password required'),
                            decoration: const InputDecoration(labelText: 'Initial Password *', prefixIcon: Icon(Icons.lock_outline, size: 18)),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Primary Role Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedPrimaryRoleId,
                          decoration: const InputDecoration(
                            labelText: 'Primary Role (Determines Landing Dashboard & Menus) *',
                            prefixIcon: Icon(Icons.shield_outlined, size: 18),
                          ),
                          items: db.roles.map((r) => DropdownMenuItem(
                            value: r.id,
                            child: Text('${r.name} ${r.isSystemRole ? "(Default Role)" : "(Custom)"}'),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() => selectedPrimaryRoleId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 18),

                        // Additional Secondary Roles for Multi-Department Access
                        Text('Additional Secondary Roles (Optional Multi-Department Access)', style: AppTextStyles.bodyBold.copyWith(fontSize: 12.5)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: db.roles.where((r) => r.id != selectedPrimaryRoleId).map((r) {
                            final isChecked = assignedRoleIds.contains(r.id);
                            return FilterChip(
                              label: Text(r.name, style: TextStyle(fontSize: 11.5, color: isChecked ? Colors.purple.shade900 : Colors.black87)),
                              selected: isChecked,
                              selectedColor: Colors.purple.withValues(alpha: 0.15),
                              onSelected: (selected) {
                                setDlgState(() {
                                  if (selected) {
                                    assignedRoleIds.add(r.id);
                                  } else {
                                    assignedRoleIds.remove(r.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Active / Deactivated Switch
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Account Status: ${isActive ? "Active (Can Log in)" : "Deactivated (Locked)"}', style: AppTextStyles.bodyBold),
                          subtitle: Text(isActive ? 'User can authenticate and access authorized ERP features.' : 'User is blocked from logging in.', style: AppTextStyles.caption),
                          value: isActive,
                          activeColor: AppColors.success,
                          onChanged: (val) => setDlgState(() => isActive = val),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                ErpButton(text: 'Cancel', isOutlined: true, onPressed: () => Navigator.of(ctx).pop()),
                ErpButton(
                  text: isEdit ? 'Save Changes' : 'Create User',
                  icon: isEdit ? Icons.save : Icons.add,
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        if (isEdit) {
                          await db.updateUserAsync(
                            existing.id,
                            name: nameCtrl.text.trim(),
                            mobile: mobileCtrl.text.trim(),
                            primaryRoleId: selectedPrimaryRoleId,
                            assignedRoleIds: assignedRoleIds,
                            isActive: isActive,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('User ${nameCtrl.text.trim()} updated successfully!'), backgroundColor: AppColors.success),
                            );
                          }
                        } else {
                          await db.addUserAsync(
                            name: nameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            mobile: mobileCtrl.text.trim(),
                            password: passwordCtrl.text.trim(),
                            primaryRoleId: selectedPrimaryRoleId,
                            assignedRoleIds: assignedRoleIds,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('New User ${nameCtrl.text.trim()} created!'), backgroundColor: AppColors.success),
                            );
                          }
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: AppColors.danger),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Reset Password Modal ---
  void _openResetPasswordDialog(AppUser user) {
    final db = ref.read(databaseServiceProvider);
    final pwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password for ${user.name}', style: AppTextStyles.h2),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter a new secure password for this user account (${user.email}).', style: AppTextStyles.bodySmall),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pwdCtrl,
                  obscureText: true,
                  validator: (v) => Validators.requiredField(v, 'New password required'),
                  decoration: const InputDecoration(labelText: 'New Password *', prefixIcon: Icon(Icons.lock_reset)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ErpButton(text: 'Cancel', isOutlined: true, onPressed: () => Navigator.of(ctx).pop()),
          ErpButton(
            text: 'Reset Password',
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await db.resetUserPasswordAsync(user.id, pwdCtrl.text.trim());
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Password for ${user.name} reset successfully!'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to reset password: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // --- Add / Edit Custom Role with Permission Matrix ---
  void _openAddEditRoleDialog([Role? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    ErpNavSection selectedDashboard = existing?.defaultDashboardSection ?? ErpNavSection.dashboard;
    bool isActive = existing?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    // Copy existing permissions or initialize empty matrix
    final Map<ErpModule, Set<ErpAction>> permMatrix = {};
    for (final mod in ErpModule.values) {
      permMatrix[mod] = Set.from(existing?.permissions[mod] ?? {});
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return Dialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorderRadius),
              child: Container(
                width: 960,
                height: 720,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isEdit ? 'Edit Role: ${existing.name}' : 'Create Custom ERP Role', style: AppTextStyles.h2),
                            const SizedBox(height: 2),
                            Text('Configure granular Module and Action permission matrix', style: AppTextStyles.subtitle),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                      ],
                    ),
                    const Divider(height: 24),

                    // Top Metadata inputs
                    Form(
                      key: formKey,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: nameCtrl,
                              validator: (v) => Validators.requiredField(v, 'Role Name required'),
                              decoration: const InputDecoration(labelText: 'Role Title *', hintText: 'e.g. Regional Sales Executive'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: descCtrl,
                              decoration: const InputDecoration(labelText: 'Role Description', hintText: 'Describe department scope & duties'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<ErpNavSection>(
                              value: selectedDashboard,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Default Landing Dashboard'),
                              items: const [
                                DropdownMenuItem(value: ErpNavSection.dashboard, child: Text('Admin Full Dashboard')),
                                DropdownMenuItem(value: ErpNavSection.inventoryDashboard, child: Text('Inventory Dashboard')),
                                DropdownMenuItem(value: ErpNavSection.purchaseList, child: Text('Purchase Dashboard')),
                                DropdownMenuItem(value: ErpNavSection.productionOrders, child: Text('Production Dashboard')),
                                DropdownMenuItem(value: ErpNavSection.salesDashboard, child: Text('Sales Dashboard')),
                                DropdownMenuItem(value: ErpNavSection.customerPayments, child: Text('Accounts / Payment Dashboard')),
                                DropdownMenuItem(value: ErpNavSection.projectList, child: Text('Project Dashboard')),
                                DropdownMenuItem(value: ErpNavSection.inventoryReports, child: Text('Reports Analytics Dashboard')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDlgState(() => selectedDashboard = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Select All / None Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Granular Permission Matrix (10 Modules x 9 Actions)', style: AppTextStyles.h3),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.select_all, size: 16),
                              label: const Text('Grant Full Access', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                setDlgState(() {
                                  for (final mod in ErpModule.values) {
                                    permMatrix[mod] = ErpAction.values.toSet();
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.deselect, size: 16),
                              label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                setDlgState(() {
                                  for (final mod in ErpModule.values) {
                                    permMatrix[mod] = {};
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Interactive Matrix Table
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: AppRadius.mdBorderRadius,
                        ),
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppColors.surfaceMuted),
                            columnSpacing: 18,
                            horizontalMargin: 12,
                            columns: [
                              const DataColumn(label: Text('Module', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              ...ErpAction.values.map((act) => DataColumn(
                                    label: Text(act.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  )),
                            ],
                            rows: ErpModule.values.map((mod) {
                              final currentActions = permMatrix[mod] ?? {};
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(mod.label, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                                        IconButton(
                                          icon: const Icon(Icons.checklist, size: 14, color: AppColors.textMuted),
                                          tooltip: 'Toggle all actions for ${mod.label}',
                                          onPressed: () {
                                            setDlgState(() {
                                              if (currentActions.length == ErpAction.values.length) {
                                                permMatrix[mod] = {};
                                              } else {
                                                permMatrix[mod] = ErpAction.values.toSet();
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...ErpAction.values.map((act) {
                                    final isGranted = currentActions.contains(act);
                                    return DataCell(
                                      Checkbox(
                                        value: isGranted,
                                        activeColor: AppColors.primary,
                                        onChanged: (val) {
                                          setDlgState(() {
                                            if (val == true) {
                                              currentActions.add(act);
                                              // Auto-grant View if any action is enabled
                                              currentActions.add(ErpAction.view);
                                            } else {
                                              currentActions.remove(act);
                                            }
                                            permMatrix[mod] = currentActions;
                                          });
                                        },
                                      ),
                                    );
                                  }),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Actions footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: isActive,
                              onChanged: (v) => setDlgState(() => isActive = v ?? true),
                            ),
                            Text('Role is Active and Assignable to Users', style: AppTextStyles.bodySmall),
                          ],
                        ),
                        Row(
                          children: [
                            ErpButton(text: 'Cancel', isOutlined: true, onPressed: () => Navigator.of(ctx).pop()),
                            const SizedBox(width: 12),
                            ErpButton(
                              text: isEdit ? 'Save Role Changes' : 'Create Role',
                              icon: Icons.check,
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  try {
                                    final permStrings = RolesApiService.permissionMapToStrings(permMatrix);
                                    if (isEdit) {
                                      await db.updateRolePermissionsAsync(existing.id, permStrings);
                                      ref.read(authStateProvider.notifier).refreshUserPermissions(existing.id, permMatrix);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Role "${existing.name}" permissions updated!'), backgroundColor: AppColors.success),
                                        );
                                      }
                                    } else {
                                      final roleId = 'role_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                                      await db.addRoleAsync(
                                        id: roleId,
                                        name: nameCtrl.text.trim(),
                                        description: descCtrl.text.trim(),
                                        permissions: permStrings,
                                        defaultDashboardSection: selectedDashboard.name,
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('New Role "${nameCtrl.text.trim()}" created!'), backgroundColor: AppColors.success),
                                        );
                                      }
                                    }
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Role operation failed: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: AppColors.danger),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteRole(Role role) {
    if (role.isSystemRole) return;
    final db = ref.read(databaseServiceProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Role "${role.name}"?', style: AppTextStyles.h2),
        content: Text(
          'Are you sure you want to permanently delete the custom role "${role.name}" (${role.id})? This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          ErpButton(text: 'Cancel', isOutlined: true, onPressed: () => Navigator.of(ctx).pop()),
          ErpButton(
            text: 'Delete Role',
            isDanger: true,
            onPressed: () async {
              try {
                await db.deleteRoleAsync(role.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Role "${role.name}" deleted successfully!'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete role: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUserStatus(AppUser user) async {
    final db = ref.read(databaseServiceProvider);
    final willBeActive = !user.isActive;
    try {
      await db.toggleUserStatusAsync(user.id, willBeActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "${user.name}" ${willBeActive ? "reactivated" : "deactivated"} successfully!'),
            backgroundColor: willBeActive ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final filteredUsers = db.users.where((u) {
      final q = _userSearchQuery.toLowerCase();
      return u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q) || u.mobile.contains(q);
    }).toList();

    final filteredRoles = db.roles.where((r) {
      final q = _roleSearchQuery.toLowerCase();
      return r.name.toLowerCase().contains(q) || r.description.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User & Role Access Management (RBAC)', style: AppTextStyles.h1),
              const SizedBox(height: 4),
              Text('Manage ERP operators, primary & multi-department roles, and granular permission matrices', style: AppTextStyles.subtitle),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 16),
                      const SizedBox(width: 8),
                      Text('Users Directory (${db.users.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, size: 16),
                      const SizedBox(width: 8),
                      Text('Roles & Permission Matrix (${db.roles.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.history_edu_rounded, size: 16),
                      const SizedBox(width: 8),
                      Text('Security Audit Trail (${db.auditLogs.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Content Area
          SizedBox(
            height: 650,
            child: TabBarView(
              controller: _tabController,
              children: [
                // -------------------------------------------------------------
                // TAB 1: USERS DIRECTORY
                // -------------------------------------------------------------
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: TextField(
                              onChanged: (val) => setState(() => _userSearchQuery = val),
                              decoration: const InputDecoration(
                                hintText: 'Search user by name, email, or mobile...',
                                prefixIcon: Icon(Icons.search, size: 18),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        ErpButton(
                          text: 'Add New User',
                          icon: Icons.person_add_alt_1,
                          onPressed: () => _openAddEditUserDialog(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ErpDataTable(
                        columns: const [
                          ErpColumn(title: 'User Name & Avatar'),
                          ErpColumn(title: 'Work Email & Contact'),
                          ErpColumn(title: 'Primary Role'),
                          ErpColumn(title: 'Secondary Roles'),
                          ErpColumn(title: 'Status'),
                          ErpColumn(title: 'Last Login'),
                          ErpColumn(title: 'Actions'),
                        ],
                        rows: filteredUsers.map((u) {
                          final roleObj = db.getRole(u.primaryRoleId);
                          final secondaryRoles = u.assignedRoleIds.map((rid) => db.getRole(rid)?.name).whereType<String>().toList();

                          return [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                  child: Text(
                                    u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(u.name, style: AppTextStyles.bodyBold),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(u.email, style: AppTextStyles.bodySmall),
                                Text(u.mobile, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                roleObj?.name ?? u.primaryRoleId,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                            secondaryRoles.isEmpty
                                ? const Text('-', style: TextStyle(color: Colors.grey))
                                : Text(secondaryRoles.join(', '), style: AppTextStyles.caption),
                            u.isActive ? ErpStatusBadge.success('ACTIVE') : ErpStatusBadge.danger('DEACTIVATED'),
                            Text(u.lastLoginAt != null ? Formatters.formatDate(u.lastLoginAt!) : 'Never logged in', style: AppTextStyles.caption),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Edit User Profile & Roles',
                                  onPressed: () => _openAddEditUserDialog(u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.lock_reset, size: 18, color: Colors.orange),
                                  tooltip: 'Reset Password',
                                  onPressed: () => _openResetPasswordDialog(u),
                                ),
                                IconButton(
                                  icon: Icon(u.isActive ? Icons.block : Icons.check_circle_outline, size: 18, color: u.isActive ? Colors.red : Colors.green),
                                  tooltip: u.isActive ? 'Deactivate User Account' : 'Reactivate User Account',
                                  onPressed: () => _toggleUserStatus(u),
                                ),
                              ],
                            ),
                          ];
                        }).toList(),
                      ),
                    ),
                  ],
                ),

                // -------------------------------------------------------------
                // TAB 2: ROLES & PERMISSIONS
                // -------------------------------------------------------------
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: TextField(
                              onChanged: (val) => setState(() => _roleSearchQuery = val),
                              decoration: const InputDecoration(
                                hintText: 'Search role title or scope...',
                                prefixIcon: Icon(Icons.search, size: 18),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        ErpButton(
                          text: 'Create Custom Role',
                          icon: Icons.add_moderator_outlined,
                          onPressed: () => _openAddEditRoleDialog(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ErpDataTable(
                        columns: const [
                          ErpColumn(title: 'Role Name'),
                          ErpColumn(title: 'Role Scope & Description'),
                          ErpColumn(title: 'Assigned Users Count', isNumeric: true),
                          ErpColumn(title: 'Role Type'),
                          ErpColumn(title: 'Landing Dashboard'),
                          ErpColumn(title: 'Actions'),
                        ],
                        rows: filteredRoles.map((r) {
                          final userCount = db.users.where((u) => u.primaryRoleId == r.id || u.assignedRoleIds.contains(r.id)).length;

                          return [
                            Text(r.name, style: AppTextStyles.bodyBold),
                            Text(r.description, style: AppTextStyles.bodySmall),
                            Text('$userCount Users', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                            r.isSystemRole
                                ? ErpStatusBadge.info('DEFAULT SYSTEM ROLE')
                                : ErpStatusBadge.neutral('CUSTOM ROLE'),
                            Text(r.defaultDashboardSection.name, style: AppTextStyles.caption),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_note, size: 20, color: AppColors.primary),
                                  tooltip: 'Configure Permissions & Matrix',
                                  onPressed: () => _openAddEditRoleDialog(r),
                                ),
                                if (!r.isSystemRole)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                                    tooltip: 'Delete Role',
                                    onPressed: () => _confirmDeleteRole(r),
                                  ),
                              ],
                            ),
                          ];
                        }).toList(),
                      ),
                    ),
                  ],
                ),

                // -------------------------------------------------------------
                // TAB 3: SECURITY & ACCESS AUDIT TRAIL
                // -------------------------------------------------------------
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter bar & Search
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: TextField(
                              onChanged: (val) => setState(() => _auditSearchQuery = val),
                              decoration: const InputDecoration(
                                hintText: 'Search user, module, authorizer...',
                                prefixIcon: Icon(Icons.search, size: 18),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('All Events'),
                              selected: _auditFilterStatus == 'ALL',
                              onSelected: (_) => setState(() => _auditFilterStatus = 'ALL'),
                            ),
                            ChoiceChip(
                              label: const Text('Allowed Access'),
                              selected: _auditFilterStatus == 'ALLOWED',
                              selectedColor: Colors.green.withValues(alpha: 0.2),
                              onSelected: (_) => setState(() => _auditFilterStatus = 'ALLOWED'),
                            ),
                            ChoiceChip(
                              label: const Text('Access Denied'),
                              selected: _auditFilterStatus == 'DENIED',
                              selectedColor: Colors.red.withValues(alpha: 0.2),
                              onSelected: (_) => setState(() => _auditFilterStatus = 'DENIED'),
                            ),
                            ChoiceChip(
                              label: const Text('Temporary Overrides'),
                              selected: _auditFilterStatus == 'OVERRIDE',
                              selectedColor: Colors.purple.withValues(alpha: 0.2),
                              onSelected: (_) => setState(() => _auditFilterStatus = 'OVERRIDE'),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (db.temporaryGrants.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_clock, size: 16, color: Colors.purple),
                                const SizedBox(width: 6),
                                Text(
                                  '${db.temporaryGrants.length} Active Temp Grant(s)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Active Temporary Grants Card
                    if (db.temporaryGrants.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.05),
                          borderRadius: AppRadius.mdBorderRadius,
                          border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key_rounded, color: Colors.purple, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Active Supervisor Overrides: ${db.temporaryGrants.map((g) {
                                  final u = db.getUser(g.grantedToUserId);
                                  final targetName = u?.name ?? g.grantedToUserId;
                                  final timeStr = g.expiresAt != null ? Formatters.formatTime(g.expiresAt!) : 'Session Only';
                                  return '$targetName -> ${g.module.label} (until $timeStr by ${g.grantedByName})';
                                }).join(" | ")}',
                                style: AppTextStyles.caption.copyWith(color: Colors.purple.shade900, fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.block, size: 14, color: Colors.red),
                              label: const Text('Revoke All Overrides', style: TextStyle(fontSize: 11.5, color: Colors.red)),
                              onPressed: () {
                                for (final g in List.from(db.temporaryGrants)) {
                                  db.revokeTemporaryAccess(g.id);
                                }
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('All temporary supervisor overrides revoked.'), backgroundColor: AppColors.warning),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Audit Logs Data Table
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final logs = db.auditLogs.where((log) {
                            final q = _auditSearchQuery.toLowerCase();
                            final matchesQuery = q.isEmpty ||
                                log.userName.toLowerCase().contains(q) ||
                                log.userRole.toLowerCase().contains(q) ||
                                log.module.label.toLowerCase().contains(q) ||
                                (log.authorizingUserName?.toLowerCase().contains(q) ?? false) ||
                                (log.notes?.toLowerCase().contains(q) ?? false);

                            if (!matchesQuery) return false;

                            if (_auditFilterStatus == 'ALLOWED') {
                              return log.status == 'allowed';
                            } else if (_auditFilterStatus == 'DENIED') {
                              return log.status == 'denied';
                            } else if (_auditFilterStatus == 'OVERRIDE') {
                              return log.status == 'temporaryGranted';
                            }
                            return true;
                          }).toList();

                          return ErpDataTable(
                            columns: const [
                              ErpColumn(title: 'Timestamp'),
                              ErpColumn(title: 'User & Role'),
                              ErpColumn(title: 'Target Module / Section'),
                              ErpColumn(title: 'Action'),
                              ErpColumn(title: 'Access Status'),
                              ErpColumn(title: 'Authorizer / Supervisor'),
                              ErpColumn(title: 'Duration / Notes'),
                            ],
                            rows: logs.map((log) {
                              Widget statusBadge;
                              if (log.status == 'allowed') {
                                statusBadge = ErpStatusBadge.success('ACCESS ALLOWED');
                              } else if (log.status == 'denied') {
                                statusBadge = ErpStatusBadge.danger('ACCESS DENIED');
                              } else {
                                statusBadge = Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.vpn_key_rounded, size: 12, color: Colors.purple),
                                      const SizedBox(width: 4),
                                      Text('TEMP OVERRIDE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade800)),
                                    ],
                                  ),
                                );
                              }

                              return [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(Formatters.formatDate(log.timestamp), style: AppTextStyles.bodySmall),
                                    Text(Formatters.formatTime(log.timestamp), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(log.userName, style: AppTextStyles.bodyBold),
                                    Text('Role: ${log.userRole}', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                                  ],
                                ),
                                Text(
                                  log.sectionName != null ? '${log.module.label} (${log.sectionName})' : log.module.label,
                                  style: AppTextStyles.bodySmall,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(log.action.label.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                                ),
                                statusBadge,
                                log.authorizingUserName != null
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.verified_user, size: 14, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(log.authorizingUserName!, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                                        ],
                                      )
                                    : const Text('-', style: TextStyle(color: Colors.grey)),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (log.durationMinutes != null)
                                      Text('Duration: ${log.durationMinutes} min', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple)),
                                    if (log.notes != null)
                                      Text(log.notes!, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                                  ],
                                ),
                              ];
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
