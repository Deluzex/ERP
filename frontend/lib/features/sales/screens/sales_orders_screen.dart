import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/figma_metric_card.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_toast.dart';
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
  String _selectedStatusFilter = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadSalesOrders();
      ref.read(databaseServiceProvider).loadFinishedProducts();
    });
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.local_shipping_outlined, color: AppColors.info, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dispatch Goods / Create Delivery Challan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Sales Order: ${so.invoiceNumber} | Customer: ${so.partyName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 640),
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transport Info Box
                    LayoutBuilder(
                      builder: (context, fieldBox) {
                        final isFieldStacked = fieldBox.maxWidth < 500;
                        final vehicleField = TextFormField(
                          controller: vehicleCtrl,
                          decoration: const InputDecoration(labelText: 'Vehicle Number *', hintText: 'e.g. MH-04-KU-8842'),
                        );
                        final driverField = TextFormField(
                          controller: driverCtrl,
                          decoration: const InputDecoration(labelText: 'Driver Name & Phone *', hintText: 'e.g. Rajesh Sharma'),
                        );

                        if (isFieldStacked) {
                          return Column(
                            children: [
                              vehicleField,
                              const SizedBox(height: 12),
                              driverField,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: vehicleField),
                            const SizedBox(width: 12),
                            Expanded(child: driverField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, fieldBox) {
                        final isFieldStacked = fieldBox.maxWidth < 500;
                        final trackField = TextFormField(
                          controller: trackingCtrl,
                          decoration: const InputDecoration(labelText: 'Tracking / LR Number', hintText: 'e.g. TRK-2026-9912'),
                        );
                        final notesField = TextFormField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(labelText: 'Delivery Notes / Gate Pass'),
                        );

                        if (isFieldStacked) {
                          return Column(
                            children: [
                              trackField,
                              const SizedBox(height: 12),
                              notesField,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: trackField),
                            const SizedBox(width: 12),
                            Expanded(child: notesField),
                          ],
                        );
                      },
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
                      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
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
                onPressed: () async {
                  // Validate delivery quantities
                  List<SaleLineItem> deliveryItems = [];
                  for (final item in so.items) {
                    final ctrl = qtyCtrls[item.finishedProductId];
                    final qtyToDispatch = double.tryParse(ctrl?.text.trim() ?? '0') ?? 0.0;
                    final remainingToDeliver = (item.quantity - item.deliveredQuantity).clamp(0.0, double.infinity);

                    final fp = db.finishedProducts.where((p) => p.id == item.finishedProductId).firstOrNull;
                    final physicalStock = fp?.currentStock ?? 0.0;

                    if (qtyToDispatch > remainingToDeliver) {
                      ErpToast.showError(
                        context,
                        'Dispatch quantity for ${item.finishedProductName} cannot exceed remaining order quantity (${remainingToDeliver.toInt()}).',
                      );
                      return;
                    }

                    if (qtyToDispatch > physicalStock) {
                      ErpToast.showError(
                        context,
                        'Cannot dispatch ${qtyToDispatch.toInt()} ${item.unit} of ${item.finishedProductName}. Only ${physicalStock.toInt()} available.',
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
                    ErpToast.showError(context, 'Please specify a dispatch quantity greater than 0.');
                    return;
                  }

                  try {
                    final deliveryDoc = await db.createDeliveryAsync(
                      salesOrderId: so.id,
                      deliveryItems: deliveryItems,
                      vehicleNumber: vehicleCtrl.text.trim(),
                      driverContact: driverCtrl.text.trim(),
                      trackingNumber: trackingCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                    );

                    Navigator.pop(ctx);
                    ErpToast.showSuccess(
                      context,
                      'Delivery challan ${deliveryDoc.invoiceNumber} created successfully. Physical stock deducted.',
                    );
                  } catch (e) {
                    ErpToast.showError(context, 'Failed to create delivery: $e');
                  }
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
          ErpSectionHeaderCard(
            icon: Icons.shopping_bag_outlined,
            title: 'Sales Orders & Stock Allocation',
            badgeText: 'SALES ORDERS',
            action: ErpButton(
              text: 'New Sales Order',
              icon: Icons.add,
              onPressed: () {
                ref.read(salesCreateDocTypeProvider.notifier).state = SalesDocumentType.salesOrder;
                ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSalesOrder;
              },
            ),
          ),
          const SizedBox(height: 18),

          // 2. Summary Metric Cards (Project Theme)
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 850
                  ? (constraints.maxWidth - (3 * 12)) / 4
                  : (constraints.maxWidth > 550 ? (constraints.maxWidth - 12) / 2 : double.infinity);
              final readyCount = db.ordersReadyForDispatchCount;
              final prodCount = db.ordersPendingProductionCount;
              final totalOrderValue = db.salesOrders.fold(0.0, (sum, so) => sum + so.totalAmount);

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.shopping_bag_outlined,
                      iconColor: AppColors.primary,
                      title: 'Total Sales Orders',
                      value: '${db.salesOrders.length}',
                      subtext: 'Confirmed Orders',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.local_shipping_outlined,
                      iconColor: AppColors.success,
                      title: 'Ready for Dispatch',
                      value: '$readyCount Orders',
                      subtext: 'Stock Reserved & Packed',
                      subtextColor: AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.precision_manufacturing_outlined,
                      iconColor: AppColors.warning,
                      title: 'In Production',
                      value: '$prodCount Orders',
                      subtext: 'Shortage Manufacturing',
                      subtextColor: AppColors.warning,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.currency_rupee,
                      iconColor: AppColors.primary,
                      title: 'Order Book Value',
                      value: Formatters.formatCurrency(totalOrderValue),
                      subtext: 'Cumulative Order Book',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 3. Tabs: All, Ready for Dispatch, In Production, Partially Delivered, Completed
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
              onTap: (_) => setState(() {
                _currentPage = 0;
              }),
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

          // 3. Search and Filter Bar
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: ErpSearchInput(
                  hintText: 'Search order no, customer, project...',
                  initialValue: _searchQuery,
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _currentPage = 0;
                  }),
                ),
              ),
              ErpFilterDropdown<String>(
                value: _selectedStatusFilter,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'READY', child: Text('Ready for Dispatch')),
                  DropdownMenuItem(value: 'PRODUCTION', child: Text('In Production / Shortage')),
                  DropdownMenuItem(value: 'PARTIAL', child: Text('Partially Delivered')),
                  DropdownMenuItem(value: 'DELIVERED', child: Text('Fully Delivered')),
                  DropdownMenuItem(value: 'DRAFT', child: Text('Draft / Other')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedStatusFilter = val;
                      _currentPage = 0;
                    });
                  }
                },
              ),
              ErpDateFilterBox(
                startDate: _startDate,
                endDate: _endDate,
                onDateRangeSelected: (start, end) => setState(() {
                  _startDate = start;
                  _endDate = end;
                  _currentPage = 0;
                }),
              ),
            ],
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
        filtered = filtered.where((so) => db.isSalesOrderStockReady(so)).toList();
        break;
      case 2:
        filtered = filtered.where((so) => !db.isSalesOrderStockReady(so) && (so.salesOrderStatus == SalesOrderStatus.productionPending || so.salesOrderStatus == SalesOrderStatus.inProduction)).toList();
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

    // Filter by status dropdown
    if (_selectedStatusFilter != 'ALL') {
      filtered = filtered.where((so) {
        switch (_selectedStatusFilter) {
          case 'READY':
            return db.isSalesOrderStockReady(so);
          case 'PRODUCTION':
            return !db.isSalesOrderStockReady(so) && (so.salesOrderStatus == SalesOrderStatus.productionPending || so.salesOrderStatus == SalesOrderStatus.inProduction);
          case 'PARTIAL':
            return so.salesOrderStatus == SalesOrderStatus.partiallyDelivered;
          case 'DELIVERED':
            return so.salesOrderStatus == SalesOrderStatus.delivered || so.salesOrderStatus == SalesOrderStatus.completed;
          case 'DRAFT':
            return so.salesOrderStatus == SalesOrderStatus.draft || so.salesOrderStatus == SalesOrderStatus.pending;
          default:
            return true;
        }
      }).toList();
    }

    // Filter by date range
    if (_startDate != null) {
      filtered = filtered.where((so) => !so.date.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))).toList();
    }
    if (_endDate != null) {
      filtered = filtered.where((so) => !so.date.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))).toList();
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

    final totalCount = filtered.length;
    final maxPage = (totalCount / _pageSize).ceil();
    final effectivePage = maxPage == 0 ? 0 : min(_currentPage, maxPage - 1);
    final startIdx = effectivePage * _pageSize;
    final endIdx = min(startIdx + _pageSize, totalCount);
    final paginatedOrders = totalCount == 0 ? <Sale>[] : filtered.sublist(startIdx, endIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ErpDataTable(
          dataRowMinHeight: 60,
          dataRowMaxHeight: 72,
          columnSpacing: 16,
          horizontalMargin: 16,
          columns: const [
        ErpColumn(title: 'SO Number', width: 130),
        ErpColumn(title: 'Customer / Party', width: 190),
        ErpColumn(title: 'Delivery Due', width: 120),
        ErpColumn(title: 'Ordered Items & Stock Status', width: 280),
        ErpColumn(title: 'Order Value', isNumeric: true, width: 130),
        ErpColumn(title: 'Workflow Status', width: 155),
        ErpColumn(title: 'Actions', width: 90),
      ],
      rows: paginatedOrders.map((so) {
        final isDelivered = so.salesOrderStatus == SalesOrderStatus.delivered || so.salesOrderStatus == SalesOrderStatus.completed;
        final isPartiallyDelivered = so.salesOrderStatus == SalesOrderStatus.partiallyDelivered;
        final isStockReady = db.isSalesOrderStockReady(so);

        ErpStatusBadge badge;
        if (isDelivered) {
          badge = ErpStatusBadge.neutral('DELIVERED');
        } else if (isPartiallyDelivered) {
          badge = ErpStatusBadge.info('PARTIALLY DELIVERED');
        } else if (isStockReady) {
          badge = ErpStatusBadge.success('COMPLETE PRODUCTION');
        } else if (so.salesOrderStatus == SalesOrderStatus.productionPending || so.salesOrderStatus == SalesOrderStatus.inProduction) {
          badge = ErpStatusBadge.warning('IN PRODUCTION');
        } else {
          badge = ErpStatusBadge.neutral('CONFIRMED');
        }

        return [
          // 1. SO Number
          InkWell(
            onTap: () {
              SalesPdfGeneratorDialog.show(context, so, db);
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                so.invoiceNumber,
                style: AppTextStyles.bodyBold.copyWith(fontSize: 12.5, color: AppColors.primary),
              ),
            ),
          ),

          // 2. Customer / Party
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  so.partyName,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (so.projectName != null && so.projectName!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    so.projectName!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // 3. Delivery Due
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                so.deliveryDate != null ? Formatters.formatDate(so.deliveryDate!) : '-',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Ord: ${Formatters.formatDate(so.saleDate)}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontSize: 10.5),
              ),
            ],
          ),

          // 4. Ordered Items & Stock Status
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: so.items.isEmpty
                ? Text('No items', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              so.items.first.finishedProductName,
                              style: AppTextStyles.bodyMedium.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border, width: 0.5),
                            ),
                            child: Text(
                              '${so.items.first.quantity.toInt()} ${so.items.first.unit}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Delivered: ${so.items.first.deliveredQuantity.toInt()}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: so.items.first.deliveredQuantity > 0 ? AppColors.successText : AppColors.textMuted,
                            ),
                          ),
                          const Text(' • ', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                          Text(
                            'Reserved: ${so.items.first.reservedQuantity.toInt()}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: so.items.first.reservedQuantity > 0 ? AppColors.infoText : AppColors.textMuted,
                            ),
                          ),
                          if (so.items.length > 1) ...[
                            const Text(' • ', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                            Text(
                              '+${so.items.length - 1} more',
                              style: const TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
          ),

          // 5. Order Value
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.formatCurrency(so.totalAmount),
              style: AppTextStyles.bodyBold.copyWith(fontSize: 12.5),
            ),
          ),

          // 6. Workflow Status
          badge,

          // 7. Actions
          Builder(
            builder: (context) {
              final canDispatch = !isDelivered && isStockReady;
              return PopupMenuButton<String>(
                tooltip: 'Actions',
                icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                onSelected: (action) async {
                  switch (action) {
                    case 'view':
                      SalesPdfGeneratorDialog.show(context, so, db);
                      break;
                    case 'dispatch':
                      if (!canDispatch) return;
                      final fullSo = await db.getSalesOrderDetailAsync(so.id);
                      if (!context.mounted) return;
                      _showDispatchDeliveryDialog(context, fullSo, db);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text('View Details')),
                      ],
                    ),
                  ),
                  if (!isDelivered)
                    PopupMenuItem(
                      value: 'dispatch',
                      enabled: canDispatch,
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 16,
                            color: canDispatch ? AppColors.info : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dispatch Delivery',
                              style: TextStyle(
                                color: canDispatch ? null : AppColors.textMuted,
                              ),
                            ),
                          ),
                          if (!canDispatch)
                            const Tooltip(
                              message: 'In production (stock shortage in master)',
                              child: Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ];
      }).toList(),
    ),
    if (filtered.isNotEmpty) ...[
      const SizedBox(height: 12),
      ErpPaginationBar(
        totalRecords: totalCount,
        currentPage: effectivePage,
        pageSize: _pageSize,
        onPageChanged: (newPage) => setState(() => _currentPage = newPage),
        onPageSizeChanged: (newSize) => setState(() {
          _pageSize = newSize;
          _currentPage = 0;
        }),
      ),
    ],
  ],
);
  }
}
