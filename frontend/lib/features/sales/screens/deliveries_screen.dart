import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/widgets/share_document_dialog.dart';
import '../../../shared/widgets/whatsapp_quick_chat_dialog.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';
import '../widgets/sales_pdf_generator.dart';

class DeliveriesScreen extends ConsumerStatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  ConsumerState<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends ConsumerState<DeliveriesScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(databaseServiceProvider).loadSalesDeliveries());
  }

  void _showEditCourierDialog(BuildContext context, Sale delivery, MockDatabaseService db) {
    final courierCtrl = TextEditingController(text: delivery.courierName ?? '');
    final trackingCtrl = TextEditingController(text: delivery.trackingNumber ?? '');
    final contactCtrl = TextEditingController(text: delivery.courierContact ?? '');
    final vehicleCtrl = TextEditingController(text: delivery.vehicleNumber ?? '');
    final notesCtrl = TextEditingController(text: delivery.dispatchNotes ?? '');
    DateTime? expDeliveryDate = delivery.expectedDeliveryDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update Courier & Tracking Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Challan No: ${delivery.invoiceNumber}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            width: double.infinity,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: courierCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Courier / Transport Partner Name',
                      hintText: 'E.g. BlueDart Express, VRL Logistics, DTDC',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: trackingCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tracking / LR Number *',
                            hintText: 'E.g. BLU-98472919',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: vehicleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Number',
                            hintText: 'E.g. MH-04-AB-1234',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: contactCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Courier / Driver Contact',
                            hintText: 'E.g. +91 98200 11223',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          controller: TextEditingController(
                            text: expDeliveryDate != null ? Formatters.formatDate(expDeliveryDate!) : '',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Expected Delivery Date',
                            suffixIcon: Icon(Icons.calendar_today, size: 16),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: expDeliveryDate ?? DateTime.now().add(const Duration(days: 3)),
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 90)),
                            );
                            if (picked != null) {
                              setDlgState(() => expDeliveryDate = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Dispatch / Transit Notes',
                      hintText: 'Special handling instructions, site contact or gate pass info',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ErpButton(
              text: 'Save Details',
              icon: Icons.check,
              onPressed: () async {
                try {
                  await db.updateDeliveryTrackingAsync(
                    delivery.id,
                    courierName: courierCtrl.text.trim().isNotEmpty ? courierCtrl.text.trim() : null,
                    trackingNumber: trackingCtrl.text.trim().isNotEmpty ? trackingCtrl.text.trim() : null,
                    vehicleNumber: vehicleCtrl.text.trim().isNotEmpty ? vehicleCtrl.text.trim() : null,
                    driverContact: contactCtrl.text.trim().isNotEmpty ? contactCtrl.text.trim() : null,
                    dispatchNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                  );
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Courier & tracking details updated successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update tracking: $e'), backgroundColor: AppColors.danger),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateInvoiceFromDeliveryDialog(BuildContext context, Sale delivery, MockDatabaseService db) {
    final discountCtrl = TextEditingController(text: '0');
    final initialPaidCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController(text: 'Invoice against Delivery ${delivery.invoiceNumber}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.receipt_long_outlined, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Generate Tax Invoice from Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Delivery Challan: ${delivery.invoiceNumber} (Delivered Qty only)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Delivered Material Value:'),
                      Text(Formatters.formatCurrency(delivery.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Customer / Party:', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                      Text(delivery.partyName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: discountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Invoice Discount (₹)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: initialPaidCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Initial Payment Received (₹)', helperText: 'Enter 0 if payment is pending / credit period'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Invoice Notes / Dispatch Reference'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ErpButton(
            text: 'Generate Tax Invoice',
            icon: Icons.check,
            onPressed: () async {
              final discount = double.tryParse(discountCtrl.text.trim()) ?? 0.0;
              final paid = double.tryParse(initialPaidCtrl.text.trim()) ?? 0.0;

              try {
                final invoice = await db.createSalesInvoiceFromDeliveryAsync(
                  deliveryId: delivery.id,
                  discountAmount: discount,
                  initialPaidAmount: paid,
                  notes: notesCtrl.text.trim(),
                );

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tax Invoice ${invoice.invoiceNumber} created from delivered items! Customer outstanding updated.'),
                    backgroundColor: AppColors.success,
                  ),
                );
                ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList;
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to generate invoice: $e'), backgroundColor: AppColors.danger),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);

    final filtered = db.deliveries.where((d) {
      final qLower = _searchQuery.toLowerCase();
      return d.invoiceNumber.toLowerCase().contains(qLower) ||
          d.partyName.toLowerCase().contains(qLower) ||
          (d.salesOrderNumber != null && d.salesOrderNumber!.toLowerCase().contains(qLower)) ||
          (d.courierName != null && d.courierName!.toLowerCase().contains(qLower)) ||
          (d.trackingNumber != null && d.trackingNumber!.toLowerCase().contains(qLower)) ||
          (d.vehicleNumber != null && d.vehicleNumber!.toLowerCase().contains(qLower));
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 650;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deliveries & Dispatch Challans', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text(
                    'Physical dispatch records, courier tracking details & invoice generation from delivered quantities',
                    style: AppTextStyles.subtitle,
                  ),
                ],
              );

              final actionBtn = ErpButton(
                text: 'Go to Sales Orders to Dispatch',
                icon: Icons.shopping_cart_outlined,
                isOutlined: true,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesOrders,
              );

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 12),
                    actionBtn,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  actionBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 2. Search
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search delivery by challan no, courier, tracking no, vehicle number, customer or sales order...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Deliveries Table
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No delivery challans found', style: AppTextStyles.h3),
                  const SizedBox(height: 6),
                  Text('Dispatch confirmed Sales Orders to generate Delivery Challans.', style: AppTextStyles.bodySmall),
                ],
              ),
            )
          else
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'Challan No'),
                ErpColumn(title: 'Date'),
                ErpColumn(title: 'Customer / Party'),
                ErpColumn(title: 'Courier & Tracking'),
                ErpColumn(title: 'Vehicle / Transit'),
                ErpColumn(title: 'Items Dispatched'),
                ErpColumn(title: 'Status'),
                ErpColumn(title: 'Actions'),
              ],
              rows: filtered.map((dlv) {
                return [
                  InkWell(
                    onTap: () {
                      ref.read(activeRecordDetailsStackProvider.notifier).push(dlv.id, 'delivery', ErpNavSection.salesDeliveries);
                    },
                    child: Text(
                      dlv.invoiceNumber,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                  Text(Formatters.formatDate(dlv.saleDate), style: AppTextStyles.bodySmall),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dlv.partyName, style: AppTextStyles.bodyMedium),
                      if (dlv.salesOrderNumber != null)
                        Text('SO: ${dlv.salesOrderNumber}', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                  // Courier & Tracking Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dlv.courierName != null)
                        Row(
                          children: [
                            const Icon(Icons.local_shipping, size: 12, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(dlv.courierName!, style: AppTextStyles.bodyBold.copyWith(fontSize: 11)),
                          ],
                        ),
                      if (dlv.trackingNumber != null)
                        Text('LR: ${dlv.trackingNumber}', style: const TextStyle(fontSize: 10.5, color: Colors.purple, fontWeight: FontWeight.w600))
                      else if (dlv.courierName == null)
                        const Text('Direct Transport', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                      if (dlv.expectedDeliveryDate != null)
                        Text('Exp: ${Formatters.formatDate(dlv.expectedDeliveryDate!)}', style: const TextStyle(fontSize: 10, color: Colors.teal)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dlv.vehicleNumber ?? '-', style: AppTextStyles.bodyBold.copyWith(fontSize: 11.5)),
                      if (dlv.driverContact != null) Text(dlv.driverContact!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10.5)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: dlv.items.map((i) {
                      return Text('• ${i.finishedProductName}: ${i.quantity.toInt()} ${i.unit}', style: const TextStyle(fontSize: 11));
                    }).toList(),
                  ),
                  ErpStatusBadge.success('DISPATCHED'),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                        tooltip: 'Edit Courier & Tracking Info',
                        onPressed: () => _showEditCourierDialog(context, dlv, db),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.teal, size: 18),
                        tooltip: 'Share Challan (WhatsApp/Email)',
                        onPressed: () => ShareDocumentDialog.show(context, dlv),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat, color: Colors.green, size: 18),
                        tooltip: 'Quick WhatsApp Message',
                        onPressed: () => WhatsAppQuickChatDialog.showCustomerQuickChat(
                          context,
                          customerName: dlv.partyName,
                          customerPhone: dlv.customerMobile ?? '+91 98765 00000',
                          docNumber: dlv.invoiceNumber,
                          projectName: dlv.projectName,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 18),
                        tooltip: 'Preview Delivery Challan PDF',
                        onPressed: () => SalesPdfGeneratorDialog.show(context, dlv, db),
                      ),
                      ErpButton(
                        text: 'Create Invoice',
                        icon: Icons.receipt_long,
                        onPressed: () => _showCreateInvoiceFromDeliveryDialog(context, dlv, db),
                      ),
                    ],
                  ),
                ];
              }).toList(),
            ),
        ],
      ),
    );
  }
}
