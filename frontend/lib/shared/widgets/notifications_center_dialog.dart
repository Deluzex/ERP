import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/models/notification_model.dart';
import '../providers/app_state_providers.dart';
import '../services/mock_database_service.dart';
import 'low_stock_whatsapp_alert_dialog.dart';

class NotificationsCenterDialog extends ConsumerStatefulWidget {
  const NotificationsCenterDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const NotificationsCenterDialog(),
    );
  }

  @override
  ConsumerState<NotificationsCenterDialog> createState() => _NotificationsCenterDialogState();
}

class _NotificationsCenterDialogState extends ConsumerState<NotificationsCenterDialog>
    with SingleTickerProviderStateMixin {
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

  void _navigateToRecord(NotificationItem notif, WidgetRef ref) {
    Navigator.of(context).pop();

    final reqType = notif.requestType.toLowerCase();
    final route = notif.route;

    if (route != null && route.isNotEmpty) {
      if (route.contains('purchase')) {
        ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseList;
      } else if (route.contains('production')) {
        ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionOrders;
      } else if (route.contains('sales')) {
        ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesOrders;
      }
      return;
    }

    if (reqType.contains('purchase')) {
      ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseList;
    } else if (reqType.contains('production')) {
      ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionOrders;
    } else {
      ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesOrders;
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final user = db.currentUser;
    final allNotifs = db.getNotificationsForUser(user);
    final unreadNotifs = allNotifs.where((n) => !n.isRead).toList();
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Container(
        width: 720,
        height: 640,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notifications & Action Center', style: AppTextStyles.h2),
                      const SizedBox(height: 2),
                      Text(
                        'Authorized for: ${user.name} (${db.getUserRole(user).name})',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (unreadNotifs.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Mark all read'),
                    onPressed: () {
                      db.markAllNotificationsAsRead(user);
                      db.markAllNotificationsAsReadAsync();
                    },
                  ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tab Bar with unread counts
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'All (${allNotifs.length})'),
                Tab(text: 'Unread (${unreadNotifs.length})'),
              ],
            ),
            const SizedBox(height: 12),

            // Tab View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNotificationList(context, db, allNotifs, isMobile),
                  _buildNotificationList(context, db, unreadNotifs, isMobile),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Bottom bar with WhatsApp Buffer Alerts shortcut
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${allNotifs.length} notification(s) visible for role',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (db.canViewLowStockAlerts(user))
                  TextButton.icon(
                    icon: const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                    label: const Text('WhatsApp Buffer Alerts'),
                    onPressed: () {
                      Navigator.pop(context);
                      LowStockWhatsAppAlertDialog.show(context);
                    },
                  ),
              ],
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(
    BuildContext context,
    MockDatabaseService db,
    List<NotificationItem> items,
    bool isMobile,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('No notifications found', style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('You are all caught up for your role.', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final notif = items[idx];
        final isPurchase = notif.notificationType.contains('purchase') ||
            notif.requestType.toLowerCase().contains('purchase');
        final isProduction = notif.notificationType.contains('production') ||
            notif.requestType.toLowerCase().contains('production');

        final iconColor = isPurchase
            ? AppColors.primary
            : (isProduction ? AppColors.warning : AppColors.info);
        final iconData = isPurchase
            ? Icons.shopping_cart_outlined
            : (isProduction ? Icons.precision_manufacturing_outlined : Icons.info_outline);

        return InkWell(
          onTap: () {
            if (!notif.isRead) {
              db.markNotificationAsRead(notif.id);
              db.markNotificationAsReadAsync(notif.id);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: notif.isRead ? AppColors.surface : AppColors.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: notif.isRead ? AppColors.border : AppColors.primary.withOpacity(0.3),
                width: notif.isRead ? 1 : 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Type badge, title, time, read status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(iconData, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  notif.requestType.toUpperCase(),
                                  style: AppTextStyles.caption.copyWith(
                                    color: iconColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  notif.title,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTimeAgo(notif.createdAt),
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (!notif.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Message text
                Text(notif.message, style: AppTextStyles.bodySmall),

                // Metadata breakdown Box
                if (notif.salesOrderNumber != null || notif.productSku != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (notif.salesOrderNumber != null)
                          Text(
                            'SO: ${notif.salesOrderNumber}',
                            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                          ),
                        if (notif.customerName != null)
                          Text(
                            'Customer: ${notif.customerName}',
                            style: AppTextStyles.caption,
                          ),
                        if (notif.productSku != null)
                          Text(
                            'SKU: ${notif.productSku}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                          ),
                        if (notif.requestedQuantity != null && notif.availableStock != null)
                          Text(
                            'Req: ${notif.requestedQuantity} | Avail: ${notif.availableStock}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                          ),
                      ],
                    ),
                  ),
                ],

                // Action button to open record
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!notif.isRead)
                      TextButton(
                        onPressed: () {
                          db.markNotificationAsRead(notif.id);
                          db.markNotificationAsReadAsync(notif.id);
                        },
                        child: const Text('Mark as Read', style: TextStyle(fontSize: 12)),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: Text('Open ${notif.requestType} Module'),
                      onPressed: () => _navigateToRecord(notif, ref),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
