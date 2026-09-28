import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/models/finished_product_model.dart';
import '../../core/models/raw_material_model.dart';
import '../../core/models/stock_movement_model.dart';
import '../../core/models/whatsapp_models.dart';
import '../../core/utils/document_sharing_service.dart';
import '../../core/utils/id_generator.dart';
import '../../core/widgets/erp_button.dart';
import '../../core/widgets/erp_data_table.dart';
import '../../core/widgets/erp_status_badge.dart';
import '../providers/app_state_providers.dart';

class LowStockWhatsAppAlertDialog extends ConsumerStatefulWidget {
  const LowStockWhatsAppAlertDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const LowStockWhatsAppAlertDialog(),
    );
  }

  @override
  ConsumerState<LowStockWhatsAppAlertDialog> createState() => _LowStockWhatsAppAlertDialogState();
}

class _LowStockWhatsAppAlertDialogState extends ConsumerState<LowStockWhatsAppAlertDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _sendAlertToRecipient(dynamic item, bool isRawMaterial, WhatsAppAlertRecipient recipient) {
    final db = ref.read(databaseServiceProvider);
    final itemName = item.name as String;
    final itemCode = item.itemCode as String;
    final itemType = isRawMaterial ? 'Raw Material' : 'Finished Product';
    final currentStock = item.currentStock as double;
    final minStock = item.minimumStock as double;
    final reorderLevel = isRawMaterial ? (item as RawMaterial).reorderLevel : (item as FinishedProduct).minimumStock * 1.5;
    final unit = item.unit as String;

    final message = DocumentSharingService.buildLowStockAlertMessage(
      itemName: itemName,
      itemCode: itemCode,
      itemType: itemType,
      currentStock: currentStock,
      minStock: minStock,
      reorderLevel: reorderLevel,
      unit: unit,
    );

    db.triggerLowStockWhatsAppAlert(
      itemId: item.id as String,
      itemName: itemName,
      itemCode: itemCode,
      itemType: itemType,
      currentStock: currentStock,
      minStock: minStock,
      reorderLevel: reorderLevel,
      unit: unit,
      recipientName: recipient.recipientName,
      recipientWhatsApp: recipient.whatsappNumber,
      messageBody: message,
    );

    db.triggerLowStockAlertAsync(
      itemId: item.id as String,
      itemType: isRawMaterial ? ItemType.rawMaterial : ItemType.finishedProduct,
      recipientId: recipient.id,
      recipientName: recipient.recipientName,
      recipientWhatsApp: recipient.whatsappNumber,
      customMessage: message,
    );

    DocumentSharingService.shareToWhatsApp(
      phoneNumber: recipient.whatsappNumber,
      message: message,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Low Stock WhatsApp Alert dispatched to ${recipient.recipientName}!'),
        backgroundColor: const Color(0xFF25D366),
      ),
    );
  }

  void _openAddRecipientDialog([WhatsAppAlertRecipient? existing]) {
    final nameCtrl = TextEditingController(text: existing?.recipientName ?? '');
    final mobileCtrl = TextEditingController(text: existing?.mobileNumber ?? '');
    final whatsappCtrl = TextEditingController(text: existing?.whatsappNumber ?? '');
    final roleCtrl = TextEditingController(text: existing?.roleOrDepartment ?? 'Production Manager');
    WhatsAppAlertType alertType = existing?.alertType ?? WhatsAppAlertType.allLowStock;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Alert Recipient' : 'Edit Alert Recipient', style: AppTextStyles.h2),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          width: double.infinity,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Recipient Name *', hintText: 'e.g. Vikram Joshi'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: roleCtrl,
                    decoration: const InputDecoration(labelText: 'Role / Department *', hintText: 'e.g. Production Head'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Role required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: mobileCtrl,
                    decoration: const InputDecoration(labelText: 'Mobile Number *', hintText: '+91 98200 12345'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Mobile required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: whatsappCtrl,
                    decoration: const InputDecoration(labelText: 'WhatsApp Number *', hintText: '+919820012345'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'WhatsApp number required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<WhatsAppAlertType>(
                    value: alertType,
                    decoration: const InputDecoration(labelText: 'Subscribed Alert Type'),
                    items: WhatsAppAlertType.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) alertType = val;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ErpButton(
            text: existing == null ? 'Save Recipient' : 'Update',
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final db = ref.read(databaseServiceProvider);
              if (existing == null) {
                db.addAlertRecipient(WhatsAppAlertRecipient(
                  id: IdGenerator.generateId('REC'),
                  recipientName: nameCtrl.text.trim(),
                  mobileNumber: mobileCtrl.text.trim(),
                  whatsappNumber: whatsappCtrl.text.trim(),
                  roleOrDepartment: roleCtrl.text.trim(),
                  alertType: alertType,
                  createdAt: DateTime.now(),
                ));
              } else {
                db.updateAlertRecipient(existing.copyWith(
                  recipientName: nameCtrl.text.trim(),
                  mobileNumber: mobileCtrl.text.trim(),
                  whatsappNumber: whatsappCtrl.text.trim(),
                  roleOrDepartment: roleCtrl.text.trim(),
                  alertType: alertType,
                ));
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final lowRM = db.lowStockRawMaterials;
    final lowFP = db.lowStockFinishedProducts;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 650;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorderRadius),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
        width: double.infinity,
        height: size.height * 0.9,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Low Stock WhatsApp Alerts & Production Warning System', style: AppTextStyles.h2),
                            const SizedBox(height: 2),
                            Text('Real-time buffer monitoring, production team notification & alert history', style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Bar
            TabBar(
              controller: _tabController,
              isScrollable: isMobile,
              tabs: [
                Tab(text: 'Active Low Stock (${lowRM.length + lowFP.length})'),
                Tab(text: 'Alert Recipients (${db.alertRecipients.length})'),
                Tab(text: 'Alert Logs & History (${db.alertHistory.length})'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Active Low Stock Items
                  _buildActiveLowStockTab(context, db, lowRM, lowFP),

                  // Tab 2: Configured Recipients
                  _buildRecipientsTab(context, db),

                  // Tab 3: Alert History
                  _buildAlertHistoryTab(context, db),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLowStockTab(BuildContext context, dynamic db, List<RawMaterial> lowRM, List<FinishedProduct> lowFP) {
    if (lowRM.isEmpty && lowFP.isEmpty) {
      return const Center(
        child: Text('All Raw Materials and Finished Products are currently above safe minimum levels! 👍'),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lowRM.isNotEmpty) ...[
            Text('Raw Materials Below Minimum Stock / Reorder Level', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'Material Name'),
                ErpColumn(title: 'Code'),
                ErpColumn(title: 'Current Stock', isNumeric: true),
                ErpColumn(title: 'Min Stock', isNumeric: true),
                ErpColumn(title: 'Reorder Level', isNumeric: true),
                ErpColumn(title: 'Quick WhatsApp Alert'),
              ],
              rows: lowRM.map((rm) {
                return [
                  Text(rm.name, style: AppTextStyles.bodyBold),
                  Text(rm.itemCode, style: AppTextStyles.bodySmall),
                  Text('${rm.currentStock} ${rm.unit}', style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger)),
                  Text('${rm.minimumStock} ${rm.unit}', style: AppTextStyles.bodyMedium),
                  Text('${rm.reorderLevel} ${rm.unit}', style: AppTextStyles.bodyMedium),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.send, size: 14),
                    label: const Text('Notify Team', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      if (db.alertRecipients.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please add at least one alert recipient in the Recipients tab!')),
                        );
                        return;
                      }
                      _sendAlertToRecipient(rm, true, db.alertRecipients.first);
                    },
                  ),
                ];
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          if (lowFP.isNotEmpty) ...[
            Text('Finished Products Below Minimum Stock', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'Finished Product'),
                ErpColumn(title: 'SKU'),
                ErpColumn(title: 'Current Stock', isNumeric: true),
                ErpColumn(title: 'Min Stock', isNumeric: true),
                ErpColumn(title: 'Quick WhatsApp Alert'),
              ],
              rows: lowFP.map((fp) {
                return [
                  Text(fp.name, style: AppTextStyles.bodyBold),
                  Text(fp.itemCode, style: AppTextStyles.bodySmall),
                  Text('${fp.currentStock} ${fp.unit}', style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger)),
                  Text('${fp.minimumStock} ${fp.unit}', style: AppTextStyles.bodyMedium),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.send, size: 14),
                    label: const Text('Notify Team', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      if (db.alertRecipients.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please add at least one alert recipient in the Recipients tab!')),
                        );
                        return;
                      }
                      _sendAlertToRecipient(fp, false, db.alertRecipients.first);
                    },
                  ),
                ];
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecipientsTab(BuildContext context, dynamic db) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 500) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registered WhatsApp Numbers', style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  ErpButton(
                    text: 'Add Recipient',
                    icon: Icons.add,
                    onPressed: () => _openAddRecipientDialog(),
                  ),
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Registered Production & Inventory WhatsApp Numbers', style: AppTextStyles.h3),
                ),
                ErpButton(
                  text: 'Add Recipient',
                  icon: Icons.add,
                  onPressed: () => _openAddRecipientDialog(),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: ErpDataTable(
              columns: const [
                ErpColumn(title: 'Recipient Name'),
                ErpColumn(title: 'Role / Department'),
                ErpColumn(title: 'WhatsApp Number'),
                ErpColumn(title: 'Alert Type'),
                ErpColumn(title: 'Actions'),
              ],
              rows: db.alertRecipients.map<List<Widget>>((WhatsAppAlertRecipient r) {
                return [
                  Text(r.recipientName, style: AppTextStyles.bodyBold),
                  Text(r.roleOrDepartment, style: AppTextStyles.bodyMedium),
                  Text(r.whatsappNumber, style: AppTextStyles.bodyMedium),
                  Text(r.alertTypeLabel, style: AppTextStyles.bodySmall),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _openAddRecipientDialog(r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                        onPressed: () => db.deleteAlertRecipient(r.id),
                      ),
                    ],
                  ),
                ];
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertHistoryTab(BuildContext context, dynamic db) {
    if (db.alertHistory.isEmpty) {
      return const Center(child: Text('No low stock alerts dispatched yet.'));
    }

    return SingleChildScrollView(
      child: ErpDataTable(
        columns: const [
          ErpColumn(title: 'Item Name'),
          ErpColumn(title: 'Type'),
          ErpColumn(title: 'Stock At Alert'),
          ErpColumn(title: 'Recipient'),
          ErpColumn(title: 'Status'),
          ErpColumn(title: 'Action'),
        ],
        rows: db.alertHistory.map<List<Widget>>((LowStockAlertRecord a) {
          return [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.itemName, style: AppTextStyles.bodyBold),
                Text(a.itemCode, style: AppTextStyles.bodySmall),
              ],
            ),
            Text(a.itemType, style: AppTextStyles.bodySmall),
            Text('${a.currentStock} ${a.unit} (Min: ${a.minimumStock})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            Text('${a.recipientName}\n${a.recipientWhatsApp}', style: const TextStyle(fontSize: 10.5)),
            a.status == AlertRecordStatus.sent ? ErpStatusBadge.warning('SENT') : ErpStatusBadge.success('RESOLVED'),
            if (a.status == AlertRecordStatus.sent)
              TextButton(
                child: const Text('Mark Resolved', style: TextStyle(fontSize: 11)),
                onPressed: () => db.resolveLowStockAlertAsync(a.id),
              )
            else
              const Text('Restored', style: TextStyle(fontSize: 11, color: AppColors.success)),
          ];
        }).toList(),
      ),
    );
  }
}
