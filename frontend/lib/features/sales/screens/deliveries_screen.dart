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

  void _showCreateInvoiceFromDeliveryDialog(BuildContext context, Sale delivery, MockDatabaseService db) {
    final discountCtrl = TextEditingController(text: '0');
    final initialPaidCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController(text: 'Invoice against Delivery ${delivery.invoiceNumber}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.receipt_long_outlined, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Generate Tax Invoice from Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Delivery Challan: ${delivery.invoiceNumber} (Delivered Qty only)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
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
            onPressed: () {
              final discount = double.tryParse(discountCtrl.text.trim()) ?? 0.0;
              final paid = double.tryParse(initialPaidCtrl.text.trim()) ?? 0.0;

              final invoice = db.createSalesInvoiceFromDelivery(
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
          (d.vehicleNumber != null && d.vehicleNumber!.toLowerCase().contains(qLower));
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deliveries & Dispatch Challans', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text(
                      'Physical dispatch records, vehicle tracking & invoice generation from delivered quantities',
                      style: AppTextStyles.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ErpButton(
                text: 'Go to Sales Orders to Dispatch',
                icon: Icons.shopping_cart_outlined,
                isOutlined: true,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesOrders,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Search
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search delivery by challan no, vehicle number, customer or sales order...',
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
                ErpColumn(title: 'SO Reference'),
                ErpColumn(title: 'Vehicle & Driver'),
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
                  Text(dlv.partyName, style: AppTextStyles.bodyMedium),
                  Text(dlv.salesOrderNumber ?? '-', style: AppTextStyles.bodySmall),
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
