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
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/figma_metric_card.dart';
import '../../../core/widgets/erp_toast.dart';
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
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  int _pageSize = 10;

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
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping, color: AppColors.primary, size: 20),
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
                  ErpToast.showSuccess(
                    context,
                    'Courier & tracking details updated successfully!',
                  );
                } catch (e) {
                  ErpToast.showError(
                    context,
                    'Failed to update tracking: $e',
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
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
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
                ErpToast.showSuccess(
                  context,
                  'Tax Invoice ${invoice.invoiceNumber} created from delivered items!',
                );
                ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList;
              } catch (e) {
                ErpToast.showError(
                  context,
                  'Failed to generate invoice: $e',
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
      final matchesSearch = d.invoiceNumber.toLowerCase().contains(qLower) ||
          d.partyName.toLowerCase().contains(qLower) ||
          (d.salesOrderNumber != null && d.salesOrderNumber!.toLowerCase().contains(qLower)) ||
          (d.courierName != null && d.courierName!.toLowerCase().contains(qLower)) ||
          (d.trackingNumber != null && d.trackingNumber!.toLowerCase().contains(qLower)) ||
          (d.vehicleNumber != null && d.vehicleNumber!.toLowerCase().contains(qLower));

      final matchesStart = _startDate == null || !d.date.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day));
      final matchesEnd = _endDate == null || !d.date.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59));

      return matchesSearch && matchesStart && matchesEnd;
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          ErpSectionHeaderCard(
            icon: Icons.local_shipping_outlined,
            title: 'Deliveries & Dispatch Challans',
            badgeText: 'DISPATCH & LOGISTICS',
            action: ErpButton(
              text: 'Go to Sales Orders to Dispatch',
              icon: Icons.shopping_cart_outlined,
              isOutlined: true,
              onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesOrders,
            ),
          ),
          const SizedBox(height: 18),

          // 2. Summary Metric Cards (Project Theme)
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 850
                  ? (constraints.maxWidth - (3 * 12)) / 4
                  : (constraints.maxWidth > 550 ? (constraints.maxWidth - 12) / 2 : double.infinity);
              final invoicedCount = db.deliveries.where((d) => d.status == 'invoiced').length;
              final pendingInvoiceCount = db.deliveries.where((d) => d.status != 'invoiced').length;
              final totalValue = db.deliveries.fold(0.0, (sum, d) => sum + d.totalAmount);

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.local_shipping_outlined,
                      iconColor: AppColors.primary,
                      title: 'Total Challans',
                      value: '${db.deliveries.length}',
                      subtext: 'Dispatched Shipments',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.receipt_long_outlined,
                      iconColor: AppColors.success,
                      title: 'Invoiced Deliveries',
                      value: '$invoicedCount',
                      subtext: 'Tax Invoices Generated',
                      subtextColor: AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.schedule_outlined,
                      iconColor: AppColors.warning,
                      title: 'Pending Invoicing',
                      value: '$pendingInvoiceCount',
                      subtext: 'Challans to Invoice',
                      subtextColor: AppColors.warning,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.currency_rupee,
                      iconColor: AppColors.primary,
                      title: 'Dispatched Valuation',
                      value: Formatters.formatCurrency(totalValue),
                      subtext: 'Cumulative Goods Dispatched',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 3. Global Filters
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 450;
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ErpSearchInput(
                      hintText: 'Search challan, customer, courier, vehicle...',
                      initialValue: _searchQuery,
                      onChanged: (val) => setState(() {
                        _searchQuery = val;
                        _currentPage = 0;
                      }),
                    ),
                    const SizedBox(height: 10),
                    ErpDateFilterBox(
                      startDate: _startDate,
                      endDate: _endDate,
                      onDateRangeSelected: (start, end) {
                        setState(() {
                          _startDate = start;
                          _endDate = end;
                          _currentPage = 0;
                        });
                      },
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: ErpSearchInput(
                      hintText: 'Search challan, customer, courier, vehicle...',
                      initialValue: _searchQuery,
                      onChanged: (val) => setState(() {
                        _searchQuery = val;
                        _currentPage = 0;
                      }),
                    ),
                  ),
                  ErpDateFilterBox(
                    startDate: _startDate,
                    endDate: _endDate,
                    onDateRangeSelected: (start, end) {
                      setState(() {
                        _startDate = start;
                        _endDate = end;
                        _currentPage = 0;
                      });
                    },
                  ),
                ],
              );
            },
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
            Builder(
              builder: (context) {
                final totalCount = filtered.length;
                final maxPage = (totalCount / _pageSize).ceil();
                final effectivePage = maxPage == 0 ? 0 : min(_currentPage, maxPage - 1);
                final startIdx = effectivePage * _pageSize;
                final endIdx = min(startIdx + _pageSize, totalCount);
                final paginatedDeliveries = totalCount == 0 ? <Sale>[] : filtered.sublist(startIdx, endIdx);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ErpDataTable(
                      dataRowMinHeight: 60,
                      dataRowMaxHeight: 74,
                      columnSpacing: 16,
                      horizontalMargin: 16,
                      columns: const [
                        ErpColumn(title: 'Challan No', width: 140),
                        ErpColumn(title: 'Date', width: 110),
                        ErpColumn(title: 'Customer / Party', width: 180),
                        ErpColumn(title: 'Courier & Tracking', width: 160),
                        ErpColumn(title: 'Vehicle / Transit', width: 130),
                        ErpColumn(title: 'Items Dispatched', width: 220),
                        ErpColumn(title: 'Status', width: 130),
                        ErpColumn(title: 'Actions', width: 90),
                      ],
                      rows: paginatedDeliveries.map((dlv) {
                return [
                  // 1. Challan No
                  InkWell(
                    onTap: () {
                      SalesPdfGeneratorDialog.show(context, dlv, db);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        dlv.invoiceNumber,
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 12.5, color: AppColors.primary),
                      ),
                    ),
                  ),

                  // 2. Date
                  Text(
                    Formatters.formatDate(dlv.saleDate),
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                  ),

                  // 3. Customer / Party
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dlv.partyName,
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (dlv.salesOrderNumber != null && dlv.salesOrderNumber!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'SO: ${dlv.salesOrderNumber}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 4. Courier & Tracking Column
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dlv.courierName != null) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 13, color: AppColors.info),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  dlv.courierName!,
                                  style: AppTextStyles.bodyBold.copyWith(fontSize: 11.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (dlv.trackingNumber != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'LR: ${dlv.trackingNumber}',
                              style: const TextStyle(fontSize: 10.5, color: AppColors.purple, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ] else ...[
                          const Text('Direct Transport', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                        ],
                        if (dlv.expectedDeliveryDate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Exp: ${Formatters.formatDate(dlv.expectedDeliveryDate!)}',
                            style: const TextStyle(fontSize: 10.5, color: AppColors.teal, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 5. Vehicle / Transit
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dlv.vehicleNumber ?? '-',
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (dlv.driverContact != null && dlv.driverContact!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            dlv.driverContact!,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 6. Items Dispatched
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: dlv.items.isEmpty
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
                                      dlv.items.first.finishedProductName,
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
                                      '${dlv.items.first.quantity.toInt()} ${dlv.items.first.unit}',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                              if (dlv.items.length > 1) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '+${dlv.items.length - 1} more items dispatched',
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                  ),

                  // 7. Status
                  ErpStatusBadge.success('DISPATCHED'),

                  // 8. Actions
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                    onSelected: (action) async {
                      switch (action) {
                        case 'view':
                          SalesPdfGeneratorDialog.show(context, dlv, db);
                          break;
                        case 'invoice':
                          final fullDlv = await db.getDeliveryDetailAsync(dlv.id);
                          if (!context.mounted) return;
                          _showCreateInvoiceFromDeliveryDialog(context, fullDlv, db);
                          break;
                        case 'tracking':
                          _showEditCourierDialog(context, dlv, db);
                          break;
                        case 'share':
                          ShareDocumentDialog.show(context, dlv);
                          break;
                        case 'whatsapp':
                          WhatsAppQuickChatDialog.showCustomerQuickChat(
                            context,
                            customerName: dlv.partyName,
                            customerPhone: dlv.customerMobile ?? '+91 98765 00000',
                            docNumber: dlv.invoiceNumber,
                            projectName: dlv.projectName,
                          );
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
                      const PopupMenuItem(
                        value: 'invoice',
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long, size: 16, color: AppColors.primary),
                            SizedBox(width: 8),
                            Expanded(child: Text('Create Invoice')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'tracking',
                        child: Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.info),
                            SizedBox(width: 8),
                            Expanded(child: Text('Edit Tracking')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 16, color: AppColors.teal),
                            SizedBox(width: 8),
                            Expanded(child: Text('Share Challan')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'whatsapp',
                        child: Row(
                          children: [
                            Icon(Icons.chat_outlined, size: 16, color: AppColors.success),
                            SizedBox(width: 8),
                            Expanded(child: Text('WhatsApp Message')),
                          ],
                        ),
                      ),
                    ],
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
        },
      ),
        ],
      ),
    );
  }
}
