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

class SalesOrdersScreen extends ConsumerStatefulWidget {
  const SalesOrdersScreen({super.key});

  @override
  ConsumerState<SalesOrdersScreen> createState() => _SalesOrdersScreenState();
}

class _SalesOrdersScreenState extends ConsumerState<SalesOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showDispatchDeliveryDialog(BuildContext context, Sale so, MockDatabaseService db) {
    final vehicleCtrl = TextEditingController(text: 'MH-04-KU-8842');
    final driverCtrl = TextEditingController(text: 'Sunil Jadhav (+91 97654 32100)');
    final trackingCtrl = TextEditingController(text: 'TRK-2026-${(db.nextDeliveryNumber * 111)}');
    final notesCtrl = TextEditingController();

    // Line item dispatch qty controllers
    final Map<String, TextEditingController> qtyCtrls = {};
    for (final item in so.items) {
      final remaining = (item.quantity - item.deliveredQuantity).clamp(0.0, double.infinity);
      qtyCtrls[item.finishedProductId] = TextEditingController(text: remaining.toInt().toString());
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.info.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.local_shipping_outlined, color: AppColors.info, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dispatch Goods / Create Delivery Challan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Sales Order: ${so.invoiceNumber} | Customer: ${so.partyName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transport Info Box
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: vehicleCtrl,
                            decoration: const InputDecoration(labelText: 'Vehicle Number *', hintText: 'e.g. MH-04-KU-8842'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: driverCtrl,
                            decoration: const InputDecoration(labelText: 'Driver Name & Phone *', hintText: 'e.g. Rajesh Sharma'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: trackingCtrl,
                            decoration: const InputDecoration(labelText: 'Tracking / LR Number', hintText: 'e.g. TRK-2026-9912'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: notesCtrl,
                            decoration: const InputDecoration(labelText: 'Delivery Notes / Gate Pass'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Text('Select Items & Quantities to Dispatch:', style: AppTextStyles.h3.copyWith(fontSize: 13.5)),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: so.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final item = so.items[idx];
                          final remainingToDeliver = (item.quantity - item.deliveredQuantity).clamp(0.0, double.infinity);
                          final ctrl = qtyCtrls[item.finishedProductId]!;
                          final fp = db.finishedProducts.where((p) => p.id == item.finishedProductId).firstOrNull;
                          final physicalStock = fp?.currentStock ?? 0.0;
                          final isShortage = physicalStock < remainingToDeliver;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.finishedProductName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text('Code: ${item.finishedProductCode} | Ordered: ${item.quantity.toInt()} ${item.unit} | Delivered: ${item.deliveredQuantity.toInt()}',
                                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            isShortage ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                            size: 13,
                                            color: isShortage ? Colors.orange.shade800 : AppColors.success,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'In Warehouse: ${physicalStock.toInt()} ${item.unit}' +
                                                (isShortage ? ' (${(remainingToDeliver - physicalStock).toInt()} in Production)' : ''),
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: isShortage ? Colors.orange.shade800 : AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    controller: ctrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Dispatch Qty',
                                      isDense: true,
                                      helperText: 'Max: ${physicalStock < remainingToDeliver ? physicalStock.toInt() : remainingToDeliver.toInt()}',
                                    ),
                                    onChanged: (val) => setDialogState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.info.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.info, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Physical stock will be deducted and reserved stock cleared upon dispatch.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ErpButton(
                text: 'Confirm Dispatch & Deduct Stock',
                icon: Icons.check,
                onPressed: () {
                  // Validate delivery quantities
                  List<SaleLineItem> deliveryItems = [];
                  for (final item in so.items) {
                    final ctrl = qtyCtrls[item.finishedProductId];
                    final qtyToDispatch = double.tryParse(ctrl?.text.trim() ?? '0') ?? 0.0;
                    final remainingToDeliver = (item.quantity - item.deliveredQuantity).clamp(0.0, double.infinity);

                    final fp = db.finishedProducts.where((p) => p.id == item.finishedProductId).firstOrNull;
                    final physicalStock = fp?.currentStock ?? 0.0;

                    if (qtyToDispatch > remainingToDeliver) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Dispatch quantity for ${item.finishedProductName} cannot exceed remaining order quantity (${remainingToDeliver.toInt()}).'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    if (qtyToDispatch > physicalStock) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cannot dispatch ${qtyToDispatch.toInt()} ${item.unit} of ${item.finishedProductName}. Only ${physicalStock.toInt()} ${item.unit} physically available in warehouse. Wait for production to finish or dispatch partial stock.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    if (qtyToDispatch > 0) {
                      deliveryItems.add(item.copyWith(
                        quantity: qtyToDispatch,
                        lineTotal: SaleLineItem.calculateLineTotal(
                          quantity: qtyToDispatch,
                          rate: item.rate,
                          discountAmount: (item.discountAmount / item.quantity) * qtyToDispatch,
                          gstPercent: item.gstPercent,
                        ),
                      ));
                    }
                  }

                  if (deliveryItems.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please specify a dispatch quantity greater than 0.'), backgroundColor: AppColors.danger),
                    );
                    return;
                  }

                  final deliveryDoc = db.createDelivery(
                    salesOrderId: so.id,
                    deliveryItems: deliveryItems,
                    vehicleNumber: vehicleCtrl.text.trim(),
                    driverContact: driverCtrl.text.trim(),
                    trackingNumber: trackingCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                  );

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Delivery Challan ${deliveryDoc.invoiceNumber} generated! Physical stock deducted from finished goods.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);

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
                    Text('Sales Orders & Stock Allocation', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text(
                      'Order execution, stock reservation, shortage production links & dispatch',
                      style: AppTextStyles.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ErpButton(
                text: 'New Sales Order',
                icon: Icons.add,
                onPressed: () {
                  ref.read(salesCreateDocTypeProvider.notifier).state = SalesDocumentType.salesOrder;
                  ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSalesOrder;
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Tabs: All, Ready for Dispatch, In Production, Partially Delivered, Completed
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              onTap: (_) => setState(() {}),
              tabs: [
                Tab(text: 'All Orders (${db.salesOrders.length})'),
                Tab(text: 'Ready for Dispatch (${db.ordersReadyForDispatchCount})'),
                Tab(text: 'In Production / Shortage (${db.ordersPendingProductionCount})'),
                Tab(text: 'Partially Delivered (${db.ordersPartiallyDeliveredCount})'),
                Tab(text: 'Fully Delivered (${db.salesOrders.where((so) => so.salesOrderStatus == SalesOrderStatus.delivered || so.salesOrderStatus == SalesOrderStatus.completed).length})'),
                Tab(text: 'Other / Draft (${db.salesOrders.where((so) => so.salesOrderStatus == SalesOrderStatus.draft || so.salesOrderStatus == SalesOrderStatus.pending).length})'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search sales orders by number, customer, project or linked proforma/quotation...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Sales Orders Table
          _buildSalesOrdersTable(context, ref, db),
        ],
      ),
    );
  }

  Widget _buildSalesOrdersTable(BuildContext context, WidgetRef ref, MockDatabaseService db) {
    List<Sale> filtered = db.salesOrders;

    // Filter by tab
    switch (_tabController.index) {
      case 1:
        filtered = filtered.where((so) => so.salesOrderStatus == SalesOrderStatus.readyForDispatch).toList();
        break;
      case 2:
        filtered = filtered.where((so) => so.salesOrderStatus == SalesOrderStatus.productionPending || so.salesOrderStatus == SalesOrderStatus.inProduction).toList();
        break;
      case 3:
        filtered = filtered.where((so) => so.salesOrderStatus == SalesOrderStatus.partiallyDelivered).toList();
        break;
      case 4:
        filtered = filtered.where((so) => so.salesOrderStatus == SalesOrderStatus.delivered || so.salesOrderStatus == SalesOrderStatus.completed).toList();
        break;
      case 5:
        filtered = filtered.where((so) => so.salesOrderStatus == SalesOrderStatus.draft || so.salesOrderStatus == SalesOrderStatus.pending).toList();
        break;
      default:
        break;
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final qLower = _searchQuery.toLowerCase();
      filtered = filtered.where((so) {
        return so.invoiceNumber.toLowerCase().contains(qLower) ||
            so.partyName.toLowerCase().contains(qLower) ||
            (so.projectName != null && so.projectName!.toLowerCase().contains(qLower)) ||
            (so.proformaNumber != null && so.proformaNumber!.toLowerCase().contains(qLower));
      }).toList();
    }

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgBorderRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No Sales Orders found in this category', style: AppTextStyles.h3),
            const SizedBox(height: 6),
            Text('Create a new Sales Order or convert from an accepted Proforma Invoice.', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }

    return ErpDataTable(
      columns: const [
        ErpColumn(title: 'SO Number'),
        ErpColumn(title: 'Customer / Party'),
        ErpColumn(title: 'Delivery Due'),
        ErpColumn(title: 'Ordered Items & Stock Status'),
        ErpColumn(title: 'Order Value', isNumeric: true),
        ErpColumn(title: 'Workflow Status'),
        ErpColumn(title: 'Actions'),
      ],
      rows: filtered.map((so) {
        ErpStatusBadge badge;
        switch (so.salesOrderStatus) {
          case SalesOrderStatus.readyForDispatch:
            badge = ErpStatusBadge.success('READY FOR DISPATCH');
            break;
          case SalesOrderStatus.productionPending:
          case SalesOrderStatus.inProduction:
            badge = ErpStatusBadge.warning('IN PRODUCTION');
            break;
          case SalesOrderStatus.partiallyDelivered:
            badge = ErpStatusBadge.info('PARTIALLY DELIVERED');
            break;
          case SalesOrderStatus.delivered:
          case SalesOrderStatus.completed:
            badge = ErpStatusBadge.neutral('DELIVERED');
            break;
          default:
            badge = ErpStatusBadge.neutral('CONFIRMED');
        }

        return [
          InkWell(
            onTap: () {
              ref.read(activeRecordDetailsStackProvider.notifier).push(so.id, 'salesOrder', ErpNavSection.salesOrders);
            },
            child: Text(
              so.invoiceNumber,
              style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primary),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(so.partyName, style: AppTextStyles.bodyMedium),
              if (so.projectName != null) Text(so.projectName!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10.5)),
            ],
          ),
          Text(so.deliveryDate != null ? Formatters.formatDate(so.deliveryDate!) : '-', style: AppTextStyles.bodySmall),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: so.items.map((i) {
              return Text(
                '• ${i.finishedProductName} (${i.quantity.toInt()} ${i.unit}) [Delivered: ${i.deliveredQuantity.toInt()}, Reserved: ${i.reservedQuantity.toInt()}]',
                style: const TextStyle(fontSize: 11),
              );
            }).toList(),
          ),
          Text(Formatters.formatCurrency(so.totalAmount), style: AppTextStyles.bodyBold),
          badge,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 18),
                tooltip: 'Preview Sales Order PDF',
                onPressed: () => SalesPdfGeneratorDialog.show(context, so, db),
              ),
              if (so.salesOrderStatus != SalesOrderStatus.delivered && so.salesOrderStatus != SalesOrderStatus.completed)
                IconButton(
                  icon: const Icon(Icons.local_shipping, color: AppColors.info, size: 18),
                  tooltip: 'Dispatch Delivery',
                  onPressed: () => _showDispatchDeliveryDialog(context, so, db),
                ),
            ],
          ),
        ];
      }).toList(),
    );
  }
}
