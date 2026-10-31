import 'erp_toast.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';
import '../../shared/providers/app_state_providers.dart';
import '../../shared/widgets/low_stock_whatsapp_alert_dialog.dart';
import '../../shared/widgets/notifications_center_dialog.dart';
import '../../shared/widgets/subscription_badge_pill.dart';

class ErpHeader extends ConsumerWidget {
  final VoidCallback? onMenuToggle;

  const ErpHeader({
    super.key,
    this.onMenuToggle,
  });

  String _resolvePageTitle(WidgetRef ref) {
    final activeRecordStack = ref.watch(activeRecordDetailsStackProvider);
    if (activeRecordStack.isNotEmpty) {
      final details = activeRecordStack.last;
      switch (details.recordType) {
        case 'rawMaterial':
          return 'Inventory';
        case 'purchase':
          return 'Purchase';
        case 'production':
          return 'Production';
        case 'quotation':
        case 'proformaInvoice':
        case 'salesOrder':
        case 'delivery':
        case 'invoice':
        case 'salesReturn':
          return 'Sales';
        case 'payment':
          return 'Payments';
        case 'vendor':
        case 'customer':
        case 'dealer':
        case 'architect':
        case 'project':
          return 'Masters';
        default:
          return 'Dashboard';
      }
    }

    final currentSection = ref.watch(currentNavSectionProvider);

    switch (currentSection) {
      case ErpNavSection.dashboard:
        return 'Dashboard';
      case ErpNavSection.inventoryDashboard:
      case ErpNavSection.rawMaterialStock:
      case ErpNavSection.finishedProductStock:
      case ErpNavSection.stockMovement:
      case ErpNavSection.stockAdjustments:
        return 'Inventory';
      case ErpNavSection.purchaseDashboard:
      case ErpNavSection.purchaseList:
      case ErpNavSection.purchaseHistory:
      case ErpNavSection.createPurchase:
      case ErpNavSection.vendorPayments:
        return 'Purchase';
      case ErpNavSection.productionDashboard:
      case ErpNavSection.productionOrders:
      case ErpNavSection.productionHistory:
      case ErpNavSection.createProduction:
      case ErpNavSection.productionCosting:
        return 'Production';
      case ErpNavSection.salesDashboard:
      case ErpNavSection.quotations:
      case ErpNavSection.createQuotation:
      case ErpNavSection.proformaInvoices:
      case ErpNavSection.salesOrders:
      case ErpNavSection.createSalesOrder:
      case ErpNavSection.salesDeliveries:
      case ErpNavSection.salesInvoiceList:
      case ErpNavSection.createSale:
      case ErpNavSection.salesReturns:
      case ErpNavSection.createSalesReturn:
        return 'Sales';
      case ErpNavSection.paymentsDashboard:
      case ErpNavSection.customerPayments:
      case ErpNavSection.dealerPayments:
      case ErpNavSection.vendorPaymentsSection:
      case ErpNavSection.commissionPayments:
      case ErpNavSection.expenseList:
        return 'Payments';
      case ErpNavSection.mastersDashboard:
      case ErpNavSection.categoriesUnits:
      case ErpNavSection.vendors:
      case ErpNavSection.customers:
      case ErpNavSection.dealers:
      case ErpNavSection.architects:
      case ErpNavSection.rawMaterials:
      case ErpNavSection.finishedProducts:
      case ErpNavSection.billOfMaterials:
      case ErpNavSection.projectList:
      case ErpNavSection.createProject:
        return 'Masters';
      case ErpNavSection.reportsDashboard:
      case ErpNavSection.inventoryReports:
      case ErpNavSection.purchaseReports:
      case ErpNavSection.productionReports:
      case ErpNavSection.salesReports:
      case ErpNavSection.projectReports:
      case ErpNavSection.commissionReports:
      case ErpNavSection.financialReports:
        return 'Reports';
      case ErpNavSection.chatSupport:
        return 'Chat Support';
      case ErpNavSection.settings:
        return 'Settings';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageTitle = _resolvePageTitle(ref);
    final db = ref.watch(databaseServiceProvider);
    final currentUser = ref.watch(currentUserProvider) ?? db.currentUser;
    // final canViewLowStock = db.canViewLowStockAlerts(currentUser);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isDesktop = MediaQuery.of(context).size.width >= 1024;
        // final showLowStockPill = availableWidth >= 780 && canViewLowStock;
        final isMobile = availableWidth < 500;
        final hideUserDetails = availableWidth < 900;

        return Container(
          height: 64,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
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
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                const SizedBox(width: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SvgPicture.asset(
                    'assets/images/deluzex_tab_logo.svg',
                    height: 28,
                    width: 28,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Current Page / Module Title (replacing top global search)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    pageTitle,
                    style: isMobile
                        ? AppTextStyles.bodyBold.copyWith(fontSize: 15, color: AppColors.textPrimary)
                        : AppTextStyles.h2.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              SizedBox(width: isMobile ? 6 : 10),

              // Low Stock Alert Quick Button if low stock exists and user role is authorized
              // if (showLowStockPill)
              //   Builder(
              //     builder: (context) {
              //       final lowCount = db.getLowStockCountForUser(currentUser);
              //       if (lowCount == 0) return const SizedBox.shrink();
              //       final label = db.getLowStockAlertLabelForUser(currentUser);
              //
              //       return Container(
              //         margin: const EdgeInsets.only(right: 6),
              //         child: InkWell(
              //           onTap: () => LowStockWhatsAppAlertDialog.show(context),
              //           borderRadius: BorderRadius.circular(20),
              //           child: Container(
              //             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              //             decoration: BoxDecoration(
              //               color: AppColors.danger.withValues(alpha: 0.12),
              //               borderRadius: BorderRadius.circular(20),
              //               border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              //             ),
              //             child: Row(
              //               mainAxisSize: MainAxisSize.min,
              //               children: [
              //                 const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 16),
              //                 const SizedBox(width: 6),
              //                 Text(
              //                   label,
              //                   style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 11.5),
              //                 ),
              //                 const SizedBox(width: 4),
              //                 const Icon(Icons.arrow_forward_ios, color: AppColors.danger, size: 10),
              //               ],
              //             ),
              //           ),
              //         ),
              //       );
              //     },
              //   ),

              // Instance Subscription Status Pill
              const SubscriptionBadgePill(),
              SizedBox(width: isMobile ? 4 : 8),

              // Notification Bell with dynamic unread badge
              Builder(
                builder: (context) {
                  final unreadCount = db.getUnreadNotificationCount(currentUser);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: unreadCount > 0
                            ? '$unreadCount Unread Notification(s)'
                            : 'Notifications & Alerts',
                        icon: Icon(
                          unreadCount > 0
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          color: unreadCount > 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () => NotificationsCenterDialog.show(context),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              SizedBox(width: isMobile ? 4 : 8),

              // User Profile Popup Menu
              _buildUserProfileMenu(context, ref, hideUserDetails),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserProfileMenu(BuildContext context, WidgetRef ref, bool hideUserDetails) {
    final db = ref.watch(databaseServiceProvider);
    final user = ref.watch(currentUserProvider) ?? db.currentUser;
    final role = db.getUserRole(user);

    return PopupMenuButton<String>(
      tooltip: 'User Profile & Session',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hideUserDetails ? 6 : 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.primary,
              child: Text(
                user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            if (!hideUserDetails) ...[
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
            ],
            const SizedBox(width: 4),
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
ErpToast.showSuccess(context, 'Password updated successfully!');
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
      builder: (ctx) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
          title: const Text('Quick Switch Demo Role'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select an authorized demo user to immediately test that role-specific dashboard and permissions matrix.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: screenHeight * 0.58),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: db.users.map<Widget>((u) {
                        final r = db.getUserRole(u);
                        final initial = u.name.isNotEmpty ? u.name.substring(0, 1).toUpperCase() : 'U';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primaryLight,
                            child: Text(
                              initial,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                            ),
                          ),
                          title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('${r.name} • ${u.email}', style: const TextStyle(fontSize: 11)),
                          onTap: () {
                            ref.read(authStateProvider.notifier).switchUser(u);
                            Navigator.of(ctx).pop();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ],
        );
      },
    );
  }
}
